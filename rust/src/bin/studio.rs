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
    },
    Recipe {
        input: String,
        recipe: String,
        directory: String,
        filename: String,
    },
}
fn read(path: &str) -> Result<Vec<u8>> {
    let f = std::fs::File::open(path)?;
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
        } => (
            pdf::print_sheet(
                &read(&input)?,
                &paper,
                width_mm,
                height_mm,
                spacing_mm,
                copies,
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
