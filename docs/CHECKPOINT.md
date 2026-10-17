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

## Exact next action

Inspect workflow runs for the current main HEAD after the notice/finalization integration. Fix any failure, independently verify refreshed artifacts, and update the existing saved downloads only after successful checks. Previously saved cd474ed artifacts remain the last verified downloads until then. Continue with a physical-photo-size/DPI vertical slice: validate requested mm/DPI in Rust, encode density explicitly, reopen and verify actual pixels/density/bytes, regenerate typed bindings and add understandable controls. Do not silently treat DPI as privacy metadata or claim physical size from pixel dimensions alone.

## Recovery

GitHub is authoritative; user messages have repeatedly reset scratch checkouts/toolchains. Fetch main and read this checkpoint first. Active checkout: universal-studio-current, not the older skeleton. Local Rust 1.99.0 and Flutter 3.47.7 were restored in this session; SDKs are transient. Local Linux release tooling lacks pkg-config/GTK headers, so hosted builds provide release/startup evidence. A prior damaged installed LLVM library was repaired from the checksum-verified official archive; debugger restrictions were not bypassed.

## Remaining launch work and blockers

OpenCV boundary/perspective/deskew and face assistance; Windows/Android OCR engine packaging and searchable-PDF geometry; manual signature refinement/storage/PDF placement; remaining PDF forms/watermarks/numbering/compression; flexible photo constraints, physical-size UI and fuller print controls; editable application packs and managed cross-studio sources; drag/drop, localization, complete screen-reader/focus/reduced-motion/large-text checks and representative usability; hard process isolation for PDF parsers; orphaned temporary-job cleanup; complete native/transitive license-obligation review; clean-device/runtime and Android workflow validation; AppImage and private production APK signing. Unchecked requirements are retained.

OCR child resource limits do not establish a filesystem/network sandbox or a bound on all parent-side preparation. Parent termination may leave private temporary files; retention/cleanup remains open. No perfect OCR, passport acceptance, universal compatibility, physical secure-erasure or commercial-product parity claim.
