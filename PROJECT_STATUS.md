# Universal Studio Toolkit — active development

Updated2026-10-20. Working development builds exist for Windows x64, Linux x64 and Android ARM64. The full requested product is not launch-complete.

- Integrated source7750582 passes Windows39403577707, Linux39403577913, Android39403577374, bridge39403577509 and notice39403577612 workflows. It includes scanner correction/manual straightening, verified native packaging and pack/signature first-use recovery. Local73 Rust/41 Flutter checks pass;12 additional workflows pass using the actual extracted Linux release libraries and bundled OCR models.
- All four current session installers are independently inspected: archive/checksum/notice/font/native inventories, Windows CRT, Linux OCR models, Android signatures/privacy/alignment, desktop startup and actual Linux package processing. Updating persistent copies was blocked before transfer by file-service authorization; earlier saved versions remain unchanged.
- Flexible compression candidate24eb562 on work/flexible-photo passes76 Rust/43 Flutter checks locally, including actual bounded-dimension JPEG/PNG/recipe exports. Its platform verification/integration remains pending; the7750582 installers do not include it.
- Linux English/Bangla/mixed OCR works with separately verified local models and system Tesseract. Windows/Android recognition and searchable PDFs remain unavailable.
- No clean-device compatibility, representative-user usability, screen-reader acceptance, complete license clearance or production-readiness claim.

The full checklist, platform matrix, phase plan, known limitations and precise next action are in docs/REQUIREMENTS.md, STATUS.md, PLAN.md, LIMITATIONS.md and CHECKPOINT.md. The first-use review is heuristic and explicitly leaves real-user validation outstanding.

Remaining major scope: custom pack slots/managed studio sources; flexible compression/direct crop/face assistance/manual signature masks/storage/PDF placement; PDF forms/searchable export/image and raster compression; platform-complete OCR; isolation/cleanup; localization/accessibility/users/clean devices/printers; AppImage and private production signing. Deferred redaction/encryption/certificate signing/Word/cloud/payment capabilities stay outside functional controls.
