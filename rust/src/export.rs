use crate::model::*;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::{
    io::{Read, Write},
    path::Path,
};

pub fn safe_name(name: &str) -> Result<()> {
    if name.is_empty()
        || name.len() > 180
        || name == "."
        || name == ".."
        || name.ends_with(['.', ' '])
        || name
            .chars()
            .any(|c| c.is_control() || "/\\:<>\"|?*".contains(c))
    {
        return Err(invalid(
            "Use a plain filename without folders or reserved characters.",
        ));
    }
    let stem = name.split('.').next().unwrap_or("").to_ascii_uppercase();
    if [
        "CON", "PRN", "AUX", "NUL", "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8",
        "COM9", "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9",
    ]
    .contains(&stem.as_str())
    {
        return Err(invalid("This filename is reserved on Windows."));
    }
    Ok(())
}
pub fn verify_output(out: &PreparedOutput) -> Result<()> {
    if out.info.bytes != out.data.len() as u64 {
        return Err(invalid("Output byte count is inconsistent."));
    }
    match out.info.format.as_str() {
        "jpeg" | "png" => {
            let expected = if out.info.format == "jpeg" {
                image::ImageFormat::Jpeg
            } else {
                image::ImageFormat::Png
            };
            if image::guess_format(&out.data)? != expected {
                return Err(invalid("Output format is inconsistent."));
            }
            let img = crate::photo::decode(&out.data)?;
            if Some(img.width()) != out.info.width || Some(img.height()) != out.info.height {
                return Err(invalid("Output dimensions are inconsistent."));
            }
        }
        "txt" => {
            if out.data.len() > crate::ocr::MAX_TEXT_BYTES {
                return Err(invalid("Plain text output exceeds 4 MiB."));
            }
            if out.info.width.is_some()
                || out.info.height.is_some()
                || out.info.pages.is_some()
                || out.info.quality.is_some()
            {
                return Err(invalid("Plain text output has inconsistent metadata."));
            }
            crate::ocr::text_output(out.data.clone())?;
        }
        "json" => {
            crate::recipe::Recipe::parse(&out.data)?;
        }
        "pdf" => {
            if Some(crate::pdf::page_count(&out.data)?) != out.info.pages {
                return Err(invalid("Output page count is inconsistent."));
            }
        }
        "zip" => {
            let mut archive = zip::ZipArchive::new(std::io::Cursor::new(&out.data))?;
            if archive.len() > 34 {
                return Err(invalid("Archive has too many entries."));
            }
            let mut content = Vec::new();
            archive
                .by_name("manifest.json")?
                .take(1_048_577)
                .read_to_end(&mut content)?;
            if content.len() > 1_048_576 {
                return Err(invalid("Archive manifest is too large."));
            }
            let m: Manifest = serde_json::from_slice(&content)?;
            if m.schema_version != 1 || m.entries.is_empty() || m.entries.len() + 2 != archive.len()
            {
                return Err(invalid("Archive manifest is inconsistent."));
            }
            archive.by_name("validation.txt")?;
            let mut names = std::collections::HashSet::new();
            let mut total = 0usize;
            for entry in m.entries {
                safe_name(&entry.filename)?;
                let key = entry.filename.to_lowercase();
                if ["manifest.json", "validation.txt"].contains(&key.as_str())
                    || !names.insert(key)
                    || !["jpeg", "png", "pdf"].contains(&entry.info.format.as_str())
                {
                    return Err(invalid("Archive entries are inconsistent."));
                }
                verify_extension(&entry.filename, &entry.info.format)?;
                let mut actual = Vec::new();
                archive
                    .by_name(&entry.filename)?
                    .take((MAX_INPUT_BYTES - total) as u64 + 1)
                    .read_to_end(&mut actual)?;
                total += actual.len();
                if total > MAX_INPUT_BYTES
                    || actual.len() as u64 != entry.info.bytes
                    || format!("{:x}", Sha256::digest(&actual)) != entry.sha256
                {
                    return Err(invalid("Archive entry failed verification."));
                }
                verify_output(&PreparedOutput {
                    data: actual,
                    info: entry.info,
                })?;
            }
        }
        _ => return Err(invalid("Unsupported output format.")),
    }
    Ok(())
}

fn verify_extension(name: &str, format: &str) -> Result<()> {
    let ext = Path::new(name)
        .extension()
        .and_then(|s| s.to_str())
        .unwrap_or("")
        .to_lowercase();
    if !(ext == format || (ext == "jpg" && format == "jpeg")) {
        return Err(invalid(
            "Filename extension must match the prepared output format.",
        ));
    }
    Ok(())
}

pub fn save_copy(dir: &Path, name: &str, out: &PreparedOutput) -> Result<()> {
    safe_name(name)?;
    verify_output(out)?;
    verify_extension(name, &out.info.format)?;
    if !dir.is_dir() {
        return Err(invalid("Choose an existing destination folder."));
    }
    let mut staged = tempfile::NamedTempFile::new_in(dir)?;
    staged.write_all(&out.data)?;
    staged.as_file().sync_all()?;
    let mut saved = Vec::new();
    staged.reopen()?.read_to_end(&mut saved)?;
    if saved != out.data {
        return Err(invalid("Saved bytes failed verification."));
    }
    staged.persist_noclobber(dir.join(name)).map_err(|_|invalid("A file with this name already exists, or the destination is not writable. Choose another name."))?;
    Ok(())
}
#[derive(Serialize, Deserialize, Debug)]
pub struct ManifestEntry {
    pub filename: String,
    pub sha256: String,
    pub info: OutputInfo,
}
#[derive(Serialize, Deserialize, Debug)]
pub struct Manifest {
    pub schema_version: u32,
    pub preset_status: String,
    pub entries: Vec<ManifestEntry>,
}
pub fn pack(items: Vec<(String, PreparedOutput)>) -> Result<PreparedOutput> {
    if items.is_empty() || items.len() > 32 {
        return Err(invalid("A pack needs 1–32 documents."));
    }
    let total = items.iter().try_fold(0usize, |total, (_, output)| {
        total.checked_add(output.data.len())
    });
    if total.is_none_or(|bytes| bytes > MAX_INPUT_BYTES) {
        return Err(invalid("Pack documents exceed 64 MiB combined."));
    }
    let mut names = std::collections::HashSet::new();
    let mut manifest = Manifest {
        schema_version: 1,
        preset_status: "User-defined requirements; not an official application preset".into(),
        entries: Vec::new(),
    };
    let mut writer = zip::ZipWriter::new(std::io::Cursor::new(Vec::new()));
    let opt = zip::write::SimpleFileOptions::default()
        .compression_method(zip::CompressionMethod::Deflated);
    for (name, out) in items {
        safe_name(&name)?;
        let key = name.to_lowercase();
        if ["manifest.json", "validation.txt"].contains(&key.as_str()) || !names.insert(key) {
            return Err(invalid("Pack filenames collide. Choose unique names."));
        }
        if !["jpeg", "png", "pdf"].contains(&out.info.format.as_str()) {
            return Err(invalid("Unsupported pack output format."));
        }
        verify_output(&out)?;
        verify_extension(&name, &out.info.format)?;
        writer.start_file(&name, opt)?;
        writer.write_all(&out.data)?;
        manifest.entries.push(ManifestEntry {
            filename: name,
            sha256: format!("{:x}", Sha256::digest(&out.data)),
            info: out.info,
        });
    }
    writer.start_file("manifest.json", opt)?;
    writer.write_all(&serde_json::to_vec_pretty(&manifest)?)?;
    let mut report="Universal Studio Toolkit — validation report\nUser-defined requirements. No official acceptance guarantee.\nOriginal files unchanged. Source paths omitted.\n\n".to_string();
    for e in &manifest.entries {
        report.push_str(&format!(
            "{}: {} bytes; {}; SHA-256 {}\n",
            e.filename, e.info.bytes, e.info.format, e.sha256
        ));
        for f in &e.info.findings {
            report.push_str(&format!(
                "  {}: {}\n",
                if f.advisory {
                    "ADVISORY"
                } else if f.passed {
                    "PASS"
                } else {
                    "FAIL"
                },
                f.message
            ));
        }
    }
    writer.start_file("validation.txt", opt)?;
    writer.write_all(report.as_bytes())?;
    let bytes = writer.finish()?.into_inner();
    let mut archive = zip::ZipArchive::new(std::io::Cursor::new(&bytes))?;
    for e in &manifest.entries {
        let mut actual = Vec::new();
        archive.by_name(&e.filename)?.read_to_end(&mut actual)?;
        if format!("{:x}", Sha256::digest(&actual)) != e.sha256 {
            return Err(invalid("ZIP output verification failed."));
        }
    }
    Ok(PreparedOutput{info:OutputInfo{format:"zip".into(),bytes:bytes.len()as u64,width:None,height:None,pages:None,quality:None,findings:vec![ValidationFinding{advisory:false,code:"archive_verified".into(),passed:true,message:"Every archived document was reopened and its hash verified against the manifest.".into()}]},data:bytes})
}
