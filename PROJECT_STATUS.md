# Universal Studio Toolkit — active development

Updated 2026-10-16. Working development builds exist for Windows x64, Linux x64 and Android ARM64. The full requested product is not launch-complete.

- Windows: release portable ZIP built, native bridge tests passed, required MSVC release CRT bundled; packaged app created a window and survived the eight-second CI startup check.
- Linux: 27 Rust tests, Flutter behavioral/native tests, analysis, release build and dependency resolution passed on Ubuntu 24.04 x64.
- Android: debug-signed installable APK and unsigned release APK built. ARM64-only contents, APK signatures, ZIP/ELF 16 KiB alignment and required native libraries checked. Device behavior is unverified.
- Recovered scan drafts, recipe/batch controls and transparency previews passed hosted verification. Draft cleanup and Android manual capture compiled and passed their hosted checks; device camera acceptance remains open.
- No clean-device compatibility, representative usability, complete license clearance or production-readiness claim.

See docs/STATUS.md, docs/CHECKPOINT.md, docs/REQUIREMENTS.md and docs/LIMITATIONS.md. Exact build identifiers and download hashes are in docs/evidence/development-builds-98dbeac.json.

Automatic approval review held some synthetic binary outputs and golden images from upload because their opaque contents could not be verified. Visual capture is not baseline regression testing; no completion claim depends on those held assets.

Latest app checkpoint 98dbeac passed Linux run 38943392106, Windows run 38943392637 and Android run 38943392331. Experimental OCR work is isolated on work/offline-ocr; it is not in these GUI downloads. See docs/CHECKPOINT.md for the exact next action and remaining scope.

Experimental OCR commit e467093 passed its hosted Linux/Windows boundary checks (run 38948658931) and 32 local Rust tests. Real English/Bangla/mixed CLI checks passed. This does not establish Flutter OCR or Windows/Android recognition support.
