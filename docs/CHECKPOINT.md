# Continuation checkpoint — 2026-10-18 UTC

This is functioning development software, not the completed launch. Preserve the full scope in REQUIREMENTS.md and continue ordinary implementation without phase approval. GitHub is authoritative: user messages have repeatedly reset the scratch checkout and removed unpushed work/toolchains.

## Current source and builds

Main processing baseline: 27c8b3daa3514e01a73d1c9f49c3d9697fa6f9f2 (tree fa68bbc0351849c881e852f8090379605e6b9ecf). It integrates sequential scans, canonical previews, Android backup/signing protection, Windows reserved-name validation and the bundled-font scanner workflow checks.

All final main workflows passed: Linux 39164619821, Windows 39164619702, Android 39164619794 and bridge 39164619682. Native/local checks: 48 Rust tests, 25 selected Flutter tests, clean analysis/formatting, five Android policy/parser tests, actual keytool lifecycle and notice provenance. Desktop startup is build-host only; Android device/provider/camera/OEM behavior remains unverified.

Next feature branch: work/print-layout, backend 3b09a8db73d281a9648aabc91488a7b97aa96e1c. Its custom physical layout/cutting guides/DPI backend and regenerated bridge pass initial checks. Local UI/native/independent-PDF work continues in universal-studio-print. See next actions below; these new print controls are not in the saved main 27 builds.

## Implemented and verified changes

Scanner PDF preparation sends original bytes plus typed per-page edits once. Rust prepares and releases each decoded page in sequence, retains encoded PDF objects only, limits cumulative encoded image writes and final PDF serialization to 64 MiB, and preserves validated original bytes if a lossless optimization rewrite exceeds the budget. This is not a process-wide memory cap or parser sandbox. Opaque-background consent checks original 8/16-bit alpha. PDF reports disclose quality-95 JPEG page images without selectable text.

Display previews pass the bounded Rust decoder, normalize orientation, and encode a canonical PNG at most 1200 pixels on each side. They never replace export bytes or output measurements. Widget requests coalesce to the latest pending edit; stale results are discarded. Selection remains on the same source after reordering. Imports reject more than 200 scan pages before file reads.

Bridge generator 39162800840 passed for backend commit d8eae294f2e66dde78f663facc11775de8d49e41. Artifact 12149124428 SHA-256 0618f4e8803fd9d63dda2a15b112347b0d44918b7e143d43e63b91e930cec298 was ZIP/allowlist verified; all eight generated source files were applied without hand editing.

Local verification: 48 Rust tests with PDFium and real English/Bangla OCR assets; 25 selected Flutter tests; clean analysis and formatting. Scanner tests import/reorder/rotate three pages, compare actual PDFium page pixels and save a Bangla-named PDF on desktop light and 390px dark/200% text. The OS picker alone is substituted. A dropdown overflow was found and fixed. Bundled-font capture-only layouts were inspected locally; screenshots are not uploaded. No golden baseline or observed user timing is claimed. See ADR-011 and USABILITY.md.

Android explicitly disables backup, excludes all nine app-data domains in legacy/cloud/device-transfer rules, and provides a no-data backup agent. A signing repair creates an explicit ephemeral development identity instead of assuming Gradle's debug-key location, then cleans it on exit. Compiled privacy verification resolves optimized XML filenames through manifest resource IDs, checks every XML configuration and each transport independently, and rejects release Internet or broad-storage permissions. Five source/parser tests plus a real-keytool lifecycle test pass. Device/OEM transport behavior and deletion of prior backups remain unverified. See ADR-010.

## Saved downloads

Successfully saved application builds from main 27c8b3d:
- Universal-Studio-Windows-x64.zip
- Universal-Studio-Linux-x64.tar.gz
- Universal-Studio-Android-debug.apk
- Universal-Studio-Android-development-release.apk

The first three preserve their previous file identities; the new optimized Android development APK has its own identity. Exact bytes/hashes and build checks are in evidence/development-builds-27c8b3d.json. Outer artifact SHA-256 and archive CRC match. All 471 retained notice hashes, native inventory, OCR model/license/font hashes, Windows CRT hashes and eight-second desktop startup reports independently verify. All three Android APKs pass local official-SDK structural/ELF/ZIP 16 KiB and compiled backup-policy checks; debug and optimized development signatures verify. The unsigned APK is a separate signing input, not the recommended installable download.

Main bridge artifact 12150073462 (SHA-256 dcb2296bba1ad4e1321128c0661ea6141e68e58624ba349230fb8f5fdde2e48e) was independently verified. All eight freshly generated source files exactly match the committed sources. Keys are never committed or included in artifacts. Development signing identities can change between builds; uninstalling to resolve mismatch deletes local drafts/settings.

## Runtime and privacy limits

Linux OCR requires separately installed /usr/bin/tesseract and verified local English/Bangla models. Normal processing never downloads. Linux bundles include pinned Apache-2.0 model/license provenance; the engine is not bundled. Windows/Android recognition is unavailable. Results are editable UTF-8 text, not searchable PDFs. Small synthetic phrases establish integration, not general accuracy.

PDF operations reject protected/forms/annotations/bookmarks/attachments/signatures/actions/XFA/tags/optional-content structures rather than discard them. PDF parsing is in-process and remains a production isolation blocker. OCR child limits/cancellation do not bound all parent-side preparation or establish a filesystem/network sandbox. Abnormal termination can leave temporary files; orphan cleanup remains open.

All 256 locked dependency records and 471 retained notice references verify. That establishes integrity/provenance, not complete native/transitive redistribution-obligation clearance. r-efi AUTHORS contains the MIT alternative; do not call it an unlicensed blocker. Fonts, OCR assets and Microsoft CRT have separate retained notices/provenance.

## Exact next actions

1. Complete work/print-layout. Backend3b09a8d generated bridge 39165065326 successfully; artifact 12150228437 SHA-256 9eb98be694847b77e4c875cbf25c6ae6d07b9f7d1e3c5b6d896815627d358d76 was ZIP/allowlist verified and applied to universal-studio-print. The new UI tests pass desktop and 390px dark/200% text with real processing, invalid-spacing recovery and actual decoded PDF preview. The Rust geometry tests verify capacity, placements, guide clearance, source preservation, embedding and rendering. Independent pypdf/Poppler output verification and the complete native/interface suite are running; inspect their logs next. Add short ADR/status/evidence, push candidate, run all three platform workflows, and integrate only after passing.
2. Keep the saved main 27 downloads labelled with that source until the new print candidate passes packaging and independent artifact checks. Copy only changed feature files onto current main so this newer evidence/checkpoint is not lost.
3. Continue OpenCV manual/automatic boundaries/perspective/deskew, editable pack slots and managed cross-studio references, remaining photo/signature/PDF operations, platform OCR/searchable geometry, accessibility/localization/user checks, cleanup/isolation/license and clean-device gates. Do not expose unfinished controls as working.

## Recovery tools

Active checkout: universal-studio-current. A separate universal-studio-filenames worktree contains the tested small filename fix, also copied into the active integration. Older universal-studio-toolkit is an obsolete skeleton. Fetch main/feature refs before edits and preserve unexpected local changes. Rust 1.99.0 and Flutter 3.47.7 are in adjacent toolchains; they are transient. Local Linux release prerequisites lack GTK/pkg-config development setup, so hosted builds supply release/startup evidence. Do not bypass permission/approval failures or publish held screenshot/fixture assets through alternate routes.

## Print-sheet candidate verification

The current work/print-layout candidate adds standard/custom paper, margins/spacing/copies, optional vector cutting guides and optional explicit DPI resampling. Source pixels stay unchanged by default; images are encoded once as JPEG95 inside a PDF and aspect ratio is preserved. Invalid fields open advanced controls and show inline errors. All 52 Rust and 27 selected Flutter tests pass, and analysis/formatting/notice checks pass. Independent pypdf/Pillow/Poppler verification measured actual saved geometry/pixels and rendered output, inspected locally. No printer/device/user certification. Evidence: custom-print-20261018.json. Push this candidate, inspect all platform workflows, then integrate only after passing, preserving the saved main27 build evidence.
