fn main() {
    match pdfium_render::prelude::Pdfium::bind_to_library(
        std::env::var("UST_PDFIUM_LIBRARY").unwrap(),
    ) {
        Ok(_) => println!("PDFium bindings loaded"),
        Err(e) => eprintln!("PDFium binding diagnostic: {e:?}"),
    }
}
