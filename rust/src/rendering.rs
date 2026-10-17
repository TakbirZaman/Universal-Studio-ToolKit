//! Lazy, serialized PDFium adapter. Non-V8/non-XFA binary; no scripting callbacks.
use crate::model::*;
use pdfium_render::prelude::*;
use std::{io::Cursor, path::PathBuf, sync::Mutex};
static PDFIUM_LOCK: Mutex<()> = Mutex::new(());
fn error(_: PdfiumError) -> StudioError {
    invalid("PDF preview could not be rendered. Check the bundled PDFium engine and document.")
}
fn library() -> Result<Pdfium> {
    let path = std::env::var_os("UST_PDFIUM_LIBRARY")
        .map(PathBuf::from)
        .unwrap_or_else(|| {
            let exe = std::env::current_exe().unwrap_or_default();
            let base = exe.parent().unwrap_or(std::path::Path::new("."));
            if cfg!(target_os = "windows") {
                base.join("pdfium.dll")
            } else {
                base.join("lib/libpdfium.so")
            }
        });
    let binding = if cfg!(target_os = "android") {
        Pdfium::bind_to_system_library()
    } else {
        Pdfium::bind_to_library(path)
    };
    match binding {
        Ok(bindings) => Ok(Pdfium::new(bindings)),
        // 0.9.x retains process-global bindings. This path reuses them without a filesystem lookup.
        Err(PdfiumError::PdfiumLibraryBindingsAlreadyInitialized) => Ok(Pdfium::default()),
        Err(_) => Err(invalid(
            "PDF previews are unavailable because the PDFium library is missing or incompatible.",
        )),
    }
}
pub fn page(data: &[u8], index: u32, max_pixels: u32) -> Result<PreparedOutput> {
    if !(64..=2048).contains(&max_pixels) {
        return Err(invalid("Preview size must be 64–2048 pixels."));
    }
    let count = crate::pdf::page_count(data)?;
    if index >= count {
        return Err(invalid("Page is outside the document."));
    }
    let _guard = PDFIUM_LOCK
        .lock()
        .map_err(|_| invalid("The preview engine needs to restart."))?;
    let engine = library()?;
    let doc = engine.load_pdf_from_byte_slice(data, None).map_err(error)?;
    let page = doc.pages().get(index as i32).map_err(error)?;
    let config = PdfRenderConfig::new()
        .set_target_width(max_pixels as i32)
        .set_maximum_height(max_pixels as i32)
        .render_form_data(false);
    let bitmap = page.render_with_config(&config).map_err(error)?;
    let img = bitmap.as_image().map_err(error)?;
    let mut encoded = Cursor::new(Vec::new());
    img.write_to(&mut encoded, image::ImageFormat::Png)?;
    let bytes = encoded.into_inner();
    let info = OutputInfo {
        format: "png".into(),
        bytes: bytes.len() as u64,
        width: Some(img.width()),
        height: Some(img.height()),
        pages: None,
        quality: None,
        print_density: None,
        findings: vec![ValidationFinding {
            advisory: false,
            code: "pdfium_render".into(),
            passed: true,
            message: format!(
                "Page {} rendered with PDFium. This image is a raster copy and does not retain selectable text, forms or vector editing.",
                index + 1
            ),
        }],
    };
    let out = PreparedOutput { data: bytes, info };
    crate::export::verify_output(&out)?;
    Ok(out)
}
pub fn pages_to_zip(data: &[u8], indices: &[u32], max_pixels: u32) -> Result<PreparedOutput> {
    if indices.is_empty() || indices.len() > 32 {
        return Err(invalid("Export 1–32 pages at a time."));
    }
    let mut seen = std::collections::HashSet::new();
    let mut items = Vec::new();
    let mut total = 0usize;
    for &index in indices {
        if !seen.insert(index) {
            return Err(invalid("Page selection contains duplicates."));
        }
        let out = page(data, index, max_pixels)?;
        total += out.data.len();
        if total > MAX_INPUT_BYTES {
            return Err(invalid(
                "Rendered pages exceed the 64 MiB output budget. Select fewer pages.",
            ));
        }
        items.push((format!("page-{:04}.png", index + 1), out));
    }
    crate::export::pack(items)
}
