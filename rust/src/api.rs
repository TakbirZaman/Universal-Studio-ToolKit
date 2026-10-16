use crate::{export, jobs, model::*, pdf, photo};
/// Byte-based source boundary: Android URIs are resolved by the platform, never treated as paths.
#[derive(Clone, Debug)]
pub struct StudioOutput {
    pub bytes: Vec<u8>,
    pub format: String,
    pub width: Option<u32>,
    pub height: Option<u32>,
    pub pages: Option<u32>,
    pub quality: Option<u8>,
    pub validation: String,
}
impl From<PreparedOutput> for StudioOutput {
    fn from(o: PreparedOutput) -> Self {
        Self {
            bytes: o.data,
            format: o.info.format,
            width: o.info.width,
            height: o.info.height,
            pages: o.info.pages,
            quality: o.info.quality,
            validation: o
                .info
                .findings
                .iter()
                .map(|f| f.message.clone())
                .collect::<Vec<_>>()
                .join(" "),
        }
    }
}
pub fn resize_photo(
    data: Vec<u8>,
    width: u32,
    height: u32,
    png: bool,
    cover: bool,
    limit_kib: Option<u32>,
    minimum_quality: u8,
    flatten: bool,
    rotation: u8,
    signature_threshold: Option<u8>,
) -> std::result::Result<StudioOutput, String> {
    jobs::serial(|| {
        photo::process(
            &data,
            &PhotoOptions {
                width,
                height,
                format: if png {
                    OutputFormat::Png
                } else {
                    OutputFormat::Jpeg
                },
                fit: if cover { Fit::Cover } else { Fit::Contain },
                min_quality: minimum_quality,
                max_bytes: limit_kib.map(|v| ByteLimit {
                    value: v as u64,
                    unit: SizeUnit::KiB,
                    strict: true,
                }),
                flatten_transparency: flatten,
                rotate_quarters: rotation,
                signature_threshold,
                ..Default::default()
            },
        )
    })
    .map(Into::into)
    .map_err(|e| e.to_string())
}
pub fn combine_pdfs(
    inputs: Vec<Vec<u8>>,
    pages: Option<Vec<u32>>,
    rotation: i32,
) -> std::result::Result<StudioOutput, String> {
    jobs::serial(|| pdf::arrange(&inputs, pages.as_deref(), rotation))
        .map(Into::into)
        .map_err(|e| e.to_string())
}
pub fn scan_pdf(inputs: Vec<Vec<u8>>) -> std::result::Result<StudioOutput, String> {
    jobs::serial(|| pdf::images_to_pdf(&inputs, &pdf::Paper::default()))
        .map(Into::into)
        .map_err(|e| e.to_string())
}
pub fn count_pdf(data: Vec<u8>) -> std::result::Result<u32, String> {
    jobs::serial(|| pdf::page_count(&data)).map_err(|e| e.to_string())
}
pub fn save_output(
    directory: String,
    filename: String,
    output: StudioOutput,
) -> std::result::Result<(), String> {
    let info = OutputInfo {
        format: output.format,
        bytes: output.bytes.len() as u64,
        width: output.width,
        height: output.height,
        pages: output.pages,
        quality: output.quality,
        findings: vec![],
    };
    export::save_copy(
        std::path::Path::new(&directory),
        &filename,
        &PreparedOutput {
            data: output.bytes,
            info,
        },
    )
    .map_err(|e| e.to_string())
}
pub fn create_print_sheet(
    data: Vec<u8>,
    width_mm: f64,
    height_mm: f64,
    copies: u32,
) -> std::result::Result<StudioOutput, String> {
    jobs::serial(|| {
        pdf::print_sheet(
            &data,
            &pdf::Paper::default(),
            width_mm,
            height_mm,
            4.,
            copies,
        )
    })
    .map(Into::into)
    .map_err(|e| e.to_string())
}
pub fn create_application_pack(
    photo: Vec<u8>,
    signature: Vec<u8>,
    certificate: Vec<u8>,
    limit_kib: u32,
) -> std::result::Result<StudioOutput, String> {
    jobs::serial(|| {
        let limit = ByteLimit {
            value: limit_kib as u64,
            unit: SizeUnit::KiB,
            strict: true,
        };
        let p = crate::photo::process(
            &photo,
            &PhotoOptions {
                max_bytes: Some(limit),
                ..Default::default()
            },
        )?;
        let s = crate::photo::process(
            &signature,
            &PhotoOptions {
                width: 300,
                height: 100,
                format: OutputFormat::Png,
                signature_threshold: Some(230),
                max_bytes: Some(limit),
                ..Default::default()
            },
        )?;
        let c = pdf::arrange(&[certificate], None, 0)?;
        let slots = vec![
            crate::packs::PackSlot {
                label: "Photo".into(),
                required: true,
                filename: "photo.jpg".into(),
                formats: vec!["jpeg".into()],
                width: Some(300),
                height: Some(300),
                max_bytes: Some(limit),
                min_pages: None,
                max_pages: None,
            },
            crate::packs::PackSlot {
                label: "Signature".into(),
                required: true,
                filename: "signature.png".into(),
                formats: vec!["png".into()],
                width: Some(300),
                height: Some(100),
                max_bytes: Some(limit),
                min_pages: None,
                max_pages: None,
            },
            crate::packs::PackSlot {
                label: "Certificate".into(),
                required: true,
                filename: "certificate.pdf".into(),
                formats: vec!["pdf".into()],
                width: None,
                height: None,
                max_bytes: None,
                min_pages: Some(1),
                max_pages: Some(200),
            },
        ];
        crate::packs::PackPreset {
            schema_version: 1,
            name: "Example application".into(),
            revision_date: "2026-10-15".into(),
            source: None,
            verified: false,
            slots,
        }
        .build(vec![Some(p), Some(s), Some(c)])
    })
    .map(Into::into)
    .map_err(|e| e.to_string())
}

pub fn render_pdf_page(
    data: Vec<u8>,
    page_index: u32,
    max_pixels: u32,
) -> std::result::Result<StudioOutput, String> {
    jobs::serial(|| crate::rendering::page(&data, page_index, max_pixels))
        .map(Into::into)
        .map_err(|e| e.to_string())
}
pub fn export_pdf_images(
    data: Vec<u8>,
    page_indices: Vec<u32>,
    max_pixels: u32,
) -> std::result::Result<StudioOutput, String> {
    jobs::serial(|| crate::rendering::pages_to_zip(&data, &page_indices, max_pixels))
        .map(Into::into)
        .map_err(|e| e.to_string())
}
#[derive(Clone, Debug)]
pub struct StudioPreferences {
    pub theme: String,
    pub history_enabled: bool,
    pub retention_days: u32,
}
pub fn load_preferences(directory: String) -> std::result::Result<StudioPreferences, String> {
    jobs::serial(|| {
        let s = crate::storage::Store::open(std::path::Path::new(&directory))?.settings()?;
        Ok(StudioPreferences {
            theme: s.theme,
            history_enabled: s.history_enabled,
            retention_days: s.retention_days,
        })
    })
    .map_err(|e| e.to_string())
}
pub fn save_preferences(
    directory: String,
    preferences: StudioPreferences,
) -> std::result::Result<(), String> {
    jobs::serial(|| {
        crate::storage::Store::open(std::path::Path::new(&directory))?.set_settings(
            &crate::storage::Settings {
                schema_version: 1,
                theme: preferences.theme,
                history_enabled: preferences.history_enabled,
                retention_days: preferences.retention_days,
            },
        )
    })
    .map_err(|e| e.to_string())
}
pub fn clear_recent_history(directory: String) -> std::result::Result<(), String> {
    jobs::serial(|| crate::storage::Store::open(std::path::Path::new(&directory))?.clear_history())
        .map_err(|e| e.to_string())
}
pub fn save_recipe(directory: String, recipe_json: String) -> std::result::Result<(), String> {
    jobs::serial(|| {
        let r = crate::recipe::Recipe::parse(recipe_json.as_bytes())?;
        crate::storage::Store::open(std::path::Path::new(&directory))?.save_recipe(&r)
    })
    .map_err(|e| e.to_string())
}
pub fn list_recipes(directory: String) -> std::result::Result<Vec<String>, String> {
    jobs::serial(|| {
        crate::storage::Store::open(std::path::Path::new(&directory))?
            .recipes()?
            .iter()
            .map(|r| serde_json::to_string(r).map_err(Into::into))
            .collect()
    })
    .map_err(|e| e.to_string())
}
pub fn run_recipe(data: Vec<u8>, recipe_json: String) -> std::result::Result<StudioOutput, String> {
    jobs::serial(|| crate::recipe::Recipe::parse(recipe_json.as_bytes())?.run(&data))
        .map(Into::into)
        .map_err(|e| e.to_string())
}
pub fn adjust_scan_page(
    data: Vec<u8>,
    mode: String,
    rotation: u8,
    brightness: i32,
    contrast: f32,
    threshold: u8,
) -> std::result::Result<StudioOutput, String> {
    jobs::serial(|| {
        let mode = match mode.as_str() {
            "original" => crate::scanner::ScanMode::Original,
            "colour" => crate::scanner::ScanMode::Colour,
            "grayscale" => crate::scanner::ScanMode::Grayscale,
            "black_white" => crate::scanner::ScanMode::BlackWhite,
            _ => return Err(invalid("Unknown scan mode.")),
        };
        crate::scanner::process(
            &data,
            &crate::scanner::ScanOptions {
                mode,
                rotate_quarters: rotation,
                brightness,
                contrast,
                threshold,
            },
        )
    })
    .map(Into::into)
    .map_err(|e| e.to_string())
}
pub fn validate_prepared_output(
    output: StudioOutput,
    filename: String,
) -> std::result::Result<(), String> {
    jobs::serial(|| {
        crate::export::safe_name(&filename)?;
        let extension = std::path::Path::new(&filename)
            .extension()
            .and_then(|s| s.to_str())
            .unwrap_or("")
            .to_lowercase();
        if !(extension == output.format || (extension == "jpg" && output.format == "jpeg")) {
            return Err(invalid("Filename extension must match the output format."));
        }
        crate::export::verify_output(&PreparedOutput {
            info: OutputInfo {
                format: output.format,
                bytes: output.bytes.len() as u64,
                width: output.width,
                height: output.height,
                pages: output.pages,
                quality: output.quality,
                findings: vec![],
            },
            data: output.bytes,
        })
    })
    .map_err(|e| e.to_string())
}

/// Lossless structure optimization; retains original bytes if no smaller result exists.
pub fn optimize_pdf(data: Vec<u8>) -> std::result::Result<StudioOutput, String> {
    jobs::serial(|| pdf::optimize_lossless(&data))
        .map(Into::into)
        .map_err(|e| e.to_string())
}
