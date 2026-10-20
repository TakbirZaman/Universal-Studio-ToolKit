# Feature / platform status — 2026-10-20

This is working development software, not a completed launch. The full target remains in REQUIREMENTS.md. “Built” means the stated build-host checks passed, not clean-device or interactive acceptance.

Integrated main runtime7750582 includes scanner correction/manual straightening and pack/signature first-use recovery alongside earlier photo/print/PDF/OCR workflows. All five platform/bridge/notice workflows pass; local73 Rust/41 Flutter checks and12 actual extracted-Linux-release workflow checks pass. All four current session installers are independently verified. Persistent replacement was blocked by file-service authorization before transfer; earlier saved copies remain unchanged. Flexible recipe candidate24eb562 on work/flexible-photo has76 Rust/43 Flutter local checks but awaits its own platform verification/integration; it is not in7750582 installers. Historical evidence remains in the evidence directory.

| Capability | Core/interface evidence | Linux | Windows | Android |
|---|---|---|---|---|
| JPEG/PNG resize, compression and EXIF | Actual dimensions/bytes, orientation1–8 and same-source quality search tested | Native/UI checks pass | Native/interface gates pass | APK builds; device behavior pending |
| Physical mm/DPI photo size | JPEG JFIF/PNG pHYs, pixel rounding, 16-bit/alpha and independent Pillow checks; real result UI tested | Packaged main 10d | Packaged main 10d | Packaged main 10d; device/printer pending |
| Fit/fill, rotate, numeric recipe crop/flip | Processing tests; basic controls and recipe editor | Implemented | Built | Built, device pending |
| Flexible recipe dimensions | Candidate24eb562: explicit bounds, actual-byte search and local exports verified; not in main775 packages | Local candidate | Candidate build pending | Candidate/device pending |
| Direct crop gestures / face suggestions | Remaining | Unavailable | Unavailable | Unavailable |
| Threshold signature cleanup and PNG backgrounds | Actual transparent pixels plus checkerboard/light/dark preview | Implemented | Built | Built, device pending |
| Manual signature mask/storage/PDF placement | Remaining | Unavailable | Unavailable | Unavailable |
| Supported PDF merge/select/delete/reorder/rotate | Reopen, page order/rotation, text and PDFium appearance checks | Implemented | Native/interface gates pass | Built, device pending |
| PDFium preview / page PNG ZIP | Bounded render adapter, real page appearance tests | Bundled | Bundled | Audited ARM64 library staged; device pending |
| Lossless PDF structure optimization | Preserves text/pixels, never rasterizes, returns original if no reduction | Implemented | Native/interface gates pass | Built, device pending |
| Visible PDF page numbers / ASCII watermarks | Five focused native tests, independent saved-PDF checks, real desktop/narrow UI/save tests; all platform packaging passed | Implemented / startup checked | Built / startup checked | APK built; device pending |
| Existing PDF text → editable UTF-8 | Actual PDFium extraction, Unicode save, blank-scan recovery and independent English/Bangla output;66 Rust/32 Flutter tests overall | Implemented / built | Native/UI checks and build passed | APK built; device pending |
| Forms/signature/searchable PDF and image/raster compression modes | Remaining; unsupported structures rejected | Unavailable | Unavailable | Unavailable |
| Scan modes, rotation, brightness/contrast and advisory quality checks | Native tests; non-destructive edits/drafts | Implemented | Built | Compiled system-camera/manual import; device pending |
| Sequential scan PDF and canonical previews | Bounded encoded intermediates, real three-page UI/PDF/save checks at desktop and narrow/200% text | Main build/startup passed | Main build/startup passed | Main complete packaging workflow passed |
| Page corners / perspective / edge suggestions | Typed Rust adapter/editor/drafts and actual outputs; sourceffc4753 platform packages pass | Native/UI/package/startup checks | Native/UI/package/startup checks | ARM64 package passes; actual device pending |
| Manual straightening / face assistance | Manual straightening actual-output/responsive checks and sourceffc4753 builds pass; automatic angle detection/face assistance remain | Manual correction built | Manual correction built | Manual correction built; device pending |
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

Local final integration: 66 Rust tests, 32 selected Flutter tests, clean analysis/formatting. Scanner tests compare actual generated PDF page pixels and save a Bangla-named copy; bundled-font captures are local inspection, not approved golden baselines or user observation. The ten-second discoverability target is unmeasured.

Android backup/signing repair 6629bbe passed run 39163380699: compiled backup opt-out, all app-data exclusions, actual release permissions, signatures and ZIP/ELF 16 KiB checks. The optimized release-mode APK uses a disposable development identity. This is not private production signing or an OEM transport test.

All 256 locked dependency records and 471 retained notice references verify before packaging. Integrity is not complete native/transitive license-obligation clearance. OCR model/license, font and Microsoft CRT provenance are separate retained records.

Linux runtime/startup evidence is Ubuntu 24.04 x64; Windows is a windows-2022 x64 build host. Neither is clean-system certification. Android is ARM64/API 24+, with no actual camera/SAF/device acceptance. Linux OCR uses separately installed /usr/bin/tesseract; Windows/Android OCR remains unavailable. No searchable PDF, perfect OCR, passport acceptance, universal compatibility, physical secure erasure or commercial feature-parity claim.

Major production gates remain: PDF worker isolation, orphan-job cleanup, full license review, broader interoperability/colour management, localization and assistive-technology checks, representative users, clean devices, AppImage and private production signing. See LIMITATIONS.md.

## Historical integration checkpoint 10d46cc

All main workflows passed: Linux 39167712992, Windows 39167713030 and Android 39167713009. Four saved downloads independently verify against evidence/development-builds-10d46cc.json, including all 471 retained notices, native inventory, OCR/font assets, Windows runtime inventory, Android signatures, compiled privacy settings and 16 KiB alignment. These are build-host/startup checks, not clean-device acceptance.

Custom print sheets passed independent pypdf/Pillow/Poppler verification (actual paper and placement dimensions, cutting guides, image pixels and non-overwrite behavior). Streamed image encoders passed same-source compression and exact byte-budget tests. See ADR-012/013. Actual printer acceptance remains unverified.

## Integrated PDF overlay slice

Runtime source1a657f6 passed Linux39251795389, Windows39251795282 and Android39251795377. All 62 Rust and 29 selected Flutter tests pass, with clean analysis. Independent pypdf/Poppler output and desktop package checks pass. Page numbers follow the final saved order; visible ASCII watermark labels preserve original text/resources and account for crop/rotation/unit geometry. See ADR-014.

## Integrated existing PDF text slice

Runtime candidate 0d7d7a6 passed Linux39253689705, Windows39253689586 and Android39253689489. All 66 Rust/32 selected Flutter tests and clean analysis pass. Independent pypdf/PDFium verification extracts English/Bangla text in page order and checks actual saved bytes, original preservation and no-clobber behavior. Local visual review and focused recheck verify help/error wrapping at 200% text. See ADR-015. All four saved downloads pass independent CRC/hash,471-notice, font/native/CRT/model inventory checks; Android compiled privacy, signatures and 16 KiB alignment also verify. Actual devices/users remain outstanding.

## Scanner geometry development candidate

work/scan-perspective adds normalized validated corners, a lazy serialized OpenCV adapter, shared corrected preview/image/PDF processing, schema2 drafts with schema1 recovery, a responsive numbered corner editor, manual/keyboard/slider edits, undo/reset and advisory edge suggestions requiring application. All70 Rust and35 selected Flutter tests pass locally, including actual Unicode save/no-clobber and desktop/narrow-dark200% workflows. A no-op contrast quantization defect found by exact-pixel tests is fixed. Image decoding readiness, full48px boundary hit areas, selected-number contrast and a reachable primary action were visually reviewed and corrected. This is heuristic/widget evidence, not observed-user or screen-reader acceptance.

Native Linux/Windows source build and independent pixel verification pass in run39312606313 at1f7d49e. Windows build-host evidence is not clean-system or packaged-app acceptance. Internal OpenCV threading is explicitly disabled; Rust serializes every adapter call. Reconfiguring an older SDK cache additionally requires HAVE_PTHREAD=OFF. The Linux final rebuild and native/regression evidence are tracked separately in CHECKPOINT.md. Android native geometry, app-library staging, complete native license applicability review and updated downloads remain outstanding.153 conservative candidate notice texts, including the separately fetched/hashed Boost1.0 license referenced by FLANN, are retained. Integrity/provenance does not establish complete license clearance.

Candidate959f220: all three native-build jobs pass run39313941003. Android is ARM64/API24+, exported symbols and16KiB ELF alignment checked, system dependencies only; no Android pixel execution/device claim. Bridge39313941095 artifact12216318217 SHA8331fa99e207538a390e14d6ba44271e9e7e71e7159ea26f3f3f9c9d25180788 passes CRC/fixed-nine-file allowlist and matches every committed generated file. App packaging/staging remains separate. A full upstream source file is retained in addition to153 notice/license files.

### Native scanner packaging candidate — 2026-10-20

The scanner correction/editor integration is committed on work/scan-perspective. Prior local verification:70 Rust tests and35 Flutter tests with actual engines. Application CI at d828067 succeeds on Linux/Windows/Android, but these packages omit the native scanner library and must not be described as geometry-enabled. Native audit39314977313 passes separately on all three build hosts, with Android compile/ELF checks only.

The next candidate adds explicit library/report/hash/architecture/notice validation and staging to all three package scripts. Source provisioning is development-only. Native tests now skip explicitly by default and application CI provisions the engine and includes them. Fresh candidate tests/build results must be recorded before delivery. Full scope and device/user/license release gates remain incomplete.

### Manual straightening candidate — 2026-10-20

The corner editor offers a collapsed manual straightening adjustment (±10°), cropping explanation, preview and undo. Portrait/landscape/square aspect checks and actual tilted-line Flutter→Rust→OpenCV→PNG verification pass; desktop/narrow-dark200% workflows exercise adjustment and undo with actual PDF save. Small native previews no longer enlarge the source. See ADR018. No automatic angle detection or Android device claim is made. This feature is not in the older saved downloads.

### Pack/signature first-use recovery candidate — 2026-10-20

The fixed example pack now supports replacing a selected document without clearing the others, cancellation recovery, role labels and actual original-source previews. Native errors name the affected slot, results list verified archived filenames/measurements, and save errors appear beside Save. Four focused actual export workflows pass at desktop/narrow dark200%, including Unicode/no-clobber ZIP save and transparent PNG; independent ZIP/Pillow/pypdf checks pass. A narrow signature-background dropdown overflow was fixed. This does not implement custom/optional slot definitions or managed sources. See ADR019 and the explicitly heuristic FIRST-USE-REVIEW-20261020.

### Approved flexible compression candidate —2026-10-20

Version3 photo recipes support explicit flexible minimum/maximum dimensions with required limits. Core JPEG/PNG/quality/bounds/cancellation/recipe checks pass; actual desktop and narrow-dark200% recipe/export workflows produce independently verified136×102 JPEGs at8029 bytes below8KiB. Fixed dimensions remain default; unsampled larger sizes may also fit. Full local checks pass76 Rust/43 Flutter tests and clean analysis. This is a candidate, separate from integrated main7750582 packages (73 Rust/41 Flutter). No extra API dependency, asset or generated binding change is introduced. Platform packaging remains pending; direct crop/face assistance and remaining scope are unchanged.
