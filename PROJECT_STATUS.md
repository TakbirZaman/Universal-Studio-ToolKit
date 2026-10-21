# Universal Studio Toolkit — active development

Verified integration 2026-10-21 (Asia/Dhaka). Windows x64, Linux x64 and Android ARM64 development builds are verified. The full requested product is not launch-complete.

Integrated source fe9740d9be4dc728b19a63b25b2f0233dd7d9ce7 contains flexible compression, saved-copy actions, custom application packs, bounded session document reuse and visual photo cropping. Feature source f13fb3dc0aee0513b9610f0ddf0764c96abda2a1 passed all seven workflows: Windows 39646610524, Linux 39646610381, Android 39646610724, bridge 39646610682, notices 39646610530, custom-pack 39646610539 and crop 39646610541.

Application packs support required/optional JPEG/PNG/PDF slots, safe filenames, exact image pixels, strict KiB and PDF page limits, source review/replacement, preset JSON import/export and verified ZIP manifests/reports. Explicit session retention is bounded to 16 items/64 MiB and includes remove/clear controls. Visual cropping adds draggable full-size edge targets, selection movement, aspect locks, exact corrected-original coordinates, bounded undo and keyboard controls, with source handoff from Photo Studio into recipes.

Provisioned native suites pass 84 Linux/82 Windows tests. Focused crop verification passes 2 native pixel/orientation tests and 6 Flutter geometry/UI checks; focused pack verification passes 6 native tests and 5 Flutter checks. Actual-output journeys run at 100%/200% text and verify saved dimensions, ZIPs, import/export and recovery. Regenerated bridge sources match committed bindings and analysis is clean. See ADR022–023 and docs/evidence.

Remaining scope: advanced signature/photo/PDF tools; Windows/Android OCR and searchable PDFs; persistent managed sources and selective retries; localization/accessibility/representative users/real devices; isolation/cleanup; complete redistribution obligations, AppImage/printers and private production signing. Exact work is retained in docs/REMAINING-WORK.md and REQUIREMENTS.md. Current artifacts are development builds; no full launch or durable replacement of older delivered installers is claimed.
