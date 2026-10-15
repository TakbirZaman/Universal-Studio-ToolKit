# Universal Studio Toolkit — active development

This is working software under development, not a completed production release.

- 24 Rust tests passed; PDFium pixel comparisons cover page reorder and lossless optimization.
- Eight Flutter tests passed, including native bridge processing, home layouts and batch retry/cancellation.
- Dart analyzer: no issues.
- Android ARM64 Rust release built; APK packaging/device testing pending.
- Existing Linux bundle predates the recovered recipe interface.

See docs/REQUIREMENTS.md, docs/STATUS.md, docs/LIMITATIONS.md and docs/RECOVERY.md for remaining scope and exact next actions. Camera, OCR, draft recovery, advanced PDF tools and complete platform packaging remain unfinished.

Automatic approval review held some synthetic binary outputs and golden images from upload because it could not verify the opaque contents. Generating source is available; fresh-checkout golden checks remain dependent on restoring the held baselines. No completion claim depends on missing assets.
