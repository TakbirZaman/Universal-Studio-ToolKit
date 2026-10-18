use image::{DynamicImage, ImageFormat, Rgb, RgbImage};
use studio_core::{export, model::*, photo};
fn noise() -> Vec<u8> {
    let mut seed = 12345u32;
    let img = DynamicImage::ImageRgb8(RgbImage::from_fn(128, 128, |_, _| {
        let mut channels = [0; 3];
        for v in &mut channels {
            seed ^= seed << 13;
            seed ^= seed >> 17;
            seed ^= seed << 5;
            *v = seed as u8;
        }
        Rgb(channels)
    }));
    let mut bytes = std::io::Cursor::new(Vec::new());
    img.write_to(&mut bytes, ImageFormat::Png).unwrap();
    bytes.into_inner()
}
#[test]
fn oversized_jpeg_candidates_continue_from_fresh_prepared_pixels() {
    let data = noise();
    let original = data.clone();
    let mut options = PhotoOptions {
        width: 128,
        height: 128,
        min_quality: 35,
        ..Default::default()
    };
    let unconstrained = photo::process(&data, &options).unwrap();
    let fresh = photo::prepare(&data, &options).unwrap();
    let mut minimum_candidate = Vec::new();
    image::codecs::jpeg::JpegEncoder::new_with_quality(&mut minimum_candidate, 35)
        .encode_image(&fresh)
        .unwrap();
    let target_kib = minimum_candidate.len().div_ceil(1024) as u64 + 1;
    assert!(unconstrained.data.len() > target_kib as usize * 1024);
    options.max_bytes = Some(ByteLimit {
        value: target_kib,
        unit: SizeUnit::KiB,
        strict: true,
    });
    let output = photo::process(&data, &options).unwrap();
    assert!(output.data.len() < target_kib as usize * 1024);
    assert!(output.info.quality.unwrap() < 100);
    assert!(output.info.quality.unwrap() >= 35);
    let pixels = photo::prepare(&data, &options).unwrap();
    let mut independently_encoded = Vec::new();
    image::codecs::jpeg::JpegEncoder::new_with_quality(
        &mut independently_encoded,
        output.info.quality.unwrap(),
    )
    .encode_image(&pixels)
    .unwrap();
    assert_eq!(output.data, independently_encoded);
    export::verify_output(&output).unwrap();
    assert_eq!(data, original);
}
#[test]
fn png_user_limit_reports_unmet_constraints_without_returning_a_truncated_image() {
    let data = noise();
    let options = PhotoOptions {
        width: 128,
        height: 128,
        format: OutputFormat::Png,
        max_bytes: Some(ByteLimit {
            value: 1,
            unit: SizeUnit::KiB,
            strict: false,
        }),
        ..Default::default()
    };
    assert!(matches!(
        photo::process(&data, &options),
        Err(StudioError::Impossible)
    ));
    let mut invalid = options;
    invalid.max_bytes = Some(ByteLimit {
        value: u64::MAX,
        unit: SizeUnit::KiB,
        strict: false,
    });
    assert!(
        photo::process(&[], &invalid)
            .unwrap_err()
            .to_string()
            .contains("File size limit is too large")
    );
}
