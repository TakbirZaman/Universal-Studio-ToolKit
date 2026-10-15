# Universal Studio Toolkit — development checkpoint

Source implementation is in active development, not a complete production release.

Fresh verification: 24 Rust tests passed; Linux host Rust and Android ARM64 Rust release builds succeeded. Flutter checks need rerunning after dependency setup; the official font-subset download returned proxy HTTP 403 in this environment. The existing Linux bundle predates the recovered recipe interface.

See docs/REQUIREMENTS.md, docs/STATUS.md, docs/LIMITATIONS.md and docs/RECOVERY.md. Camera, OCR, scan drafts, advanced PDF tools and complete platform packaging remain unfinished.

Some generated test-output and golden-image uploads were held by automatic approval review because it could not establish that opaque binary content was non-sensitive. Their synthetic generators remain in rust/examples and test/; missing files must be regenerated or inspected and approved before relying on the corresponding checks.
