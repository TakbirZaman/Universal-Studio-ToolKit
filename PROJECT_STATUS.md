# Universal Studio Toolkit — active development

Updated 2026-10-16. Working development builds exist for Windows x64, Linux x64 and Android ARM64. The full requested product is not launch-complete.

- Windows: release portable ZIP built, native bridge tests passed, required MSVC release CRT bundled; packaged app created a window and survived the eight-second CI startup check.
- Linux: 24 Rust tests, Flutter behavioral/native tests, analysis, release build and dependency resolution passed on Ubuntu 24.04 x64.
- Android: debug-signed installable APK and unsigned release APK built. ARM64-only contents, APK signatures, ZIP/ELF 16 KiB alignment and required native libraries checked. Device behavior is unverified.
- Recovered scan drafts, recipe/batch controls and transparency previews passed hosted verification. Draft cleanup improvements are entering verification separately.
- No clean-device compatibility, representative usability, complete license clearance or production-readiness claim.

See docs/STATUS.md, docs/CHECKPOINT.md, docs/REQUIREMENTS.md and docs/LIMITATIONS.md. Exact build identifiers and download hashes are in docs/evidence/development-builds-20261016.json.

Automatic approval review held some synthetic binary outputs and golden images from upload because their opaque contents could not be verified. Visual capture is not baseline regression testing; no completion claim depends on those held assets.
