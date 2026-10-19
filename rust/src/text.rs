//! Plain UTF-8 documents shared by PDF extraction and editable text export.
use crate::model::*;
pub const MAX_BYTES: usize = 4 * 1024 * 1024;
pub fn output(bytes: Vec<u8>) -> Result<PreparedOutput> {
    if bytes.is_empty() || bytes.len() > MAX_BYTES || std::str::from_utf8(&bytes).is_err() {
        return Err(invalid("Text must be non-empty UTF-8 and at most 4 MiB."));
    }
    Ok(PreparedOutput {
        info: OutputInfo {
            format: "txt".into(),
            bytes: bytes.len() as u64,
            width: None,
            height: None,
            pages: None,
            quality: None,
            print_density: None,
            findings: vec![ValidationFinding {
                advisory: false,
                code: "utf8_text".into(),
                passed: true,
                message: "Plain UTF-8 text validated. Your original document is unchanged.".into(),
            }],
        },
        data: bytes,
    })
}
