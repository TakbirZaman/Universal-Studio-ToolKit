//! Print density is technical output metadata, retained only by explicit request.
//! Image decoding/colour management remains in the image adapter.
use crate::model::*;
use image::DynamicImage;
use std::io::Cursor;

pub fn validate_dpi(dpi: u16) -> Result<()> {
    if !(1..=2400).contains(&dpi) {
        return Err(invalid("Print resolution must be between 1 and 2400 DPI."));
    }
    Ok(())
}

pub fn encode_png(image: &DynamicImage, dpi: u16) -> Result<Vec<u8>> {
    validate_dpi(dpi)?;
    let mut bytes = Vec::new();
    let mut encoder = png::Encoder::new(&mut bytes, image.width(), image.height());
    encoder.set_depth(png::BitDepth::Eight);
    encoder.set_compression(png::Compression::Fast);
    let per_metre = (f64::from(dpi) / 0.0254).round() as u32;
    encoder.set_pixel_dims(Some(png::PixelDimensions {
        xppu: per_metre,
        yppu: per_metre,
        unit: png::Unit::Meter,
    }));
    let pixels = if image.color().has_alpha() {
        encoder.set_color(png::ColorType::Rgba);
        image.to_rgba8().into_raw()
    } else {
        encoder.set_color(png::ColorType::Rgb);
        image.to_rgb8().into_raw()
    };
    let mut writer = encoder
        .write_header()
        .map_err(|_| invalid("Couldn’t encode the PNG print settings."))?;
    writer
        .write_image_data(&pixels)
        .map_err(|_| invalid("Couldn’t encode the PNG pixels."))?;
    writer
        .finish()
        .map_err(|_| invalid("Couldn’t finish the PNG copy."))?;
    Ok(bytes)
}

fn density(x: f64, y: f64) -> Result<Option<PrintDensity>> {
    if !x.is_finite() || !y.is_finite() || x <= 0.0 || y <= 0.0 {
        return Err(invalid("The image has invalid print-density metadata."));
    }
    Ok(Some(PrintDensity { x_dpi: x, y_dpi: y }))
}

pub fn read(data: &[u8], format: OutputFormat) -> Result<Option<PrintDensity>> {
    if data.len() > MAX_INPUT_BYTES {
        return Err(invalid("The encoded image exceeds the supported size."));
    }
    match format {
        OutputFormat::Png => {
            let decoder = png::Decoder::new_with_limits(
                Cursor::new(data),
                png::Limits {
                    bytes: 4 * 1024 * 1024,
                },
            );
            let reader = decoder
                .read_info()
                .map_err(|_| invalid("Couldn’t verify PNG print-density metadata."))?;
            match reader.info().pixel_dims {
                Some(value) if value.unit == png::Unit::Meter => density(
                    f64::from(value.xppu) * 0.0254,
                    f64::from(value.yppu) * 0.0254,
                ),
                _ => Ok(None), // Unspecified units describe aspect, not physical DPI.
            }
        }
        OutputFormat::Jpeg => read_jfif(data),
    }
}

fn read_jfif(data: &[u8]) -> Result<Option<PrintDensity>> {
    if !data.starts_with(&[0xff, 0xd8]) {
        return Err(invalid("Couldn’t verify JPEG print-density metadata."));
    }
    let mut offset = 2;
    let mut found = None;
    let mut jfif_seen = false;
    while offset < data.len() {
        if data[offset] != 0xff {
            return Err(invalid("JPEG marker metadata is malformed."));
        }
        while offset < data.len() && data[offset] == 0xff {
            offset += 1;
        }
        let marker = *data
            .get(offset)
            .ok_or_else(|| invalid("JPEG marker is truncated."))?;
        offset += 1;
        if marker == 0xda || marker == 0xd9 {
            return Ok(found);
        }
        if marker == 0x01 || (0xd0..=0xd7).contains(&marker) {
            continue;
        }
        let length_bytes = data
            .get(offset..offset + 2)
            .ok_or_else(|| invalid("JPEG segment is truncated."))?;
        let length = usize::from(u16::from_be_bytes([length_bytes[0], length_bytes[1]]));
        if length < 2 {
            return Err(invalid("JPEG segment length is invalid."));
        }
        let end = offset
            .checked_add(length)
            .filter(|&end| end <= data.len())
            .ok_or_else(|| invalid("JPEG segment exceeds the image."))?;
        let payload = &data[offset + 2..end];
        if marker == 0xe0 && payload.starts_with(b"JFIF\0") {
            if jfif_seen {
                return Err(invalid("JPEG contains multiple print-density headers."));
            }
            jfif_seen = true;
            if payload.len() < 14 {
                return Err(invalid("JPEG print-density metadata is truncated."));
            }
            let x = f64::from(u16::from_be_bytes([payload[8], payload[9]]));
            let y = f64::from(u16::from_be_bytes([payload[10], payload[11]]));
            let value = match payload[7] {
                0 => None,
                1 => density(x, y)?,
                2 => density(x * 2.54, y * 2.54)?,
                _ => return Err(invalid("JPEG print-density unit is unsupported.")),
            };
            if found.is_some() && found != value {
                return Err(invalid("JPEG contains conflicting print densities."));
            }
            found = value;
        }
        offset = end;
    }
    Err(invalid("JPEG header ended before image data."))
}
