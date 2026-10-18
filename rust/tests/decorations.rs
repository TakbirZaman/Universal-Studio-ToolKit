use lopdf::{Dictionary, Document, Object, Stream, dictionary};
use studio_core::{decorations::*, pdf, rendering};
fn source(rotation: i64, unit: f32) -> Vec<u8> {
    let mut doc = Document::with_version("1.7");
    let pages = doc.new_object_id();
    let font=doc.add_object(dictionary!{"Type"=>"Font","Subtype"=>"Type1","BaseFont"=>"Courier-Bold","Encoding"=>"WinAnsiEncoding"});
    let state = doc.add_object(dictionary! {"Type"=>"ExtGState","ca"=>0.5,"CA"=>0.5});
    // Leave a translated/clipped graphics state active. Overlays must restore the
    // original initial state, not inherit this translation, alpha or text spacing.
    let content=doc.add_object(Stream::new(Dictionary::new(),b"1 0 0 1 5 7 cm 30 90 140 60 re W n /USTStudioOpaque0 gs BT /USTStudioFont0 12 Tf 3 Tc 40 120 Td (ORIGINAL) Tj ET\n".to_vec()));
    let page=doc.add_object(dictionary!{"Type"=>"Page","Parent"=>pages,"CropBox"=>vec![10.into(),20.into(),210.into(),300.into()],"Rotate"=>rotation,"UserUnit"=>unit,"Contents"=>content});
    doc.objects.insert(pages,Object::Dictionary(dictionary!{"Type"=>"Pages","Kids"=>vec![Object::Reference(page)],"Count"=>1,"MediaBox"=>vec![(-20).into(),(-30).into(),240.into(),330.into()],"Resources"=>dictionary!{"Font"=>dictionary!{"USTStudioFont0"=>font},"ExtGState"=>dictionary!{"USTStudioOpaque0"=>state}}}));
    let root = doc.add_object(dictionary! {"Type"=>"Catalog","Pages"=>pages});
    doc.trailer.set("Root", root);
    let mut bytes = vec![];
    doc.save_to(&mut bytes).unwrap();
    bytes
}
#[test]
fn numbering_stays_at_visual_bottom_for_rotated_cropped_and_scaled_pages() {
    for rotation in [0, 90, 180, 270, -90] {
        for unit in [1., 2.] {
            let input = source(rotation, unit);
            let original = input.clone();
            let output = apply(
                &input,
                &OverlayOptions {
                    page_numbers: true,
                    margin_mm: 2.,
                    ..Default::default()
                },
            )
            .unwrap();
            let before = image::load_from_memory(&rendering::page(&input, 0, 700).unwrap().data)
                .unwrap()
                .to_rgba8();
            let after =
                image::load_from_memory(&rendering::page(&output.data, 0, 700).unwrap().data)
                    .unwrap()
                    .to_rgba8();
            assert_eq!(before.dimensions(), after.dimensions());
            let mut changed = 0;
            for (x, y, pixel) in before.enumerate_pixels() {
                if pixel != after.get_pixel(x, y) {
                    changed += 1;
                    assert!(
                        y > before.height() * 3 / 4,
                        "Number left the visual footer for rotation {rotation}, unit {unit}"
                    );
                }
            }
            assert!(changed > 10);
            assert_eq!(input, original);
            let text = pdf::extract_text(&output.data).unwrap();
            assert!(text.contains("ORIGINAL"));
            assert!(text.contains("Page 1 of 1"));
        }
    }
}
#[test]
fn visible_watermark_escapes_literal_text_and_preserves_existing_resources() {
    let input = source(90, 1.);
    let text = r"Draft (copy) \ 42";
    let output = apply(
        &input,
        &OverlayOptions {
            page_numbers: true,
            watermark: Some(text.into()),
            watermark_font_points: 14.,
            margin_mm: 2.,
        },
    )
    .unwrap();
    let doc = pdf::load(&output.data).unwrap();
    let page = *doc.get_pages().values().next().unwrap();
    let resources = doc
        .get_dictionary(page)
        .unwrap()
        .get(b"Resources")
        .unwrap()
        .as_dict()
        .unwrap();
    let fonts = resources.get(b"Font").unwrap().as_dict().unwrap();
    assert!(fonts.has(b"USTStudioFont0"));
    assert!(fonts.has(b"USTStudioFont1"));
    let extracted = pdf::extract_text(&output.data).unwrap();
    assert!(extracted.contains(text));
    assert!(extracted.contains("ORIGINAL"));
    let before = rendering::page(&input, 0, 700).unwrap();
    let after = rendering::page(&output.data, 0, 700).unwrap();
    assert_ne!(before.data, after.data);
}
#[test]
fn no_overlay_retains_validated_bytes_and_invalid_constraints_return_no_output() {
    let input = source(0, 1.);
    assert_eq!(apply(&input, &Default::default()).unwrap().data, input);
    assert!(
        apply(
            &input,
            &OverlayOptions {
                watermark: Some("বাংলা".into()),
                ..Default::default()
            }
        )
        .is_err()
    );
    assert!(
        apply(
            &input,
            &OverlayOptions {
                watermark: Some("Very long watermark ".repeat(4)),
                watermark_font_points: 96.,
                ..Default::default()
            }
        )
        .is_err()
    );
    assert!(
        apply(
            &source(45, 1.),
            &OverlayOptions {
                page_numbers: true,
                ..Default::default()
            }
        )
        .is_err()
    );
    assert!(
        apply(
            &source(0, 0.),
            &OverlayOptions {
                page_numbers: true,
                ..Default::default()
            }
        )
        .is_err()
    );
    assert!(
        apply(
            &input,
            &OverlayOptions {
                margin_mm: f64::NAN,
                ..Default::default()
            }
        )
        .is_err()
    );
}

#[test]
fn page_labels_follow_saved_order_after_merge_and_reorder() {
    let mut sources = vec![];
    for label in ["SOURCE_A", "SOURCE_B", "SOURCE_C"] {
        let mut doc = pdf::load(&source(0, 1.)).unwrap();
        for object in doc.objects.values_mut() {
            if let Object::Stream(stream) = object {
                if let Ok(text) = String::from_utf8(stream.content.clone()) {
                    if text.contains("ORIGINAL") {
                        stream.content = text.replace("ORIGINAL", label).into_bytes();
                    }
                }
            }
        }
        let mut bytes = vec![];
        doc.save_to(&mut bytes).unwrap();
        sources.push(bytes);
    }
    let ordered = pdf::arrange(&sources, Some(&[3, 1, 2]), 0).unwrap();
    let output = apply(
        &ordered.data,
        &OverlayOptions {
            page_numbers: true,
            margin_mm: 2.,
            ..Default::default()
        },
    )
    .unwrap();
    let doc = pdf::load(&output.data).unwrap();
    assert_eq!(doc.get_pages().len(), 3);
    for (index, label) in ["SOURCE_C", "SOURCE_A", "SOURCE_B"].iter().enumerate() {
        let text = doc.extract_text(&[(index + 1) as u32]).unwrap();
        assert!(text.contains(label));
        assert!(text.contains(&format!("Page {} of 3", index + 1)));
    }
}
