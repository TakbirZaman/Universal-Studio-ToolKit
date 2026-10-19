# ADR 015 — existing PDF text and editable UTF-8 export

Status: local core/interface candidate on work/pdf-text. All 66 Rust and 32 selected Flutter tests pass; clean analysis. Platform packaging remains pending.

Use the already bundled PDFium adapter to read an existing text layer after the supported-PDF validator. Reuse its serialized engine lock and the bounded job queue. This runs no OCR, scripts or external resource callbacks. Keep page order, separate nonempty page results, and report pages with no selectable text. An entirely empty result explains that a scan may need offline OCR where available.

Preflight a cumulative one-million-character PDFium count before collecting page strings and enforce 4 MiB of actual UTF-8 output through the bounded writer. These limits do not sandbox PDFium or cap its internal parsing allocations. Review reading order, font mappings and missing characters; do not promise visual layout reconstruction. Output is editable plain text, not a searchable PDF.

A shared plain-text output validator separates byte/UTF-8 checks from OCR-specific disclosures. The OCR workflow keeps its approximation warning. PDF extraction and edited text exports use their own accurate findings, the shared output validator and no-clobber save service. No dependency, model or font is added.

Verification in progress: actual native extraction order, blank and malformed pages, Unicode edited text, byte limits, source preservation and Unicode no-clobber export. Regenerate typed bindings and implement responsive editor/save flow before platform builds or integration.

The editor opens from PDF Studio using the prepared output when present or the selected source otherwise; source choice is stated next to the action. Existing PDF preview sits beside the editor on desktop and above it on narrow layouts. Actual UTF-8 size is validated after edits on the worker. Saved name/location/bytes and original-preserved status follow the shared export service. Image-only errors keep text export disabled; no fictitious OCR is run.

Generator39252445602 passed for backend15600d7. Artifact12187280337 SHA-256 9c8c545ee27d0c6fc3f9c921f23b018d3adece5bcd11fb040d07220bdbfa2836 was CRC/SHA/allowlist checked and all eight generated files applied without hand editing.

Independent pypdf and PDFium verification extracted English/Bangla text from a licensed-font synthetic PDF, checked page order, actual UTF-8 bytes, source preservation and no-clobber export. Native tests also reject a 126-page text layer above the one-million-character budget. Desktop light and 390px dark/200% text tests exercise entry action, actual extraction, Bangla edits and saved UTF-8 bytes. Visual inspection found a truncated help line; wrapping and a shorter title were verified in the focused UI recheck. No representative-user or clean-device claim.
