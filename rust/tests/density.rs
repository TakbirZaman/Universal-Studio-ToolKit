use image::DynamicImage;
use std::io::Cursor;
use studio_core::{density, export, model::*, photo};

fn source() -> Vec<u8> {
    let image = image::RgbaImage::from_fn(80, 100, |x, y| {
        image::Rgba([
            (x * 3) as u8,
            (y * 2) as u8,
            120,
            if x < 10 { 0 } else { 255 },
        ])
    });
    let mut bytes = Cursor::new(Vec::new());
    DynamicImage::ImageRgba8(image)
        .write_to(&mut bytes, image::ImageFormat::Png)
        .unwrap();
    bytes.into_inner()
}

#[test]
fn physical_jpeg_and_png_reopen_with_actual_density_pixels_and_limits() {
    let input = source();
    let original = input.clone();
    for format in [OutputFormat::Jpeg, OutputFormat::Png] {
        let options = PhotoOptions {
            format,
            flatten_transparency: format == OutputFormat::Jpeg,
            max_bytes: Some(ByteLimit {
                value: 100,
                unit: SizeUnit::KiB,
                strict: true,
            }),
            ..Default::default()
        };
        let output = photo::process_physical(
            &input,
            &PhysicalPhotoSpec {
                width_mm: 35.0,
                height_mm: 45.0,
                dpi: 300,
            },
            &options,
        )
        .unwrap();
        assert_eq!(
            (output.info.width, output.info.height),
            (Some(413), Some(531))
        );
        assert!(output.data.len() < 102400);
        assert_eq!(output.info.bytes as usize, output.data.len());
        let actual = density::read(&output.data, format).unwrap().unwrap();
        assert!((actual.x_dpi - 300.0).abs() < 0.013);
        assert!((actual.y_dpi - 300.0).abs() < 0.013);
        assert_eq!(output.info.print_density, Some(actual));
        export::verify_output(&output).unwrap();
        if format == OutputFormat::Png {
            assert!(
                photo::decode(&output.data)
                    .unwrap()
                    .to_rgba8()
                    .pixels()
                    .any(|p| p[3] == 0)
            );
        }
        let mut forged = output;
        forged.info.print_density = Some(PrintDensity {
            x_dpi: 72.0,
            y_dpi: 72.0,
        });
        assert!(export::verify_output(&forged).is_err());
    }
    assert_eq!(input, original);
}

#[test]
fn invalid_physical_requests_do_not_decode_or_silently_resize() {
    for spec in [
        PhysicalPhotoSpec {
            width_mm: f64::NAN,
            height_mm: 45.0,
            dpi: 300,
        },
        PhysicalPhotoSpec {
            width_mm: 35.0,
            height_mm: f64::INFINITY,
            dpi: 300,
        },
        PhysicalPhotoSpec {
            width_mm: 35.0,
            height_mm: 45.0,
            dpi: 0,
        },
        PhysicalPhotoSpec {
            width_mm: 35.0,
            height_mm: 45.0,
            dpi: 2401,
        },
        PhysicalPhotoSpec {
            width_mm: 100000.0,
            height_mm: 45.0,
            dpi: 300,
        },
        PhysicalPhotoSpec {
            width_mm: 0.00001,
            height_mm: 45.0,
            dpi: 300,
        },
    ] {
        assert!(
            photo::process_physical(b"invalid source", &spec, &PhotoOptions::default()).is_err()
        );
    }
    let output = photo::process(
        &source(),
        &PhotoOptions {
            format: OutputFormat::Png,
            ..Default::default()
        },
    )
    .unwrap();
    assert_eq!(output.info.print_density, None);
    assert_eq!(
        density::read(&output.data, OutputFormat::Png).unwrap(),
        None
    );
}

#[test]
fn malformed_or_ambiguous_jfif_headers_fail_without_panicking() {
    for data in [
        vec![],
        vec![0xff, 0xd8, 0xff],
        vec![0xff, 0xd8, 0xff, 0xe0, 0, 1],
        vec![0xff, 0xd8, 0xff, 0xe0, 0xff, 0xff],
    ] {
        assert!(density::read(&data, OutputFormat::Jpeg).is_err());
    }
    let mut bytes = Vec::new();
    let image = photo::decode(&source()).unwrap();
    let mut encoder = image::codecs::jpeg::JpegEncoder::new_with_quality(&mut bytes, 90);
    encoder.set_pixel_density(image::codecs::jpeg::PixelDensity::dpi(300));
    encoder.encode_image(&image).unwrap();
    let length = usize::from(u16::from_be_bytes([bytes[4], bytes[5]]));
    let first = bytes[2..4 + length].to_vec();
    bytes.splice(2..2, first);
    assert!(density::read(&bytes, OutputFormat::Jpeg).is_err());
}

#[test]
fn pixel_rounding_and_density_are_explicit_and_not_privacy_tags() {
    let output = photo::process_physical(
        &source(),
        &PhysicalPhotoSpec {
            width_mm: 35.0,
            height_mm: 45.0,
            dpi: 300,
        },
        &PhotoOptions {
            flatten_transparency: true,
            ..Default::default()
        },
    )
    .unwrap();
    assert!(output.info.findings.iter().any(
        |finding| finding.code == "print_density_verified" && finding.message.contains("34.97")
    ));
    let encoded = serde_json::to_vec(&output.info).unwrap();
    let decoded: OutputInfo = serde_json::from_slice(&encoded).unwrap();
    assert_eq!(decoded.print_density, output.info.print_density);
    let text = studio_core::ocr::text_output(b"synthetic text".to_vec()).unwrap();
    let mut forged = text;
    forged.info.print_density = output.info.print_density;
    assert!(export::verify_output(&forged).is_err());
}
