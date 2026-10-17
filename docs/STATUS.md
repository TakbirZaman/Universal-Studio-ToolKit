# Feature / platform status

Updated 2026-10-17. This is an implementation in progress, not launch completion.

| Capability | Rust Linux evidence | Flutter integration | Windows | Android |
|---|---|---|---|---|
| Fixed-size JPEG/PNG resize, bounded compression | Tested, real outputs | Tested bridge + controls | Built + native bridge tested | Built, device unverified |
| EXIF orientation 1–8 | Tested dimensions | Engine integration | Unverified | Unverified |
| Transparency consent and simple signature cleanup | Tested | Controls and preview | Unverified | Unverified |
| PDF merge / keep-delete-reorder / rotate | Tested, sample output inspected | Controls | Unverified | Unverified |
| Lossless PDF optimization | Text extraction and pixel-preservation tests passed | Opt-in control and typed bridge tested | Native bridge verification running | APK build running |
| PDFium preview and page PNG export | Tested; reordered page pixel identity | Connected, bridge test passed | Bundled; startup checked | Checksum-verified ARM64 staging implemented |
| Images to PDF / print sheets | Tested; Poppler visual inspection | Connected | Unverified | Unverified |
| Scan modes, brightness/contrast, rotation | Three new tests pass | Non-destructive source plus derived page preview | Unverified | Manual capture compiled; device testing pending |
| Advisory blur/exposure/edge warnings | Synthetic-case tests pass | Advisory text only | Unverified | Unverified |
| Application ZIP / manifest / hashes | Tested | Fixed example pack connected | Unverified | Unverified |
| Safe recipe processing and SQLite storage | Tested | Editor/import/export and batch controls; scheduler tested | Unverified | Unverified |
| SQLite settings / history retention | Restart/opt-in/validation tests pass | Theme settings and clear-history connected | Unverified | Unverified |
| Save copy | Non-clobber + read-back tested | Real bridge tested | Unverified | SAF compiled; device testing pending |
| Desktop/mobile UI layouts | Flutter behavioral tests pass; visual capture only | Real rendered widgets | Built; window startup checked | Device testing pending |
| Local scan drafts and retention | Hosted storage tests passed | Save, restore and delete connected | Unverified | Device testing pending |
| PNG preview backgrounds | Hosted widget test passed | Checkerboard, light and dark | Unverified | Unverified |
| Manual camera capture | Channel contract tests passed | Scoped Android adapter and capture control | Image import only | APK compiled; device behavior pending |
| OpenCV geometry/face assistance | Not implemented | Not exposed as working | Pending | Pending |
| Experimental printed-text OCR | Real English/Bangla/mixed recognition and UTF-8 validation tested | Typed bridge, cancellation and editable editor tested locally; hosted Linux build/startup passed (39023943472) | Core compiles; recognition unavailable | Recognition unavailable |
| Distribution | Core executable compiled | Linux x64 release bundle built; display launch blocked | Portable ZIP built, startup gate passed | ARM64 debug and unsigned APKs built |

Hosted Linux run 38862360058 passed 24 Rust tests, selected Flutter behavioral/native tests, analysis, capture-only rendering, release build and dependency resolution. Android run 38863568022 passed ARM64 APK packaging, debug signature and ZIP/ELF 16 KiB checks. Windows run 38864343687 passed its native tests, release build and packaged-window startup check with bundled release CRT. Exact hashes and source commits: evidence/development-builds-20261016.json.

All platform entries marked unverified concern per-feature interaction or clean-device behavior; compilation alone does not validate them. No real-user usability observation, accessibility certification, hostile-document process isolation, clean-device compatibility or complete dependency obligation clearance has been claimed. Golden baseline regression remains pending approved baselines.

Draft-clear controls and additional storage protection tests passed the current Linux and Windows suites.

Commit 7257778 passed Linux run 38900451000, Windows run 38900451112 and Android run 38900451024. Both desktop bundles created windows; 26 Rust tests and selected Flutter tests passed. See evidence/development-builds-7257778.json. Lossless optimization controls and additional text-layer preservation tests are entering a separate verification run.

Application checkpoint 98dbeac passed all three platform workflows: Linux 38943392106, Windows 38943392637, Android 38943392331. PDF optimization, keyboard/contrast tests and the licensed Bangla font are included. Independent download evidence: evidence/development-builds-98dbeac.json. Experimental Linux OCR CLI work lives on work/offline-ocr; Flutter OCR, Windows/Android engines and searchable PDF remain unavailable.

Experimental OCR branch: Linux Rust CLI recognition and verified UTF-8 export tested on clean synthetic English, Bangla and mixed-language cases. Local suite: 32 Rust tests. Hosted compile/boundary run 38948658931 passed Linux and Windows; Windows engine recognition remains unavailable. GUI integration, bundled model/engine workflows, timeout/resource/representative accuracy and device gates remain open.

Linux OCR integration run 39023943472 (96686d1) passed 35 Rust tests, 19 selected Flutter tests, clean analysis, model-staged release packaging and build-host window startup. Artifact hashes/inventory: evidence/experimental-ocr-build-96686d1.json. The engine is a separately installed system dependency; Windows/Android OCR remains unavailable. Additional local recovery and 200% dark-layout capture checks are documented in evidence/ocr-integration-20261017.json.
