use studio_core::{pdf, photo, rendering};
#[test]
fn pdfium_renders_real_pages_and_exports_images() {
    // This test is an explicit native integration gate; never silently skipped.
    assert!(
        std::env::var_os("UST_PDFIUM_LIBRARY").is_some(),
        "Set UST_PDFIUM_LIBRARY to the audited native PDFium binary"
    );
    let input = std::fs::read("../verification-outputs/three-page-scan.pdf").unwrap();
    let preview = rendering::page(&input, 0, 800).unwrap();
    let image = photo::decode(&preview.data).unwrap();
    assert!(image.width() <= 800 && image.height() <= 800);
    assert!(image.to_rgb8().pixels().any(|p| p[0] < 200));
    let moved = pdf::arrange(&[input.clone()], Some(&[3, 1, 2]), 0).unwrap();
    let expected = rendering::page(&input, 2, 800).unwrap();
    let actual = rendering::page(&moved.data, 0, 800).unwrap();
    assert_eq!(
        expected.data, actual.data,
        "Reordered page must render identically"
    );
    let zip = rendering::pages_to_zip(&input, &[2, 0], 800).unwrap();
    studio_core::export::verify_output(&zip).unwrap();
    assert!(rendering::page(&input, 99, 800).is_err());
    assert!(rendering::page(&input, 0, 99999).is_err());
}
