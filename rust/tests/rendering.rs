use studio_core::{pdf, photo, rendering};
#[test]
fn pdfium_renders_real_pages_and_exports_images() {
    // This test is an explicit native integration gate; never silently skipped.
    assert!(
        std::env::var_os("UST_PDFIUM_LIBRARY").is_some(),
        "Set UST_PDFIUM_LIBRARY to the audited native PDFium binary"
    );
    // Generate synthetic pages locally so the test requires no private documents
    // or committed output artifacts.
    let sources: Vec<Vec<u8>> = (0..3)
        .map(|index| {
            let image = image::RgbImage::from_fn(80, 100, |x, y| {
                image::Rgb([((x + index * 30) % 200) as u8, (y % 180) as u8, 150])
            });
            let mut encoded = std::io::Cursor::new(Vec::new());
            image::DynamicImage::ImageRgb8(image)
                .write_to(&mut encoded, image::ImageFormat::Png)
                .unwrap();
            encoded.into_inner()
        })
        .collect();
    let input = pdf::images_to_pdf(&sources, &Default::default())
        .unwrap()
        .data;
    let optimized = pdf::optimize_lossless(&input).unwrap();
    assert!(optimized.data.len() <= input.len());
    for index in 0..3 {
        assert_eq!(
            rendering::page(&input, index, 800).unwrap().data,
            rendering::page(&optimized.data, index, 800).unwrap().data
        );
    }
    studio_core::export::verify_output(&optimized).unwrap();
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

#[test]
fn lossless_optimization_preserves_selectable_text_and_rendering() {
    use lopdf::{Document, Object, Stream, dictionary};
    let mut document = Document::with_version("1.7");
    let pages = document.new_object_id();
    let font = document.add_object(dictionary! {
        "Type" => "Font", "Subtype" => "Type1", "BaseFont" => "Helvetica",
        "Encoding" => "WinAnsiEncoding"
    });
    let content = document.add_object(Stream::new(
        dictionary! {},
        b"BT /F1 18 Tf 40 100 Td (Selectable document text) Tj ET".to_vec(),
    ));
    let page = document.add_object(dictionary! {
        "Type" => "Page", "Parent" => pages,
        "MediaBox" => vec![0.into(), 0.into(), 300.into(), 200.into()],
        "Resources" => dictionary! {"Font" => dictionary! {"F1" => font}},
        "Contents" => content
    });
    document.objects.insert(
        pages,
        Object::Dictionary(dictionary! {
            "Type" => "Pages", "Kids" => vec![Object::Reference(page)], "Count" => 1
        }),
    );
    let root = document.add_object(dictionary! {"Type" => "Catalog", "Pages" => pages});
    document.trailer.set("Root", root);
    let mut original = Vec::new();
    document.save_to(&mut original).unwrap();
    let optimized = pdf::optimize_lossless(&original).unwrap();
    let before = pdf::extract_text(&original).unwrap();
    assert!(before.contains("Selectable document text"));
    assert_eq!(before, pdf::extract_text(&optimized.data).unwrap());
    assert_eq!(
        rendering::page(&original, 0, 800).unwrap().data,
        rendering::page(&optimized.data, 0, 800).unwrap().data
    );
    assert!(optimized.data.len() <= original.len());
}
