use image::{DynamicImage, ImageFormat, RgbImage, RgbaImage};
use std::io::Cursor;
use studio_core::{export, model::*, photo, recipe::Recipe};

fn source(alpha: bool) -> Vec<u8> {
    let mut seed = 17u32;
    let mut next = || {
        seed = seed.wrapping_mul(1664525).wrapping_add(1013904223);
        (seed >> 24) as u8
    };
    let image = if alpha {
        DynamicImage::ImageRgba8(RgbaImage::from_fn(256, 192, |_, _| {
            image::Rgba([next(), next(), next(), 127])
        }))
    } else {
        DynamicImage::ImageRgb8(RgbImage::from_fn(256, 192, |_, _| {
            image::Rgb([next(), next(), next()])
        }))
    };
    let mut out = Cursor::new(Vec::new());
    image.write_to(&mut out, ImageFormat::Png).unwrap();
    out.into_inner()
}
#[test]
fn approved_smaller_sizes_meet_actual_limits_without_recompressing_jpeg_candidates() {
    let data = source(false);
    let original = data.clone();
    let minimum = PhotoOptions {
        width: 96,
        height: 72,
        min_quality: 80,
        ..Default::default()
    };
    let small = photo::process(&data, &minimum).unwrap();
    let limit = ByteLimit {
        value: (small.data.len() as u64).div_ceil(1000),
        unit: SizeUnit::KB,
        strict: true,
    };
    let options = PhotoOptions {
        width: 256,
        height: 192,
        min_quality: 80,
        max_bytes: Some(limit),
        ..Default::default()
    };
    assert!(matches!(
        photo::process(&data, &options),
        Err(StudioError::Impossible)
    ));
    let out = photo::process_flexible(&data, &options, 96, 72, &|| false).unwrap();
    let (w, h) = (out.info.width.unwrap(), out.info.height.unwrap());
    assert!((96..=256).contains(&w) && (72..=192).contains(&h));
    assert!(
        w < 256
            && h < 192
            && out.info.quality.unwrap() >= 80
            && limit.accepts(out.data.len()).unwrap()
    );
    let direct = photo::process(
        &data,
        &PhotoOptions {
            width: w,
            height: h,
            ..options.clone()
        },
    )
    .unwrap();
    assert_eq!(out.data, direct.data);
    assert_eq!(data, original);
    export::verify_output(&out).unwrap();
    assert!(
        out.info
            .findings
            .iter()
            .any(|f| f.code == "flexible_dimensions_verified")
    );
}
#[test]
fn flexible_png_keeps_alpha_and_impossible_minimums_never_return_an_invalid_copy() {
    let data = source(true);
    let small = photo::process(
        &data,
        &PhotoOptions {
            width: 64,
            height: 48,
            format: OutputFormat::Png,
            ..Default::default()
        },
    )
    .unwrap();
    let limit = ByteLimit {
        value: (small.data.len() as u64).div_ceil(1024),
        unit: SizeUnit::KiB,
        strict: false,
    };
    let options = PhotoOptions {
        width: 256,
        height: 192,
        format: OutputFormat::Png,
        max_bytes: Some(limit),
        ..Default::default()
    };
    let out = photo::process_flexible(&data, &options, 64, 48, &|| false).unwrap();
    assert_eq!(out.info.quality, None);
    assert!(limit.accepts(out.data.len()).unwrap());
    assert!(
        image::load_from_memory(&out.data)
            .unwrap()
            .to_rgba8()
            .pixels()
            .any(|p| p[3] < 255)
    );
    let impossible = PhotoOptions {
        max_bytes: Some(ByteLimit { value: 0, ..limit }),
        ..options.clone()
    };
    assert!(matches!(
        photo::process_flexible(&data, &impossible, 64, 48, &|| false),
        Err(StudioError::Impossible)
    ));
    assert!(photo::process_flexible(&data, &options, 257, 48, &|| false).is_err());
    assert!(
        photo::process_flexible(
            &data,
            &PhotoOptions {
                max_bytes: None,
                ..options
            },
            64,
            48,
            &|| false
        )
        .is_err()
    );
}
#[test]
fn versioned_flexible_recipe_roundtrips_and_cancellation_stops_without_output() {
    let json = r#"{"schema_version":3,"name":"User photo","revision_date":"2026-10-20","steps":[{"type":"flexible_resize","width":256,"height":192,"minimum_width":96,"minimum_height":72,"fit":"contain"},{"type":"compress","limit":{"value":8,"unit":"ki_b","strict":true},"min_quality":80},{"type":"export","format":"jpeg"}]}"#;
    let recipe = Recipe::parse(json.as_bytes()).unwrap();
    let out = recipe.run(&source(false)).unwrap();
    assert!(out.data.len() < 8192);
    export::verify_output(&out).unwrap();
    let roundtrip = serde_json::to_vec(&recipe).unwrap();
    assert!(Recipe::parse(&roundtrip).is_ok());
    assert!(
        Recipe::parse(
            json.replace("\"schema_version\":3", "\"schema_version\":2")
                .as_bytes()
        )
        .is_err()
    );
    assert!(
        Recipe::parse(
            json.replace("\"minimum_width\":96", "\"minimum_width\":999")
                .as_bytes()
        )
        .is_err()
    );
    let mut missing: serde_json::Value = serde_json::from_str(json).unwrap();
    missing["steps"].as_array_mut().unwrap().remove(1);
    assert!(Recipe::parse(&serde_json::to_vec(&missing).unwrap()).is_err());
    let options = PhotoOptions {
        max_bytes: Some(ByteLimit {
            value: 8,
            unit: SizeUnit::KiB,
            strict: true,
        }),
        ..Default::default()
    };
    assert!(matches!(
        photo::process_flexible(b"not an image", &options, 100, 100, &|| true),
        Err(StudioError::Cancelled)
    ));
}
