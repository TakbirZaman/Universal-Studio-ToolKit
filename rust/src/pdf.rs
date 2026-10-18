use crate::{model::*, photo};
use lopdf::content::{Content, Operation};
use lopdf::{Dictionary, Document, Object, ObjectId, Stream, dictionary};

pub fn load(data: &[u8]) -> Result<Document> {
    if data.len() > MAX_INPUT_BYTES {
        return Err(invalid("PDF exceeds the 64 MiB input limit."));
    }
    let doc = Document::load_mem(data)?;
    if doc.is_encrypted() {
        return Err(invalid(
            "Protected PDFs are not supported. The original protection is unchanged.",
        ));
    }
    let pages = doc.get_pages();
    if pages.is_empty() || pages.len() > MAX_PAGES {
        return Err(invalid("Select a PDF with 1–200 pages."));
    }
    // Conservative launch boundary: reject structures that cannot yet be preserved safely.
    fn check(o: &Object, depth: usize) -> Result<()> {
        if depth > 32 {
            return Err(invalid("PDF object nesting exceeds the supported limit."));
        }
        match o {
            Object::Dictionary(d) => {
                for key in [
                    b"AcroForm".as_slice(),
                    b"Annots",
                    b"Outlines",
                    b"EmbeddedFiles",
                    b"JavaScript",
                    b"JS",
                    b"OpenAction",
                    b"AA",
                    b"XFA",
                    b"ByteRange",
                    b"Collection",
                    b"StructTreeRoot",
                    b"OCProperties",
                ] {
                    if d.has(key) {
                        return Err(invalid(
                            "This PDF contains forms, annotations, signatures, bookmarks, attachments, actions or advanced structures that this version cannot safely preserve.",
                        ));
                    }
                }
                for (_, v) in d.iter() {
                    check(v, depth + 1)?;
                }
            }
            Object::Array(a) => {
                for v in a {
                    check(v, depth + 1)?;
                }
            }
            Object::Stream(s) => check(&Object::Dictionary(s.dict.clone()), depth + 1)?,
            _ => {}
        }
        Ok(())
    }
    if doc.objects.len() > 100000 {
        return Err(invalid("PDF has too many objects."));
    }
    for o in doc.objects.values() {
        check(o, 0)?;
    }
    Ok(doc)
}
fn inherited(doc: &Document, id: ObjectId, key: &[u8]) -> Result<Option<Object>> {
    let mut current = id;
    for _ in 0..64 {
        let d = doc.get_dictionary(current)?;
        if let Ok(v) = d.get(key) {
            return Ok(Some(v.clone()));
        }
        match d.get(b"Parent").and_then(Object::as_reference) {
            Ok(p) => current = p,
            Err(_) => return Ok(None),
        }
    }
    Err(invalid("PDF page inheritance is cyclic or too deep."))
}
pub(crate) fn finish(mut doc: Document, count: usize) -> Result<PreparedOutput> {
    doc.prune_objects();
    doc.compress();
    let mut writer = crate::buffer::BoundedBuffer::new(MAX_INPUT_BYTES);
    let saved = doc.save_to(&mut writer);
    if writer.exceeded {
        return Err(StudioError::ResourceLimit(
            "PDF exceeds the 64 MiB export limit. Export fewer pages at once.".into(),
        ));
    }
    saved?;
    let bytes = writer.into_inner();
    let check = load(&bytes)?;
    if check.get_pages().len() != count {
        return Err(invalid("PDF page count verification failed."));
    }
    Ok(PreparedOutput{info:OutputInfo{format:"pdf".into(),bytes:bytes.len() as u64,width:None,height:None,pages:Some(count as u32),quality:None,print_density:None,findings:vec![ValidationFinding{advisory:false,code:"pdf_reopened".into(),message:"PDF reopened and page count verified. This is structural validation, not a visual comparison.".into(),passed:true}]},data:bytes})
}
/// Lossless structural optimization only. Never rasterizes or recompresses images.
/// If rewriting does not reduce bytes, return the validated original unchanged.
pub fn optimize_lossless(data: &[u8]) -> Result<PreparedOutput> {
    let document = load(data)?;
    let pages = document.get_pages().len();
    let mut output = match finish(document, pages) {
        Ok(output) => output,
        Err(StudioError::ResourceLimit(_)) => PreparedOutput {
            data: data.to_vec(),
            info: OutputInfo {
                format: "pdf".into(),
                bytes: data.len() as u64,
                width: None,
                height: None,
                pages: Some(pages as u32),
                quality: None,
                print_density: None,
                findings: vec![],
            },
        },
        Err(error) => return Err(error),
    };
    let reduced = output.data.len() < data.len();
    if !reduced {
        output.data = data.to_vec();
        output.info.bytes = data.len() as u64;
    }
    output.info.findings.push(ValidationFinding {
        advisory: true,
        code: if reduced {
            "lossless_smaller"
        } else {
            "lossless_unchanged"
        }
        .into(),
        message: if reduced {
            "Supported PDF structures optimized without rasterizing pages."
        } else {
            "No smaller lossless result was found. The saved copy has the original bytes."
        }
        .into(),
        passed: true,
    });
    Ok(output)
}

/// Explicit page order (one-based); omitted pages are deleted. No duplicates.
pub fn arrange(
    inputs: &[Vec<u8>],
    selection: Option<&[u32]>,
    rotate: i32,
) -> Result<PreparedOutput> {
    if inputs.iter().map(Vec::len).sum::<usize>() > MAX_INPUT_BYTES {
        return Err(invalid("Combined inputs exceed 64 MiB."));
    }
    if inputs.is_empty() || inputs.len() > 32 || rotate % 90 != 0 {
        return Err(invalid("Select 1–32 PDFs and rotate in 90-degree steps."));
    }
    let mut out = Document::with_version("1.7");
    let root_pages = out.new_object_id();
    let mut page_dicts = Vec::new();
    for data in inputs {
        let mut doc = load(data)?;
        doc.renumber_objects_with(out.max_id + 1);
        for id in doc.get_pages().values() {
            let mut page = doc.get_dictionary(*id)?.clone();
            for k in [b"Resources".as_slice(), b"MediaBox", b"CropBox", b"Rotate"] {
                if !page.has(k) {
                    if let Some(v) = inherited(&doc, *id, k)? {
                        page.set(k, v);
                    }
                }
            }
            let angle = page
                .get(b"Rotate")
                .ok()
                .and_then(|v| doc.dereference(v).ok())
                .and_then(|(_, v)| v.as_i64().ok())
                .unwrap_or(0);
            page.set("Rotate", (angle + rotate as i64).rem_euclid(360));
            page.set("Parent", root_pages);
            page_dicts.push(page);
        }
        out.max_id = doc.max_id;
        out.objects.extend(doc.objects);
    }
    if page_dicts.len() > MAX_PAGES {
        return Err(invalid("Combined PDF exceeds 200 pages."));
    }
    let chosen: Vec<u32> = selection
        .map(|s| s.to_vec())
        .unwrap_or_else(|| (1..=page_dicts.len() as u32).collect());
    if chosen.is_empty() {
        return Err(invalid("Keep at least one page."));
    }
    let mut seen = std::collections::HashSet::new();
    let mut kids = Vec::new();
    for n in chosen {
        if n == 0 || n as usize > page_dicts.len() || !seen.insert(n) {
            return Err(invalid(
                "Page numbers must be in range and must not repeat.",
            ));
        }
        kids.push(Object::Reference(
            out.add_object(page_dicts[n as usize - 1].clone()),
        ));
    }
    let count = kids.len();
    out.objects.insert(
        root_pages,
        Object::Dictionary(dictionary! {"Type"=>"Pages","Kids"=>kids,"Count"=>count as i64}),
    );
    let catalog = out.add_object(dictionary! {"Type"=>"Catalog","Pages"=>root_pages});
    out.trailer.set("Root", catalog);
    finish(out, count)
}
pub fn parse_ranges(text: &str, total: u32) -> Result<Vec<u32>> {
    let mut result = Vec::new();
    for part in text.split(',') {
        let ends: Vec<_> = part.trim().split('-').collect();
        let a = ends[0]
            .parse::<u32>()
            .map_err(|_| invalid("Use page ranges such as 1-3,5."))?;
        let b = if ends.len() == 2 {
            ends[1]
                .parse::<u32>()
                .map_err(|_| invalid("Invalid page range."))?
        } else if ends.len() == 1 {
            a
        } else {
            return Err(invalid("Invalid page range."));
        };
        if a == 0 || b < a || b > total {
            return Err(invalid("Page range is outside the document."));
        }
        for n in a..=b {
            if result.contains(&n) {
                return Err(invalid("Page ranges overlap."));
            }
            result.push(n);
        }
    }
    Ok(result)
}
#[derive(Clone, Debug, serde::Serialize, serde::Deserialize)]
pub struct Paper {
    pub width_mm: f64,
    pub height_mm: f64,
    pub margin_mm: f64,
}
impl Default for Paper {
    fn default() -> Self {
        Self {
            width_mm: 210.,
            height_mm: 297.,
            margin_mm: 12.,
        }
    }
}
pub(crate) fn paper(p: &Paper) -> Result<(f32, f32, f32)> {
    if ![p.width_mm, p.height_mm, p.margin_mm]
        .iter()
        .all(|n| n.is_finite())
        || p.width_mm <= 0.
        || p.height_mm <= 0.
        || p.width_mm > 1000.
        || p.height_mm > 1000.
        || p.margin_mm < 0.
        || 2. * p.margin_mm >= p.width_mm.min(p.height_mm)
    {
        return Err(invalid("Paper and margins do not leave a usable page."));
    }
    Ok((
        (p.width_mm * 72. / 25.4) as f32,
        (p.height_mm * 72. / 25.4) as f32,
        (p.margin_mm * 72. / 25.4) as f32,
    ))
}
pub(crate) fn add_prepared_image(
    doc: &mut Document,
    img: &image::DynamicImage,
    budget: usize,
) -> Result<(ObjectId, u32, u32)> {
    if photo::has_transparency(img) {
        return Err(invalid(
            "Transparent images need an explicit background before PDF conversion.",
        ));
    }
    let mut bytes = crate::buffer::BoundedBuffer::new(budget);
    let encoded = image::codecs::jpeg::JpegEncoder::new_with_quality(&mut bytes, 95)
        .encode_image(&img.to_rgb8());
    if bytes.exceeded {
        return Err(StudioError::ResourceLimit(
            "Encoded page images exceed 64 MiB. Export fewer pages at once.".into(),
        ));
    }
    encoded?;
    let id = doc.add_object(Stream::new(dictionary!{"Type"=>"XObject","Subtype"=>"Image","Width"=>img.width(),"Height"=>img.height(),"ColorSpace"=>"DeviceRGB","BitsPerComponent"=>8,"Filter"=>"DCTDecode"}, bytes.into_inner()));
    Ok((id, img.width(), img.height()))
}
/// Own only encoded PDF objects. Callers release each decoded page before the next.
pub(crate) struct ImagePdfBuilder {
    doc: Document,
    pages: ObjectId,
    kids: Vec<Object>,
    bounds: (f32, f32, f32),
    image_bytes: usize,
}
impl ImagePdfBuilder {
    pub(crate) fn new(p: &Paper) -> Result<Self> {
        let bounds = paper(p)?;
        let mut doc = Document::with_version("1.7");
        let pages = doc.new_object_id();
        Ok(Self {
            doc,
            pages,
            kids: vec![],
            bounds,
            image_bytes: 0,
        })
    }
    pub(crate) fn add(&mut self, img: &image::DynamicImage) -> Result<()> {
        if self.kids.len() >= MAX_PAGES {
            return Err(invalid("Select 1–200 images."));
        }
        let (w, h, m) = self.bounds;
        let (image, iw, ih) = add_prepared_image(
            &mut self.doc,
            img,
            MAX_INPUT_BYTES.saturating_sub(self.image_bytes),
        )?;
        self.image_bytes += self.doc.get_object(image)?.as_stream()?.content.len();
        let scale = ((w - 2. * m) / iw as f32).min((h - 2. * m) / ih as f32);
        let (pw, ph) = (iw as f32 * scale, ih as f32 * scale);
        let operations = vec![
            Operation::new("q", vec![]),
            Operation::new(
                "cm",
                vec![
                    pw.into(),
                    0.into(),
                    0.into(),
                    ph.into(),
                    ((w - pw) / 2.).into(),
                    ((h - ph) / 2.).into(),
                ],
            ),
            Operation::new("Do", vec![Object::Name(b"Photo".to_vec())]),
            Operation::new("Q", vec![]),
        ];
        let stream = self.doc.add_object(Stream::new(
            Dictionary::new(),
            Content { operations }.encode()?,
        ));
        let page=self.doc.add_object(dictionary!{"Type"=>"Page","Parent"=>self.pages,"MediaBox"=>vec![0.into(),0.into(),w.into(),h.into()],"Resources"=>dictionary!{"XObject"=>dictionary!{"Photo"=>image}},"Contents"=>stream});
        self.kids.push(page.into());
        Ok(())
    }
    pub(crate) fn finish(mut self) -> Result<PreparedOutput> {
        let count = self.kids.len();
        if count == 0 {
            return Err(invalid("Select 1–200 images."));
        }
        self.doc.objects.insert(
            self.pages,
            Object::Dictionary(
                dictionary! {"Type"=>"Pages","Kids"=>self.kids,"Count"=>count as i64},
            ),
        );
        let root = self
            .doc
            .add_object(dictionary! {"Type"=>"Catalog","Pages"=>self.pages});
        self.doc.trailer.set("Root", root);
        finish(self.doc, count)
    }
}
pub fn images_to_pdf(inputs: &[Vec<u8>], p: &Paper) -> Result<PreparedOutput> {
    if inputs.is_empty() || inputs.len() > MAX_PAGES {
        return Err(invalid("Select 1–200 images."));
    }
    let total = inputs
        .iter()
        .try_fold(0usize, |total, data| total.checked_add(data.len()))
        .ok_or_else(|| invalid("Combined inputs exceed 64 MiB."))?;
    if total > MAX_INPUT_BYTES {
        return Err(invalid("Combined inputs exceed 64 MiB."));
    }
    let mut builder = ImagePdfBuilder::new(p)?;
    for data in inputs {
        let img = photo::decode(data)?;
        builder.add(&img)?;
    }
    builder.finish()
}
pub fn extract_text(data: &[u8]) -> Result<String> {
    let d = load(data)?;
    let pages: Vec<_> = d.get_pages().keys().copied().collect();
    Ok(d.extract_text(&pages)?)
}
pub fn page_count(data: &[u8]) -> Result<u32> {
    Ok(load(data)?.get_pages().len() as u32)
}

pub fn print_sheet(
    data: &[u8],
    p: &Paper,
    photo_width_mm: f64,
    photo_height_mm: f64,
    spacing_mm: f64,
    copies: u32,
) -> Result<PreparedOutput> {
    crate::printing::sheet(
        data,
        &crate::printing::PrintSheetSpec {
            paper: p.clone(),
            photo_width_mm,
            photo_height_mm,
            spacing_mm,
            copies,
            cutting_guides: false,
            raster_dpi: None,
        },
    )
}

#[cfg(test)]
mod budget_tests {
    use super::*;
    #[test]
    fn exhausted_budget_does_not_append_pdf_objects() {
        let mut doc = Document::with_version("1.7");
        let img = image::DynamicImage::new_rgb8(16, 16);
        assert!(matches!(
            add_prepared_image(&mut doc, &img, 1),
            Err(StudioError::ResourceLimit(_))
        ));
        assert!(doc.objects.is_empty());
        assert!(add_prepared_image(&mut doc, &img, 4096).is_ok());
    }
}
