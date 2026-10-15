# Architecture decisions

## ADR 001 — Byte boundary, 2026-10-15
Flutter owns file/camera/document-provider access. Rust accepts bounded bytes, not Android content URIs disguised as paths. Sources are typed independently of the widgets. Desktop saves use a same-directory temporary file, sync, read-back verification and persist_noclobber. Android exports must use a provider adapter and read-back verification before being marked supported.

## ADR 002 — Conservative PDF handling
lopdf 0.38.0 is pinned for the first implementation; newer versions require separate compatibility testing. Page inheritance is materialized before replacing the page tree. Unsupported forms, annotations, attachments, bookmarks, scripts, tagged structures and signatures are rejected, rather than silently discarded. Input PDFs are not rendered by lopdf. PDFium remains a separate required rendering adapter; structural reopening is not evidence of appearance fidelity. No rasterization is used for page manipulation.

## ADR 003 — Compression
Fixed output dimensions, exhaustive bounded descending JPEG quality search (100 through user minimum). Every candidate is encoded from one prepared source. First valid result has the highest tested quality; no monotonicity assumption. PNG uses lossless encoding only and reports infeasibility. KiB UI limits use strict below; core supports KB/KiB and inclusive limits. Transparent-to-JPEG conversion requires explicit consent. ICC-profile inputs are rejected pending colour-managed conversion; metadata removal is not represented as colour conversion.

## ADR 004 — Shipping evidence
The full user specification remains the target. An implemented core function is not a shipped UI feature. Native build, device, visual correctness, malicious-document resource isolation and representative-user validation are separate gates. Unsupported features do not appear as functional controls. No network processing, accounts or monetization. Dependency downloads occur during development only.

## ADR 005 — Resource ownership
One processing worker at a time. Input images: 64 MiB encoded, 24 megapixels, 12000 pixels per axis, decoder allocation limit. PDFs: 64 MiB and 200 pages; lopdf parsing still requires process-level isolation before hostile-input production readiness can be claimed. Batch results retain successes. JPEG cancellation can occur between candidates; other engines at stage boundaries. No fake progress percentages.

## ADR 006 — PDFium initialization and rendering
PDFium adapter uses pdfium-render 0.9.4 and a non-V8/non-XFA Linux PDFium 8076 binary. The bindings are process-global in this wrapper version. Initial load uses an explicit packaged path (or explicit developer override); later instances reuse existing bindings. A global mutex serializes all PDFium calls, including direct core calls. Preview bitmaps are bounded to 2048 pixels per side. Source PDFs pass the conservative structural gate before rendering. Reorder tests compare rendered PNG bytes, not only page counts. Native binary provenance, SHA-256 and upstream build notices are included. Other platform binaries remain unverified.

## ADR 007 — Local persistence and provider export
SQLite uses bundled rusqlite 0.40.2, versioned transactional migrations, parameterized queries, strict settings schemas, and history disabled by default. Recipe storage validates schema and step order before saving. No document content or source paths enter the database. The interface currently persists theme and can clear history; opt-in recording UI is not yet enabled.
Android export source uses ACTION_CREATE_DOCUMENT, writes on one I/O worker, reopens the content URI and verifies length plus SHA-256. It reports unverified/partial provider writes truthfully and does not silently delete them. This adapter has not yet passed Android build/device validation. Desktop export retains atomic non-clobber behavior.
