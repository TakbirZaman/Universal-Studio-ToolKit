# Checkpoint — 2026-10-17 UTC

This is functioning development software, not launch completion. Full scope remains in REQUIREMENTS.md. Continue ordinary implementation without phase-by-phase approval.

## Latest saved application builds

Source cd474ede184bb62c1ad1fd868c4d34bbcc7637b5 passed all three hosted platform gates:
- Linux 39024416796: 35 Rust tests, 19 selected Flutter behavioral/native tests including real English/Bangla/mixed OCR and the editable result screen, clean analysis, capture-only home rendering, release bundle, dependency resolution and eight-second packaged-window startup on Ubuntu 24.04 x64.
- Windows 39024416815: core/native Flutter tests and analysis, portable ZIP with official release CRT provenance and eight-second packaged-window startup on windows-2022 x64. OCR engine recognition is unavailable.
- Android 39024416794: ARM64 debug-signed and unsigned release APKs, debug-signature verification, native inventory and ZIP/ELF 16 KiB checks. Device/camera/provider behavior remains unverified; OCR is unavailable.

All three artifacts were downloaded and independently checked against outer SHA-256, ZIP CRC, native/font/notice inventories and desktop startup reports. Linux model/license hashes and provenance also match. Exact inner/outer measurements: evidence/development-builds-cd474ed.json. The three saved user downloads are Universal-Studio-Windows-x64.zip, Universal-Studio-Linux-x64.tar.gz and Universal-Studio-Android-debug.apk (updated versions saved successfully). Debug keys can change across CI builds; uninstalling to resolve a signing mismatch deletes app-local drafts/settings.

Typed bridge regeneration run 39024416799 passed. Artifact 12096909913 was SHA-256/ZIP/allowlist verified; all six freshly generated files exactly match committed source. Do not hand-edit generated files.

## OCR scope and verification

Linux OCR uses only fixed /usr/bin/tesseract with verified local English/Bangla tessdata_fast models, typed single-use opaque jobs, cancellable serial waiting, named states and verified UTF-8 save-copy export. The selected scan is freshly adjusted before recognition. The review screen keeps text editable, retains edits on retry/export failure and reports ready only after the editor transfer settles. Presence/model hashes gate its entry. Windows/Android report unavailable; no searchable PDF claims.

Models are staged only from explicitly supplied local files; CI explicitly fetches pinned development assets. Normal application use and the staging helper never download. The bundle retains Apache-2.0 LICENSE/provenance. The Tesseract engine remains a separately installed Linux runtime prerequisite, not a bundled portable engine. See ADR-008-offline-ocr.md, OCR-IMPLEMENTATION.md and OCR-ASSETS.md.

Additional local checks: actual Bangla-named text save/non-overwrite, invalid-filename recovery preserving edits, three staging-boundary tests and two visually inspected capture-only layouts (desktop light and 390px dark at 200% text). Model lookup without UST_OCR_TESSDATA passed through the real Rust CLI using the same executable-parent lookup; actual output hash and original preservation are in evidence/ocr-integration-20261017.json. Small synthetic phrases are integration evidence, not representative accuracy/performance.

A widget test caught unsendable closure capture during worker transfer. Top-level compute callbacks now transfer only text bytes. Finalization also hides the engine-cancel action after recognition ends; cancellation cannot expose a premature ready status. The latest finalization change passed three native/widget tests and clean analysis locally; current-main packaging checks must complete before claiming its refreshed packages passed.

## Notice provenance integration

Branch work/license-provenance commit 895e1ecbcab0f60d448b6a55c8c32d5fa64a1d6e passed hosted Linux and Windows notice checks in run 39024849049. All 256 locked dependency records and 471 retained notice-file references verify. All 71 Dart versions, 252 source archive checksums and four actual SDK source revisions are recorded. Four boundary tests reject changed/missing notices, traversal, duplicates and incomplete/changed lockfile coverage. Windows checkout attributes preserve notice bytes.

The current integration adds these pre-package checks on every platform. This is integrity/provenance, not automatic license classification or complete redistribution clearance. Composite/native obligations still need review. r-efi AUTHORS contains the MIT alternative; it is not a missing-license blocker. Retain whole multi-license files.

## Physical-photo slice — work/photo-density

Backend API commit 6850494b3fb97c34070206828d2d7db7c7218653 triggered successful bridge generation run 39025892759. Its seven-file source artifact (12098760967) was SHA-256/ZIP/allowlist verified and applied. Generated files were not hand-edited.

The current candidate implements mm/DPI controls and typed actual print density, JPEG JFIF/PNG pHYs encoding, default density stripping, source-precision alpha consent and preserved 16-bit PNG/padding. All 41 Rust tests passed; 22 selected Flutter tests passed, including real processing/result UI through a substituted OS picker at desktop and 390px dark/200% text. Analysis is clean. The preview header wraps after an overflow was found; success uses a labelled icon and output details are collapsed. Independent Pillow checks reopened actual saved JPEG/PNG at 413×531 pixels and 300 / 299.9994 DPI, verified actual bytes, source preservation and non-overwrite. Evidence: physical-density-20261017.json. No printer or official-application acceptance claim.

The existing platform-interface package was promoted to a pinned test dependency without a version/source change; png 0.18.1 became a direct dependency at its existing locked version. The dependency set remains 256 records/471 retained notice references and provenance verification passes. See ADR-009-physical-photo-density.md.

Main source 38879229cfab62b12cf6b9f70276492b5ee388f7 passed Linux 39025313290, Windows 39025313390, Android 39025313287 and notice matrix 39025313275. Those refreshed artifacts have not yet replaced the saved cd474ed downloads. The physical-photo candidate must pass its own platform builds before those downloads claim this feature.

## Exact next action

Integrate the locally verified physical-photo candidate, inspect the current main HEAD's Linux/Windows/Android workflow runs, fix failures and independently verify the resulting artifacts before replacing existing saved downloads. Keep source/packaging evidence distinct from device/printer acceptance. Then inspect Android backup/extraction policy and bound multipage scan intermediates: current Dart scanning retains every adjusted page before PDF assembly, so compressed input limits alone do not bound intermediate memory. Continue the full requirements checklist without phase approval.

## Recovery

GitHub is authoritative; user messages have repeatedly reset scratch checkouts/toolchains. Fetch main and read this checkpoint first. Active checkout: universal-studio-current, not the older skeleton. Local Rust 1.99.0 and Flutter 3.47.7 were restored in this session; SDKs are transient. Local Linux release tooling lacks pkg-config/GTK headers, so hosted builds provide release/startup evidence. A prior damaged installed LLVM library was repaired from the checksum-verified official archive; debugger restrictions were not bypassed.

## Remaining launch work and blockers

OpenCV boundary/perspective/deskew and face assistance; Windows/Android OCR engine packaging and searchable-PDF geometry; manual signature refinement/storage/PDF placement; remaining PDF forms/watermarks/numbering/compression; flexible photo constraints, physical-size UI and fuller print controls; editable application packs and managed cross-studio sources; drag/drop, localization, complete screen-reader/focus/reduced-motion/large-text checks and representative usability; hard process isolation for PDF parsers; orphaned temporary-job cleanup; complete native/transitive license-obligation review; clean-device/runtime and Android workflow validation; AppImage and private production APK signing. Unchecked requirements are retained.

OCR child resource limits do not establish a filesystem/network sandbox or a bound on all parent-side preparation. Parent termination may leave private temporary files; retention/cleanup remains open. No perfect OCR, passport acceptance, universal compatibility, physical secure-erasure or commercial-product parity claim.

## Recovery checkpoint — 2026-10-18

GitHub main is 28163d4aedaa19cd43ce0f504dc7cb8e57601763, including physical mm/DPI photos. Linux 39027810803, Windows 39027810924 and Android 39027810830 passed; their artifacts still need independent download verification and replacement of the saved cd474ed builds. Android privacy branch 5e2f4b0464c9e84bf65af4470bd659bba74270a0 compiled both APKs in run 39028960308 but failed in post-build packaging with no command diagnostic. Current repair generates an explicit ephemeral development key, cleans it on exit and labels failing stages; source privacy tests and the real-keytool boundary test pass locally. Hosted APK verification remains required.

Unpushed safe-scan-session work from the previous transient environment did not survive the reset. Reimplement bounded scan intermediates after Android packaging passes. Current Dart scanner still caches full adjusted PNGs. No claims of a finished launch, real-device acceptance, full license clearance or searchable PDF.

## Scanner integration candidate — 2026-10-18

work/safe-scan-session backend API commit d8eae294f2e66dde78f663facc11775de8d49e41 is pushed. Generated bridge run 39162800840/artifact 12149124428 (SHA-256 0618f4e8803fd9d63dda2a15b112347b0d44918b7e143d43e63b91e930cec298) passed and all eight fixed source paths were verified/applied. Local UI sends original pages plus typed edits once, retains no full adjusted PNG cache, validates display previews through Rust, coalesces preview requests and preserves selected-page identity during reorder. Three new Flutter checks exercise actual import/edit/reorder/PDF rendering and Bangla-named save on desktop and 390px dark/doubled text, plus invalid-image preview rejection. All 25 selected Flutter tests pass.

Android repair cef69ab compiled and signed/aligned the optimized development APK, then compiled-resource verification revealed R8 renamed backup XML paths. Repair 6629bbe9f4f16f679a6ae25840242c72149cf59a resolves manifest resource IDs through aapt2 resources and verifies every configuration and each transport independently. Five source/parser tests and a real-keytool lifecycle test pass. Hosted run 39163380699 is pending; inspect its result next. The scanner candidate includes the same verifier fix.

Verified main281 builds are now downloaded with physical DPI; evidence development-builds-28163d4.json checks every retained notice hash, native/font/model/CRT inventory and startup reports. Saved downloads must stay labelled main281 until a newer candidate passes its own packaging and independent artifact checks. Source remains development software.

Local final scanner verification: 47 Rust tests pass with PDFium and actual English/Bangla OCR assets; 25 selected Flutter tests pass; flutter analyze reports no issues; Cargo formatting, five Android policy/parser tests, keytool lifecycle test and all 256-dependency/471-notice hashes pass. Existing download replacements succeeded as version 4 for all three files (main281). Next push this candidate, inspect all three feature-branch package workflows, fix failures, then integrate only after passing.
