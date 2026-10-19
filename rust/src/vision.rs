//! Lazy pixel-only scanner adapter. No document paths are passed to C++.
use crate::model::{MAX_PIXELS, Result, invalid};
use image::RgbaImage;
use libloading::Library;
use serde::{Deserialize, Serialize};
use std::{
    path::PathBuf,
    sync::{Mutex, OnceLock},
};

/// Normalized pixel centres on the EXIF-oriented source, before page rotation.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq)]
#[serde(deny_unknown_fields)]
pub struct PagePoint {
    pub x: f64,
    pub y: f64,
}

/// Clockwise corners: top left, top right, bottom right, bottom left.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq)]
#[serde(deny_unknown_fields)]
pub struct PageCorners {
    pub top_left: PagePoint,
    pub top_right: PagePoint,
    pub bottom_right: PagePoint,
    pub bottom_left: PagePoint,
}
impl Default for PageCorners {
    fn default() -> Self {
        Self {
            top_left: PagePoint { x: 0., y: 0. },
            top_right: PagePoint { x: 1., y: 0. },
            bottom_right: PagePoint { x: 1., y: 1. },
            bottom_left: PagePoint { x: 0., y: 1. },
        }
    }
}
impl PageCorners {
    fn points(self) -> [PagePoint; 4] {
        [
            self.top_left,
            self.top_right,
            self.bottom_right,
            self.bottom_left,
        ]
    }
    pub fn validate(self) -> Result<()> {
        let points = self.points();
        let mut area = 0.;
        for i in 0..4 {
            let a = points[i];
            let b = points[(i + 1) % 4];
            let c = points[(i + 2) % 4];
            if !a.x.is_finite()
                || !a.y.is_finite()
                || !(0.0..=1.0).contains(&a.x)
                || !(0.0..=1.0).contains(&a.y)
                || (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x) <= 0.000001
            {
                return Err(invalid(
                    "Place four distinct corners clockwise around the page, inside the image.",
                ));
            }
            area += a.x * b.y - b.x * a.y;
        }
        if area < 0.02 {
            return Err(invalid(
                "The page corners must cover at least 1% of the source image.",
            ));
        }
        Ok(())
    }
    /// Keep the longer opposite edge on each axis; never silently scale to fit a limit.
    pub fn output_dimensions(self, width: u32, height: u32) -> Result<(u32, u32)> {
        self.validate()?;
        dimensions(width, height)?;
        let p = self.points();
        let edge = |a: usize, b: usize| {
            ((p[a].x - p[b].x) * f64::from(width - 1))
                .hypot((p[a].y - p[b].y) * f64::from(height - 1))
        };
        let w = edge(0, 1).max(edge(3, 2)).round() as u32 + 1;
        let h = edge(0, 3).max(edge(1, 2)).round() as u32 + 1;
        dimensions(w, h)?;
        Ok((w, h))
    }
    fn xy(self) -> [f64; 8] {
        let p = self.points();
        [
            p[0].x, p[0].y, p[1].x, p[1].y, p[2].x, p[2].y, p[3].x, p[3].y,
        ]
    }
}
fn dimensions(w: u32, h: u32) -> Result<()> {
    if !(2..=12000).contains(&w)
        || !(2..=12000).contains(&h)
        || u64::from(w) * u64::from(h) > MAX_PIXELS
    {
        return Err(invalid(
            "Perspective correction needs 2–12000 pixels per side and at most 24 million pixels. Choose a smaller source or adjust the corners.",
        ));
    }
    Ok(())
}
type Version = unsafe extern "C" fn() -> u32;
type Warp = unsafe extern "C" fn(
    *const u8,
    u32,
    u32,
    usize,
    *const f64,
    usize,
    *mut u8,
    u32,
    u32,
    usize,
) -> i32;
type Suggest = unsafe extern "C" fn(*const u8, u32, u32, usize, *mut f64, usize) -> i32;
struct Engine {
    // Function pointers remain valid because this library lives in the same static.
    _library: Library,
    warp: Warp,
    suggest: Suggest,
}
static ENGINE: OnceLock<Engine> = OnceLock::new();
static ENGINE_LOCK: Mutex<()> = Mutex::new(());
fn unavailable() -> crate::model::StudioError {
    invalid(
        "Page corner correction is unavailable because its local processing library is missing or incompatible. Your original is unchanged.",
    )
}
fn library_path() -> Result<PathBuf> {
    if let Some(path) = std::env::var_os("UST_VISION_LIBRARY") {
        // Explicit developer override only; recipes and document metadata cannot set this.
        return Ok(path.into());
    }
    if cfg!(target_os = "android") {
        return Ok("libust_cv.so".into());
    }
    let exe = std::env::current_exe().map_err(|_| unavailable())?;
    let base = exe.parent().ok_or_else(unavailable)?;
    Ok(if cfg!(target_os = "windows") {
        base.join("ust_cv.dll")
    } else {
        base.join("lib/libust_cv.so")
    })
}
// Caller holds ENGINE_LOCK, including initialization and all native calls.
fn engine() -> Result<&'static Engine> {
    if let Some(engine) = ENGINE.get() {
        return Ok(engine);
    }
    let path = library_path()?;
    // SAFETY: only an explicitly provisioned native adapter is loaded. Required
    // symbols and ABI/engine versions are checked before any pixel call.
    let loaded = unsafe {
        let library = Library::new(path).map_err(|_| unavailable())?;
        let abi = *library
            .get::<Version>(b"ust_cv_abi_version\0")
            .map_err(|_| unavailable())?;
        let version = *library
            .get::<Version>(b"ust_cv_engine_version\0")
            .map_err(|_| unavailable())?;
        if abi() != 1 || version() != 50000 {
            return Err(unavailable());
        }
        let warp = *library
            .get::<Warp>(b"ust_cv_warp_rgba\0")
            .map_err(|_| unavailable())?;
        let suggest = *library
            .get::<Suggest>(b"ust_cv_suggest_rgba\0")
            .map_err(|_| unavailable())?;
        Engine {
            _library: library,
            warp,
            suggest,
        }
    };
    let _ = ENGINE.set(loaded);
    ENGINE.get().ok_or_else(unavailable)
}
pub fn available() -> bool {
    let Ok(_guard) = ENGINE_LOCK.lock() else {
        return false;
    };
    engine().is_ok()
}
pub fn perspective(source: RgbaImage, corners: PageCorners) -> Result<RgbaImage> {
    let (w, h) = corners.output_dimensions(source.width(), source.height())?;
    let length = usize::try_from(u64::from(w) * u64::from(h) * 4)
        .map_err(|_| invalid("Corrected page is too large."))?;
    let mut bytes = Vec::new();
    bytes.try_reserve_exact(length).map_err(|_| {
        invalid("There is not enough memory to correct this page. Try a smaller source.")
    })?;
    bytes.resize(length, 0);
    let xy = corners.xy();
    let _guard = ENGINE_LOCK.lock().map_err(|_| unavailable())?;
    let engine = engine()?;
    // SAFETY: both buffers are disjoint, contiguous RGBA8 with validated dimensions,
    // exact lengths, and live for the whole synchronous call. xy has eight doubles.
    let code = unsafe {
        (engine.warp)(
            source.as_ptr(),
            source.width(),
            source.height(),
            source.as_raw().len(),
            xy.as_ptr(),
            xy.len(),
            bytes.as_mut_ptr(),
            w,
            h,
            bytes.len(),
        )
    };
    if code != 0 {
        return Err(invalid(
            "The page could not be corrected. Check the corners or try a smaller image. Your original is unchanged.",
        ));
    }
    RgbaImage::from_raw(w, h, bytes)
        .ok_or_else(|| invalid("The corrected image buffer is invalid."))
}
pub fn suggest(source: &RgbaImage) -> Result<Option<PageCorners>> {
    dimensions(source.width(), source.height())?;
    let mut xy = [0.; 8];
    let _guard = ENGINE_LOCK.lock().map_err(|_| unavailable())?;
    let engine = engine()?;
    // SAFETY: source is a live contiguous RGBA8 buffer; xy is eight writable doubles.
    let code = unsafe {
        (engine.suggest)(
            source.as_ptr(),
            source.width(),
            source.height(),
            source.as_raw().len(),
            xy.as_mut_ptr(),
            xy.len(),
        )
    };
    if code == 1 {
        return Ok(None);
    }
    if code != 0 {
        return Err(invalid(
            "Page edges could not be suggested. Set the corners manually.",
        ));
    }
    let corners = PageCorners {
        top_left: PagePoint { x: xy[0], y: xy[1] },
        top_right: PagePoint { x: xy[2], y: xy[3] },
        bottom_right: PagePoint { x: xy[4], y: xy[5] },
        bottom_left: PagePoint { x: xy[6], y: xy[7] },
    };
    corners.validate()?;
    Ok(Some(corners))
}
