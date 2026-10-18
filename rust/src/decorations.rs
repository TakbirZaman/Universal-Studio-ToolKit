//! Visible PDF text overlays. These are neither redaction nor digital signing.
use crate::{model::*, pdf};
use lopdf::{
    Dictionary, Document, Object, ObjectId, Stream,
    content::{Content, Operation},
    dictionary,
};

#[derive(Clone, Debug)]
pub struct OverlayOptions {
    pub page_numbers: bool,
    pub watermark: Option<String>,
    pub watermark_font_points: f64,
    pub margin_mm: f64,
}
impl Default for OverlayOptions {
    fn default() -> Self {
        Self {
            page_numbers: false,
            watermark: None,
            watermark_font_points: 32.,
            margin_mm: 10.,
        }
    }
}
#[derive(Clone, Debug)]
pub struct PageGeometry {
    pub width: f64,
    pub height: f64,
    pub unit: f64,
    pub transform: [f64; 6],
}
fn number(value: &Object) -> Result<f64> {
    let n = match value {
        Object::Integer(n) => *n as f64,
        Object::Real(n) => f64::from(*n),
        _ => return Err(invalid("PDF page geometry contains a nonnumeric value.")),
    };
    if !n.is_finite() {
        return Err(invalid("PDF page geometry is not finite."));
    }
    Ok(n)
}
fn rect(doc: &Document, value: &Object) -> Result<[f64; 4]> {
    let (_, value) = doc.dereference(value)?;
    let values = value.as_array()?;
    if values.len() != 4 {
        return Err(invalid("PDF page box needs four coordinates."));
    }
    let r = [
        number(&doc.dereference(&values[0])?.1)?,
        number(&doc.dereference(&values[1])?.1)?,
        number(&doc.dereference(&values[2])?.1)?,
        number(&doc.dereference(&values[3])?.1)?,
    ];
    if r[2] <= r[0] || r[3] <= r[1] {
        return Err(invalid("PDF page box has no positive area."));
    }
    Ok(r)
}
pub fn geometry(doc: &Document, page: ObjectId) -> Result<PageGeometry> {
    let media = pdf::inherited(doc, page, b"MediaBox")?
        .ok_or_else(|| invalid("PDF page has no media box."))?;
    let media = rect(doc, &media)?;
    let crop = match pdf::inherited(doc, page, b"CropBox")? {
        Some(value) => rect(doc, &value)?,
        None => media,
    };
    let (x0, y0, x1, y1) = (
        media[0].max(crop[0]),
        media[1].max(crop[1]),
        media[2].min(crop[2]),
        media[3].min(crop[3]),
    );
    if x1 <= x0 || y1 <= y0 {
        return Err(invalid("PDF crop box lies outside its media box."));
    }
    let rotation = match pdf::inherited(doc, page, b"Rotate")? {
        Some(value) => doc.dereference(&value)?.1.as_i64()?,
        None => 0,
    };
    if rotation % 90 != 0 {
        return Err(invalid(
            "PDF overlays support page rotation in 90-degree steps.",
        ));
    }
    // UserUnit is a page entry, not an inherited page-tree attribute.
    let unit = match doc.get_dictionary(page)?.get(b"UserUnit") {
        Ok(value) => number(&doc.dereference(value)?.1)?,
        Err(_) => 1.,
    };
    if unit <= 0. || unit > 75000. {
        return Err(invalid("PDF page units are outside the supported range."));
    }
    let (w, h) = (x1 - x0, y1 - y0);
    let (width, height, transform) = match rotation.rem_euclid(360) {
        0 => (w, h, [1., 0., 0., 1., x0, y0]),
        90 => (h, w, [0., 1., -1., 0., x1, y0]),
        180 => (w, h, [-1., 0., 0., -1., x1, y1]),
        _ => (h, w, [0., -1., 1., 0., x0, y1]),
    };
    Ok(PageGeometry {
        width,
        height,
        unit,
        transform,
    })
}
fn dictionary_value(doc: &Document, owner: &Dictionary, key: &[u8]) -> Result<Dictionary> {
    match owner.get(key) {
        Ok(value) => Ok(doc.dereference(value)?.1.as_dict()?.clone()),
        Err(_) => Ok(Dictionary::new()),
    }
}
fn unique(dictionary: &Dictionary, prefix: &str) -> Result<String> {
    for index in 0..1000 {
        let key = format!("{prefix}{index}");
        if !dictionary.has(key.as_bytes()) {
            return Ok(key);
        }
    }
    Err(invalid("PDF has too many conflicting overlay resources."))
}
fn real(value: f64) -> Object {
    Object::Real(value as f32)
}
fn text_ops(font: &str, state: &str, text: &str, size: f64, matrix: [f64; 6]) -> Vec<Operation> {
    vec![
        Operation::new("q", vec![]),
        Operation::new("gs", vec![Object::Name(state.as_bytes().to_vec())]),
        Operation::new("g", vec![real(0.15)]),
        Operation::new("BT", vec![]),
        Operation::new(
            "Tf",
            vec![Object::Name(font.as_bytes().to_vec()), real(size)],
        ),
        Operation::new("Tc", vec![0.into()]),
        Operation::new("Tw", vec![0.into()]),
        Operation::new("Tz", vec![100.into()]),
        Operation::new("Ts", vec![0.into()]),
        Operation::new("Tr", vec![0.into()]),
        Operation::new("Tm", matrix.into_iter().map(real).collect()),
        Operation::new("Tj", vec![Object::string_literal(text.as_bytes().to_vec())]),
        Operation::new("ET", vec![]),
        Operation::new("Q", vec![]),
    ]
}
fn original_streams(doc: &Document, page: ObjectId) -> Result<Vec<Object>> {
    let dictionary = doc.get_dictionary(page)?;
    let Ok(value) = dictionary.get(b"Contents") else {
        return Ok(vec![]);
    };
    let (_, resolved) = doc.dereference(value)?;
    let values = match resolved {
        Object::Array(values) => values.clone(),
        Object::Stream(_) => vec![value.clone()],
        _ => return Err(invalid("PDF page contents are not supported streams.")),
    };
    for value in &values {
        if !matches!(value, Object::Reference(_))
            || !matches!(doc.dereference(value)?.1, Object::Stream(_))
        {
            return Err(invalid(
                "PDF page contents must reference supported streams.",
            ));
        }
    }
    Ok(values)
}
pub fn apply(data: &[u8], options: &OverlayOptions) -> Result<PreparedOutput> {
    if !options.margin_mm.is_finite()
        || !(1.0..=50.0).contains(&options.margin_mm)
        || !options.watermark_font_points.is_finite()
        || !(6.0..=96.0).contains(&options.watermark_font_points)
    {
        return Err(invalid(
            "Use margins of 1–50 mm and watermark text size of 6–96 points.",
        ));
    }
    if let Some(text) = &options.watermark {
        if text.trim().is_empty()
            || text.len() > 80
            || !text.bytes().all(|c| (32..=126).contains(&c))
        {
            return Err(invalid(
                "Use 1–80 English letters, numbers or plain symbols for watermark text in this version.",
            ));
        }
    }
    let mut doc = pdf::load(data)?;
    let pages = doc.get_pages();
    let count = pages.len();
    if !options.page_numbers && options.watermark.is_none() {
        return Ok(PreparedOutput {
            data: data.to_vec(),
            info: OutputInfo {
                format: "pdf".into(),
                bytes: data.len() as u64,
                width: None,
                height: None,
                pages: Some(count as u32),
                quality: None,
                print_density: None,
                findings: vec![],
            },
        });
    }
    let font=doc.add_object(dictionary!{"Type"=>"Font","Subtype"=>"Type1","BaseFont"=>"Courier","Encoding"=>"WinAnsiEncoding"});
    let opaque = doc.add_object(dictionary! {"Type"=>"ExtGState","ca"=>1.0,"CA"=>1.0});
    let translucent = doc.add_object(dictionary! {"Type"=>"ExtGState","ca"=>0.18,"CA"=>0.18});
    for (index, page) in pages.values().enumerate() {
        let geometry = geometry(&doc, *page)?;
        let mut resources = match pdf::inherited(&doc, *page, b"Resources")? {
            Some(value) => doc.dereference(&value)?.1.as_dict()?.clone(),
            None => Dictionary::new(),
        };
        let mut fonts = dictionary_value(&doc, &resources, b"Font")?;
        let font_name = unique(&fonts, "USTStudioFont")?;
        fonts.set(font_name.as_bytes(), font);
        resources.set("Font", fonts);
        let mut states = dictionary_value(&doc, &resources, b"ExtGState")?;
        let opaque_name = unique(&states, "USTStudioOpaque")?;
        states.set(opaque_name.as_bytes(), opaque);
        let watermark_name = unique(&states, "USTStudioWatermark")?;
        states.set(watermark_name.as_bytes(), translucent);
        resources.set("ExtGState", states);
        let mut ops = vec![
            Operation::new("Q", vec![]),
            Operation::new("q", vec![]),
            Operation::new("cm", geometry.transform.into_iter().map(real).collect()),
        ];
        let margin = options.margin_mm * 72. / 25.4 / geometry.unit;
        if options.page_numbers {
            let text = format!("Page {} of {}", index + 1, count);
            let size = 10. / geometry.unit;
            let width = text.len() as f64 * 0.6 * size;
            if geometry.width < 2. * margin + width + 0.3 * size
                || geometry.height < 2. * margin + 1.3 * size
            {
                return Err(invalid(
                    "A page is too small for these page-number margins.",
                ));
            }
            ops.extend(text_ops(
                &font_name,
                &opaque_name,
                &text,
                size,
                [
                    1.,
                    0.,
                    0.,
                    1.,
                    (geometry.width - width) / 2.,
                    margin + 0.3 * size,
                ],
            ));
        }
        if let Some(text) = &options.watermark {
            let size = options.watermark_font_points / geometry.unit;
            let width = text.len() as f64 * 0.6 * size;
            let angle = std::f64::consts::FRAC_1_SQRT_2;
            let mut xs = vec![];
            let mut ys = vec![];
            for (x, y) in [
                (-0.1 * size, -0.3 * size),
                (width + 0.2 * size, -0.3 * size),
                (-0.1 * size, size),
                (width + 0.2 * size, size),
            ] {
                xs.push(angle * x - angle * y);
                ys.push(angle * x + angle * y);
            }
            let min_x = xs.iter().copied().fold(f64::INFINITY, f64::min);
            let max_x = xs.iter().copied().fold(f64::NEG_INFINITY, f64::max);
            let min_y = ys.iter().copied().fold(f64::INFINITY, f64::min);
            let max_y = ys.iter().copied().fold(f64::NEG_INFINITY, f64::max);
            if max_x - min_x > geometry.width - 2. * margin
                || max_y - min_y > geometry.height - 2. * margin
            {
                return Err(invalid(
                    "Watermark text does not fit a page. Shorten it or choose a smaller text size.",
                ));
            }
            let tx = geometry.width / 2. - (min_x + max_x) / 2.;
            let ty = geometry.height / 2. - (min_y + max_y) / 2.;
            ops.extend(text_ops(
                &font_name,
                &watermark_name,
                text,
                size,
                [angle, angle, -angle, angle, tx, ty],
            ));
        }
        ops.push(Operation::new("Q", vec![]));
        let original = original_streams(&doc, *page)?;
        let prefix = doc.add_object(Stream::new(Dictionary::new(), b"q\n".to_vec()));
        let suffix = doc.add_object(Stream::new(
            Dictionary::new(),
            Content { operations: ops }.encode()?,
        ));
        let mut contents = vec![Object::Reference(prefix)];
        contents.extend(original);
        contents.push(Object::Reference(suffix));
        let page = doc.get_dictionary_mut(*page)?;
        page.set("Resources", resources);
        page.set("Contents", contents);
    }
    let mut output = pdf::finish(doc, count)?;
    if options.page_numbers {
        output.info.findings.push(ValidationFinding{advisory:false,passed:true,code:"page_numbers".into(),message:"Visible page numbers added in the saved page order, accounting for rotation and crop boxes.".into()});
    }
    if options.watermark.is_some() {
        output.info.findings.push(ValidationFinding {
            advisory: true,
            passed: true,
            code: "visible_watermark".into(),
            message:
                "Visible text watermark added. Underlying document content remains in the PDF."
                    .into(),
        });
    }
    crate::export::verify_output(&output)?;
    Ok(output)
}
