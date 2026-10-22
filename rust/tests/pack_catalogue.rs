use studio_core::{api, packs::PackPreset, storage::Store};

fn preset(name: &str) -> PackPreset {
    PackPreset::parse(
        serde_json::json!({
            "schema_version":1,"name":name,"revision_date":"2026-10-22",
            "source":"User supplied requirements", "verified":false,
            "slots":[{"label":"Portrait","required":true,"filename":"photo.jpg",
                "formats":["jpeg"],"width":300,"height":300,"max_bytes":null,
                "min_pages":null,"max_pages":null}]
        })
        .to_string()
        .as_bytes(),
    )
    .unwrap()
}

#[test]
fn restart_unicode_identity_no_overwrite_and_delete() {
    let dir = tempfile::tempdir().unwrap();
    let original = preset("আবেদন'; DROP TABLE presets;--");
    {
        let db = Store::open(dir.path()).unwrap();
        db.save_preset(&original).unwrap();
        db.save_preset(&original).unwrap();
        let mut changed = original.clone();
        changed.slots[0].width = Some(200);
        assert!(
            db.save_preset(&changed)
                .unwrap_err()
                .to_string()
                .contains("already exists")
        );
    }
    let db = Store::open(dir.path()).unwrap();
    let restored = db.presets().unwrap();
    assert_eq!(restored.len(), 1);
    assert_eq!(restored[0].name, original.name);
    assert_eq!(restored[0].slots[0].width, Some(300));
    assert!(db.history().unwrap().is_empty());
    db.delete_preset(&original.name).unwrap();
    assert!(
        Store::open(dir.path())
            .unwrap()
            .presets()
            .unwrap()
            .is_empty()
    );
    assert_eq!(db.settings().unwrap().theme, "system");
}

#[test]
fn concurrent_writers_obey_transactional_quota_and_deletion_frees_capacity() {
    let dir = tempfile::tempdir().unwrap();
    Store::open(dir.path()).unwrap();
    std::thread::scope(|scope| {
        for group in 0..2 {
            let path = dir.path();
            scope.spawn(move || {
                let db = Store::open(path).unwrap();
                for i in 0..40 {
                    if let Err(error) = db.save_preset(&preset(&format!("Group {group}-{i}"))) {
                        assert!(error.to_string().contains("64 entries"), "{error}");
                    }
                }
            });
        }
    });
    let db = Store::open(dir.path()).unwrap();
    let items = db.presets().unwrap();
    assert_eq!(items.len(), 64);
    assert!(db.save_preset(&preset("New")).is_err());
    db.delete_preset(&items[0].name).unwrap();
    db.save_preset(&preset("New")).unwrap();
    assert_eq!(db.presets().unwrap().len(), 64);
}

#[test]
fn api_rejects_document_payloads_and_bad_presets_before_persisting() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().to_string_lossy().to_string();
    let original = preset("Example");
    let mut json = serde_json::to_value(&original).unwrap();
    json["source_bytes"] = serde_json::json!([1, 2, 3]);
    assert!(api::save_pack_preset(path.clone(), json.to_string()).is_err());
    assert!(api::save_pack_preset(path.clone(), "x".repeat(65537)).is_err());
    assert!(!dir.path().join("studio.sqlite3").exists());
    api::save_pack_preset(path.clone(), serde_json::to_string(&original).unwrap()).unwrap();
    let listed = api::list_pack_presets(path.clone()).unwrap();
    assert_eq!(listed.len(), 1);
    let restored = PackPreset::parse(listed[0].as_bytes()).unwrap();
    assert_eq!(restored.name, original.name);
    api::delete_pack_preset(path.clone(), original.name).unwrap();
    assert!(api::list_pack_presets(path).unwrap().is_empty());
}

#[test]
fn corrupt_or_mismatched_rows_are_reported_without_deletion() {
    let dir = tempfile::tempdir().unwrap();
    let db = Store::open(dir.path()).unwrap();
    let raw = rusqlite::Connection::open(dir.path().join("studio.sqlite3")).unwrap();
    raw.execute(
        "INSERT INTO presets(name,value) VALUES(?1,?2)",
        rusqlite::params![
            "Wrong identity",
            serde_json::to_string(&preset("Actual identity")).unwrap()
        ],
    )
    .unwrap();
    assert!(db.presets().unwrap_err().to_string().contains("identity"));
    assert_eq!(
        raw.query_row("SELECT count(*) FROM presets", [], |r| r.get::<_, i64>(0))
            .unwrap(),
        1
    );
    db.delete_preset("Wrong identity").unwrap();
    raw.execute(
        "INSERT INTO presets(name,value) VALUES('Broken','not json')",
        [],
    )
    .unwrap();
    assert!(db.presets().is_err());
    assert_eq!(db.settings().unwrap().theme, "system");
}
