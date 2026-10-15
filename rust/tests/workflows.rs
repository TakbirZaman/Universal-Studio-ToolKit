use image::{DynamicImage, ImageFormat, Rgb, RgbImage};
use std::io::{Cursor, Read};
use studio_core::{export, jobs, model::*, pdf, photo, recipe};
fn image(w: u32, h: u32) -> Vec<u8> {
    let mut img = RgbImage::new(w, h);
    for (x, y, p) in img.enumerate_pixels_mut() {
        *p = Rgb([
            (x * 13 % 256) as u8,
            (y * 19 % 256) as u8,
            ((x + y) * 7 % 256) as u8,
        ]);
    }
    let mut out = Cursor::new(Vec::new());
    DynamicImage::ImageRgb8(img)
        .write_to(&mut out, ImageFormat::Png)
        .unwrap();
    out.into_inner()
}
#[test]
fn fixed_dimensions_and_actual_limit() {
    let o = PhotoOptions {
        max_bytes: Some(ByteLimit {
            value: 40,
            unit: SizeUnit::KiB,
            strict: true,
        }),
        ..Default::default()
    };
    let out = photo::process(&image(800, 400), &o).unwrap();
    assert_eq!((out.info.width, out.info.height), (Some(300), Some(300)));
    assert!(out.data.len() < 40960);
    assert_eq!(out.info.bytes, out.data.len() as u64);
}
#[test]
fn impossible_constraints_do_not_return_violating_output() {
    let o = PhotoOptions {
        max_bytes: Some(ByteLimit {
            value: 1,
            unit: SizeUnit::KB,
            strict: true,
        }),
        min_quality: 100,
        ..Default::default()
    };
    assert!(matches!(
        photo::process(&image(500, 500), &o),
        Err(StudioError::Impossible)
    ));
}
#[test]
fn exact_limit_semantics() {
    let l = ByteLimit {
        value: 1,
        unit: SizeUnit::KB,
        strict: true,
    };
    assert!(!l.accepts(1000).unwrap());
    assert!(ByteLimit { strict: false, ..l }.accepts(1000).unwrap());
    assert!(
        ByteLimit {
            unit: SizeUnit::KiB,
            ..l
        }
        .accepts(1000)
        .unwrap()
    );
    assert!(
        ByteLimit {
            value: u64::MAX,
            ..l
        }
        .bytes()
        .is_err()
    );
}
#[test]
fn reject_invalid_dimensions_and_untrusted_bytes() {
    assert!(photo::process(b"not an image", &Default::default()).is_err());
    assert!(
        photo::process(
            &image(2, 2),
            &PhotoOptions {
                width: 0,
                ..Default::default()
            }
        )
        .is_err()
    );
    assert!(
        photo::process(
            &image(2, 2),
            &PhotoOptions {
                width: u32::MAX,
                height: u32::MAX,
                ..Default::default()
            }
        )
        .is_err()
    );
}
#[test]
fn signature_has_transparency() {
    let mut buf = Cursor::new(Vec::new());
    DynamicImage::ImageRgb8(RgbImage::from_pixel(10, 10, Rgb([255, 255, 255])))
        .write_to(&mut buf, ImageFormat::Png)
        .unwrap();
    let out = photo::process(
        &buf.into_inner(),
        &PhotoOptions {
            width: 10,
            height: 10,
            format: OutputFormat::Png,
            signature_threshold: Some(230),
            ..Default::default()
        },
    )
    .unwrap();
    assert!(
        photo::decode(&out.data)
            .unwrap()
            .to_rgba8()
            .pixels()
            .all(|p| p[3] == 0)
    );
    assert!(photo::process(&out.data, &PhotoOptions::default()).is_err());
    assert!(
        photo::process(
            &out.data,
            &PhotoOptions {
                flatten_transparency: true,
                ..Default::default()
            }
        )
        .is_ok()
    );
}
#[test]
fn merge_extract_reorder_rotation() {
    let a = pdf::images_to_pdf(&[image(20, 30), image(30, 20)], &Default::default()).unwrap();
    let b = pdf::images_to_pdf(&[image(10, 10)], &Default::default()).unwrap();
    let merged = pdf::arrange(&[a.data, b.data], Some(&[3, 1]), 90).unwrap();
    let d = pdf::load(&merged.data).unwrap();
    assert_eq!(d.get_pages().len(), 2);
    for id in d.get_pages().values() {
        assert_eq!(
            d.get_dictionary(*id)
                .unwrap()
                .get(b"Rotate")
                .unwrap()
                .as_i64()
                .unwrap(),
            90
        );
    }
    assert!(pdf::arrange(&[merged.data], Some(&[1, 1]), 0).is_err());
}
#[test]
fn ranges_are_bounded() {
    assert_eq!(pdf::parse_ranges("3,1-2", 3).unwrap(), vec![3, 1, 2]);
    for s in ["0", "1-4", "3-1", "1,1", "../1", ""] {
        assert!(pdf::parse_ranges(s, 3).is_err());
    }
}
#[test]
fn pdf_rejects_structures_it_cannot_preserve() {
    let out = pdf::images_to_pdf(&[image(10, 10)], &Default::default()).unwrap();
    let mut d = pdf::load(&out.data).unwrap();
    let id = *d.get_pages().values().next().unwrap();
    d.get_dictionary_mut(id)
        .unwrap()
        .set("Annots", Vec::<lopdf::Object>::new());
    let mut bytes = Vec::new();
    d.save_to(&mut bytes).unwrap();
    assert!(pdf::load(&bytes).is_err());
}
#[test]
fn exports_preserve_existing_and_support_bangla() {
    let dir = tempfile::tempdir().unwrap();
    let out = photo::process(&image(20, 20), &Default::default()).unwrap();
    export::save_copy(dir.path(), "ছবি.jpg", &out).unwrap();
    let original = std::fs::read(dir.path().join("ছবি.jpg")).unwrap();
    assert!(export::save_copy(dir.path(), "ছবি.jpg", &out).is_err());
    assert_eq!(original, std::fs::read(dir.path().join("ছবি.jpg")).unwrap());
    for n in [
        "../escape.jpg",
        "a/b.jpg",
        "CON.jpg",
        "bad\\name",
        "trailing.",
    ] {
        assert!(export::save_copy(dir.path(), n, &out).is_err());
    }
}
#[test]
fn pack_manifest_matches_actual_archive() {
    let photo = photo::process(&image(20, 20), &Default::default()).unwrap();
    let pack = export::pack(vec![("ছবি.jpg".into(), photo)]).unwrap();
    let mut zip = zip::ZipArchive::new(Cursor::new(pack.data)).unwrap();
    let mut manifest = String::new();
    zip.by_name("manifest.json")
        .unwrap()
        .read_to_string(&mut manifest)
        .unwrap();
    let m: export::Manifest = serde_json::from_str(&manifest).unwrap();
    assert_eq!(m.entries.len(), 1);
    assert!(!manifest.contains("/tmp"));
    assert_eq!(
        zip.by_name("ছবি.jpg").unwrap().size(),
        m.entries[0].info.bytes
    );
}
#[test]
fn print_sheet_validates_geometry() {
    let out = pdf::print_sheet(&image(300, 300), &Default::default(), 30., 30., 4., 12).unwrap();
    assert_eq!(out.info.pages, Some(1));
    assert!(pdf::print_sheet(&image(300, 300), &Default::default(), 300., 300., 4., 1).is_err());
    assert!(pdf::print_sheet(&image(300, 200), &Default::default(), 30., 30., 4., 1).is_err());
}
#[test]
fn recipes_reject_code_and_wrong_order() {
    let good=br#"{"schema_version":1,"name":"Photo","revision_date":"2026-10-15","steps":[{"type":"resize","width":300,"height":300,"fit":"cover"},{"type":"export","format":"jpeg"}]}"#;
    let r = recipe::Recipe::parse(good).unwrap();
    assert_eq!(r.run(&image(30, 20)).unwrap().info.width, Some(300));
    for bad in [br#"{"schema_version":1,"name":"x","revision_date":"x","steps":[{"type":"shell","command":"rm"}]}"#.as_slice(),br#"{"schema_version":2,"name":"x","revision_date":"x","steps":[]}"#]{assert!(recipe::Recipe::parse(bad).is_err());}
}
#[test]
fn batch_keeps_successes() {
    let cancel = jobs::Cancellation::default();
    let b = jobs::photo_batch(
        &[image(20, 20), b"bad".to_vec(), image(10, 10)],
        &Default::default(),
        &cancel,
    );
    assert_eq!(b.state, jobs::JobState::PartiallySucceeded);
    assert!(b.items[0].is_ok() && b.items[2].is_ok());
    cancel.cancel();
    assert_eq!(
        jobs::photo_batch(&[image(10, 10)], &Default::default(), &cancel).state,
        jobs::JobState::Cancelled
    );
}
#[test]
fn physical_dimensions_use_explicit_dpi() {
    assert_eq!(photo::physical_pixels(25.4, 300.).unwrap(), 300);
    assert!(photo::physical_pixels(f64::NAN, 300.).is_err());
}
#[test]
fn exif_normalizes_all_eight_orientations() {
    for i in 1..=8 {
        let data = std::fs::read(format!("tests/fixtures/orientation-{i}.jpg")).unwrap();
        let img = photo::decode(&data).unwrap();
        assert_eq!(
            (img.width(), img.height()),
            if i >= 5 { (20, 40) } else { (40, 20) }
        );
    }
}
#[test]
fn pack_slots_enforce_constraints() {
    use studio_core::packs::*;
    let p = PackPreset {
        schema_version: 1,
        name: "Example".into(),
        revision_date: "2026-10-15".into(),
        source: None,
        verified: false,
        slots: vec![PackSlot {
            label: "Photo".into(),
            required: true,
            filename: "photo.jpg".into(),
            formats: vec!["jpeg".into()],
            width: Some(300),
            height: Some(300),
            max_bytes: None,
            min_pages: None,
            max_pages: None,
        }],
    };
    assert!(p.build(vec![None]).is_err());
    let valid = photo::process(&image(20, 20), &Default::default()).unwrap();
    assert!(p.build(vec![Some(valid)]).is_ok());
    let invalid = photo::process(
        &image(20, 20),
        &PhotoOptions {
            width: 20,
            ..Default::default()
        },
    )
    .unwrap();
    assert!(p.build(vec![Some(invalid)]).is_err());
}
