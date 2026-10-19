//! Offline Tesseract adapter. Engine discovery is platform-owned, never a recipe step.
use crate::{jobs::Cancellation, model::*};
use sha2::{Digest, Sha256};
use std::{
    io::Read,
    path::{Path, PathBuf},
};

pub(crate) const MAX_TEXT_BYTES: usize = crate::text::MAX_BYTES;
const MODELS: [(&str, usize, &str); 3] = [
    (
        "eng.traineddata",
        4113088,
        "7d4322bd2a7749724879683fc3912cb542f19906c83bcc1a52132556427170b2",
    ),
    (
        "ben.traineddata",
        855841,
        "31163084c279aaebd376216f0c3d5c17ad4b5fee8db49dae79c20000b5de5964",
    ),
    (
        "LICENSE",
        11358,
        "cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30",
    ),
];

#[derive(Clone, Copy, Debug, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Language {
    English,
    Bangla,
    Mixed,
}
#[cfg(target_os = "linux")]
impl Language {
    fn engine_name(self) -> &'static str {
        match self {
            Self::English => "eng",
            Self::Bangla => "ben",
            Self::Mixed => "eng+ben",
        }
    }
}

pub fn model_directory() -> Result<PathBuf> {
    if let Some(directory) = std::env::var_os("UST_OCR_TESSDATA") {
        return Ok(PathBuf::from(directory));
    }
    let executable = std::env::current_exe()?;
    Ok(executable
        .parent()
        .ok_or_else(|| invalid("OCR resources are unavailable."))?
        .join("ocr")
        .join("tessdata"))
}

fn verified_model(directory: &Path, name: &str, length: usize, digest: &str) -> Result<Vec<u8>> {
    let path = directory.join(name);
    if !std::fs::symlink_metadata(&path)?.file_type().is_file() {
        return Err(invalid(
            "OCR assets must be regular local files, not links or devices.",
        ));
    }
    let mut options = std::fs::OpenOptions::new();
    options.read(true);
    #[cfg(target_os = "linux")]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.custom_flags(libc::O_NOFOLLOW | libc::O_NONBLOCK);
    }
    let file = options.open(path)?;
    if !file.metadata()?.is_file() {
        return Err(invalid("OCR assets must be regular local files."));
    }
    let mut bytes = Vec::new();
    file.take(length as u64 + 1).read_to_end(&mut bytes)?;
    if bytes.len() != length || format!("{:x}", Sha256::digest(&bytes)) != digest {
        return Err(invalid(
            "Offline OCR language files failed verification. Import the supported English and Bangla files with their license.",
        ));
    }
    Ok(bytes)
}

/// Only the three pinned, locally supplied data files are accepted. No downloads.
pub fn verify_models(directory: &Path) -> Result<()> {
    for (name, length, digest) in MODELS {
        verified_model(directory, name, length, digest)?;
    }
    Ok(())
}

#[cfg(target_os = "linux")]
fn stage_models(source: &Path, destination: &Path) -> Result<()> {
    use std::io::Write;
    std::fs::create_dir(destination)?;
    for (name, length, digest) in MODELS {
        let bytes = verified_model(source, name, length, digest)?;
        let mut file = std::fs::OpenOptions::new()
            .write(true)
            .create_new(true)
            .open(destination.join(name))?;
        file.write_all(&bytes)?;
        file.sync_all()?;
        verified_model(destination, name, length, digest)?;
    }
    Ok(())
}

pub fn available() -> bool {
    cfg!(target_os = "linux")
        && Path::new("/usr/bin/tesseract").is_file()
        && model_directory().and_then(|p| verify_models(&p)).is_ok()
}

pub fn text_output(bytes: Vec<u8>) -> Result<PreparedOutput> {
    if bytes.is_empty() || bytes.len() > MAX_TEXT_BYTES || std::str::from_utf8(&bytes).is_err() {
        return Err(invalid(
            "OCR text must be non-empty UTF-8 and at most 4 MiB.",
        ));
    }
    Ok(PreparedOutput {
        info: OutputInfo {
            format: "txt".into(), bytes: bytes.len() as u64,
            width: None, height: None, pages: None, quality: None,
            print_density: None,
            findings: vec![ValidationFinding {
                advisory: true, code: "ocr_review_required".into(), passed: true,
                message: "Offline OCR is approximate. Review and edit the recognized text before use. This is plain text, not a searchable PDF.".into(),
            }],
        },
        data: bytes,
    })
}

#[cfg(target_os = "linux")]
pub fn recognize(data: &[u8], language: Language, cancel: &Cancellation) -> Result<PreparedOutput> {
    use std::{
        os::unix::process::CommandExt,
        process::{Child, Command, Stdio},
        time::{Duration, Instant},
    };
    if cancel.is_cancelled() {
        return Err(StudioError::Cancelled);
    }
    let source_models = model_directory()?;
    verify_models(&source_models)?;
    if !Path::new("/usr/bin/tesseract").is_file() {
        return Err(invalid(
            "Install a local Tesseract engine before using offline OCR.",
        ));
    }
    let prepared = crate::photo::decode(data)?;
    if cancel.is_cancelled() {
        return Err(StudioError::Cancelled);
    }
    let work = tempfile::tempdir()?;
    let work_path = work.path().canonicalize()?;
    let models = work_path.join("tessdata");
    stage_models(&source_models, &models)?;
    if cancel.is_cancelled() {
        return Err(StudioError::Cancelled);
    }
    let source = work_path.join("page.png");
    let output = work_path.join("recognized");
    prepared.write_to(
        &mut std::fs::File::create(&source)?,
        image::ImageFormat::Png,
    )?;
    let mut command = Command::new("/usr/bin/tesseract");
    command.current_dir(&work_path);
    command
        .arg(&source)
        .arg(&output)
        .arg("--tessdata-dir")
        .arg(&models)
        .args([
            "-l",
            language.engine_name(),
            "--oem",
            "1",
            "--psm",
            "3",
            "--dpi",
            "300",
        ])
        .env("OMP_THREAD_LIMIT", "1")
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null());
    // These limits affect only the child. The closure performs no allocation or I/O.
    let parent_pid = std::process::id() as libc::pid_t;
    unsafe {
        command.pre_exec(move || {
            if libc::prctl(libc::PR_SET_PDEATHSIG, libc::SIGKILL) != 0
                || libc::prctl(libc::PR_SET_NO_NEW_PRIVS, 1, 0, 0, 0) != 0
            {
                return Err(std::io::Error::last_os_error());
            }
            if libc::getppid() != parent_pid {
                return Err(std::io::Error::from_raw_os_error(libc::ESRCH));
            }
            for (resource, soft, hard) in [
                (libc::RLIMIT_AS, 768 * 1024 * 1024, 768 * 1024 * 1024),
                (libc::RLIMIT_CPU, 30, 31),
                (
                    libc::RLIMIT_FSIZE,
                    MAX_TEXT_BYTES as u64,
                    MAX_TEXT_BYTES as u64,
                ),
                (libc::RLIMIT_CORE, 0, 0),
            ] {
                let limit = libc::rlimit {
                    rlim_cur: soft,
                    rlim_max: hard,
                };
                if libc::setrlimit(resource, &limit) != 0 {
                    return Err(std::io::Error::last_os_error());
                }
            }
            Ok(())
        });
    }
    struct OwnedChild {
        child: Child,
        completed: bool,
    }
    impl Drop for OwnedChild {
        fn drop(&mut self) {
            if !self.completed {
                let _ = self.child.kill();
                let _ = self.child.wait();
            }
        }
    }
    let mut child = OwnedChild {
        child: command.spawn()?,
        completed: false,
    };
    let started = Instant::now();
    loop {
        if cancel.is_cancelled() {
            return Err(StudioError::Cancelled);
        }
        if started.elapsed() > Duration::from_secs(60) {
            return Err(invalid(
                "OCR reached its time limit. Try a clearer crop or a smaller page.",
            ));
        }
        if let Some(status) = child.child.try_wait()? {
            child.completed = true;
            if !status.success() {
                return Err(invalid(
                    "OCR could not finish within its resource limits. Try a clearer crop or a smaller page.",
                ));
            }
            break;
        }
        std::thread::sleep(Duration::from_millis(25));
    }
    let mut bytes = Vec::new();
    std::fs::File::open(output.with_extension("txt"))?
        .take(MAX_TEXT_BYTES as u64 + 1)
        .read_to_end(&mut bytes)?;
    if bytes.iter().all(u8::is_ascii_whitespace) {
        return Err(invalid(
            "No printed text was found. Try a clearer crop or another language.",
        ));
    }
    text_output(bytes)
}

#[cfg(not(target_os = "linux"))]
pub fn recognize(
    _data: &[u8],
    _language: Language,
    _cancel: &Cancellation,
) -> Result<PreparedOutput> {
    Err(invalid(
        "Offline OCR is not packaged for this platform in this build.",
    ))
}
