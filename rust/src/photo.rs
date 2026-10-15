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
    let mut img = decode(data)?;
    if let Some(crop)=o.crop {
        if crop.width==0 || crop.height==0 || crop.x.checked_add(crop.width).is_none_or(|v|v>img.width()) || crop.y.checked_add(crop.height).is_none_or(|v|v>img.height()) { return Err(invalid("Crop extends outside the orientation-corrected photo.")); }
        img=img.crop_imm(crop.x,crop.y,crop.width,crop.height);
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
    if o.format == OutputFormat::Jpeg
        && !o.flatten_transparency
        && img.to_rgba8().pixels().any(|p| p[3] < 255)
    {
        return Err(invalid(
            "JPEG cannot keep transparency. Choose PNG or explicitly allow a background colour.",
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
                image::codecs::jpeg::JpegEncoder::new_with_quality(&mut bytes, q)
                    .encode_image(&img)?;
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
            let mut buf = Cursor::new(Vec::new());
            img.write_to(&mut buf, ImageFormat::Png)?;
            let bytes = buf.into_inner();
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
    let format = match o.format {
        OutputFormat::Jpeg => "jpeg",
        OutputFormat::Png => "png",
    }
    .to_string();
    let info=OutputInfo{format,bytes:bytes.len() as u64,width:Some(o.width),height:Some(o.height),pages:None,quality,findings:vec![ValidationFinding{advisory:false,code:"verified".into(),message:"Encoded output reopened; dimensions, format and byte limit verified. Metadata removed; unprofiled pixels treated as sRGB.".into(),passed:true}]};
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
