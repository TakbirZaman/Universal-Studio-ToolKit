# Feature / platform status — 2026-10-18

This is working development software, not a completed launch. The full target remains in REQUIREMENTS.md. “Built” means the stated build-host checks passed, not clean-device or interactive acceptance.

Main 28163d4 includes physical photo sizing, offline Linux OCR and notice provenance. Its independently verified, saved Windows/Linux/Android downloads are described in evidence/development-builds-28163d4.json. Scanner candidate 3276e3c adds sequential preparation, validated bounded previews and Android backup-policy protection; see CHECKPOINT.md for the current integration/build state.

| Capability | Core/interface evidence | Linux | Windows | Android |
|---|---|---|---|---|
| JPEG/PNG resize, compression and EXIF | Actual dimensions/bytes, orientation1–8 and same-source quality search tested | Native/UI checks pass | Native/interface gates pass | APK builds; device behavior pending |
| Physical mm/DPI photo size | JPEG JFIF/PNG pHYs, pixel rounding, 16-bit/alpha and independent Pillow checks; real result UI tested | Packaged main 281 | Packaged main 281 | Packaged main 281; device/printer pending |
| Fit/fill, rotate, numeric recipe crop/flip | Processing tests; basic controls and recipe editor | Implemented | Built | Built, device pending |
| Flexible dimensions / direct crop gestures / face suggestions | Remaining | Unavailable | Unavailable | Unavailable |
| Threshold signature cleanup and PNG backgrounds | Actual transparent pixels plus checkerboard/light/dark preview | Implemented | Built | Built, device pending |
| Manual signature mask/storage/PDF placement | Remaining | Unavailable | Unavailable | Unavailable |
| Supported PDF merge/select/delete/reorder/rotate | Reopen, page order/rotation, text and PDFium appearance checks | Implemented | Native/interface gates pass | Built, device pending |
| PDFium preview / page PNG ZIP | Bounded render adapter, real page appearance tests | Bundled | Bundled | Audited ARM64 library staged; device pending |
| Lossless PDF structure optimization | Preserves text/pixels, never rasterizes, returns original if no reduction | Implemented | Native/interface gates pass | Built, device pending |
| Watermarks/numbers/forms/signature/searchable PDF and image/raster compression modes | Remaining; unsupported structures rejected | Unavailable | Unavailable | Unavailable |
| Scan modes, rotation, brightness/contrast and advisory quality checks | Native tests; non-destructive edits/drafts | Implemented | Built | Compiled system-camera/manual import; device pending |
| Sequential scan PDF and canonical previews | Candidate: bounded encoded intermediates, real three-page UI/PDF/save checks at desktop and narrow/200% text | Candidate build/startup passed | Candidate build/startup passed | Candidate complete packaging workflow passed |
| Manual corners / perspective / deskew / OpenCV | Remaining | Unavailable | Unavailable | Unavailable |
| Camera capture and URI export | Scoped adapters and channel contracts | Image import; camera unavailable | Image import; camera unavailable | APK compiles; permissions/cancellation/recreation/provider testing pending |
| Local scan drafts and retention | Save/restore/delete/clear, schema/hash and symlink protections tested | Implemented | Storage tests pass | Built, device pending |
| English/Bangla/mixed printed OCR | Real engine/typed job cancellation, editable editor and verified UTF-8 export | Requires system Tesseract and pinned local models | Recognition unavailable | Recognition unavailable |
| Print sheets | Standard/custom paper, physical layout, guides, optional DPI, capacity/aspect and independently reopened PDF tested locally | New candidate; packaging pending | New candidate; packaging pending | New candidate; device pending |
| Print-sheet actual-size instruction / recovery | Native workflow tests at desktop and 390px/200%; field errors open advanced settings | Tested locally | Packaging pending | Device/printer acceptance pending |
| Application pack | Fixed example photo/signature/certificate ZIP; actual report/manifest/hash validation | Implemented example | Built | Built, device pending |
| Editable pack slots and managed studio references | Remaining | Unavailable | Unavailable | Unavailable |
| Recipes/batches/settings | Schema/order/path safety, persistence/import/export, item results/retry, opt-in storage tests | Implemented | Native/interface gates pass | Built, device pending |
| Save copies / Unicode names | No-clobber, staged/read-back verification, Bangla names; additional Windows reserved names fixed locally | Tested | Runtime/clean-system pending | SAF adapter compiled; provider/device pending |
| Accessibility and usability | Goal search, text labels, keyboard shortcuts, contrast tests, responsive tokens; two real scanner/photo workflow layouts | Heuristic/widget evidence | Build-host only | Device/screen-reader/first-use observation pending |

## Current checks and practical limits

Local final integration: 48 Rust tests, 25 selected Flutter tests, clean analysis/formatting. Scanner tests compare actual generated PDF page pixels and save a Bangla-named copy; bundled-font captures are local inspection, not approved golden baselines or user observation. The ten-second discoverability target is unmeasured.

Android backup/signing repair 6629bbe passed run 39163380699: compiled backup opt-out, all app-data exclusions, actual release permissions, signatures and ZIP/ELF 16 KiB checks. The optimized release-mode APK uses a disposable development identity. This is not private production signing or an OEM transport test.

All 256 locked dependency records and 471 retained notice references verify before packaging. Integrity is not complete native/transitive license-obligation clearance. OCR model/license, font and Microsoft CRT provenance are separate retained records.

Linux runtime/startup evidence is Ubuntu 24.04 x64; Windows is a windows-2022 x64 build host. Neither is clean-system certification. Android is ARM64/API 24+, with no actual camera/SAF/device acceptance. Linux OCR uses separately installed /usr/bin/tesseract; Windows/Android OCR remains unavailable. No searchable PDF, perfect OCR, passport acceptance, universal compatibility, physical secure erasure or commercial feature-parity claim.

Major production gates remain: PDF worker isolation, orphan-job cleanup, full license review, broader interoperability/colour management, localization and assistive-technology checks, representative users, clean devices, AppImage and private production signing. See LIMITATIONS.md.

## Saved integration checkpoint 27c8b3d

All main workflows passed: Linux 39164619821, Windows 39164619702, Android 39164619794 and bridge 39164619682. Sequential scanner preparation, bounded canonical previews, Android local-data backup policy/development signing and portable Windows names are included. The four saved downloads (including the optimized Android development release) independently verify against evidence/development-builds-27c8b3d.json. The new custom print-sheet candidate remains on work/print-layout and is not yet in these packages.

Custom print-sheet candidate: 52 Rust tests and 27 selected Flutter tests pass, with clean analysis. Independent pypdf/Poppler verification checks actual 120 × 90 mm paper, nine 30 × 20 mm placements, 72 cutting segments, resampled image dimensions and non-overwrite/failure behavior. Actual printer acceptance remains unverified. See ADR-012 and evidence/custom-print-20261018.json.
