# ADR 012 — validated physical print sheets

Status: core and interface verified locally; platform packaging pending.

Keep layout dimensions in millimetres and convert to PDF points only at the rendering boundary. A typed PrintSheetSpec validates finite paper/photo/margin/spacing/copy constraints before decoding. Compute capacity and each actual placement independently; reject overflow rather than silently omit copies. Support A4, A5, Letter, 4 × 6 inch and custom paper through the same model.

Cutting guides are optional vector segments outside photo boxes. They require at least 1.5 mm margins and 3 mm spacing. Validate segment coordinates against the page; tests also check that no guide enters a photo. Keep the photo as one shared PDF image object across copies.

Preserve original pixel dimensions by default. Optional explicit DPI resampling works from the normalized decoded source and encodes once to JPEG quality 95; it never recompresses an earlier candidate. DPI cannot create real detail. Report source detail separately from effective embedded density and requested resampling, including pixel rounding. Preserve aspect ratio within exact photo boxes, leaving tiny white space when necessary rather than stretching or silently cropping. Reject materially mismatched source/photo aspect ratios and nonopaque sources until the user prepares an appropriate photo.

Paper, margins, spacing and optional sampling controls are labelled with units. Advanced controls are collapsed initially; failed field validation opens them and shows inline errors. Always instruct Actual size / 100%, without Fit to page. Printer drivers and hardware are a separate acceptance gate.

No dependency versions or native engines are added. Legacy print API and CLI requests retain source pixels and omit cutting guides by default. Existing encoded-image/final-PDF budgets, source preservation, staged save and reopen verification still apply.

Verification 2026-10-18: four geometry/PDF tests, complete 52-test Rust suite and 27 selected Flutter tests, clean analysis and formatting. Actual native UI workflows pass with bundled fonts on desktop light and 390px dark/200% text, including invalid-guide-spacing recovery and decoded PDF preview pixels. Generator39165065326 produced eight verified generated files; see evidence/custom-print-20261018.json. An independent Pillow/pypdf/Poppler check measures actual saved paper/placement dimensions, embedded pixels, drawing counts, original preservation, non-overwrite and failed-constraint cleanup. Local rendered PDF inspection found no clipping or overlapping marks. This is not printer, device or representative-user certification.
