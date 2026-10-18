# ADR 011 — sequential scan preparation and validated display previews

Status: backend and typed interface verified locally; platform packaging and device checks pending.

A session previously held all adjusted full-resolution PNGs in Dart before PDF assembly. Small compressed JPEG sources could therefore create large simultaneous PNG intermediates. The existing Rust session helper had a cumulative PNG limit, but the interface bypassed that helper by adjusting each page itself.

Send original bytes and typed per-page edits in one asynchronous bridge request. Validate session page count, combined source bytes and finite edit constraints first. Prepare one decoded page at a time, append its JPEG representation to the PDF, then release its decoded pixels. Keep only encoded PDF objects across iterations. Refuse encoded image writes before exceeding a cumulative 64 MiB budget, and refuse PDF serialization beyond 64 MiB. Preserve validated original bytes when a lossless optimization rewrite exceeds that output budget. A failed operation saves nothing and cannot modify source bytes.

PDF conversion requires opaque pixels at the original 8/16-bit precision; rounding a nearly opaque 16-bit alpha value to 255 must not silently grant background consent. Scan PDFs explicitly report JPEG quality 95 and the absence of selectable text. Original page copies and edit settings remain available for drafts and reset.

Image display also passes through the bounded Rust decoder and canonical PNG encoder before reaching Flutter's image codec. The display thumbnail is at most 1200 pixels on either side and does not replace the export bytes or actual output measurements. Preview requests serialize within their widget and coalesce rapid edits to the latest pending request; stale completions never appear under a newly selected source. PDFium retains its separate bounded render adapter.

This bounds encoded scan intermediates and display dimensions, not total process memory or CPU. Rust/image decoding and colour operations can use additional temporary buffers; original sources, the current decoded page, PDF objects, serialized output and bridge copies may coexist. PDF parsing/rendering still lacks hard worker-process isolation. No hard process-wide memory cap or immediate cancellation claim is made.

Verification includes real reordered/adjusted multipage PDFs rendered with PDFium and compared with separately prepared single-page references, original-byte preservation, 200-page/error boundaries, early encoded-budget rejection without partial PDF objects, invalid preview input and 16-bit alpha rejection. Interface and packaged-device evidence must remain separately recorded.

Local verification 2026-10-18: generated bridge run 39162800840 passed; eight source files were SHA-256/ZIP/allowlist verified before application. The interface suite passed 25 tests including the actual three-page workflow on desktop light and 390px dark with 200% text, invalid-input preview rejection, real English/Bangla OCR and physical photo preparation. A page-appearance dropdown overflow found by the new test was fixed with an expanded selector. The picker alone is substituted; PDF preparation, rendering, comparison and Bangla-named save use real native services. No representative user test or physical-device acceptance is implied.
