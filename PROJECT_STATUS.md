# Universal Studio Toolkit — active development

Updated2026-10-20. Working development builds exist for Windows x64, Linux x64 and Android ARM64. The full requested product is not launch-complete.

- Scanner geometry and manual straightening sourceffc4753 passes all three platform builds: Linux39401787599, Windows39401787571 and Android39401787595. The source has71 Rust/37 Flutter checks; actual platform packages still require per-artifact delivery inspection. Android device behavior remains unverified.
- Subsequent pack/signature recovery changes pass73 Rust and41 Flutter tests locally with clean analysis. They add individual slot replacement/cancel recovery, real source previews, measured ZIP-entry feedback, document-specific errors, inline save recovery and a narrow200% preview fix. Integration platform builds must pass before these are called packaged.
- Independently inspected scanner-enabled baseline6d7d6f9 passes all three package workflows, archive/checksum/notice/native checks, desktop startup and Android signatures/privacy/alignment. Session downloads are available. Updating saved copies was blocked before transfer by file-service authorization; prior saved versions remain unchanged.
- Linux English/Bangla/mixed OCR works with separately verified local models and system Tesseract. Windows/Android recognition and searchable PDFs remain unavailable.
- No clean-device compatibility, representative-user usability, screen-reader acceptance, complete license clearance or production-readiness claim.

The full checklist, platform matrix, phase plan, known limitations and precise next action are in docs/REQUIREMENTS.md, STATUS.md, PLAN.md, LIMITATIONS.md and CHECKPOINT.md. The first-use review is heuristic and explicitly leaves real-user validation outstanding.

Remaining major scope: custom pack slots/managed studio sources; flexible compression/direct crop/face assistance/manual signature masks/storage/PDF placement; PDF forms/searchable export/image and raster compression; platform-complete OCR; isolation/cleanup; localization/accessibility/users/clean devices/printers; AppImage and private production signing. Deferred redaction/encryption/certificate signing/Word/cloud/payment capabilities stay outside functional controls.
