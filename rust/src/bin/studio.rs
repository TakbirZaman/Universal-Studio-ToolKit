use serde::Deserialize;
use std::{io::Read, path::Path};
use studio_core::{export, model::*, pdf, photo, recipe};
#[derive(Deserialize)]
#[serde(tag = "operation", rename_all = "snake_case", deny_unknown_fields)]
enum Request {
    Photo {
        input: String,
        directory: String,
        filename: String,
        options: PhotoOptions,
    },
    Pdf {
        inputs: Vec<String>,
        directory: String,
        filename: String,
        pages: Option<Vec<u32>>,
        rotation: i32,
    },
    OptimizePdf {
        input: String,
        directory: String,
        filename: String,
    },
    Ocr {
        input: String,
        directory: String,
        filename: String,
        language: studio_core::ocr::Language,
    },
    Scan {
        inputs: Vec<String>,
        directory: String,
        filename: String,
        paper: pdf::Paper,
    },
    Print {
        input: String,
        directory: String,
        filename: String,
        paper: pdf::Paper,
        width_mm: f64,
        height_mm: f64,
        spacing_mm: f64,
        copies: u32,
        #[serde(default)]
        cutting_guides: bool,
        #[serde(default)]
        raster_dpi: Option<u16>,
    },
    Recipe {
        input: String,
        recipe: String,
        directory: String,
        filename: String,
    },
}
fn read(path: &str) -> Result<Vec<u8>> {
    if !std::fs::symlink_metadata(path)?.file_type().is_file() {
        return Err(invalid(
            "Choose a regular local file, not a link, pipe or device.",
        ));
    }
    let mut options = std::fs::OpenOptions::new();
    options.read(true);
    #[cfg(target_os = "linux")]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.custom_flags(libc::O_NOFOLLOW | libc::O_NONBLOCK);
    }
    let f = options.open(path)?;
    if !f.metadata()?.is_file() {
        return Err(invalid("Choose a regular local file."));
    }
    if f.metadata()?.len() > MAX_INPUT_BYTES as u64 {
        return Err(invalid("Input exceeds 64 MiB."));
    }
    let mut b = Vec::new();
    f.take(MAX_INPUT_BYTES as u64 + 1).read_to_end(&mut b)?;
    if b.len() > MAX_INPUT_BYTES {
        return Err(invalid("Input exceeds 64 MiB."));
    }
    Ok(b)
}
fn run() -> Result<OutputInfo> {
    let config = std::env::args().nth(1).ok_or_else(|| {
        invalid("Usage: studio request.json. See README.md for request examples.")
    })?;
    let req: Request = serde_json::from_slice(&read(&config)?)?;
    let (out, dir, name) = match req {
        Request::Photo {
            input,
            directory,
            filename,
            options,
        } => (
            photo::process(&read(&input)?, &options)?,
            directory,
            filename,
        ),
        Request::Pdf {
            inputs,
            directory,
            filename,
            pages,
            rotation,
        } => (
            pdf::arrange(
                &inputs.iter().map(|s| read(s)).collect::<Result<Vec<_>>>()?,
                pages.as_deref(),
                rotation,
            )?,
            directory,
            filename,
        ),
        Request::OptimizePdf {
            input,
            directory,
            filename,
        } => (pdf::optimize_lossless(&read(&input)?)?, directory, filename),
        Request::Ocr {
            input,
            directory,
            filename,
            language,
        } => (
            studio_core::ocr::recognize(&read(&input)?, language, &Default::default())?,
            directory,
            filename,
        ),
        Request::Scan {
            inputs,
            directory,
            filename,
            paper,
        } => (
            pdf::images_to_pdf(
                &inputs.iter().map(|s| read(s)).collect::<Result<Vec<_>>>()?,
                &paper,
            )?,
            directory,
            filename,
        ),
        Request::Print {
            input,
            directory,
            filename,
            paper,
            width_mm,
            height_mm,
            spacing_mm,
            copies,
            cutting_guides,
            raster_dpi,
        } => (
            studio_core::printing::sheet(
                &read(&input)?,
                &studio_core::printing::PrintSheetSpec {
                    paper,
                    photo_width_mm: width_mm,
                    photo_height_mm: height_mm,
                    spacing_mm,
                    copies,
                    cutting_guides,
                    raster_dpi,
                },
            )?,
            directory,
            filename,
        ),
        Request::Recipe {
            input,
            recipe: r,
            directory,
            filename,
        } => (
            recipe::Recipe::parse(&read(&r)?)?.run(&read(&input)?)?,
            directory,
            filename,
        ),
    };
    export::save_copy(Path::new(&dir), &name, &out)?;
    Ok(out.info)
}
fn main() {
    match run() {
        Ok(info) => println!("{}", serde_json::to_string_pretty(&info).unwrap()),
        Err(e) => {
            eprintln!("{e}");
            std::process::exit(1);
        }
    }
}

#[cfg(test)]
mod request_security_tests {
    use super::Request;
    #[test]
    fn ocr_requests_cannot_supply_executables_or_engine_arguments() {
        let mut request = serde_json::json!({
            "operation": "ocr", "input": "page.png", "directory": "out",
            "filename": "recognized.txt", "language": "english", "engine": "sh"
        });
        assert!(serde_json::from_value::<Request>(request.clone()).is_err());
        request.as_object_mut().unwrap().remove("engine");
        assert!(serde_json::from_value::<Request>(request.clone()).is_ok());
        request["language"] = "eng --psm 0".into();
        assert!(serde_json::from_value::<Request>(request).is_err());
    }
}
