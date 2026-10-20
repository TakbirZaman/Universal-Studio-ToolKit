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
    #[serde(default)]
    pub corners: Option<crate::vision::PageCorners>,
}
impl Default for ScanOptions {
    fn default() -> Self {
        Self {
            mode: ScanMode::Original,
            rotate_quarters: 0,
            brightness: 0,
            contrast: 0.,
            threshold: 128,
            corners: None,
        }
    }
}
#[derive(Debug, Clone)]
pub struct ScanAdvisory {
    pub code: String,
    pub message: String,
}
fn prepare(data: &[u8], options: &ScanOptions) -> Result<(image::DynamicImage, Vec<ScanAdvisory>)> {
    prepare_with_corners(data, options, options.corners)
}
fn prepare_with_corners(
    data: &[u8],
    options: &ScanOptions,
    corners: Option<crate::vision::PageCorners>,
) -> Result<(image::DynamicImage, Vec<ScanAdvisory>)> {
    if !(-100..=100).contains(&options.brightness)
        || !options.contrast.is_finite()
        || !(-100.0..=100.0).contains(&options.contrast)
    {
        return Err(invalid(
            "Brightness and contrast must be between -100 and 100.",
        ));
    }
    if let Some(corners) = corners {
        corners.validate()?;
    }
    let mut img = crate::photo::decode(data)?;
    if crate::photo::has_transparency(&img) {
        return Err(invalid(
            "Scan pages need an opaque background. Add a background in Photo Studio first.",
        ));
    }
    let reduced_depth = corners.is_some()
        && matches!(
            img.color(),
            image::ColorType::L16
                | image::ColorType::La16
                | image::ColorType::Rgb16
                | image::ColorType::Rgba16
                | image::ColorType::Rgb32F
                | image::ColorType::Rgba32F
        );
    if let Some(corners) = corners {
        img =
            image::DynamicImage::ImageRgba8(crate::vision::perspective(img.into_rgba8(), corners)?);
    }
    img = match options.rotate_quarters % 4 {
        1 => img.rotate90(),
        2 => img.rotate180(),
        3 => img.rotate270(),
        _ => img,
    };
    let mut advisories = quality_advisories(&img);
    if corners.is_some() {
        advisories.push(ScanAdvisory {
            code: "perspective_resampling".into(),
            message: "Page corners were corrected using interpolated pixels before rotation. Check fine text at full size. The original is unchanged.".into(),
        });
    }
    if reduced_depth {
        advisories.push(ScanAdvisory {
            code: "perspective_eight_bit".into(),
            message: "Perspective correction converted this page to 8-bit colour channels.".into(),
        });
    }
    if options.brightness != 0 {
        img = img.brighten(options.brightness);
    }
    // image's floating-point contrast conversion can quantize even at zero.
    // An unchanged appearance must keep the prepared pixel values exactly.
    if options.contrast != 0. {
        img = img.adjust_contrast(options.contrast);
    }
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
    Ok((img, advisories))
}
pub fn process(data: &[u8], options: &ScanOptions) -> Result<PreparedOutput> {
    encode_prepared(prepare(data, options)?)
}
fn encode_prepared(
    (img, advisories): (image::DynamicImage, Vec<ScanAdvisory>),
) -> Result<PreparedOutput> {
    let bytes = crate::density::encode_png_limited(&img, None, MAX_INPUT_BYTES)?;
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
    session_from_refs(
        &sources
            .iter()
            .zip(options)
            .map(|(data, options)| (data.as_slice(), options))
            .collect::<Vec<_>>(),
    )
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ScanPage {
    pub data: Vec<u8>,
    pub options: ScanOptions,
}
pub fn session_pages_pdf(pages: &[ScanPage]) -> Result<PreparedOutput> {
    session_from_refs(
        &pages
            .iter()
            .map(|page| (page.data.as_slice(), &page.options))
            .collect::<Vec<_>>(),
    )
}
fn session_from_refs(pages: &[(&[u8], &ScanOptions)]) -> Result<PreparedOutput> {
    if pages.is_empty() || pages.len() > MAX_PAGES {
        return Err(invalid("Select 1–200 scan pages."));
    }
    let total = pages
        .iter()
        .try_fold(0usize, |sum, (data, _)| sum.checked_add(data.len()))
        .ok_or_else(|| invalid("Scan source images exceed 64 MiB."))?;
    if total > MAX_INPUT_BYTES {
        return Err(invalid("Scan source images exceed 64 MiB."));
    }
    for (index, (_, edit)) in pages.iter().enumerate() {
        if let Some(corners) = edit.corners {
            corners
                .validate()
                .map_err(|error| invalid(&format!("Page {}: {}", index + 1, error)))?;
        }
        if !(-100..=100).contains(&edit.brightness)
            || !edit.contrast.is_finite()
            || !(-100.0..=100.0).contains(&edit.contrast)
        {
            return Err(invalid(
                "Brightness and contrast must be between -100 and 100.",
            ));
        }
    }
    let mut builder = crate::pdf::ImagePdfBuilder::new(&Default::default())?;
    let mut findings = vec![];
    for (index, (source, edit)) in pages.iter().enumerate() {
        let (img, advisories) = prepare(source, edit)
            .map_err(|error| invalid(&format!("Page {}: {}", index + 1, error)))?;
        builder.add(&img)?;
        for advisory in advisories {
            findings.push(ValidationFinding {
                advisory: true,
                code: advisory.code,
                message: format!("Page {}: {}", index + 1, advisory.message),
                passed: false,
            });
        }
    }
    let mut output = builder.finish()?;
    output.info.findings.extend(findings);
    output.info.findings.push(ValidationFinding { advisory: true, code: "scan_raster_pdf".into(), message: "Scan pages are encoded as JPEG at quality 95. This PDF contains page images, without selectable text.".into(), passed: true });
    crate::export::verify_output(&output)?;
    Ok(output)
}

pub fn preview(data: &[u8], options: &ScanOptions, max_pixels: u32) -> Result<PreparedOutput> {
    if !(128..=1600).contains(&max_pixels) {
        return Err(invalid("Image preview size must be 128–1600 pixels."));
    }
    let (img, advisories) = prepare(data, options)?;
    let mut result = crate::photo::display_preview(&img, max_pixels)?;
    result
        .info
        .findings
        .extend(advisories.into_iter().map(|a| ValidationFinding {
            advisory: true,
            code: a.code,
            message: a.message,
            passed: false,
        }));
    Ok(result)
}
