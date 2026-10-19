# ADR 015 — existing PDF text and editable UTF-8 export

Status: backend candidate on work/pdf-text. No interface/platform completion claim yet.

Use the already bundled PDFium adapter to read an existing text layer after the supported-PDF validator. Reuse its serialized engine lock and the bounded job queue. This runs no OCR, scripts or external resource callbacks. Keep page order, separate nonempty page results, and report pages with no selectable text. An entirely empty result explains that a scan may need offline OCR where available.

Preflight a cumulative one-million-character PDFium count before collecting page strings and enforce 4 MiB of actual UTF-8 output through the bounded writer. These limits do not sandbox PDFium or cap its internal parsing allocations. Review reading order, font mappings and missing characters; do not promise visual layout reconstruction. Output is editable plain text, not a searchable PDF.

A shared plain-text output validator separates byte/UTF-8 checks from OCR-specific disclosures. The OCR workflow keeps its approximation warning. PDF extraction and edited text exports use their own accurate findings, the shared output validator and no-clobber save service. No dependency, model or font is added.

Verification in progress: actual native extraction order, blank and malformed pages, Unicode edited text, byte limits, source preservation and Unicode no-clobber export. Regenerate typed bindings and implement responsive editor/save flow before platform builds or integration.
