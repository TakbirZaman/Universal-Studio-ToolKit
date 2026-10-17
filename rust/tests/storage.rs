use studio_core::{model::*, recipe::Recipe, storage::*};
#[test]
fn settings_survive_restart_and_history_is_opt_in() {
    let dir = tempfile::tempdir().unwrap();
    let mut db = Store::open(dir.path()).unwrap();
    assert_eq!(db.settings().unwrap(), Settings::default());
    let info = OutputInfo {
        format: "jpeg".into(),
        bytes: 100,
        width: Some(300),
        height: Some(300),
        pages: None,
        quality: None,
        print_density: None,
        findings: vec![],
    };
    db.record("photo", &info).unwrap();
    assert!(db.history().unwrap().is_empty());
    db.set_settings(&Settings {
        theme: "dark".into(),
        history_enabled: true,
        ..Default::default()
    })
    .unwrap();
    db.record("photo", &info).unwrap();
    drop(db);
    let mut db = Store::open(dir.path()).unwrap();
    assert_eq!(db.settings().unwrap().theme, "dark");
    assert_eq!(db.history().unwrap().len(), 1);
    db.set_settings(&Settings::default()).unwrap();
    assert!(db.history().unwrap().is_empty());
}
#[test]
fn recipes_roundtrip_with_unicode_names_and_bound_parameters() {
    let dir = tempfile::tempdir().unwrap();
    let db = Store::open(dir.path()).unwrap();
    let r=Recipe::parse(br#"{"schema_version":1,"name":"safe","revision_date":"2026-10-15","steps":[{"type":"export","format":"png"}]}"#).unwrap();
    let mut named = r;
    named.name = "ছবি'; DROP TABLE recipes;--".into();
    db.save_recipe(&named).unwrap();
    assert_eq!(db.recipes().unwrap()[0].name, named.name);
    db.delete_recipe(&named.name).unwrap();
    assert!(db.recipes().unwrap().is_empty());
}
#[test]
fn settings_reject_unsupported_values() {
    let d = tempfile::tempdir().unwrap();
    let mut s = Store::open(d.path()).unwrap();
    assert!(
        s.set_settings(&Settings {
            theme: "unrecognized".into(),
            ..Default::default()
        })
        .is_err()
    );
    assert!(
        s.set_settings(&Settings {
            retention_days: 0,
            ..Default::default()
        })
        .is_err()
    );
}
