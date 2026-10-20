use image::{DynamicImage, ImageFormat, Rgba, RgbaImage};
use studio_core::{
    scanner::{self, ScanOptions},
    vision::{self, PageCorners, PagePoint},
};

fn rectangle(left: f64, top: f64, right: f64, bottom: f64) -> PageCorners {
    PageCorners {
        top_left: PagePoint { x: left, y: top },
        top_right: PagePoint { x: right, y: top },
        bottom_right: PagePoint {
            x: right,
            y: bottom,
        },
        bottom_left: PagePoint { x: left, y: bottom },
    }
}
#[test]
fn corners_reject_crossings_nonfinite_small_and_unbounded_shapes() {
    let full = PageCorners::default();
    assert_eq!(full.output_dimensions(272, 184).unwrap(), (272, 184));
    assert_eq!(
        rectangle(0.1, 0.2, 0.9, 0.8)
            .output_dimensions(101, 201)
            .unwrap(),
        (81, 121)
    );
    for invalid in [
        rectangle(-0.01, 0., 1., 1.),
        rectangle(0., 0., 1.01, 1.),
        rectangle(0., 0., f64::NAN, 1.),
        rectangle(0., 0., f64::INFINITY, 1.),
        rectangle(0., 0., 0.01, 0.01),
        rectangle(0.5, 0., 0.5, 1.),
        PageCorners {
            top_right: full.bottom_right,
            bottom_right: full.top_right,
            ..full
        },
        PageCorners {
            bottom_right: PagePoint { x: 0.1, y: 0.1 },
            ..full
        },
    ] {
        assert!(invalid.validate().is_err(), "{invalid:?}");
    }
    for (w, h) in [
        (0, 10),
        (1, 10),
        (12001, 2),
        (6000, 6000),
        (u32::MAX, u32::MAX),
    ] {
        assert!(full.output_dimensions(w, h).is_err());
    }
    // A rotated quadrilateral can require a side over the limit even if the source fits.
    let diamond = PageCorners {
        top_left: PagePoint { x: 0., y: 0. },
        top_right: PagePoint { x: 1., y: 0.01 },
        bottom_right: PagePoint { x: 1., y: 1. },
        bottom_left: PagePoint { x: 0., y: 0.99 },
    };
    assert!(diamond.output_dimensions(12000, 2000).is_ok());
    let encoded = serde_json::to_string(&full).unwrap();
    assert_eq!(serde_json::from_str::<PageCorners>(&encoded).unwrap(), full);
    assert!(
        serde_json::from_str::<PageCorners>(&encoded.replace("\"top_left\"", "\"extra\"")).is_err()
    );
}
fn require_native() {
    assert!(
        std::env::var_os("UST_VISION_LIBRARY").is_some(),
        "Provision UST_VISION_LIBRARY before running native scanner tests"
    );
    assert!(
        vision::available(),
        "Explicit native test library must load with the expected ABI/version"
    );
}
fn source() -> RgbaImage {
    RgbaImage::from_fn(101, 201, |x, y| Rgba([x as u8, y as u8, 100, 255]))
}
#[test]
#[ignore = "Requires UST_VISION_LIBRARY; run with --include-ignored after provisioning the adapter"]
fn native_identity_crop_rotation_and_saved_output_are_actual_pixels() {
    require_native();
    let original = source();
    assert_eq!(
        vision::perspective(original.clone(), PageCorners::default()).unwrap(),
        original
    );
    let mut bytes = std::io::Cursor::new(Vec::new());
    DynamicImage::ImageRgba8(original.clone())
        .write_to(&mut bytes, ImageFormat::Png)
        .unwrap();
    let bytes = bytes.into_inner();
    let untouched = bytes.clone();
    let out = scanner::process(
        &bytes,
        &ScanOptions {
            rotate_quarters: 1,
            corners: Some(rectangle(0.1, 0.2, 0.9, 0.8)),
            ..Default::default()
        },
    )
    .unwrap();
    assert_eq!((out.info.width, out.info.height), (Some(121), Some(81)));
    let actual = image::load_from_memory(&out.data).unwrap().to_rgba8();
    assert_eq!(*actual.get_pixel(120, 0), *original.get_pixel(10, 40));
    assert_eq!(*actual.get_pixel(0, 80), *original.get_pixel(90, 160));
    assert!(
        out.info
            .findings
            .iter()
            .any(|f| f.code == "perspective_resampling" && f.advisory)
    );
    studio_core::export::verify_output(&out).unwrap();
    let temp = tempfile::tempdir().unwrap();
    studio_core::export::save_copy(temp.path(), "সনদ.png", &out).unwrap();
    assert_eq!(
        std::fs::read(temp.path().join("সনদ.png")).unwrap(),
        out.data
    );
    assert!(studio_core::export::save_copy(temp.path(), "সনদ.png", &out).is_err());
    assert_eq!(bytes, untouched);
    let crop = vision::perspective(original.clone(), rectangle(0.1, 0.2, 0.9, 0.8)).unwrap();
    for y in 0..121 {
        for x in 0..81 {
            assert_eq!(crop.get_pixel(x, y), original.get_pixel(x + 10, y + 40));
        }
    }
    assert!(vision::perspective(original, rectangle(0., 0., 0., 0.)).is_err());
}
#[test]
#[ignore = "Requires UST_VISION_LIBRARY; run with --include-ignored after provisioning the adapter"]
fn native_suggestions_blank_and_concurrent_calls_are_safe() {
    require_native();
    let blank = RgbaImage::from_pixel(272, 184, Rgba([255, 255, 255, 255]));
    assert_eq!(vision::suggest(&blank).unwrap(), None);
    let page = RgbaImage::from_fn(272, 184, |x, y| {
        if (30..240).contains(&x) && (25..160).contains(&y) {
            Rgba([245, 245, 245, 255])
        } else {
            Rgba([25, 25, 25, 255])
        }
    });
    let corners = vision::suggest(&page).unwrap().unwrap();
    assert!((corners.top_left.x - 30. / 271.).abs() < 0.025);
    assert!((corners.top_left.y - 25. / 183.).abs() < 0.025);
    let threads: Vec<_> = (0..4)
        .map(|_| {
            std::thread::spawn(|| {
                for _ in 0..3 {
                    let input = source();
                    assert_eq!(
                        vision::perspective(input.clone(), PageCorners::default()).unwrap(),
                        input
                    );
                }
            })
        })
        .collect();
    for thread in threads {
        thread.join().unwrap();
    }
}

#[test]
#[ignore = "Requires UST_VISION_LIBRARY; run with --include-ignored after provisioning the adapter"]
fn native_orientation_preview_session_and_depth_use_the_same_geometry() {
    require_native();
    let mut pages = Vec::new();
    for n in [1, 6, 3] {
        let data = std::fs::read(format!("tests/fixtures/orientation-{n}.jpg")).unwrap();
        let options = ScanOptions {
            corners: Some(PageCorners::default()),
            ..Default::default()
        };
        let expected = studio_core::photo::decode(&data).unwrap().into_rgba8();
        let output = scanner::process(&data, &options).unwrap();
        assert_eq!(
            image::load_from_memory(&output.data).unwrap().into_rgba8(),
            expected
        );
        let preview = scanner::preview(&data, &options, 1600).unwrap();
        let original_preview = studio_core::photo::source_preview(&data, 1600).unwrap();
        let actual_preview = image::load_from_memory(&preview.data).unwrap().to_rgba8();
        let expected_preview = image::load_from_memory(&original_preview.data)
            .unwrap()
            .to_rgba8();
        assert_eq!(actual_preview.dimensions(), expected_preview.dimensions());
        let maximum_error = actual_preview
            .as_raw()
            .iter()
            .zip(expected_preview.as_raw())
            .map(|(a, b)| a.abs_diff(*b))
            .max()
            .unwrap();
        assert!(maximum_error <= 1, "Preview channel error: {maximum_error}");
        pages.push(scanner::ScanPage { data, options });
    }
    let output = scanner::session_pages_pdf(&pages).unwrap();
    assert_eq!(output.info.pages, Some(3));
    for (i, page) in pages.iter().enumerate() {
        let adjusted = scanner::process(&page.data, &page.options).unwrap();
        let independent =
            studio_core::pdf::images_to_pdf(&[adjusted.data], &Default::default()).unwrap();
        assert_eq!(
            studio_core::rendering::page(&output.data, i as u32, 600)
                .unwrap()
                .data,
            studio_core::rendering::page(&independent.data, 0, 600)
                .unwrap()
                .data
        );
    }
    let image = DynamicImage::ImageRgb16(image::ImageBuffer::from_pixel(
        10,
        12,
        image::Rgb([1000u16, 2000, 3000]),
    ));
    let mut bytes = std::io::Cursor::new(Vec::new());
    image.write_to(&mut bytes, ImageFormat::Png).unwrap();
    let output = scanner::process(
        bytes.get_ref(),
        &ScanOptions {
            corners: Some(PageCorners::default()),
            ..Default::default()
        },
    )
    .unwrap();
    assert!(
        output
            .info
            .findings
            .iter()
            .any(|f| f.code == "perspective_eight_bit" && f.advisory)
    );
    let old =
        r#"{"mode":"original","rotate_quarters":0,"brightness":0,"contrast":0,"threshold":128}"#;
    assert!(
        serde_json::from_str::<ScanOptions>(old)
            .unwrap()
            .corners
            .is_none()
    );
}
