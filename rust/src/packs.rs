use crate::model::*;
use serde::{Deserialize, Serialize};
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct PackSlot {
    pub label: String,
    pub required: bool,
    pub filename: String,
    pub formats: Vec<String>,
    pub width: Option<u32>,
    pub height: Option<u32>,
    pub max_bytes: Option<ByteLimit>,
    pub min_pages: Option<u32>,
    pub max_pages: Option<u32>,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct PackPreset {
    pub schema_version: u32,
    pub name: String,
    pub revision_date: String,
    pub source: Option<String>,
    pub verified: bool,
    pub slots: Vec<PackSlot>,
}
impl PackPreset {
    pub fn parse(bytes: &[u8]) -> Result<Self> {
        if bytes.len() > 65536 {
            return Err(invalid("Pack preset exceeds 64 KiB."));
        }
        let preset: Self = serde_json::from_slice(bytes)?;
        preset.validate()?;
        Ok(preset)
    }
    /// Process original sources with explicit slot settings, then reopen and validate outputs.
    /// Empty bytes mean an intentionally omitted optional slot.
    pub fn prepare(&self, inputs: Vec<Vec<u8>>) -> Result<PreparedOutput> {
        self.validate()?;
        if inputs.len() != self.slots.len()
            || inputs.iter().map(Vec::len).sum::<usize>() > MAX_INPUT_BYTES
        {
            return Err(invalid(
                "Supply one source per slot totalling at most 64 MiB.",
            ));
        }
        let mut outputs = Vec::new();
        for (slot, bytes) in self.slots.iter().zip(inputs) {
            if bytes.is_empty() {
                if slot.required {
                    return Err(invalid(&format!(
                        "{}: choose a source for this required slot.",
                        slot.label
                    )));
                }
                outputs.push(None);
                continue;
            }
            let prepare = || -> Result<PreparedOutput> {
                if slot.formats.len() != 1 {
                    return Err(invalid(
                        "Choose one output format for automatic preparation.",
                    ));
                }
                if slot.formats[0] == "pdf" {
                    crate::pdf::arrange(&[bytes], None, 0)
                } else {
                    let (Some(width), Some(height)) = (slot.width, slot.height) else {
                        return Err(invalid(
                            "Set both output pixel dimensions for image preparation.",
                        ));
                    };
                    crate::photo::process(
                        &bytes,
                        &PhotoOptions {
                            width,
                            height,
                            format: if slot.formats[0] == "png" {
                                OutputFormat::Png
                            } else {
                                OutputFormat::Jpeg
                            },
                            max_bytes: slot.max_bytes,
                            ..Default::default()
                        },
                    )
                }
            };
            outputs.push(Some(
                prepare().map_err(|error| invalid(&format!("{}: {error}", slot.label)))?,
            ));
        }
        self.build(outputs)
    }

    pub fn validate(&self) -> Result<()> {
        if self.schema_version != 1
            || self.slots.is_empty()
            || self.slots.len() > 32
            || self.name.trim().is_empty()
            || self.name.len() > 128
            || self.revision_date.len() > 32
            || self.source.as_ref().is_some_and(|s| s.len() > 2048)
        {
            return Err(invalid("Unsupported pack preset."));
        }
        if self.verified {
            return Err(invalid(
                "Official preset verification is not supported in this version. Import as an example.",
            ));
        }
        let mut seen = std::collections::HashSet::new();
        for slot in &self.slots {
            crate::export::safe_name(&slot.filename)
                .map_err(|error| invalid(&format!("{}: {error}", slot.label)))?;
            if !seen.insert(slot.filename.to_lowercase())
                || slot.label.trim().is_empty()
                || slot.label.len() > 128
                || ["manifest.json", "validation.txt"]
                    .contains(&slot.filename.to_lowercase().as_str())
            {
                return Err(invalid("Pack slots need labels and unique filenames."));
            }
            if slot.formats.is_empty()
                || slot
                    .formats
                    .iter()
                    .any(|f| !["jpeg", "png", "pdf"].contains(&f.as_str()))
            {
                return Err(invalid("Pack contains an unsupported output format."));
            }
            let extension = std::path::Path::new(&slot.filename)
                .extension()
                .and_then(|value| value.to_str())
                .unwrap_or("")
                .to_lowercase();
            let filename_format = if extension == "jpg" {
                "jpeg"
            } else {
                &extension
            };
            if !slot.formats.iter().any(|format| format == filename_format) {
                return Err(invalid(&format!(
                    "{}: filename extension must match an accepted output format.",
                    slot.label
                )));
            }
            if slot.width.is_some_and(|n| n == 0 || n > 12000)
                || slot.height.is_some_and(|n| n == 0 || n > 12000)
                || slot
                    .width
                    .zip(slot.height)
                    .is_some_and(|(w, h)| u64::from(w) * u64::from(h) > MAX_PIXELS)
                || slot.min_pages.is_some_and(|n| n == 0 || n > 200)
                || slot.max_pages.is_some_and(|n| n == 0 || n > 200)
            {
                return Err(invalid(
                    "Invalid pixel dimensions or page limits in pack slot.",
                ));
            }
            if let Some(limit) = slot.max_bytes {
                limit.bytes()?;
            }
            if slot
                .min_pages
                .zip(slot.max_pages)
                .is_some_and(|(a, b)| a > b)
            {
                return Err(invalid("Page-count limits conflict."));
            }
        }
        Ok(())
    }
    pub fn build(&self, outputs: Vec<Option<PreparedOutput>>) -> Result<PreparedOutput> {
        self.validate()?;
        if outputs.len() != self.slots.len() {
            return Err(invalid(
                "Supply one output or an explicit empty value for every slot.",
            ));
        }
        let mut items = Vec::new();
        for (slot, output) in self.slots.iter().zip(outputs) {
            let Some(mut o) = output else {
                if slot.required {
                    return Err(invalid("A required application document is missing."));
                }
                continue;
            };
            let matches = slot.formats.contains(&o.info.format)
                && slot.width.is_none_or(|v| Some(v) == o.info.width)
                && slot.height.is_none_or(|v| Some(v) == o.info.height)
                && slot
                    .min_pages
                    .is_none_or(|v| o.info.pages.is_some_and(|n| n >= v))
                && slot
                    .max_pages
                    .is_none_or(|v| o.info.pages.is_some_and(|n| n <= v))
                && slot
                    .max_bytes
                    .map(|v| v.accepts(o.data.len()))
                    .transpose()?
                    .unwrap_or(true);
            if !matches {
                return Err(invalid(&format!(
                    "{}: the prepared document does not meet its format, pixel, byte or page requirements. Adjust this slot before exporting.",
                    slot.label
                )));
            }
            let extension = std::path::Path::new(&slot.filename)
                .extension()
                .and_then(|x| x.to_str())
                .unwrap_or("")
                .to_lowercase();
            if !(extension == o.info.format || (extension == "jpg" && o.info.format == "jpeg")) {
                return Err(invalid(
                    "The filename extension does not match the output format.",
                ));
            }
            o.info.findings.push(ValidationFinding {
                advisory: false,
                code: "slot_constraints".into(),
                passed: true,
                message: format!(
                    "{}: required format, dimensions, bytes and page constraints passed.",
                    slot.label
                ),
            });
            items.push((slot.filename.clone(), o));
        }
        crate::export::pack(items)
    }
}
