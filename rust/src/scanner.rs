use crate::model::*;
use serde::{Deserialize, Serialize};
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ScanMode {
    Original,
    Colour,
    Grayscale,
    BlackWhite,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ScanOptions {
    pub mode: ScanMode,
    pub rotate_quarters: u8,
    pub brightness: i32,
    pub contrast: f32,
    pub threshold: u8,
}
impl Default for ScanOptions {
    fn default() -> Self {
        Self {
            mode: ScanMode::Original,
            rotate_quarters: 0,
            brightness: 0,
            contrast: 0.,
            threshold: 128,
        }
    }
}
#[derive(Debug, Clone)]
pub struct ScanAdvisory {
    pub code: String,
    pub message: String,
}
pub fn process(data: &[u8], options: &ScanOptions) -> Result<PreparedOutput> {
    if !(-100..=100).contains(&options.brightness)
        || !options.contrast.is_finite()
        || !(-100.0..=100.0).contains(&options.contrast)
    {
        return Err(invalid(
            "Brightness and contrast must be between -100 and 100.",
        ));
    }
    let mut img = crate::photo::decode(data)?;
    if img.to_rgba8().pixels().any(|p| p[3] != 255) {
        return Err(invalid(
            "Scan pages need an opaque background. Add a background in Photo Studio first.",
        ));
    }
    img = match options.rotate_quarters % 4 {
        1 => img.rotate90(),
        2 => img.rotate180(),
        3 => img.rotate270(),
        _ => img,
    };
    let advisories = quality_advisories(&img);
    img = img
        .brighten(options.brightness)
        .adjust_contrast(options.contrast);
    img = match options.mode {
        ScanMode::Original => img,
        ScanMode::Colour => img.adjust_contrast(10.),
        ScanMode::Grayscale => img.grayscale(),
        ScanMode::BlackWhite => {
            let mut gray = img.to_luma8();
            for p in gray.pixels_mut() {
                p[0] = if p[0] >= options.threshold { 255 } else { 0 };
            }
            image::DynamicImage::ImageLuma8(gray)
        }
    };
    let mut bytes = std::io::Cursor::new(Vec::new());
    img.write_to(&mut bytes, image::ImageFormat::Png)?;
    let bytes = bytes.into_inner();
    let mut findings=vec![ValidationFinding{advisory:false,code:"scan_adjusted".into(),message:"Page adjustments encoded to PNG and reopened. Original pixels are retained separately by the session.".into(),passed:true}];
    for a in advisories {
        findings.push(ValidationFinding {
            advisory: true,
            code: a.code,
            message: a.message,
            passed: false,
        });
    }
    let result = PreparedOutput {
        info: OutputInfo {
            format: "png".into(),
            bytes: bytes.len() as u64,
            width: Some(img.width()),
            height: Some(img.height()),
            pages: None,
            quality: None,
            print_density: None,
            findings,
        },
        data: bytes,
    };
    crate::export::verify_output(&result)?;
    Ok(result)
}
/// Advisory-only heuristics evaluated on a bounded thumbnail. Blank pages can trigger blur warnings.
pub fn quality_advisories(img: &image::DynamicImage) -> Vec<ScanAdvisory> {
    let gray = img.thumbnail(512, 512).to_luma8();
    let (w, h) = gray.dimensions();
    let count = (w as u64 * h as u64).max(1) as f64;
    let dark = gray.pixels().filter(|p| p[0] < 12).count() as f64 / count;
    let bright = gray.pixels().filter(|p| p[0] > 248).count() as f64 / count;
    let mut result = Vec::new();
    if dark > 0.50 {
        result.push(ScanAdvisory {
            code: "exposure_dark".into(),
            message: "Advisory: much of this page is very dark. Check lighting and readability."
                .into(),
        });
    }
    if bright > 0.85 {
        result.push(ScanAdvisory{code:"exposure_bright".into(),message:"Advisory: most of this page is nearly white. Check for lost faint text; a blank page may also trigger this warning.".into()});
    }
    if w >= 3 && h >= 3 {
        let (mut sum, mut squared, mut n) = (0., 0., 0.);
        for y in 1..h - 1 {
            for x in 1..w - 1 {
                let p = |x, y| f64::from(gray.get_pixel(x, y)[0]);
                let lap = p(x - 1, y) + p(x + 1, y) + p(x, y - 1) + p(x, y + 1) - 4. * p(x, y);
                sum += lap;
                squared += lap * lap;
                n += 1.;
            }
        }
        if squared / n - (sum / n).powi(2) < 25. {
            result.push(ScanAdvisory{code:"possible_blur".into(),message:"Advisory: little sharp detail was detected. Check focus at full size; blank areas can produce the same result.".into()});
        }
        let mut boundary_dark = 0;
        let mut boundary_count = 0;
        for x in 0..w {
            for y in [0, h - 1] {
                boundary_count += 1;
                if gray.get_pixel(x, y)[0] < 80 {
                    boundary_dark += 1;
                }
            }
        }
        for y in 1..h - 1 {
            for x in [0, w - 1] {
                boundary_count += 1;
                if gray.get_pixel(x, y)[0] < 80 {
                    boundary_dark += 1;
                }
            }
        }
        if boundary_dark as f64 / boundary_count as f64 > 0.15 {
            result.push(ScanAdvisory{code:"possible_clipping".into(),message:"Advisory: dark content touches the image edge. Check whether text or page borders were cut off.".into()});
        }
    }
    result
}
pub fn session_pdf(sources: &[Vec<u8>], options: &[ScanOptions]) -> Result<PreparedOutput> {
    if sources.len() != options.len() || sources.is_empty() {
        return Err(invalid("Every scan page needs matching edit settings."));
    }
    if sources.iter().map(Vec::len).sum::<usize>() > MAX_INPUT_BYTES {
        return Err(invalid("Scan source images exceed 64 MiB."));
    }
    let mut pages = Vec::new();
    let mut total = 0usize;
    for (source, edit) in sources.iter().zip(options) {
        let out = process(source, edit)?;
        total += out.data.len();
        if total > MAX_INPUT_BYTES {
            return Err(invalid(
                "Adjusted pages exceed 64 MiB. Export fewer pages at once.",
            ));
        }
        pages.push(out.data);
    }
    crate::pdf::images_to_pdf(&pages, &Default::default())
}
