use std::io::{Cursor, Read};
use studio_core::{api, model::*, packs::PackPreset};

fn preset() -> PackPreset {
    PackPreset::parse(serde_json::json!({
        "schema_version":1,"name":"Retry example","revision_date":"2026-10-24","source":null,"verified":false,
        "slots":[
            {"label":"Portrait","required":true,"filename":"portrait.jpg","formats":["jpeg"],"width":30,"height":20,"max_bytes":null,"min_pages":null,"max_pages":null},
            {"label":"Signature","required":true,"filename":"signature.png","formats":["png"],"width":40,"height":10,"max_bytes":null,"min_pages":null,"max_pages":null},
            {"label":"Optional","required":false,"filename":"optional.pdf","formats":["pdf"],"width":null,"height":null,"max_bytes":null,"min_pages":1,"max_pages":2}
        ]
    }).to_string().as_bytes()).unwrap()
}
fn image() -> Vec<u8> {
    let mut bytes = Cursor::new(Vec::new());
    image::DynamicImage::ImageRgb8(image::RgbImage::from_fn(30, 20, |x, y| {
        image::Rgb([(x * 7) as u8, (y * 9) as u8, 80])
    }))
    .write_to(&mut bytes, image::ImageFormat::Png)
    .unwrap();
    bytes.into_inner()
}

#[test]
fn failed_peer_can_be_repaired_and_archive_keeps_successful_encoded_bytes() {
    let preset = preset();
    let first = preset.prepare_slot(0, image()).unwrap().unwrap();
    let saved_first = first.data.clone();
    assert!(
        preset
            .prepare_slot(1, b"broken".to_vec())
            .unwrap_err()
            .to_string()
            .starts_with("Signature:")
    );
    let second = preset.prepare_slot(1, image()).unwrap().unwrap();
    assert!(preset.prepare_slot(2, vec![]).unwrap().is_none());
    let output = preset.build(vec![Some(first), Some(second), None]).unwrap();
    let mut archive = zip::ZipArchive::new(Cursor::new(output.data)).unwrap();
    let mut stored = Vec::new();
    archive
        .by_name("portrait.jpg")
        .unwrap()
        .read_to_end(&mut stored)
        .unwrap();
    assert_eq!(stored, saved_first);
    assert_eq!(archive.len(), 4);
    assert!(archive.by_name("optional.pdf").is_err());
}

#[test]
fn cached_builder_reopens_bytes_and_rejects_stale_or_fabricated_metadata() {
    let preset = preset();
    let json = serde_json::to_string(&preset).unwrap();
    let first = api::prepare_custom_pack_slot(image(), json.clone(), 0).unwrap();
    let second = api::prepare_custom_pack_slot(image(), json.clone(), 1).unwrap();
    let build = |a: api::StudioOutput, b: api::StudioOutput, settings: String| {
        api::build_custom_application_pack(vec![Some(a), Some(b), None], settings)
    };
    assert!(build(first.clone(), second.clone(), json.clone()).is_ok());
    let mut bad = first.clone();
    bad.width = Some(99);
    assert!(build(bad, second.clone(), json.clone()).is_err());
    let mut bad = first.clone();
    bad.bytes[0] = 0;
    assert!(build(bad, second.clone(), json.clone()).is_err());
    let mut bad = first.clone();
    bad.pages = Some(1);
    assert!(build(bad, second.clone(), json.clone()).is_err());
    let mut changed = preset.clone();
    changed.slots[0].width = Some(31);
    assert!(
        build(
            first.clone(),
            second.clone(),
            serde_json::to_string(&changed).unwrap()
        )
        .unwrap_err()
        .contains("Portrait:")
    );
    assert!(api::build_custom_application_pack(vec![None, Some(second), None], json).is_err());
}

#[test]
fn independent_preparation_checks_page_constraints_and_slot_bounds() {
    let mut preset = preset();
    preset.slots[2].min_pages = Some(2);
    let pdf = studio_core::pdf::images_to_pdf(&[image()], &Default::default()).unwrap();
    assert!(
        preset
            .prepare_slot(2, pdf.data)
            .unwrap_err()
            .to_string()
            .contains("Optional:")
    );
    assert!(preset.prepare_slot(99, image()).is_err());
    assert!(
        preset
            .prepare_slot(0, vec![])
            .unwrap_err()
            .to_string()
            .contains("Portrait:")
    );
}

#[test]
fn cached_api_rejects_wrong_count_and_aggregate_encoded_budget_before_decoding() {
    let json = serde_json::to_string(&preset()).unwrap();
    assert!(api::build_custom_application_pack(vec![], json.clone()).is_err());
    let mut output = api::prepare_custom_pack_slot(image(), json.clone(), 0).unwrap();
    output.bytes = vec![0; MAX_INPUT_BYTES + 1];
    assert!(
        api::build_custom_application_pack(vec![Some(output), None, None], json)
            .unwrap_err()
            .contains("64 MiB")
    );
}
