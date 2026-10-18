use image::{DynamicImage, ImageFormat, Rgb, RgbImage};
use studio_core::{pdf, photo, rendering, scanner::*};
fn source(seed: u8) -> Vec<u8> {
    let img = DynamicImage::ImageRgb8(RgbImage::from_fn(180, 100, |x, y| {
        Rgb([(x as u8).wrapping_add(seed), y as u8, seed])
    }));
    let mut out = std::io::Cursor::new(Vec::new());
    img.write_to(&mut out, ImageFormat::Png).unwrap();
    out.into_inner()
}
#[test]
fn streamed_pages_preserve_order_edits_and_originals() {
    let pages = vec![
        ScanPage {
            data: source(180),
            options: ScanOptions {
                rotate_quarters: 1,
                ..Default::default()
            },
        },
        ScanPage {
            data: source(40),
            options: ScanOptions {
                mode: ScanMode::Grayscale,
                ..Default::default()
            },
        },
        ScanPage {
            data: source(10),
            options: Default::default(),
        },
    ];
    let originals = pages.iter().map(|p| p.data.clone()).collect::<Vec<_>>();
    let output = session_pages_pdf(&pages).unwrap();
    assert_eq!(output.info.pages, Some(3));
    for (i, page) in pages.iter().enumerate() {
        let adjusted = process(&page.data, &page.options).unwrap();
        let independent = pdf::images_to_pdf(&[adjusted.data], &Default::default()).unwrap();
        assert_eq!(
            rendering::page(&output.data, i as u32, 600).unwrap().data,
            rendering::page(&independent.data, 0, 600).unwrap().data
        );
        assert_eq!(page.data, originals[i]);
    }
}
#[test]
fn invalid_sessions_fail_before_export_and_identify_bad_page() {
    let page = ScanPage {
        data: source(1),
        options: Default::default(),
    };
    assert!(
        session_pages_pdf(&vec![page.clone(); 201])
            .unwrap_err()
            .to_string()
            .contains("1–200")
    );
    let bad = ScanPage {
        data: vec![],
        options: Default::default(),
    };
    assert!(
        session_pages_pdf(&[page, bad])
            .unwrap_err()
            .to_string()
            .starts_with("Page 2:")
    );
    assert!(session_pdf(&[], &[]).is_err());
}
#[test]
fn preview_is_bounded_and_rejects_untrusted_formats() {
    let data = source(50);
    let output = photo::source_preview(&data, 128).unwrap();
    assert_eq!(output.info.width, Some(128));
    assert!(output.info.height.unwrap() <= 128);
    assert!(output.info.print_density.is_none());
    assert!(photo::source_preview(b"GIF89a", 128).is_err());
    assert!(photo::source_preview(&data, 1601).is_err());
    let preview = preview(
        &data,
        &ScanOptions {
            rotate_quarters: 1,
            ..Default::default()
        },
        128,
    )
    .unwrap();
    assert_eq!(preview.info.height, Some(128));
}

#[test]
fn nearly_opaque_sixteen_bit_pages_require_an_explicit_background() {
    let img = DynamicImage::ImageRgba16(image::ImageBuffer::from_pixel(
        8,
        8,
        image::Rgba([100u16, 200, 300, 65534]),
    ));
    let mut encoded = std::io::Cursor::new(Vec::new());
    img.write_to(&mut encoded, ImageFormat::Png).unwrap();
    let bytes = encoded.into_inner();
    assert!(
        process(&bytes, &Default::default())
            .unwrap_err()
            .to_string()
            .contains("opaque background")
    );
    assert!(
        pdf::images_to_pdf(&[bytes], &Default::default())
            .unwrap_err()
            .to_string()
            .contains("explicit background")
    );
}
