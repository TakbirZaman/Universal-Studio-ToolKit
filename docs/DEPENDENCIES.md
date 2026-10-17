# Dependency decisions and license gate

Primary references checked on 2026-10-15:
- https://docs.rs/image/0.25.10/image/ — image decoder limits and orientation API. image is MIT OR Apache-2.0. JPEG/PNG only enabled.
- https://docs.rs/lopdf/0.38.0/lopdf/ — selected pinned PDF manipulation library, MIT. Newer 0.45 release was available; migration is a separate compatibility decision.
- https://cjycode.com/flutter_rust_bridge/quickstart — generation/integration workflow, version 2.13.0 pinned in both languages.
- https://pub.dev/packages/flutter_riverpod/versions — 3.4.3 stable.
- https://pub.dev/packages/file_selector/versions — 1.1.0, BSD-3-Clause. Platform support does not mean every operation is available on every platform.

Cargo.lock and pubspec.lock are the authoritative resolved versions. Run scripts/collect_notices.py after dependency changes. It copies actual license/notice files and inventories direct and transitive packages. Missing files or unreviewed terms block release claims. Development compiler/code-generator dependencies are separate from redistributed runtime dependencies; the inventory is intentionally conservative.

No third-party photos or face models are bundled. The Linux OCR build stages only explicitly fetched, checksum-verified English/Bangla tessdata_fast models with Apache-2.0 LICENSE and provenance; see OCR-ASSETS.md. Roboto regular/bold and Material icons are bundled with their SDK license texts. Flutter Material icons are from Flutter's SDK; include SDK notices. Unmodified Noto Sans Bengali is bundled separately under SIL OFL 1.1 with its copyright, full license and source/hash provenance. Windows/Android fallback appearance and Bangla glyph availability still require device validation. Do not assume model or language-pack redistribution rights from download availability.

PDFium Linux 8076 is bundled with provenance, SHA-256 and its complete upstream build-license folder; rusqlite 0.40.2 bundles SQLite. Review the refreshed transitive inventory. OpenCV and the Tesseract engine are not bundled; engine redistribution and native transitive audits remain required. OCR model licensing is audited separately from the engine and font. Poppler/Pillow/pypdf are verification tools in the development environment, not redistributed application libraries.
