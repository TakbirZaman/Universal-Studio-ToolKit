//! Physical print layout rules and PDF export. No filesystem assumptions.
use crate::{
    model::*,
    pdf::{self, Paper},
};
use lopdf::{
    Dictionary, Document, Object, Stream,
    content::{Content, Operation},
    dictionary,
};

#[derive(Clone, Debug)]
pub struct PrintSheetSpec {
    pub paper: Paper,
    pub photo_width_mm: f64,
    pub photo_height_mm: f64,
    pub spacing_mm: f64,
    pub copies: u32,
    pub cutting_guides: bool,
    pub raster_dpi: Option<u16>,
}
#[derive(Clone, Debug)]
pub struct Placement {
    pub x_mm: f64,
    pub y_mm: f64,
    pub width_mm: f64,
    pub height_mm: f64,
}
#[derive(Clone, Debug)]
pub struct CutLine {
    pub x1_mm: f64,
    pub y1_mm: f64,
    pub x2_mm: f64,
    pub y2_mm: f64,
}
#[derive(Clone, Debug)]
pub struct Layout {
    pub placements: Vec<Placement>,
    pub cut_lines: Vec<CutLine>,
    pub capacity: u32,
}
impl PrintSheetSpec {
    pub fn layout(&self) -> Result<Layout> {
        pdf::paper(&self.paper)?;
        let p = &self.paper;
        if p.width_mm < 10.
            || p.height_mm < 10.
            || ![self.photo_width_mm, self.photo_height_mm, self.spacing_mm]
                .iter()
                .all(|n| n.is_finite())
            || !(1.0..=1000.0).contains(&self.photo_width_mm)
            || !(1.0..=1000.0).contains(&self.photo_height_mm)
            || !(0.0..=1000.0).contains(&self.spacing_mm)
            || !(1..=200).contains(&self.copies)
        {
            return Err(invalid(
                "Use paper sides of 10–1000 mm, photo sides of 1–1000 mm, and 1–200 copies.",
            ));
        }
        if let Some(dpi) = self.raster_dpi {
            crate::density::validate_dpi(dpi)?;
            let w = crate::photo::physical_pixels(self.photo_width_mm, f64::from(dpi))?;
            let h = crate::photo::physical_pixels(self.photo_height_mm, f64::from(dpi))?;
            if w as u64 * h as u64 > MAX_PIXELS {
                return Err(invalid(
                    "The photo at this DPI exceeds the 24 megapixel limit. Lower the DPI or print size.",
                ));
            }
        }
        if self.cutting_guides && (p.margin_mm < 1.5 || self.spacing_mm < 3.) {
            return Err(invalid(
                "Cutting guides need margins of at least 1.5 mm and spacing of at least 3 mm.",
            ));
        }
        let cols = ((p.width_mm - 2. * p.margin_mm + self.spacing_mm)
            / (self.photo_width_mm + self.spacing_mm))
            .floor() as u32;
        let rows = ((p.height_mm - 2. * p.margin_mm + self.spacing_mm)
            / (self.photo_height_mm + self.spacing_mm))
            .floor() as u32;
        let capacity = cols.saturating_mul(rows);
        if cols == 0 || rows == 0 || self.copies > capacity {
            return Err(invalid(
                "The requested copies do not fit on this sheet. Reduce copies, margins, spacing or photo dimensions.",
            ));
        }
        let mut placements = Vec::new();
        let mut cut_lines = Vec::new();
        for i in 0..self.copies {
            let x = p.margin_mm + f64::from(i % cols) * (self.photo_width_mm + self.spacing_mm);
            let y = p.height_mm
                - p.margin_mm
                - self.photo_height_mm
                - f64::from(i / cols) * (self.photo_height_mm + self.spacing_mm);
            // Bound the actual calculated boxes, independent of capacity rounding.
            if x < 0.
                || y < 0.
                || x + self.photo_width_mm > p.width_mm + 1e-8
                || y + self.photo_height_mm > p.height_mm + 1e-8
            {
                return Err(invalid(
                    "The calculated print layout extends outside the paper.",
                ));
            }
            placements.push(Placement {
                x_mm: x,
                y_mm: y,
                width_mm: self.photo_width_mm,
                height_mm: self.photo_height_mm,
            });
            if self.cutting_guides {
                for edge_x in [x, x + self.photo_width_mm] {
                    cut_lines.push(CutLine {
                        x1_mm: edge_x,
                        y1_mm: y - 1.5,
                        x2_mm: edge_x,
                        y2_mm: y - 0.5,
                    });
                    cut_lines.push(CutLine {
                        x1_mm: edge_x,
                        y1_mm: y + self.photo_height_mm + 0.5,
                        x2_mm: edge_x,
                        y2_mm: y + self.photo_height_mm + 1.5,
                    });
                }
                for edge_y in [y, y + self.photo_height_mm] {
                    cut_lines.push(CutLine {
                        x1_mm: x - 1.5,
                        y1_mm: edge_y,
                        x2_mm: x - 0.5,
                        y2_mm: edge_y,
                    });
                    cut_lines.push(CutLine {
                        x1_mm: x + self.photo_width_mm + 0.5,
                        y1_mm: edge_y,
                        x2_mm: x + self.photo_width_mm + 1.5,
                        y2_mm: edge_y,
                    });
                }
            }
        }
        if cut_lines.iter().any(|line| {
            [line.x1_mm, line.x2_mm]
                .iter()
                .any(|x| *x < -1e-8 || *x > p.width_mm + 1e-8)
                || [line.y1_mm, line.y2_mm]
                    .iter()
                    .any(|y| *y < -1e-8 || *y > p.height_mm + 1e-8)
        }) {
            return Err(invalid("Cutting guides extend outside the paper."));
        }
        Ok(Layout {
            placements,
            cut_lines,
            capacity,
        })
    }
}
fn pt(mm: f64) -> Object {
    Object::Real((mm * 72. / 25.4) as f32)
}
pub fn sheet(data: &[u8], spec: &PrintSheetSpec) -> Result<PreparedOutput> {
    let layout = spec.layout()?;
    let mut image = crate::photo::decode(data)?;
    if crate::photo::has_transparency(&image) {
        return Err(invalid(
            "Transparent images need an explicit background before PDF conversion.",
        ));
    }
    if ((f64::from(image.width()) / f64::from(image.height()))
        / (spec.photo_width_mm / spec.photo_height_mm)
        - 1.)
        .abs()
        > 0.01
    {
        return Err(invalid(
            "Crop the photo to the requested aspect ratio first; printing will not distort it.",
        ));
    }
    let source_dpi = (f64::from(image.width()) / spec.photo_width_mm * 25.4)
        .min(f64::from(image.height()) / spec.photo_height_mm * 25.4);
    if let Some(dpi) = spec.raster_dpi {
        let width = crate::photo::physical_pixels(spec.photo_width_mm, f64::from(dpi))?;
        let height = crate::photo::physical_pixels(spec.photo_height_mm, f64::from(dpi))?;
        image = image.resize(width, height, image::imageops::FilterType::Lanczos3);
    }
    let mut doc = Document::with_version("1.7");
    let pages = doc.new_object_id();
    let (image_id, iw, ih) = pdf::add_prepared_image(&mut doc, &image, MAX_INPUT_BYTES)?;
    let mut operations = vec![];
    for place in &layout.placements {
        // Preserve aspect ratio, including physical/pixel rounding. Any tiny
        // remainder is white page space, never distortion or implicit cropping.
        let scale = (place.width_mm / f64::from(iw)).min(place.height_mm / f64::from(ih));
        let (w, h) = (f64::from(iw) * scale, f64::from(ih) * scale);
        let (x, y) = (
            place.x_mm + (place.width_mm - w) / 2.,
            place.y_mm + (place.height_mm - h) / 2.,
        );
        operations.extend([
            Operation::new("q", vec![]),
            Operation::new("cm", vec![pt(w), 0.into(), 0.into(), pt(h), pt(x), pt(y)]),
            Operation::new("Do", vec![Object::Name(b"Photo".to_vec())]),
            Operation::new("Q", vec![]),
        ]);
    }
    if !layout.cut_lines.is_empty() {
        operations.push(Operation::new("q", vec![]));
        operations.push(Operation::new("G", vec![0.into()]));
        operations.push(Operation::new("w", vec![Object::Real(0.5)]));
        for line in &layout.cut_lines {
            operations.extend([
                Operation::new("m", vec![pt(line.x1_mm), pt(line.y1_mm)]),
                Operation::new("l", vec![pt(line.x2_mm), pt(line.y2_mm)]),
            ]);
        }
        operations.push(Operation::new("S", vec![]));
        operations.push(Operation::new("Q", vec![]));
    }
    let stream = doc.add_object(Stream::new(
        Dictionary::new(),
        Content { operations }.encode()?,
    ));
    let page=doc.add_object(dictionary!{"Type"=>"Page","Parent"=>pages,"MediaBox"=>vec![0.into(),0.into(),pt(spec.paper.width_mm),pt(spec.paper.height_mm)],"Resources"=>dictionary!{"XObject"=>dictionary!{"Photo"=>image_id}},"Contents"=>stream});
    doc.objects.insert(
        pages,
        Object::Dictionary(
            dictionary! {"Type"=>"Pages","Kids"=>vec![Object::Reference(page)],"Count"=>1},
        ),
    );
    let root = doc.add_object(dictionary! {"Type"=>"Catalog","Pages"=>pages});
    doc.trailer.set("Root", root);
    let mut output = pdf::finish(doc, 1)?;
    output.info.findings.push(ValidationFinding{advisory:false,passed:true,code:"print_layout".into(),message:format!("{} copies; paper {:.2} × {:.2} mm; photo boxes {:.2} × {:.2} mm; margins {:.2} mm; spacing {:.2} mm. Layout capacity {}. Print at Actual size / 100%, without Fit to page.",spec.copies,spec.paper.width_mm,spec.paper.height_mm,spec.photo_width_mm,spec.photo_height_mm,spec.paper.margin_mm,spec.spacing_mm,layout.capacity)});
    output.info.findings.push(ValidationFinding{advisory:true,passed:true,code:"print_sampling".into(),message:format!("Image encoded once as JPEG at quality 95. Source detail at the requested size: {:.1} DPI. Embedded photo: {} × {} pixels. Resampling cannot create missing detail; tiny white space may result from aspect/pixel rounding.",source_dpi,iw,ih)});
    let actual_dpi =
        (f64::from(iw) / spec.photo_width_mm).max(f64::from(ih) / spec.photo_height_mm) * 25.4;
    output.info.findings.push(ValidationFinding {advisory:true,passed:true,code:"print_density".into(),message:match spec.raster_dpi {Some(dpi)=>format!("Requested resampling: {} DPI. Effective embedded density: {:.2} DPI; pixel rounding applies.",dpi,actual_dpi),None=>format!("Source pixel dimensions retained. Effective embedded density: {:.2} DPI.",actual_dpi)}});
    crate::export::verify_output(&output)?;
    Ok(output)
}
