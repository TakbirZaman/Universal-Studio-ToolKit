# ADR 014 — visible page labels and text watermarks

Status: candidate on work/pdf-overlays; restored after a transient workspace reset. All 62 core tests pass after recovery. Independent pypdf/Poppler saved-output verification passes. The desktop light and 390px dark/200% text native workflow/save checks pass. All 29 selected Flutter tests and clean analysis pass after recovery; platform packaging is pending.

Add optional page numbers and an ASCII text watermark to the existing merge/arrange/rotate workflow. Apply marks after page ordering and rotation, before optional lossless optimization, then validate and save through the existing no-clobber export service. Keep actual optimized dimensions/bytes while retaining both overlay and optimization findings.

Use lopdf content streams and built-in Courier; no new font assets or runtime downloads. Clone inherited resources with unique names and wrap original content in a saved graphics state so existing clipping, translation, alpha and text spacing do not leak into overlays. Preserve original content and resources; this is a visible mark, not redaction or certificate signing.

Map from displayed crop-box coordinates through the inverse page rotation into default page space, including negative media origins and supported page-local UserUnit values. Use conservative text bounds and reject labels that cannot fit. Validate the source's effective PDF version before accepting nondefault units. Declare output PDF 1.7 or retain a higher effective version for the added transparency; no-op requests preserve validated source bytes exactly.

Limit watermark text to 1–80 visible ASCII characters until Unicode font embedding is implemented and tested. State this beside the field and report errors inline. The expansion summary identifies active options; prepared PDF pages remain the authoritative preview.

Verification includes actual native rendering across rotations and crop boxes, precise footer pixel bands, source preservation, resource collisions, escaped literal text, final page order, version declarations and invalid constraints. Independent pypdf/Poppler verification reopens and renders saved synthetic PDFs. Real FFI widget scenarios cover desktop light and 390px dark/200% text, validation recovery and Unicode filename export. Re-run these after recovery; do not infer clean-device, universal PDF or observed-user acceptance from these checks.
