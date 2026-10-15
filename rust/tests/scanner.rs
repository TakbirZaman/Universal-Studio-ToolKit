use image::{DynamicImage, ImageFormat, Rgb, RgbImage};
use studio_core::scanner::*;
fn encode(img: DynamicImage) -> Vec<u8> {
    let mut b = std::io::Cursor::new(Vec::new());
    img.write_to(&mut b, ImageFormat::Png).unwrap();
    b.into_inner()
}
#[test]
fn scan_modes_rotate_without_mutating_source() {
    let image = DynamicImage::ImageRgb8(RgbImage::from_fn(40, 20, |x, y| {
        Rgb([(x * 5) as u8, (y * 10) as u8, 200])
    }));
    let source = encode(image);
    let original = source.clone();
    for mode in [
        ScanMode::Original,
        ScanMode::Colour,
        ScanMode::Grayscale,
        ScanMode::BlackWhite,
    ] {
        let out = process(
            &source,
            &ScanOptions {
                mode,
                rotate_quarters: 1,
                ..Default::default()
            },
        )
        .unwrap();
        assert_eq!((out.info.width, out.info.height), (Some(20), Some(40)));
        let img = studio_core::photo::decode(&out.data).unwrap().to_rgb8();
        if matches!(mode, ScanMode::BlackWhite) {
            assert!(img.pixels().all(|p| p[0] == 0 || p[0] == 255));
        }
    }
    assert_eq!(source, original);
}
#[test]
fn quality_warnings_are_advisory_and_detect_known_cases() {
    let dark = DynamicImage::ImageRgb8(RgbImage::from_pixel(100, 100, Rgb([0, 0, 0])));
    let bright = DynamicImage::ImageRgb8(RgbImage::from_pixel(100, 100, Rgb([255, 255, 255])));
    assert!(
        quality_advisories(&dark)
            .iter()
            .any(|a| a.code == "exposure_dark")
    );
    assert!(
        quality_advisories(&bright)
            .iter()
            .any(|a| a.code == "exposure_bright")
    );
    assert!(process(&encode(bright), &ScanOptions::default()).is_ok());
}
#[test]
fn scan_session_reorders_and_checks_edits() {
    let source = encode(DynamicImage::ImageRgb8(RgbImage::from_pixel(
        100,
        200,
        Rgb([250, 250, 250]),
    )));
    let out = session_pdf(
        &[source.clone(), source.clone(), source.clone()],
        &[
            ScanOptions::default(),
            ScanOptions::default(),
            ScanOptions::default(),
        ],
    )
    .unwrap();
    assert_eq!(out.info.pages, Some(3));
    assert!(session_pdf(&[source.clone()], &[]).is_err());
    assert!(
        process(
            &source,
            &ScanOptions {
                contrast: f32::NAN,
                ..Default::default()
            }
        )
        .is_err()
    );
}
