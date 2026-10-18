# Continuation checkpoint — 2026-10-18 UTC

This is functioning development software, not the completed launch. Preserve the full scope in REQUIREMENTS.md and continue ordinary implementation without phase approval. GitHub is authoritative: user messages have repeatedly reset the scratch checkout and removed unpushed work/toolchains.

## Source and current integration

- Main before this integration: 28163d4aedaa19cd43ce0f504dc7cb8e57601763. This includes physical photo mm/DPI and notice provenance gates.
- Scanner candidate: work/safe-scan-session, 3276e3cf5e642daa3764eea93c00fd42e60965aa (tree 661c84a516a524b2c545e4506ae5c6e708875494).
- Candidate Linux 39163851304 and Windows 39163851241 passed native/interface tests, packaging, dependencies/notices and eight-second packaged-window startup. Android 39163851248 also passed its complete build, signing, compiled privacy, native/alignment and artifact workflow.
- Android privacy repair 6629bbe9f4f16f679a6ae25840242c72149cf59a passed run 39163380699. It is included in the scanner candidate.
- Final local integration additionally rejects Windows COM/LPT superscript device names, improves file/page accessibility labels, clarifies scanner selection, loads bundled fonts in the scanner workflow test and waits for actual decoded preview pixels. It must pass its own main platform gates before download replacement.

## Implemented and verified changes

Scanner PDF preparation sends original bytes plus typed per-page edits once. Rust prepares and releases each decoded page in sequence, retains encoded PDF objects only, limits cumulative encoded image writes and final PDF serialization to 64 MiB, and preserves validated original bytes if a lossless optimization rewrite exceeds the budget. This is not a process-wide memory cap or parser sandbox. Opaque-background consent checks original 8/16-bit alpha. PDF reports disclose quality-95 JPEG page images without selectable text.

Display previews pass the bounded Rust decoder, normalize orientation, and encode a canonical PNG at most 1200 pixels on each side. They never replace export bytes or output measurements. Widget requests coalesce to the latest pending edit; stale results are discarded. Selection remains on the same source after reordering. Imports reject more than 200 scan pages before file reads.

Bridge generator 39162800840 passed for backend commit d8eae294f2e66dde78f663facc11775de8d49e41. Artifact 12149124428 SHA-256 0618f4e8803fd9d63dda2a15b112347b0d44918b7e143d43e63b91e930cec298 was ZIP/allowlist verified; all eight generated source files were applied without hand editing.

Local verification: 48 Rust tests with PDFium and real English/Bangla OCR assets; 25 selected Flutter tests; clean analysis and formatting. Scanner tests import/reorder/rotate three pages, compare actual PDFium page pixels and save a Bangla-named PDF on desktop light and 390px dark/200% text. The OS picker alone is substituted. A dropdown overflow was found and fixed. Bundled-font capture-only layouts were inspected locally; screenshots are not uploaded. No golden baseline or observed user timing is claimed. See ADR-011 and USABILITY.md.

Android explicitly disables backup, excludes all nine app-data domains in legacy/cloud/device-transfer rules, and provides a no-data backup agent. A signing repair creates an explicit ephemeral development identity instead of assuming Gradle's debug-key location, then cleans it on exit. Compiled privacy verification resolves optimized XML filenames through manifest resource IDs, checks every XML configuration and each transport independently, and rejects release Internet or broad-storage permissions. Five source/parser tests plus a real-keytool lifecycle test pass. Device/OEM transport behavior and deletion of prior backups remain unverified. See ADR-010.

## Saved downloads

Latest successfully saved files are main28163d4 builds, each version 4:
- Universal-Studio-Windows-x64.zip
- Universal-Studio-Linux-x64.tar.gz
- Universal-Studio-Android-debug.apk

Their exact inner/outer SHA-256, bytes and startup records are in evidence/development-builds-28163d4.json. Independent checks covered archive CRC, all 471 retained notice hashes, native inventory, font/model/license and Windows CRT hashes. Android debug signature and ZIP/ELF 16 KiB alignment were independently checked with official SDK build tools. These downloads do not yet contain the scanner/Android privacy candidate. Update them only after the new source passes packaging and independent artifact checks.

## Runtime and privacy limits

Linux OCR requires separately installed /usr/bin/tesseract and verified local English/Bangla models. Normal processing never downloads. Linux bundles include pinned Apache-2.0 model/license provenance; the engine is not bundled. Windows/Android recognition is unavailable. Results are editable UTF-8 text, not searchable PDFs. Small synthetic phrases establish integration, not general accuracy.

PDF operations reject protected/forms/annotations/bookmarks/attachments/signatures/actions/XFA/tags/optional-content structures rather than discard them. PDF parsing is in-process and remains a production isolation blocker. OCR child limits/cancellation do not bound all parent-side preparation or establish a filesystem/network sandbox. Abnormal termination can leave temporary files; orphan cleanup remains open.

All 256 locked dependency records and 471 retained notice references verify. That establishes integrity/provenance, not complete native/transitive redistribution-obligation clearance. r-efi AUTHORS contains the MIT alternative; do not call it an unlicensed blocker. Fonts, OCR assets and Microsoft CRT have separate retained notices/provenance.

## Exact next actions

1. All three scanner candidate platform jobs passed. Integrate verified source plus the locally verified filename/font/accessibility refinements into main; retain expected-SHA guards.
2. Inspect resulting main Linux/Windows/Android workflows, fix any failures, independently verify artifacts and replace the existing saved downloads. An optimized development-signed release APK is also produced; it is not production signing. CI identities can change; uninstalling to resolve mismatch deletes local drafts/settings.
3. Continue remaining requirements: OpenCV manual/automatic boundary and perspective/deskew adapters; custom print-sheet controls; editable pack slots and managed cross-studio sources; remaining photo/signature/PDF operations; platform OCR/searchable geometry; accessibility/localization/user checks; cleanup/isolation/license and clean-device gates. Do not expose unfinished controls as working.

## Recovery tools

Active checkout: universal-studio-current. A separate universal-studio-filenames worktree contains the tested small filename fix, also copied into the active integration. Older universal-studio-toolkit is an obsolete skeleton. Fetch main/feature refs before edits and preserve unexpected local changes. Rust 1.99.0 and Flutter 3.47.7 are in adjacent toolchains; they are transient. Local Linux release prerequisites lack GTK/pkg-config development setup, so hosted builds supply release/startup evidence. Do not bypass permission/approval failures or publish held screenshot/fixture assets through alternate routes.
