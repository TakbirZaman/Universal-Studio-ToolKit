# Continuation checkpoint — 2026-10-19 UTC

The complete launch scope is retained in REQUIREMENTS.md. This is functioning development software, not a finished launch. Continue ordinary work autonomously without phase approval.

## Main integration and verification

Main now integrates PDF page numbers/visible ASCII watermarks from runtime candidate 1a657f64013ffc3b271bca1fbf7b4e0ee4d6448d, preserving the newer main 81d13b9 build evidence. All 62 Rust tests,29 selected Flutter tests, clean analysis/formatting, independent pypdf/Poppler saved-output checks and three platform workflows passed. Linux39251795389 artifact 12185179567, Windows39251795282 artifact 12186183091, Android39251795377 artifact 12186357927. Desktop startup is eight seconds on build hosts, not clean-system acceptance. Independent desktop CRC/SHA,471 notices, fonts/native assets, Linux OCR assets and Windows CRT inventory checks pass. Android CRC/native/16 KiB alignment, compiled privacy and both installable signatures verify independently. All four updated downloads were successfully saved. See evidence/development-builds-1a657f6.json.

The main runtime also includes physical photo DPI, sequential scans/canonical previews, Android backup/development-signing protection, custom print layouts/guides and streamed PNG/JPEG byte bounds. Saved downloads now correspond to runtime 0d7d7a6 integrated into main 3ecafef, including both overlays and editable PDF text. Keep evidence/development-builds-10d46cc.json and historical output evidence.

## Existing PDF text integration

Main now also integrates runtime candidate 0d7d7a6f79a7b5f626235fc74f86850e17ae9178. It adds bounded PDFium text-layer extraction, shared plain UTF-8 validation, responsive original-preview/editor, empty-scan recovery and Unicode save. All 66 Rust/32 selected Flutter tests, clean analysis and independent English/Bangla extraction checks pass. Local visual review fixed a truncated help line at 200% text; focused UI rechecks pass.

All three candidate workflows passed: Linux39253689705 artifact 12187705638 (outer SHA433ccfcf082e6b8ebcc402edf3354b2600bd2a762c5d995dc09b4f71bc7b5a58), Windows39253689586 artifact 12186777058 (outer SHAda38f06be6b63ce6130e3335ea0ec7aa4b1e02ce85a2d6ab922168a5fae3a27a), Android39253689489 artifact 12187945610 (outer SHA45702153765c80992e55b68cdf8dabc9ed0678a72572b049a353396c29c57cf6). These are runtime 0d feature artifacts, not builds from the later integration commit.

Bridge generator 39252445602 passed for backend 15600d7. Artifact12187280337 SHA-256 9c8c545ee27d0c6fc3f9c921f23b018d3adece5bcd11fb040d07220bdbfa2836 was CRC/SHA/allowlist checked and eight generated sources applied without manual editing. Exact source/ADR/evidence/verification scripts are committed.

## Exact next actions

1. Text package verification and saving are complete: CRC/SHA,471 notices, fonts/native/model/CRT inventories, startup records and all three Android APK structures/alignment/privacy/signatures pass. All four replacements succeeded. See evidence/development-builds-0d7d7a6.json. Preserve source labels and historical evidence.
2. Main3ecafef platform/bridge checks are running independently; inspect their conclusions and compare all eight regenerated files with committed sources. Main04e03a3 and its bridge already passed all four workflows. Runtime source0d7d7a6 differs from main 3ecafef only in documentation. Push this final evidence/checkpoint, then begin the next full-scope slice.
3. Continue manual scan corners/perspective/deskew and OpenCV adapter/license work; editable pack slots and managed studio references; remaining photo/signature/PDF operations and flexible compression; platform OCR/searchable geometry; accessibility/localization/user checks; isolation/cleanup/license and clean-device release gates.

## Limitations

Linux OCR requires separately installed /usr/bin/tesseract and verified local models. Windows/Android OCR and searchable PDFs remain unavailable. Text extraction can have missing glyphs or a different reading order; it does not run OCR. PDF imports reject unsupported forms/annotations/bookmarks/attachments/signatures/actions/XFA/tags/optional-content structures. PDFium/lopdf parse in-process; encoded and text-output bounds do not cap their internal allocations or sandbox them. Abnormal exits can leave temporary files. Complete native/transitive licensing obligations, physical-printer acceptance and representative users remain outstanding.

Android builds are ARM64/API 24+ and use development signing identities. Clean-device camera/SAF/OEM/backup behavior is unverified. An identity change can require uninstalling, which deletes local settings/drafts. No production key, clean-system certification, perfect OCR, passport acceptance, physical secure erasure or universal compatibility is claimed.

## Recovery

GitHub is authoritative. Current worktrees: universal-studio-main-recovery for main, universal-studio-pdf-overlays for integrated candidate, universal-studio-pdf-text for the next feature. Original universal-studio-current is an old425c064 checkout with a script executable-mode difference; leave it untouched. Toolchains are adjacent Rust 1.99.0/Flutter 3.47.7. Use /bin/bash with login=false if the default shell fails. Shared target is universal-studio-pdf-overlays/rust/target and currently contains the NEW text-candidate bridge; rebuild the desired checkout before other FFI tests. Preserve unexpected changes, push checkpoints frequently, and never bypass permission/review failures or held-asset decisions. Do not commit credentials, keys, private artifact URLs or delivery identities.

## Next concrete implementation

Implement validated manual scan corner/perspective correction behind the narrow processing adapter; inspect OpenCV platform/license/build requirements before bundling it. If a platform dependency blocks that adapter, continue editable application-pack slot constraints and builder UI against the existing PackPreset/PackSlot models. Keep the entire remaining scope in REQUIREMENTS.md. Do not expose suggested/unsupported controls as working. No representative users or actual Android devices were available in this run.
