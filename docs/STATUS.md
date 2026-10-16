# Feature / platform status

Updated 2026-10-16. This is an implementation in progress, not launch completion.

| Capability | Rust Linux evidence | Flutter integration | Windows | Android |
|---|---|---|---|---|
| Fixed-size JPEG/PNG resize, bounded compression | Tested, real outputs | Tested bridge + controls | Built + native bridge tested | Built, device unverified |
| EXIF orientation 1–8 | Tested dimensions | Engine integration | Unverified | Unverified |
| Transparency consent and simple signature cleanup | Tested | Controls and preview | Unverified | Unverified |
| PDF merge / keep-delete-reorder / rotate | Tested, sample output inspected | Controls | Unverified | Unverified |
| PDFium preview and page PNG export | Tested; reordered page pixel identity | Connected, bridge test passed | Bundled; startup checked | Checksum-verified ARM64 staging implemented |
| Images to PDF / print sheets | Tested; Poppler visual inspection | Connected | Unverified | Unverified |
| Scan modes, brightness/contrast, rotation | Three new tests pass | Non-destructive source plus derived page preview | Unverified | Camera absent |
| Advisory blur/exposure/edge warnings | Synthetic-case tests pass | Advisory text only | Unverified | Unverified |
| Application ZIP / manifest / hashes | Tested | Fixed example pack connected | Unverified | Unverified |
| Safe recipe processing and SQLite storage | Tested | Editor/import/export and batch controls; scheduler tested | Unverified | Unverified |
| SQLite settings / history retention | Restart/opt-in/validation tests pass | Theme settings and clear-history connected | Unverified | Unverified |
| Save copy | Non-clobber + read-back tested | Real bridge tested | Unverified | SAF compiled; device testing pending |
| Desktop/mobile UI layouts | Flutter behavioral tests pass; visual capture only | Real rendered widgets | Built; window startup checked | Device testing pending |
| Local scan drafts and retention | Hosted storage tests passed | Save, restore and delete connected | Unverified | Device testing pending |
| PNG preview backgrounds | Hosted widget test passed | Checkerboard, light and dark | Unverified | Unverified |
| Full camera/OpenCV geometry/OCR | Not implemented | Not exposed as working | Pending | Pending |
| Distribution | Core executable compiled | Linux x64 release bundle built; display launch blocked | Portable ZIP built, startup gate passed | ARM64 debug and unsigned APKs built |

Hosted Linux run 38862360058 passed 24 Rust tests, selected Flutter behavioral/native tests, analysis, capture-only rendering, release build and dependency resolution. Android run 38863568022 passed ARM64 APK packaging, debug signature and ZIP/ELF 16 KiB checks. Windows run 38864343687 passed its native tests, release build and packaged-window startup check with bundled release CRT. Exact hashes and source commits: evidence/development-builds-20261016.json.

All platform entries marked unverified concern per-feature interaction or clean-device behavior; compilation alone does not validate them. No real-user usability observation, accessibility certification, hostile-document process isolation, clean-device compatibility or complete dependency obligation clearance has been claimed. Golden baseline regression remains pending approved baselines.

Draft-clear controls and additional storage protection tests are entering a new hosted verification run; they are not included in the builds above.
