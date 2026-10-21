use std::io::Cursor;
use studio_core::{api, photo};

#[test]
fn geometry_uses_guarded_orientation_corrected_source() {
    let source = include_bytes!("fixtures/orientation-6.jpg").to_vec();
    let original = source.clone();
    let decoded = photo::decode(&source).unwrap();
    assert_eq!(
        api::photo_source_dimensions(source.clone()).unwrap(),
        vec![decoded.width(), decoded.height()]
    );
    let crop = serde_json::json!({"schema_version":2,"name":"Selected crop","revision_date":"2026-10-21",
        "steps":[{"type":"crop","x":0,"y":0,"width":decoded.width()/2,"height":decoded.height()/2},
        {"type":"export","format":"png"}]});
    let output = api::run_recipe(source.clone(), crop.to_string()).unwrap();
    let actual = image::load_from_memory(&output.bytes).unwrap().to_rgba8();
    let expected = decoded
        .crop_imm(0, 0, decoded.width() / 2, decoded.height() / 2)
        .to_rgba8();
    assert_eq!(actual, expected);
    assert_eq!(source, original);
}
#[test]
fn exact_crop_pixels_and_invalid_bounds_are_verified() {
    let image = image::ImageBuffer::from_fn(8, 6, |x, y| {
        image::Rgba([x as u8 * 20, y as u8 * 20, 60, 255])
    });
    let mut bytes = Cursor::new(Vec::new());
    image::DynamicImage::ImageRgba8(image.clone())
        .write_to(&mut bytes, image::ImageFormat::Png)
        .unwrap();
    let recipe = |x, width| {
        serde_json::json!({"schema_version":2,"name":"Exact","revision_date":"2026-10-21",
        "steps":[{"type":"crop","x":x,"y":1,"width":width,"height":3},{"type":"export","format":"png"}]}).to_string()
    };
    let output = api::run_recipe(bytes.get_ref().clone(), recipe(2, 4)).unwrap();
    let actual = image::load_from_memory(&output.bytes).unwrap().to_rgba8();
    assert_eq!(actual.dimensions(), (4, 3));
    for y in 0..3 {
        for x in 0..4 {
            assert_eq!(actual.get_pixel(x, y), image.get_pixel(x + 2, y + 1));
        }
    }
    assert!(api::run_recipe(bytes.get_ref().clone(), recipe(7, 4)).is_err());
    assert!(api::photo_source_dimensions(vec![0, 1, 2]).is_err());
}
