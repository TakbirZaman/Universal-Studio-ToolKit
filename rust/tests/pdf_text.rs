use lopdf::{Dictionary, Document, Object, Stream, dictionary};
use studio_core::{export, rendering, text};
fn document(labels: &[Option<&str>]) -> Vec<u8> {
    let mut document = Document::with_version("1.7");
    let pages = document.new_object_id();
    let font = document.add_object(dictionary!{"Type"=>"Font", "Subtype"=>"Type1", "BaseFont"=>"Helvetica", "Encoding"=>"WinAnsiEncoding"});
    let mut kids = Vec::new();
    for label in labels {
        let content = match label {
            Some(value) if value.len() > 80 => {
                let mut content = String::from("BT /F1 5 Tf 40 700 Td 6 TL ");
                for chunk in value.as_bytes().chunks(100) {
                    content.push_str(&format!("({}) Tj T* ", std::str::from_utf8(chunk).unwrap()));
                }
                content.push_str("ET");
                content
            }
            Some(value) => format!("BT /F1 14 Tf 40 700 Td ({value}) Tj ET"),
            None => "0 0 0 rg 40 40 100 100 re f".into(),
        };
        let stream = document.add_object(Stream::new(Dictionary::new(), content.into_bytes()));
        let page = document.add_object(dictionary!{"Type"=>"Page", "Parent"=>pages, "MediaBox"=>vec![0.into(),0.into(),595.into(),842.into()], "Resources"=>dictionary!{"Font"=>dictionary!{"F1"=>font}}, "Contents"=>stream});
        kids.push(Object::Reference(page));
    }
    document.objects.insert(
        pages,
        Object::Dictionary(
            dictionary! {"Type"=>"Pages", "Kids"=>kids, "Count"=>labels.len() as i64},
        ),
    );
    let catalog = document.add_object(dictionary! {"Type"=>"Catalog", "Pages"=>pages});
    document.trailer.set("Root", catalog);
    let mut bytes = Vec::new();
    document.save_to(&mut bytes).unwrap();
    bytes
}
#[test]
fn existing_text_keeps_page_order_and_reports_empty_pages_without_ocr() {
    let source = document(&[Some("First certificate"), None, Some("Last certificate")]);
    let original = source.clone();
    let output = rendering::selectable_text(&source).unwrap();
    let decoded = std::str::from_utf8(&output.data).unwrap();
    assert!(decoded.find("First certificate").unwrap() < decoded.find("Last certificate").unwrap());
    assert_eq!(source, original);
    assert!(
        output
            .info
            .findings
            .iter()
            .any(|f| f.message.contains("1 pages had no selectable text"))
    );
    assert!(
        !output
            .info
            .findings
            .iter()
            .any(|f| f.code == "ocr_review_required")
    );
    export::verify_output(&output).unwrap();
    let dir = tempfile::tempdir().unwrap();
    export::save_copy(dir.path(), "সনদের-লেখা.txt", &output).unwrap();
    assert_eq!(
        std::fs::read(dir.path().join("সনদের-লেখা.txt")).unwrap(),
        output.data
    );
    assert!(export::save_copy(dir.path(), "সনদের-লেখা.txt", &output).is_err());
}
#[test]
fn image_only_and_invalid_pdfs_do_not_fabricate_text() {
    assert!(
        rendering::selectable_text(&document(&[None]))
            .unwrap_err()
            .to_string()
            .contains("No selectable text")
    );
    assert!(rendering::selectable_text(b"not a PDF").is_err());
}
#[test]
fn plain_text_preserves_unicode_and_enforces_actual_utf8_bytes() {
    let bytes = "সনদ\nCertificate ✓".as_bytes().to_vec();
    let output = text::output(bytes.clone()).unwrap();
    assert_eq!(output.data, bytes);
    export::verify_output(&output).unwrap();
    assert!(text::output(Vec::new()).is_err());
    assert!(text::output(vec![0xff]).is_err());
    assert!(text::output(vec![b'a'; text::MAX_BYTES + 1]).is_err());
}
#[test]
fn oversized_text_layer_is_rejected_before_collecting_an_export() {
    let text = "A".repeat(8000);
    let source = document(&vec![Some(text.as_str()); 126]);
    let failure = rendering::selectable_text(&source).unwrap_err().to_string();
    assert!(failure.contains("one million characters"), "{failure}");
}
