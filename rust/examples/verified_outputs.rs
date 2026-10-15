use image::{DynamicImage, ImageFormat, Rgb, RgbImage};
use std::io::Cursor;
use studio_core::{export, model::*, pdf, photo};
fn sample(w: u32, h: u32, color: [u8; 3]) -> Vec<u8> {
    let mut img = RgbImage::from_pixel(w, h, Rgb(color));
    for (x, y, p) in img.enumerate_pixels_mut() {
        if x % 60 < 3 || y % 60 < 3 {
            *p = Rgb([45, 55, 65]);
        }
    }
    let mut b = Cursor::new(Vec::new());
    DynamicImage::ImageRgb8(img)
        .write_to(&mut b, ImageFormat::Png)
        .unwrap();
    b.into_inner()
}
fn main() -> Result<()> {
    let dest = std::env::args()
        .nth(1)
        .unwrap_or("verification-outputs".into());
    let dir = std::path::Path::new(&dest);
    std::fs::create_dir_all(dir)?;
    let photo = photo::process(
        &sample(600, 400, [180, 205, 240]),
        &PhotoOptions {
            max_bytes: Some(ByteLimit {
                value: 50,
                unit: SizeUnit::KiB,
                strict: true,
            }),
            ..Default::default()
        },
    )?;
    export::save_copy(dir, "photo-300x300.jpg", &photo)?;
    let signature = photo::process(
        &sample(600, 200, [255, 255, 255]),
        &PhotoOptions {
            width: 300,
            height: 100,
            format: OutputFormat::Png,
            signature_threshold: Some(230),
            ..Default::default()
        },
    )?;
    export::save_copy(dir, "signature.png", &signature)?;
    let scans = pdf::images_to_pdf(
        &[
            sample(400, 600, [235, 245, 225]),
            sample(600, 400, [245, 225, 220]),
            sample(400, 600, [220, 235, 250]),
        ],
        &Default::default(),
    )?;
    export::save_copy(dir, "three-page-scan.pdf", &scans)?;
    let arranged = pdf::arrange(&[scans.data.clone()], Some(&[3, 1, 2]), 90)?;
    export::save_copy(dir, "reordered-rotated.pdf", &arranged)?;
    let sheet = pdf::print_sheet(&photo.data, &Default::default(), 30., 30., 4., 12)?;
    export::save_copy(dir, "print-sheet.pdf", &sheet)?;
    let pack = export::pack(vec![
        ("photo.jpg".into(), photo),
        ("signature.png".into(), signature),
        ("certificate.pdf".into(), scans),
    ])?;
    export::save_copy(dir, "application-pack.zip", &pack)?;
    println!("Verified outputs saved; pack {} bytes", pack.info.bytes);
    Ok(())
}
