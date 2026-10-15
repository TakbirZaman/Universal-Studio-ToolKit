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
    pub fn validate(&self) -> Result<()> {
        if self.schema_version != 1 || self.slots.is_empty() || self.slots.len() > 32 {
            return Err(invalid("Unsupported pack preset."));
        }
        if self.verified {
            return Err(invalid(
                "Official preset verification is not supported in this version. Import as an example.",
            ));
        }
        let mut seen = std::collections::HashSet::new();
        for slot in &self.slots {
            crate::export::safe_name(&slot.filename)?;
            if !seen.insert(slot.filename.to_lowercase()) || slot.label.is_empty() {
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
                return Err(invalid(
                    "An application document does not meet its slot requirements. Adjust it before exporting.",
                ));
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
