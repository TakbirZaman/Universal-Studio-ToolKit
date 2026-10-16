# Feature / platform status

Updated 2026-10-16. This is an implementation in progress, not launch completion.

| Capability | Rust Linux evidence | Flutter integration | Windows | Android |
|---|---|---|---|---|
| Fixed-size JPEG/PNG resize, bounded compression | Tested, real outputs | Tested bridge + controls | Source only | Source only |
| EXIF orientation 1–8 | Tested dimensions | Engine integration | Unverified | Unverified |
| Transparency consent and simple signature cleanup | Tested | Controls and preview | Unverified | Unverified |
| PDF merge / keep-delete-reorder / rotate | Tested, sample output inspected | Controls | Unverified | Unverified |
| PDFium preview and page PNG export | Tested; reordered page pixel identity | Connected, bridge test passed | Binary not bundled | Checksum-verified ARM64 staging implemented |
| Images to PDF / print sheets | Tested; Poppler visual inspection | Connected | Unverified | Unverified |
| Scan modes, brightness/contrast, rotation | Three new tests pass | Non-destructive source plus derived page preview | Unverified | Camera absent |
| Advisory blur/exposure/edge warnings | Synthetic-case tests pass | Advisory text only | Unverified | Unverified |
| Application ZIP / manifest / hashes | Tested | Fixed example pack connected | Unverified | Unverified |
| Safe recipe processing and SQLite storage | Tested | Editor/import/export and batch controls; scheduler tested | Unverified | Unverified |
| SQLite settings / history retention | Restart/opt-in/validation tests pass | Theme settings and clear-history connected | Unverified | Unverified |
| Save copy | Non-clobber + read-back tested | Real bridge tested | Unverified | SAF source added; build/device testing pending |
| Desktop/mobile UI layouts | Flutter widget/golden tests pass | Real rendered widgets | Native build pending | Device testing pending |
| Local scan drafts and retention | Source reconstructed; fresh hosted test pending | Save, restore and delete connected | Unverified | Device testing pending |
| PNG preview backgrounds | Source reconstructed; widget test pending | Checkerboard, light and dark | Unverified | Unverified |
| Full camera/OpenCV geometry/OCR | Not implemented | Not exposed as working | Pending | Pending |
| Distribution | Core executable compiled | Linux x64 release bundle built; display launch blocked | No executable yet | No APK yet |

Hosted checkpoint 2d08043 passed 24 Rust tests and the selected Flutter behavioral/native bridge tests. Home rendering completed in capture-only mode; baseline regression remains pending. The native bridge test also passed separately against the bundled release Rust/PDFium libraries. Flutter analysis reports no issues. Refreshed logs are in docs/evidence. Linux release build succeeded on Ubuntu 24.04 x86_64; dynamic-library resolution has no missing libraries on this host. Xvfb launch was blocked because the environment prohibits its display sockets; native desktop interaction and clean-device validation remain outstanding. Dependency collection covers 256 resolved packages with no missing root/upstream license files, but obligation review is not complete.

No real-user usability observation, accessibility certification, hostile-document process isolation, clean-device compatibility or complete dependency compliance clearance has been claimed.

Hosted Linux bundle: run 38861560809 succeeded; downloaded artifact CRC, both SHA-256 checksums and required file inventory verified in docs/evidence/hosted-linux-artifact.json. The bundle is from commit 2d08043, before recovered draft/preview changes. Run 38862360058 is verifying the recovered source. Android run 38862360030 has passed setup and entered the unsigned release build; do not claim APK completion until its gates pass.
