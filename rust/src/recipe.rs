use crate::model::*;
use serde::{Deserialize, Serialize};
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case", deny_unknown_fields)]
pub enum Step {
    Crop {
        x: u32,
        y: u32,
        width: u32,
        height: u32,
    },
    Flip {
        horizontal: bool,
        vertical: bool,
    },
    Resize {
        width: u32,
        height: u32,
        fit: Fit,
    },
    FlexibleResize {
        width: u32,
        height: u32,
        minimum_width: u32,
        minimum_height: u32,
        fit: Fit,
    },
    Compress {
        limit: ByteLimit,
        min_quality: u8,
    },
    RemoveMetadata,
    Rename {
        filename: String,
    },
    Export {
        format: OutputFormat,
    },
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Recipe {
    pub schema_version: u32,
    pub name: String,
    pub revision_date: String,
    pub steps: Vec<Step>,
}
impl Recipe {
    pub fn parse(bytes: &[u8]) -> Result<Self> {
        if bytes.len() > 65536 {
            return Err(invalid("Recipe is too large."));
        }
        let r: Self = serde_json::from_slice(bytes)?;
        r.validate()?;
        Ok(r)
    }
    pub fn validate(&self) -> Result<()> {
        if ![1, 2, 3, 4].contains(&self.schema_version)
            || self.name.trim().is_empty()
            || self.name.len() > 128
            || self.steps.is_empty()
            || self.steps.len() > 7
        {
            return Err(invalid("Unsupported or empty recipe."));
        }
        let mut previous = -1;
        for step in &self.steps {
            let rank = match step {
                Step::Crop {
                    x,
                    y,
                    width,
                    height,
                } => {
                    if self.schema_version < 2
                        || *width == 0
                        || *height == 0
                        || *width as u64 * *height as u64 > MAX_PIXELS
                        || x.checked_add(*width).is_none_or(|v| v > 12000)
                        || y.checked_add(*height).is_none_or(|v| v > 12000)
                    {
                        return Err(invalid(
                            "Crop needs recipe version 2 or later and valid pixel coordinates.",
                        ));
                    }
                    0
                }
                Step::Flip {
                    horizontal,
                    vertical,
                } => {
                    if self.schema_version != 4 || !(*horizontal || *vertical) {
                        return Err(invalid(
                            "Flipping needs recipe version 4 and at least one enabled direction.",
                        ));
                    }
                    1
                }
                Step::Resize { width, height, .. } => {
                    if *width == 0
                        || *height == 0
                        || *width > 12000
                        || *height > 12000
                        || *width as u64 * *height as u64 > MAX_PIXELS
                    {
                        return Err(invalid("Invalid resize dimensions."));
                    }
                    2
                }
                Step::FlexibleResize {
                    width,
                    height,
                    minimum_width,
                    minimum_height,
                    ..
                } => {
                    if self.schema_version < 3
                        || *minimum_width == 0
                        || *minimum_height == 0
                        || minimum_width > width
                        || minimum_height > height
                        || *width > 12000
                        || *height > 12000
                        || u64::from(*width) * u64::from(*height) > MAX_PIXELS
                    {
                        return Err(invalid(
                            "Flexible resizing needs recipe version 3 or later and valid minimum/maximum pixels.",
                        ));
                    }
                    2
                }
                Step::Compress { limit, min_quality } => {
                    limit.bytes()?;
                    if !(1..=100).contains(min_quality) {
                        return Err(invalid("Invalid minimum quality."));
                    }
                    3
                }
                Step::RemoveMetadata => 4,
                Step::Rename { filename } => {
                    crate::export::safe_name(filename)?;
                    5
                }
                Step::Export { .. } => 6,
            };
            if rank <= previous {
                return Err(invalid("Recipe steps repeat or are out of order."));
            }
            previous = rank;
        }
        if self
            .steps
            .iter()
            .any(|s| matches!(s, Step::FlexibleResize { .. }))
            && !self
                .steps
                .iter()
                .any(|s| matches!(s, Step::Compress { .. }))
        {
            return Err(invalid("Flexible resizing needs a maximum file size."));
        }
        if previous != 6 {
            return Err(invalid("A recipe must end with export."));
        }
        if let Some(Step::Export { format }) = self.steps.last() {
            for step in &self.steps {
                if let Step::Rename { filename } = step {
                    let ext = std::path::Path::new(filename)
                        .extension()
                        .and_then(|s| s.to_str())
                        .unwrap_or("")
                        .to_lowercase();
                    if !match format {
                        OutputFormat::Jpeg => ext == "jpg" || ext == "jpeg",
                        OutputFormat::Png => ext == "png",
                    } {
                        return Err(invalid(
                            "Recipe filename extension must match output format.",
                        ));
                    }
                }
            }
        }
        Ok(())
    }
    pub fn run(&self, bytes: &[u8]) -> Result<PreparedOutput> {
        self.validate()?;
        let original = crate::photo::decode(bytes)?;
        let mut o = PhotoOptions {
            width: original.width(),
            height: original.height(),
            ..Default::default()
        };
        let mut flexible_minimum = None;
        for s in &self.steps {
            match s {
                Step::Crop {
                    x,
                    y,
                    width,
                    height,
                } => {
                    o.crop = Some(CropRect {
                        x: *x,
                        y: *y,
                        width: *width,
                        height: *height,
                    });
                    o.width = *width;
                    o.height = *height;
                }
                Step::Resize { width, height, fit } => {
                    o.width = *width;
                    o.height = *height;
                    o.fit = *fit;
                }
                Step::Flip {
                    horizontal,
                    vertical,
                } => {
                    // Vertical reflection equals a half-turn followed by horizontal
                    // reflection. prepare() applies both after the original-pixel crop.
                    o.rotate_quarters = if *vertical { 2 } else { 0 };
                    o.flip_horizontal = *horizontal ^ *vertical;
                }
                Step::FlexibleResize {
                    width,
                    height,
                    minimum_width,
                    minimum_height,
                    fit,
                } => {
                    o.width = *width;
                    o.height = *height;
                    o.fit = *fit;
                    flexible_minimum = Some((*minimum_width, *minimum_height));
                }
                Step::Compress { limit, min_quality } => {
                    o.max_bytes = Some(*limit);
                    o.min_quality = *min_quality;
                }
                Step::Export { format } => o.format = *format,
                _ => {}
            }
        }
        if let Some((width, height)) = flexible_minimum {
            crate::photo::process_flexible(bytes, &o, width, height, &|| false)
        } else {
            crate::photo::process(bytes, &o)
        }
    }
}
