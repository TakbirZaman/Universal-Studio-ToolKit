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
    encode_png_limited(image, Some(dpi), MAX_INPUT_BYTES)
}

/// Streaming IDAT output avoids png::write_image_data's full compressed-image
/// intermediate. Borrow 8-bit pixels and convert 16-bit samples one row at a time.
pub(crate) fn encode_png_limited(
    image: &DynamicImage,
    dpi: Option<u16>,
    limit: usize,
) -> Result<Vec<u8>> {
    use std::io::Write;
    if let Some(dpi) = dpi {
        validate_dpi(dpi)?;
    }
    if image.width() == 0
        || image.height() == 0
        || image.width() > 12000
        || image.height() > 12000
        || image.width() as u64 * image.height() as u64 > MAX_PIXELS
    {
        return Err(invalid("PNG dimensions exceed the supported image limits."));
    }
    let (color, depth, channels) = match image {
        DynamicImage::ImageLuma8(_) => (png::ColorType::Grayscale, png::BitDepth::Eight, 1),
        DynamicImage::ImageLumaA8(_) => (png::ColorType::GrayscaleAlpha, png::BitDepth::Eight, 2),
        DynamicImage::ImageRgb8(_) => (png::ColorType::Rgb, png::BitDepth::Eight, 3),
        DynamicImage::ImageRgba8(_) => (png::ColorType::Rgba, png::BitDepth::Eight, 4),
        DynamicImage::ImageLuma16(_) => (png::ColorType::Grayscale, png::BitDepth::Sixteen, 1),
        DynamicImage::ImageLumaA16(_) => {
            (png::ColorType::GrayscaleAlpha, png::BitDepth::Sixteen, 2)
        }
        DynamicImage::ImageRgb16(_) => (png::ColorType::Rgb, png::BitDepth::Sixteen, 3),
        DynamicImage::ImageRgba16(_) => (png::ColorType::Rgba, png::BitDepth::Sixteen, 4),
        _ => return Err(invalid("This PNG pixel representation is not supported.")),
    };
    let mut bytes = crate::buffer::BoundedBuffer::new(limit.min(MAX_INPUT_BYTES));
    let encoded = (|| -> Result<()> {
        let mut encoder = png::Encoder::new(&mut bytes, image.width(), image.height());
        encoder.set_compression(png::Compression::Fast);
        encoder.set_color(color);
        encoder.set_depth(depth);
        if let Some(dpi) = dpi {
            let per_metre = (f64::from(dpi) / 0.0254).round() as u32;
            encoder.set_pixel_dims(Some(png::PixelDimensions {
                xppu: per_metre,
                yppu: per_metre,
                unit: png::Unit::Meter,
            }));
        }
        let mut writer = encoder
            .write_header()
            .map_err(|_| invalid("Couldn’t encode the PNG header."))?;
        {
            let mut stream = writer
                .stream_writer_with_size(16 * 1024)
                .map_err(|_| invalid("Couldn’t start the PNG copy."))?;
            if depth == png::BitDepth::Eight {
                stream.write_all(image.as_bytes())?;
            } else {
                let samples = match image {
                    DynamicImage::ImageLuma16(v) => v.as_raw(),
                    DynamicImage::ImageLumaA16(v) => v.as_raw(),
                    DynamicImage::ImageRgb16(v) => v.as_raw(),
                    DynamicImage::ImageRgba16(v) => v.as_raw(),
                    _ => unreachable!(),
                };
                let row_samples = image.width() as usize * channels;
                let mut row = Vec::with_capacity(row_samples * 2);
                for samples in samples.chunks(row_samples) {
                    row.clear();
                    for value in samples {
                        row.extend_from_slice(&value.to_be_bytes());
                    }
                    stream.write_all(&row)?;
                }
            }
            stream
                .finish()
                .map_err(|_| invalid("Couldn’t finish the PNG pixels."))?;
        }
        writer
            .finish()
            .map_err(|_| invalid("Couldn’t finish the PNG copy."))?;
        Ok(())
    })();
    if bytes.exceeded {
        return Err(StudioError::ResourceLimit("PNG copy exceeds the encoded byte budget. Reduce dimensions or change the file-size requirement.".into()));
    }
    encoded?;
    Ok(bytes.into_inner())
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

#[cfg(test)]
mod streaming_tests {
    use super::*;
    #[test]
    fn bounded_stream_preserves_samples_and_print_density() {
        use image::{ImageBuffer, Luma, LumaA, Rgb, Rgba};
        let cases = vec![
            DynamicImage::ImageLuma8(ImageBuffer::from_fn(5, 3, |x, y| {
                Luma([(x * 23 + y * 41) as u8])
            })),
            DynamicImage::ImageLumaA8(ImageBuffer::from_fn(5, 3, |x, y| {
                LumaA([(x * 23) as u8, (y * 90) as u8])
            })),
            DynamicImage::ImageRgb8(ImageBuffer::from_fn(5, 3, |x, y| {
                Rgb([x as u8, y as u8, 123])
            })),
            DynamicImage::ImageRgba8(ImageBuffer::from_fn(5, 3, |x, y| {
                Rgba([x as u8, y as u8, 123, 77])
            })),
            DynamicImage::ImageLuma16(ImageBuffer::from_fn(5, 3, |x, y| {
                Luma([(x * 4097 + y * 257) as u16])
            })),
            DynamicImage::ImageLumaA16(ImageBuffer::from_fn(5, 3, |x, y| {
                LumaA([(x * 4097) as u16, (y * 12345) as u16])
            })),
            DynamicImage::ImageRgb16(ImageBuffer::from_fn(5, 3, |x, y| {
                Rgb([x as u16 * 4097, y as u16 * 257, 12345])
            })),
            DynamicImage::ImageRgba16(ImageBuffer::from_fn(5, 3, |x, y| {
                Rgba([x as u16 * 4097, y as u16 * 257, 12345, 65534])
            })),
        ];
        for image in cases {
            for dpi in [None, Some(300)] {
                let bytes = encode_png_limited(&image, dpi, 1024 * 1024).unwrap();
                let decoded = image::load_from_memory(&bytes).unwrap();
                assert_eq!(decoded.color(), image.color());
                assert_eq!(decoded.as_bytes(), image.as_bytes());
                let actual = read(&bytes, OutputFormat::Png).unwrap();
                if dpi.is_some() {
                    assert!((actual.unwrap().x_dpi - 300.).abs() < 0.013);
                } else {
                    assert!(actual.is_none());
                }
            }
        }
    }
    #[test]
    fn exact_encoded_budget_succeeds_and_one_byte_less_returns_no_partial_copy() {
        let mut seed = 123u32;
        let image = DynamicImage::ImageRgba8(image::ImageBuffer::from_fn(64, 64, |_, _| {
            let mut p = [0; 4];
            for value in &mut p {
                seed ^= seed << 13;
                seed ^= seed >> 17;
                seed ^= seed << 5;
                *value = seed as u8;
            }
            image::Rgba(p)
        }));
        let original = image.as_bytes().to_vec();
        let bytes = encode_png_limited(&image, None, MAX_INPUT_BYTES).unwrap();
        assert_eq!(
            encode_png_limited(&image, None, bytes.len()).unwrap(),
            bytes
        );
        assert!(matches!(
            encode_png_limited(&image, None, bytes.len() - 1),
            Err(StudioError::ResourceLimit(_))
        ));
        assert!(matches!(
            encode_png_limited(&image, Some(300), 32),
            Err(StudioError::ResourceLimit(_))
        ));
        assert_eq!(image.as_bytes(), original);
    }
}
