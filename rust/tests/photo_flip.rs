use image::{GenericImageView, Rgba, RgbaImage};
use std::io::Cursor;
use studio_core::{
    photo,
    recipe::{Recipe, Step},
};

fn recipe(horizontal: bool, vertical: bool, crop: bool) -> Recipe {
    let mut steps = Vec::new();
    if crop {
        steps.push(serde_json::json!({"type":"crop","x":1,"y":1,"width":3,"height":2}));
    }
    steps.push(serde_json::json!({"type":"flip","horizontal":horizontal,"vertical":vertical}));
    steps.push(serde_json::json!({"type":"export","format":"png"}));
    Recipe::parse(serde_json::json!({"schema_version":4,"name":"Reflect","revision_date":"2026-10-22","steps":steps}).to_string().as_bytes()).unwrap()
}

#[test]
fn every_saved_pixel_and_alpha_matches_reflection_after_crop() {
    let source = RgbaImage::from_fn(5, 4, |x, y| {
        Rgba([
            (x * 30) as u8,
            (y * 50) as u8,
            (x + y) as u8,
            ((x + y) * 20) as u8,
        ])
    });
    let mut encoded = Cursor::new(Vec::new());
    image::DynamicImage::ImageRgba8(source.clone())
        .write_to(&mut encoded, image::ImageFormat::Png)
        .unwrap();
    let original = encoded.into_inner();
    for cropped in [false, true] {
        for (horizontal, vertical) in [(true, false), (false, true), (true, true)] {
            let mut baseline_recipe = recipe(horizontal, vertical, cropped);
            baseline_recipe
                .steps
                .retain(|step| !matches!(step, Step::Flip { .. }));
            let baseline = image::load_from_memory(&baseline_recipe.run(&original).unwrap().data)
                .unwrap()
                .to_rgba8();
            let output = recipe(horizontal, vertical, cropped)
                .run(&original)
                .unwrap();
            let actual = image::load_from_memory(&output.data).unwrap().to_rgba8();
            let (width, height) = if cropped { (3, 2) } else { (5, 4) };
            assert_eq!(actual.dimensions(), (width, height));
            for y in 0..height {
                for x in 0..width {
                    let sx = if horizontal { width - 1 - x } else { x };
                    let sy = if vertical { height - 1 - y } else { y };
                    assert_eq!(actual.get_pixel(x, y), baseline.get_pixel(sx, sy));
                }
            }
        }
    }
    assert_eq!(
        image::load_from_memory(&original).unwrap().to_rgba8(),
        source
    );
}

#[test]
fn exif_is_corrected_before_reflecting() {
    let source = include_bytes!("fixtures/orientation-6.jpg");
    let corrected = photo::decode(source).unwrap();
    for (horizontal, vertical) in [(true, false), (false, true), (true, true)] {
        let output = recipe(horizontal, vertical, false).run(source).unwrap();
        let actual = image::load_from_memory(&output.data).unwrap();
        assert_eq!(actual.dimensions(), corrected.dimensions());
        let (width, height) = corrected.dimensions();
        for y in 0..height {
            for x in 0..width {
                let sx = if horizontal { width - 1 - x } else { x };
                let sy = if vertical { height - 1 - y } else { y };
                assert_eq!(actual.get_pixel(x, y), corrected.get_pixel(sx, sy));
            }
        }
    }
}

#[test]
fn legacy_versions_invalid_flags_and_reordered_steps_are_rejected() {
    let valid = recipe(true, false, false);
    let mut json = serde_json::to_value(valid).unwrap();
    json["schema_version"] = 3.into();
    assert!(Recipe::parse(json.to_string().as_bytes()).is_err());
    json["schema_version"] = 4.into();
    json["steps"][0]["horizontal"] = false.into();
    assert!(Recipe::parse(json.to_string().as_bytes()).is_err());
    json["steps"][0]["horizontal"] = true.into();
    json["steps"].as_array_mut().unwrap().swap(0, 1);
    assert!(Recipe::parse(json.to_string().as_bytes()).is_err());
}
