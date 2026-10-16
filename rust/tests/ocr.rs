use studio_core::{export, ocr};
#[cfg(target_os = "linux")]
use studio_core::{jobs::Cancellation, model::StudioError};

#[test]
fn editable_text_is_verified_utf8_and_saved_without_overwrite() {
    let output = ocr::text_output("আমার বাংলা ভাষা\n".as_bytes().to_vec()).unwrap();
    export::verify_output(&output).unwrap();
    let directory = tempfile::tempdir().unwrap();
    export::save_copy(directory.path(), "বাংলা.txt", &output).unwrap();
    assert_eq!(
        std::fs::read(directory.path().join("বাংলা.txt")).unwrap(),
        output.data
    );
    assert!(export::save_copy(directory.path(), "বাংলা.txt", &output).is_err());
    assert!(ocr::text_output(vec![0xff]).is_err());
    assert!(ocr::text_output(Vec::new()).is_err());
    let mut forged = output;
    forged.info.width = Some(300);
    assert!(export::verify_output(&forged).is_err());
}

#[test]
fn corrupted_local_models_are_rejected() {
    let directory = tempfile::tempdir().unwrap();
    std::fs::write(directory.path().join("eng.traineddata"), b"corrupt").unwrap();
    assert!(ocr::verify_models(directory.path()).is_err());
}

#[cfg(target_os = "linux")]
#[test]
fn pre_cancelled_ocr_does_not_decode_or_start_engine() {
    let cancel = Cancellation::default();
    cancel.cancel();
    assert!(matches!(
        ocr::recognize(b"not an image", ocr::Language::English, &cancel),
        Err(StudioError::Cancelled)
    ));
}

#[cfg(target_os = "linux")]
#[test]
fn model_devices_and_pipes_do_not_block_validation() {
    use std::{ffi::CString, sync::mpsc, time::Duration};
    let directory = tempfile::tempdir().unwrap();
    let filename = directory.path().join("eng.traineddata");
    let name = CString::new(filename.to_str().unwrap()).unwrap();
    assert_eq!(unsafe { libc::mkfifo(name.as_ptr(), 0o600) }, 0);
    let path = directory.path().to_owned();
    let (sender, receiver) = mpsc::channel();
    std::thread::spawn(move || {
        let _ = sender.send(ocr::verify_models(&path).is_err());
    });
    assert!(
        receiver
            .recv_timeout(Duration::from_secs(1))
            .expect("Model validation blocked on a pipe")
    );
}
