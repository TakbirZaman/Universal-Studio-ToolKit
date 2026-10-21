use std::io::Cursor;
use studio_core::{api, export, model::*, packs::*};
fn image() -> Vec<u8> {
    let mut bytes = Cursor::new(Vec::new());
    image::DynamicImage::new_rgb8(40, 20)
        .write_to(&mut bytes, image::ImageFormat::Png)
        .unwrap();
    bytes.into_inner()
}
fn preset() -> PackPreset {
    PackPreset {
        schema_version: 1,
        name: "Personal requirements".into(),
        revision_date: "2026-10-21".into(),
        source: None,
        verified: false,
        slots: vec![
            PackSlot {
                label: "Portrait".into(),
                required: true,
                filename: "portrait.jpg".into(),
                formats: vec!["jpeg".into()],
                width: Some(80),
                height: Some(60),
                max_bytes: Some(ByteLimit {
                    value: 100,
                    unit: SizeUnit::KiB,
                    strict: true,
                }),
                min_pages: None,
                max_pages: None,
            },
            PackSlot {
                label: "Optional signature".into(),
                required: false,
                filename: "signature.png".into(),
                formats: vec!["png".into()],
                width: Some(90),
                height: Some(30),
                max_bytes: None,
                min_pages: None,
                max_pages: None,
            },
        ],
    }
}
#[test]
fn custom_pack_measures_archive_and_retains_originals() {
    let original = image();
    let output = preset().prepare(vec![original.clone(), vec![]]).unwrap();
    export::verify_output(&output).unwrap();
    let mut archive = zip::ZipArchive::new(Cursor::new(&output.data)).unwrap();
    assert_eq!(archive.len(), 3);
    assert!(archive.by_name("signature.png").is_err());
    let mut photo = Vec::new();
    std::io::Read::read_to_end(&mut archive.by_name("portrait.jpg").unwrap(), &mut photo).unwrap();
    let decoded = image::load_from_memory(&photo).unwrap();
    assert_eq!((decoded.width(), decoded.height()), (80, 60));
    assert!(photo.len() < 100 * 1024);
    assert_eq!(original, image());
}
#[test]
fn custom_pack_errors_identify_required_or_bad_source() {
    assert!(
        preset()
            .prepare(vec![vec![], vec![]])
            .unwrap_err()
            .to_string()
            .starts_with("Portrait:")
    );
    assert!(
        preset()
            .prepare(vec![vec![1, 2], vec![]])
            .unwrap_err()
            .to_string()
            .starts_with("Portrait:")
    );
    assert!(preset().prepare(vec![image()]).is_err());
    let mut p = preset();
    p.slots[0].max_bytes = Some(ByteLimit {
        value: 1,
        unit: SizeUnit::KiB,
        strict: true,
    });
    // A tiny image can fit; if successful, the actual archive must still verify.
    if let Ok(out) = p.prepare(vec![image(), vec![]]) {
        export::verify_output(&out).unwrap();
    }
}
#[test]
fn preset_import_rejects_invalid_and_reserved_constraints() {
    let p = preset();
    for filename in [
        "../portrait.jpg",
        "manifest.json",
        "VALIDATION.TXT",
        "CON.jpg",
    ] {
        let mut invalid = p.clone();
        invalid.slots[0].filename = filename.into();
        assert!(invalid.validate().is_err());
    }
    for dimension in [0, 12001] {
        let mut invalid = p.clone();
        invalid.slots[0].width = Some(dimension);
        assert!(invalid.validate().is_err());
    }
    let mut invalid = p.clone();
    invalid.slots[0].min_pages = Some(0);
    assert!(invalid.validate().is_err());
    let mut invalid = p.clone();
    invalid.slots[1].filename = "PORTRAIT.JPG".into();
    assert!(invalid.validate().is_err());
    let mut invalid = p.clone();
    invalid.verified = true;
    assert!(invalid.validate().is_err());
    assert!(PackPreset::parse(&vec![b' '; 65537]).is_err());
    let mut json = serde_json::to_value(&p).unwrap();
    json["execute"] = serde_json::json!("anything");
    assert!(PackPreset::parse(&serde_json::to_vec(&json).unwrap()).is_err());
}
#[test]
fn native_api_roundtrips_requirement_only_json() {
    let json = serde_json::to_string(&preset()).unwrap();
    let output = api::validate_pack_preset(json.clone()).unwrap();
    api::validate_prepared_output(output.clone(), "application-preset.json".into()).unwrap();
    let parsed = PackPreset::parse(&output.bytes).unwrap();
    assert_eq!(parsed.slots.len(), 2);
    assert!(
        !String::from_utf8(output.bytes)
            .unwrap()
            .contains("sourceName")
    );
    let pack = api::create_custom_application_pack(vec![image(), vec![]], json).unwrap();
    assert_eq!(pack.format, "zip");
}
#[test]
fn pdf_slot_enforces_actual_page_count() {
    let mut p = preset();
    p.slots.truncate(1);
    let slot = &mut p.slots[0];
    slot.formats = vec!["pdf".into()];
    slot.filename = "certificate.pdf".into();
    slot.width = None;
    slot.height = None;
    slot.min_pages = Some(2);
    slot.max_pages = Some(3);
    slot.max_bytes = None;
    let pdf = studio_core::pdf::images_to_pdf(&[image()], &Default::default()).unwrap();
    let error = p.prepare(vec![pdf.data]).unwrap_err().to_string();
    assert!(error.starts_with("Portrait:"));
}
