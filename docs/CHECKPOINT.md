# Continuation checkpoint — 2026-10-19 UTC

The complete launch scope is retained in REQUIREMENTS.md. This is functioning development software, not a finished launch. Continue ordinary work autonomously without phase approval.

## Main integration and verification

Main now integrates PDF page numbers/visible ASCII watermarks from runtime candidate1a657f64013ffc3b271bca1fbf7b4e0ee4d6448d, preserving the newer main81d13b9 build evidence. All62 Rust tests,29 selected Flutter tests, clean analysis/formatting, independent pypdf/Poppler saved-output checks and three platform workflows passed. Linux39251795389 artifact12185179567, Windows39251795282 artifact12186183091, Android39251795377 artifact12186357927. Desktop startup is eight seconds on build hosts, not clean-system acceptance. Independent desktop CRC/SHA,471 notices, fonts/native assets, Linux OCR assets and Windows CRT inventory checks pass. Android artifact checks and saving the updated package set are next.

The main runtime also includes physical photo DPI, sequential scans/canonical previews, Android backup/development-signing protection, custom print layouts/guides and streamed PNG/JPEG byte bounds. Saved downloads still correspond to main10d46cc until replacements succeed. Keep evidence/development-builds-10d46cc.json and historical output evidence.

## Active next feature: existing PDF text

work/pdf-text candidate0d7d7a6f79a7b5f626235fc74f86850e17ae9178 is pushed. It branches from overlay1a657f6 and adds bounded PDFium text-layer extraction, a shared plain UTF-8 validator, responsive original-preview/editor, empty-scan recovery and actual Unicode save. All66 Rust/32 selected Flutter tests and independent English/Bangla extraction checks pass locally. Visual inspection led to a shorter title and wrapped help/errors at200% text; the focused UI recheck passes. Platform CI is pending for this candidate. Do not merge before all three workflows pass.

Bridge generator39252445602 passed for backend15600d7. Artifact12187280337 SHA-256 9c8c545ee27d0c6fc3f9c921f23b018d3adece5bcd11fb040d07220bdbfa2836 was CRC/SHA/allowlist checked and all eight generated sources applied without manual editing. Candidate source/ADR/evidence/scripts are on its branch. Preserve this newer main checkpoint and build evidence during integration; copy only intended changes rather than replacing the complete main tree.

## Exact next actions

1. Independently verify the downloaded overlay Android artifact and all three APKs, then save the four updated application downloads with existing identities/version guards. Update the package evidence with actual bytes/hashes and report any failed save accurately.
2. Inspect all three text-candidate platform runs. Fix failures, integrate only after passing, independently verify the new packages and update downloads again as appropriate. New main platform runs are independent checks; do not mislabel feature artifacts as built from a different commit.
3. Continue manual scan corners/perspective/deskew and OpenCV adapter/license work; editable pack slots/managed studio references; remaining photo/signature/PDF operations and flexible compression; platform OCR/searchable geometry; accessibility/localization/user checks; isolation/cleanup/license and clean-device release gates.

## Limitations

Linux OCR requires separately installed /usr/bin/tesseract and verified local models. Windows/Android OCR and searchable PDFs remain unavailable. Text extraction can have missing glyphs or a different reading order; it does not run OCR. PDF imports reject unsupported forms/annotations/bookmarks/attachments/signatures/actions/XFA/tags/optional-content structures. PDFium/lopdf parse in-process; encoded and text-output bounds do not cap their internal allocations or sandbox them. Abnormal exits can leave temporary files. Complete native/transitive licensing obligations, physical-printer acceptance and representative users remain outstanding.

Android builds are ARM64/API24+ and use development signing identities. Clean-device camera/SAF/OEM/backup behavior is unverified. An identity change can require uninstalling, which deletes local settings/drafts. No production key, clean-system certification, perfect OCR, passport acceptance, physical secure erasure or universal compatibility is claimed.

## Recovery

GitHub is authoritative. Current worktrees: universal-studio-main-recovery for main, universal-studio-pdf-overlays for integrated candidate, universal-studio-pdf-text for the next feature. Original universal-studio-current is an old425c064 checkout with a script executable-mode difference; leave it untouched. Toolchains are adjacent Rust1.99.0/Flutter3.47.7. Use /bin/bash with login=false if the default shell fails. Shared target is universal-studio-pdf-overlays/rust/target and currently contains the NEW text-candidate bridge; rebuild the desired checkout before other FFI tests. Preserve unexpected changes, push checkpoints frequently, and never bypass permission/review failures or held-asset decisions. Do not commit credentials, keys, private artifact URLs or delivery identities.
