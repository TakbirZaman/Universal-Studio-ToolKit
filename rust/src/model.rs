use serde::{Deserialize, Serialize};

#[derive(Debug, thiserror::Error)]
pub enum StudioError {
    #[error("{0}")]
    Invalid(String),
    #[error("Couldn’t meet both requirements. Increase the size limit or change the dimensions.")]
    Impossible,
    #[error("Processing was cancelled; no output was saved.")]
    Cancelled,
    #[error("Couldn’t read or save the document. Check access and free space.")]
    Io(#[from] std::io::Error),
    #[error("The image could not be processed.")]
    Image(#[from] image::ImageError),
    #[error("The PDF could not be processed.")]
    Pdf(#[from] lopdf::Error),
    #[error("The recipe or manifest is invalid.")]
    Json(#[from] serde_json::Error),
    #[error("The archive could not be written.")]
    Zip(#[from] zip::result::ZipError),
}
pub type Result<T> = std::result::Result<T, StudioError>;
pub fn invalid(s: &str) -> StudioError {
    StudioError::Invalid(s.into())
}
pub const MAX_INPUT_BYTES: usize = 64 * 1024 * 1024;
pub const MAX_PIXELS: u64 = 24_000_000;
pub const MAX_PAGES: usize = 200;
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum SourceDocument {
    Managed { id: String },
    ContentUri { uri: String },
    LocalFile { path: String },
}
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SizeUnit {
    KB,
    KiB,
}
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct ByteLimit {
    pub value: u64,
    pub unit: SizeUnit,
    pub strict: bool,
}
impl ByteLimit {
    pub fn bytes(self) -> Result<u64> {
        self.value
            .checked_mul(match self.unit {
                SizeUnit::KB => 1000,
                SizeUnit::KiB => 1024,
            })
            .ok_or_else(|| invalid("File size limit is too large."))
    }
    pub fn accepts(self, n: usize) -> Result<bool> {
        let b = self.bytes()?;
        Ok(if self.strict {
            (n as u64) < b
        } else {
            n as u64 <= b
        })
    }
}
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "snake_case")]
pub enum OutputFormat {
    Jpeg,
    Png,
}
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Fit {
    Contain,
    Cover,
}
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CropRect {
    pub x: u32,
    pub y: u32,
    pub width: u32,
    pub height: u32,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct PhotoOptions {
    pub width: u32,
    pub height: u32,
    pub format: OutputFormat,
    pub fit: Fit,
    pub min_quality: u8,
    pub max_bytes: Option<ByteLimit>,
    pub background: [u8; 3],
    pub flatten_transparency: bool,
    pub rotate_quarters: u8,
    pub flip_horizontal: bool,
    pub signature_threshold: Option<u8>,
    #[serde(default)]
    pub crop: Option<CropRect>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub output_dpi: Option<u16>,
}
impl Default for PhotoOptions {
    fn default() -> Self {
        Self {
            width: 300,
            height: 300,
            format: OutputFormat::Jpeg,
            fit: Fit::Contain,
            min_quality: 60,
            max_bytes: None,
            background: [255, 255, 255],
            flatten_transparency: false,
            rotate_quarters: 0,
            flip_horizontal: false,
            signature_threshold: None,
            crop: None,
            output_dpi: None,
        }
    }
}
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ValidationFinding {
    #[serde(default)]
    pub advisory: bool,
    pub code: String,
    pub message: String,
    pub passed: bool,
}
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct PrintDensity {
    pub x_dpi: f64,
    pub y_dpi: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct PhysicalPhotoSpec {
    pub width_mm: f64,
    pub height_mm: f64,
    pub dpi: u16,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OutputInfo {
    pub format: String,
    pub bytes: u64,
    pub width: Option<u32>,
    pub height: Option<u32>,
    pub pages: Option<u32>,
    pub quality: Option<u8>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub print_density: Option<PrintDensity>,
    pub findings: Vec<ValidationFinding>,
}
#[derive(Debug, Clone)]
pub struct PreparedOutput {
    pub data: Vec<u8>,
    pub info: OutputInfo,
}
