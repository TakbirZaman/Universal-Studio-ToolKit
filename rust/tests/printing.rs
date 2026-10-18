use image::{DynamicImage, ImageFormat, Rgb, RgbImage};
use studio_core::{
    pdf::{self, Paper},
    printing::*,
    rendering,
};
fn spec() -> PrintSheetSpec {
    PrintSheetSpec {
        paper: Paper {
            width_mm: 120.,
            height_mm: 90.,
            margin_mm: 5.,
        },
        photo_width_mm: 30.,
        photo_height_mm: 20.,
        spacing_mm: 10.,
        copies: 9,
        cutting_guides: true,
        raster_dpi: None,
    }
}
fn source(width: u32, height: u32) -> Vec<u8> {
    let mut out = std::io::Cursor::new(Vec::new());
    DynamicImage::ImageRgb8(RgbImage::from_fn(width, height, |x, y| {
        Rgb([(x * 2) as u8, (y * 2) as u8, 140])
    }))
    .write_to(&mut out, ImageFormat::Png)
    .unwrap();
    out.into_inner()
}
#[test]
fn exact_capacity_and_cutting_guides_stay_inside_paper_and_outside_photos() {
    let spec = spec();
    let layout = spec.layout().unwrap();
    assert_eq!(layout.capacity, 9);
    assert_eq!(layout.placements.len(), 9);
    assert_eq!(layout.cut_lines.len(), 72);
    let last = layout.placements.last().unwrap();
    assert!((last.x_mm + last.width_mm - 115.).abs() < 1e-8);
    assert!((last.y_mm - 5.).abs() < 1e-8);
    for line in layout.cut_lines {
        for x in [line.x1_mm, line.x2_mm] {
            assert!((0.0..=120.0).contains(&x));
        }
        for y in [line.y1_mm, line.y2_mm] {
            assert!((0.0..=90.0).contains(&y));
        }
        for r in &layout.placements {
            let crosses = if (line.x1_mm - line.x2_mm).abs() < 1e-8 {
                line.x1_mm > r.x_mm + 1e-8
                    && line.x1_mm < r.x_mm + r.width_mm - 1e-8
                    && line.y1_mm.max(line.y2_mm) > r.y_mm + 1e-8
                    && line.y1_mm.min(line.y2_mm) < r.y_mm + r.height_mm - 1e-8
            } else {
                line.y1_mm > r.y_mm + 1e-8
                    && line.y1_mm < r.y_mm + r.height_mm - 1e-8
                    && line.x1_mm.max(line.x2_mm) > r.x_mm + 1e-8
                    && line.x1_mm.min(line.x2_mm) < r.x_mm + r.width_mm - 1e-8
            };
            assert!(!crosses, "Cutting guide crosses a photo");
        }
    }
}
#[test]
fn letter_and_custom_constraints_are_validated_before_decoding() {
    let mut s = spec();
    s.paper = Paper {
        width_mm: 215.9,
        height_mm: 279.4,
        margin_mm: 10.,
    };
    s.photo_width_mm = 35.;
    s.photo_height_mm = 45.;
    s.spacing_mm = 4.;
    s.copies = 20;
    assert_eq!(s.layout().unwrap().capacity, 25);
    for mutate in [
        |s: &mut PrintSheetSpec| s.photo_width_mm = f64::NAN,
        |s: &mut PrintSheetSpec| s.paper.width_mm = 1e-200,
        |s: &mut PrintSheetSpec| s.copies = 201,
        |s: &mut PrintSheetSpec| s.spacing_mm = 2.,
        |s: &mut PrintSheetSpec| s.paper.margin_mm = 1.,
        |s: &mut PrintSheetSpec| s.raster_dpi = Some(0),
        |s: &mut PrintSheetSpec| {
            s.photo_width_mm = 900.;
            s.raster_dpi = Some(2400);
        },
    ] {
        let mut bad = s.clone();
        mutate(&mut bad);
        assert!(bad.layout().is_err());
        assert!(sheet(b"untrusted", &bad).is_err());
    }
    let mut too_many = spec();
    too_many.copies = 10;
    assert!(too_many.layout().is_err());
}
#[test]
fn saved_pdf_has_exact_paper_copy_count_guides_and_aspect_preserving_placement() {
    let mut s = spec();
    s.photo_width_mm = 30.;
    s.photo_height_mm = 30.;
    s.copies = 4;
    let data = source(100, 101);
    let original = data.clone();
    let result = sheet(&data, &s).unwrap();
    assert_eq!(data, original);
    assert_eq!(result.info.pages, Some(1));
    let doc = pdf::load(&result.data).unwrap();
    let page = *doc.get_pages().values().next().unwrap();
    let media = doc
        .get_dictionary(page)
        .unwrap()
        .get(b"MediaBox")
        .unwrap()
        .as_array()
        .unwrap();
    let number = |o: &lopdf::Object| o.as_float().unwrap() as f64;
    assert!((number(&media[2]) * 25.4 / 72. - 120.).abs() < 0.001);
    assert!((number(&media[3]) * 25.4 / 72. - 90.).abs() < 0.001);
    let content = lopdf::content::Content::decode(&doc.get_page_content(page).unwrap()).unwrap();
    assert_eq!(
        content
            .operations
            .iter()
            .filter(|op| op.operator == "Do")
            .count(),
        4
    );
    assert_eq!(
        content
            .operations
            .iter()
            .filter(|op| op.operator == "l")
            .count(),
        32
    );
    for op in content.operations.iter().filter(|op| op.operator == "cm") {
        assert!((number(&op.operands[0]) / number(&op.operands[3]) - 100. / 101.).abs() < 1e-5);
    }
    let with_guides = rendering::page(&result.data, 0, 900).unwrap();
    s.cutting_guides = false;
    let without_guides = rendering::page(&sheet(&data, &s).unwrap().data, 0, 900).unwrap();
    assert_ne!(with_guides.data, without_guides.data);
}
#[test]
fn explicit_resampling_changes_embedded_pixels_without_recompressing_candidates() {
    let mut s = spec();
    s.photo_height_mm = 30.;
    s.copies = 4;
    s.raster_dpi = Some(300);
    let data = source(80, 80);
    let result = sheet(&data, &s).unwrap();
    let doc = pdf::load(&result.data).unwrap();
    let image = doc
        .objects
        .values()
        .filter_map(|o| o.as_stream().ok())
        .find(|stream| {
            stream
                .dict
                .get(b"Subtype")
                .ok()
                .and_then(|o| o.as_name().ok())
                == Some(b"Image")
        })
        .unwrap();
    assert_eq!(image.dict.get(b"Width").unwrap().as_i64().unwrap(), 354);
    assert_eq!(image.dict.get(b"Height").unwrap().as_i64().unwrap(), 354);
    assert!(
        result
            .info
            .findings
            .iter()
            .any(|f| f.code == "print_sampling" && f.message.contains("67.7 DPI"))
    );
    assert!(
        result
            .info
            .findings
            .iter()
            .any(|f| f.code == "print_density" && f.message.contains("299.72 DPI"))
    );
    s.photo_width_mm = 20.;
    assert!(
        sheet(&data, &s)
            .unwrap_err()
            .to_string()
            .contains("aspect ratio")
    );
}
