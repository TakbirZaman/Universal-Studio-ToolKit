# Feature / platform status — 2026-10-18

This is working development software, not a completed launch. The full target remains in REQUIREMENTS.md. “Built” means the stated build-host checks passed, not clean-device or interactive acceptance.

Main 10d46cc includes sequential scans, bounded canonical previews, physical photo DPI, custom print-sheet layouts and streamed image encoding. Windows, Linux and Android packaging workflows passed. Saved downloads were independently verified; see evidence/development-builds-10d46cc.json. PDF overlays are a separate candidate, not included in these packages.

| Capability | Core/interface evidence | Linux | Windows | Android |
|---|---|---|---|---|
| JPEG/PNG resize, compression and EXIF | Actual dimensions/bytes, orientation1–8 and same-source quality search tested | Native/UI checks pass | Native/interface gates pass | APK builds; device behavior pending |
| Physical mm/DPI photo size | JPEG JFIF/PNG pHYs, pixel rounding, 16-bit/alpha and independent Pillow checks; real result UI tested | Packaged main 10d | Packaged main 10d | Packaged main 10d; device/printer pending |
| Fit/fill, rotate, numeric recipe crop/flip | Processing tests; basic controls and recipe editor | Implemented | Built | Built, device pending |
| Flexible dimensions / direct crop gestures / face suggestions | Remaining | Unavailable | Unavailable | Unavailable |
| Threshold signature cleanup and PNG backgrounds | Actual transparent pixels plus checkerboard/light/dark preview | Implemented | Built | Built, device pending |
| Manual signature mask/storage/PDF placement | Remaining | Unavailable | Unavailable | Unavailable |
| Supported PDF merge/select/delete/reorder/rotate | Reopen, page order/rotation, text and PDFium appearance checks | Implemented | Native/interface gates pass | Built, device pending |
| PDFium preview / page PNG ZIP | Bounded render adapter, real page appearance tests | Bundled | Bundled | Audited ARM64 library staged; device pending |
| Lossless PDF structure optimization | Preserves text/pixels, never rasterizes, returns original if no reduction | Implemented | Native/interface gates pass | Built, device pending |
| Watermarks/numbers/forms/signature/searchable PDF and image/raster compression modes | Remaining; unsupported structures rejected | Unavailable | Unavailable | Unavailable |
| Scan modes, rotation, brightness/contrast and advisory quality checks | Native tests; non-destructive edits/drafts | Implemented | Built | Compiled system-camera/manual import; device pending |
| Sequential scan PDF and canonical previews | Bounded encoded intermediates, real three-page UI/PDF/save checks at desktop and narrow/200% text | Main build/startup passed | Main build/startup passed | Main complete packaging workflow passed |
| Manual corners / perspective / deskew / OpenCV | Remaining | Unavailable | Unavailable | Unavailable |
| Camera capture and URI export | Scoped adapters and channel contracts | Image import; camera unavailable | Image import; camera unavailable | APK compiles; permissions/cancellation/recreation/provider testing pending |
| Local scan drafts and retention | Save/restore/delete/clear, schema/hash and symlink protections tested | Implemented | Storage tests pass | Built, device pending |
| English/Bangla/mixed printed OCR | Real engine/typed job cancellation, editable editor and verified UTF-8 export | Requires system Tesseract and pinned local models | Recognition unavailable | Recognition unavailable |
| Print sheets | Standard/custom paper, physical layout, guides, optional DPI, capacity/aspect and independently reopened PDF tested locally | Main packaging passed | Main packaging passed | Main packaged; device pending |
| Print-sheet actual-size instruction / recovery | Native workflow tests at desktop and 390px/200%; field errors open advanced settings | Tested locally | Main packaging passed | Device/printer acceptance pending |
| Application pack | Fixed example photo/signature/certificate ZIP; actual report/manifest/hash validation | Implemented example | Built | Built, device pending |
| Editable pack slots and managed studio references | Remaining | Unavailable | Unavailable | Unavailable |
| Recipes/batches/settings | Schema/order/path safety, persistence/import/export, item results/retry, opt-in storage tests | Implemented | Native/interface gates pass | Built, device pending |
| Save copies / Unicode names | No-clobber, staged/read-back verification, Bangla names; additional Windows reserved names fixed locally | Tested | Runtime/clean-system pending | SAF adapter compiled; provider/device pending |
| Accessibility and usability | Goal search, text labels, keyboard shortcuts, contrast tests, responsive tokens; two real scanner/photo workflow layouts | Heuristic/widget evidence | Build-host only | Device/screen-reader/first-use observation pending |

## Current checks and practical limits

Local final integration: 57 Rust tests, 27 selected Flutter tests, clean analysis/formatting. Scanner tests compare actual generated PDF page pixels and save a Bangla-named copy; bundled-font captures are local inspection, not approved golden baselines or user observation. The ten-second discoverability target is unmeasured.

Android backup/signing repair 6629bbe passed run 39163380699: compiled backup opt-out, all app-data exclusions, actual release permissions, signatures and ZIP/ELF 16 KiB checks. The optimized release-mode APK uses a disposable development identity. This is not private production signing or an OEM transport test.

All 256 locked dependency records and 471 retained notice references verify before packaging. Integrity is not complete native/transitive license-obligation clearance. OCR model/license, font and Microsoft CRT provenance are separate retained records.

Linux runtime/startup evidence is Ubuntu 24.04 x64; Windows is a windows-2022 x64 build host. Neither is clean-system certification. Android is ARM64/API 24+, with no actual camera/SAF/device acceptance. Linux OCR uses separately installed /usr/bin/tesseract; Windows/Android OCR remains unavailable. No searchable PDF, perfect OCR, passport acceptance, universal compatibility, physical secure erasure or commercial feature-parity claim.

Major production gates remain: PDF worker isolation, orphan-job cleanup, full license review, broader interoperability/colour management, localization and assistive-technology checks, representative users, clean devices, AppImage and private production signing. See LIMITATIONS.md.

## Saved integration checkpoint 10d46cc

All main workflows passed: Linux 39167712992, Windows 39167713030 and Android 39167713009. Four saved downloads independently verify against evidence/development-builds-10d46cc.json, including all 471 retained notices, native inventory, OCR/font assets, Windows runtime inventory, Android signatures, compiled privacy settings and 16 KiB alignment. These are build-host/startup checks, not clean-device acceptance.

Custom print sheets passed independent pypdf/Pillow/Poppler verification (actual paper and placement dimensions, cutting guides, image pixels and non-overwrite behavior). Streamed image encoders passed same-source compression and exact byte-budget tests. See ADR-012/013. Actual printer acceptance remains unverified.
