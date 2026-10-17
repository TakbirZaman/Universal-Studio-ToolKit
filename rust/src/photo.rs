use crate::model::*;
use image::{
    DynamicImage, GenericImageView, ImageDecoder, ImageFormat, ImageReader, Rgba, RgbaImage,
};
use std::io::Cursor;

pub fn decode(data: &[u8]) -> Result<DynamicImage> {
    if data.is_empty() || data.len() > MAX_INPUT_BYTES {
        return Err(invalid("Select an image smaller than 64 MiB."));
    }
    let mut r = ImageReader::new(Cursor::new(data)).with_guessed_format()?;
    if !matches!(r.format(), Some(ImageFormat::Jpeg | ImageFormat::Png)) {
        return Err(invalid("Choose a JPEG or PNG image."));
    }
    let mut limits = image::Limits::default();
    limits.max_image_width = Some(12000);
    limits.max_image_height = Some(12000);
    limits.max_alloc = Some(128 * 1024 * 1024);
    r.limits(limits);
    let mut decoder = r.into_decoder()?;
    let (w, h) = decoder.dimensions();
    if w as u64 * h as u64 > MAX_PIXELS {
        return Err(invalid("Image exceeds the 24 megapixel processing limit."));
    }
    let orientation = decoder.orientation()?;
    // Reject embedded ICC profiles until colour-managed conversion is available.
    if decoder.icc_profile()?.is_some() {
        return Err(invalid(
            "This image has an ICC colour profile. Colour-managed conversion is not available yet; export an sRGB copy first.",
        ));
    }
    let mut img = DynamicImage::from_decoder(decoder)?;
    img.apply_orientation(orientation);
    Ok(img)
}
fn has_transparency(image: &DynamicImage) -> bool {
    match image {
        DynamicImage::ImageRgba8(value) => value.pixels().any(|pixel| pixel[3] < u8::MAX),
        DynamicImage::ImageLumaA8(value) => value.pixels().any(|pixel| pixel[1] < u8::MAX),
        DynamicImage::ImageRgba16(value) => value.pixels().any(|pixel| pixel[3] < u16::MAX),
        DynamicImage::ImageLumaA16(value) => value.pixels().any(|pixel| pixel[1] < u16::MAX),
        _ => false,
    }
}

fn sixteen_bit(image: &DynamicImage) -> bool {
    matches!(
        image.color(),
        image::ColorType::L16
            | image::ColorType::La16
            | image::ColorType::Rgb16
            | image::ColorType::Rgba16
    )
}

pub fn prepare(data: &[u8], o: &PhotoOptions) -> Result<DynamicImage> {
    if o.width == 0
        || o.height == 0
        || o.width as u64 * o.height as u64 > MAX_PIXELS
        || o.width > 12000
        || o.height > 12000
    {
        return Err(invalid(
            "Enter positive dimensions within 24 megapixels and 12000 pixels per side.",
        ));
    }
    if !(1..=100).contains(&o.min_quality) {
        return Err(invalid("Minimum quality must be between 1 and 100."));
    }
    if let Some(dpi) = o.output_dpi {
        crate::density::validate_dpi(dpi)?;
    }
    let mut img = decode(data)?;
    if let Some(crop) = o.crop {
        if crop.width == 0
            || crop.height == 0
            || crop
                .x
                .checked_add(crop.width)
                .is_none_or(|v| v > img.width())
            || crop
                .y
                .checked_add(crop.height)
                .is_none_or(|v| v > img.height())
        {
            return Err(invalid(
                "Crop extends outside the orientation-corrected photo.",
            ));
        }
        img = img.crop_imm(crop.x, crop.y, crop.width, crop.height);
    }
    img = match o.rotate_quarters % 4 {
        1 => img.rotate90(),
        2 => img.rotate180(),
        3 => img.rotate270(),
        _ => img,
    };
    if o.flip_horizontal {
        img = img.fliph();
    }
    if let Some(threshold) = o.signature_threshold {
        if o.format != OutputFormat::Png {
            return Err(invalid("Use PNG for a transparent signature."));
        }
        let mut rgba = img.to_rgba8();
        for p in rgba.pixels_mut() {
            let v = (u16::from(p[0]) + u16::from(p[1]) + u16::from(p[2])) / 3;
            if v >= threshold as u16 {
                p[3] = 0;
            }
        }
        img = DynamicImage::ImageRgba8(rgba);
    }
    if o.format == OutputFormat::Jpeg && !o.flatten_transparency && has_transparency(&img) {
        return Err(invalid(
            "JPEG cannot keep transparency. Choose PNG or explicitly allow a background colour.",
        ));
    }
    let decoded_pixel_bytes = match o.fit {
        Fit::Contain => 8,
        Fit::Cover => u64::from(img.color().bytes_per_pixel()),
    };
    if o.format == OutputFormat::Png
        && sixteen_bit(&img)
        && u64::from(o.width) * u64::from(o.height) * decoded_pixel_bytes > 128 * 1024 * 1024
    {
        return Err(invalid(
            "16-bit output exceeds the 128 MiB decoded-image limit. Reduce its dimensions.",
        ));
    }
    let f = image::imageops::FilterType::Lanczos3;
    img = match o.fit {
        Fit::Cover => img.resize_to_fill(o.width, o.height, f),
        Fit::Contain => {
            let resized = img.resize(o.width, o.height, f);
            let alpha = if o.format == OutputFormat::Png {
                0
            } else {
                255
            };
            if o.format == OutputFormat::Png && sixteen_bit(&resized) {
                let mut canvas = image::ImageBuffer::<Rgba<u16>, Vec<u16>>::from_pixel(
                    o.width,
                    o.height,
                    Rgba([
                        u16::from(o.background[0]) * 257,
                        u16::from(o.background[1]) * 257,
                        u16::from(o.background[2]) * 257,
                        0,
                    ]),
                );
                image::imageops::overlay(
                    &mut canvas,
                    &resized.to_rgba16(),
                    ((o.width - resized.width()) / 2).into(),
                    ((o.height - resized.height()) / 2).into(),
                );
                DynamicImage::ImageRgba16(canvas)
            } else {
                let mut canvas = RgbaImage::from_pixel(
                    o.width,
                    o.height,
                    Rgba([o.background[0], o.background[1], o.background[2], alpha]),
                );
                image::imageops::overlay(
                    &mut canvas,
                    &resized,
                    ((o.width - resized.width()) / 2).into(),
                    ((o.height - resized.height()) / 2).into(),
                );
                DynamicImage::ImageRgba8(canvas)
            }
        }
    };
    if o.format == OutputFormat::Jpeg {
        let mut rgba = img.to_rgba8();
        let transparent = rgba.pixels().any(|p| p[3] < 255);
        if transparent && !o.flatten_transparency {
            return Err(invalid(
                "JPEG cannot keep transparency. Choose PNG or explicitly allow a background colour.",
            ));
        }
        for p in rgba.pixels_mut() {
            let a = u32::from(p[3]);
            for c in 0..3 {
                p[c] = ((u32::from(p[c]) * a + u32::from(o.background[c]) * (255 - a) + 127) / 255)
                    as u8;
            }
            p[3] = 255;
        }
        img = DynamicImage::ImageRgb8(DynamicImage::ImageRgba8(rgba).to_rgb8());
    }
    Ok(img)
}
pub fn process(data: &[u8], o: &PhotoOptions) -> Result<PreparedOutput> {
    process_cancellable(data, o, &|| false)
}
pub fn process_cancellable(
    data: &[u8],
    o: &PhotoOptions,
    cancel: &dyn Fn() -> bool,
) -> Result<PreparedOutput> {
    if cancel() {
        return Err(StudioError::Cancelled);
    }
    let img = prepare(data, o)?;
    let mut best = None;
    match o.format {
        OutputFormat::Jpeg => {
            // Exhaustive bounded search: each candidate comes from the same prepared pixels.
            for q in (o.min_quality..=100).rev() {
                if cancel() {
                    return Err(StudioError::Cancelled);
                }
                let mut bytes = Vec::new();
                let mut encoder = image::codecs::jpeg::JpegEncoder::new_with_quality(&mut bytes, q);
                if let Some(dpi) = o.output_dpi {
                    encoder.set_pixel_density(image::codecs::jpeg::PixelDensity::dpi(dpi));
                }
                encoder.encode_image(&img)?;
                if o.max_bytes
                    .map(|l| l.accepts(bytes.len()))
                    .transpose()?
                    .unwrap_or(true)
                {
                    best = Some((bytes, Some(q)));
                    break;
                }
            }
        }
        OutputFormat::Png => {
            let bytes = if let Some(dpi) = o.output_dpi {
                crate::density::encode_png(&img, dpi)?
            } else {
                let mut buf = Cursor::new(Vec::new());
                img.write_to(&mut buf, ImageFormat::Png)?;
                buf.into_inner()
            };
            if o.max_bytes
                .map(|l| l.accepts(bytes.len()))
                .transpose()?
                .unwrap_or(true)
            {
                best = Some((bytes, None));
            }
        }
    }
    let (bytes, quality) = best.ok_or(StudioError::Impossible)?;
    if cancel() {
        return Err(StudioError::Cancelled);
    }
    let decoded = decode(&bytes)?;
    if decoded.dimensions() != (o.width, o.height) {
        return Err(invalid("Output dimensions did not pass verification."));
    }
    let print_density = crate::density::read(&bytes, o.format)?;
    if let Some(requested) = o.output_dpi {
        let actual =
            print_density.ok_or_else(|| invalid("Print-density metadata was not saved."))?;
        if (actual.x_dpi - f64::from(requested)).abs() > 0.013
            || (actual.y_dpi - f64::from(requested)).abs() > 0.013
        {
            return Err(invalid(
                "Saved print density did not meet the requested DPI.",
            ));
        }
    } else if print_density.is_some() {
        return Err(invalid(
            "Print-density metadata was retained without a request.",
        ));
    }
    let format = match o.format {
        OutputFormat::Jpeg => "jpeg",
        OutputFormat::Png => "png",
    }
    .to_string();
    let info=OutputInfo{format,bytes:bytes.len() as u64,width:Some(o.width),height:Some(o.height),pages:None,quality,print_density,findings:vec![ValidationFinding{advisory:false,code:"verified".into(),message:"Encoded output reopened; dimensions, format and byte limit verified. Personal metadata removed; unprofiled pixels treated as sRGB.".into(),passed:true}]};
    let mut info = info;
    if let Some(density) = print_density {
        info.findings.push(ValidationFinding {
            advisory: true, code: "print_density_verified".into(), passed: true,
            message: format!("Print resolution verified: {:.4} × {:.4} DPI; actual print size {:.2} × {:.2} mm. Pixel rounding applies. Print at Actual size / 100%.", density.x_dpi, density.y_dpi, f64::from(o.width) / density.x_dpi * 25.4, f64::from(o.height) / density.y_dpi * 25.4),
        });
    }
    Ok(PreparedOutput { data: bytes, info })
}
pub fn physical_pixels(mm: f64, dpi: f64) -> Result<u32> {
    if !mm.is_finite() || !dpi.is_finite() || mm <= 0.0 || dpi <= 0.0 || mm * dpi / 25.4 > 12000.0 {
        return Err(invalid(
            "Enter valid millimetres and DPI within the size limit.",
        ));
    }
    let pixels = (mm * dpi / 25.4).round() as u32;
    if pixels == 0 {
        return Err(invalid("Physical size rounds to zero pixels."));
    }
    Ok(pixels)
}

pub fn process_physical(
    data: &[u8],
    spec: &PhysicalPhotoSpec,
    options: &PhotoOptions,
) -> Result<PreparedOutput> {
    crate::density::validate_dpi(spec.dpi)?;
    let mut options = options.clone();
    options.width = physical_pixels(spec.width_mm, f64::from(spec.dpi))?;
    options.height = physical_pixels(spec.height_mm, f64::from(spec.dpi))?;
    options.output_dpi = Some(spec.dpi);
    process(data, &options)
}
