# Checkpoint — 2026-10-17 UTC

Full scope remains in REQUIREMENTS.md. This is functioning development software, not launch completion. Continue ordinary implementation without phase-by-phase approval.

## Stable application checkpoint

Application source 98dbeacac7c9e558205eb9bb8fc990594f122543 passed:
- Linux run 38943392106: 27 Rust tests, selected Flutter behavioral/native/contrast/keyboard tests, analysis, release bundle, library resolution and an eight-second packaged-window startup check on Ubuntu 24.04 x64.
- Windows run 38943392637: Rust/native Flutter tests, portable ZIP with release CRT provenance, packaged-window startup on the windows-2022 build host.
- Android run 38943392331: ARM64 debug-signed and unsigned release APKs; signature, native contents and ZIP/ELF 16 KiB checks. Device behavior is unverified.

All three downloads were independently checked against artifact SHA-256, ZIP CRC, native/font/notice inventories and desktop startup reports. Exact inner/outer hashes: evidence/development-builds-98dbeac.json. User-facing saved downloads are Universal-Studio-Windows-x64.zip, Universal-Studio-Linux-x64.tar.gz and Universal-Studio-Android-debug.apk. They include lossless PDF controls, keyboard shortcuts, guarded saves, distinct dark accents, original Android/Windows icons, scoped Android camera capture, scan drafts and licensed Bangla fallback typography. They do not include the experimental OCR adapter.

Golden rendering is capture-only; approved regression baselines remain unavailable. No representative users, clean-device workflows or accessibility certification have been claimed. Debug APK keys can differ between CI builds; uninstalling to resolve a signature mismatch deletes app-local data.

## Work in progress: work/offline-ocr

Current application code 96686d1f6f6b4fde0b76d623367640a497479ebe includes the Linux Rust Tesseract adapter, typed FRB opaque single-use jobs, cancellable queue waiting, named job states, verified UTF-8 text export and an editable Scanner Studio result screen. Windows/Android OCR capability remains false. The entry is hidden unless the Linux engine exists and all pinned local model/license files verify. The current selected page is freshly adjusted before OCR. No searchable PDF claims.

Verification this session:
- All 35 local Rust tests passed with real PDFium, including queued cancellation and six OCR boundary/export tests.
- All 19 selected Flutter behavioral/native tests passed, including real English, Bangla and mixed-language OCR through FRB and editable result population.
- Additional native tests passed actual Bangla-named UTF-8 save, non-overwrite and invalid-filename recovery without losing edits.
- Three model-staging boundary tests passed. Actual pinned English/Bangla models and LICENSE staged successfully. Host Tesseract 5.3.4 again returned both clean synthetic phrases exactly; this is narrow integration evidence, not representative accuracy.
- Two capture-only layout checks passed and were visually inspected: desktop light and 390px dark at 200% text. Captures remain local, not uploaded or treated as approved golden baselines.
- Flutter analysis is clean after removing unused imports and fixing braces.
- API commit 84bcbf0 passed hosted Linux/Windows core checks (39022900303); generated bridge source from 39022900304 was SHA-256/ZIP/allowlist verified before applying all six files. Later core run 39023339613 also passed.

A real-engine widget test caught an unsendable widget-closure transfer and premature ready status. Text conversion now uses top-level compute callbacks; ready is reported only after the editor transfer settles. Cancellation clears cancellation-only error text, keeps old edited text, and waits for cleanup.

The new Linux integration workflow initially needed an unavailable job-level runner context corrected, then an unused-import analysis fix. Run 39023943472 targeting 96686d1 passed all integration/build/startup steps. Artifact 12098096286 was independently checked against outer SHA-256, ZIP CRC, native inventory, all model/license hashes, provenance and its eight-second window startup report; see evidence/experimental-ocr-build-96686d1.json. The workflow explicitly downloads pinned development models; normal application use and the local staging helper never download. Models ship with Apache-2.0 LICENSE and provenance. `/usr/bin/tesseract` remains a system runtime prerequisite and is not bundled.

Model discovery without UST_OCR_TESSDATA also passed through the real Rust CLI using the same executable-parent lookup; output bytes/hash and original preservation are recorded in evidence/ocr-integration-20261017.json. OCR home search/copy corrections passed the four home/workspace tests and clean analysis. Exact next action: integrate this verified slice into main, inspect its Linux/Windows/Android build gates and independently verify each new artifact. Persist the verified new bundle separately from older saved stable builds. Continue the full requirements checklist after this slice; no phase approval is needed.

See ADR-008-offline-ocr.md, OCR-IMPLEMENTATION.md, OCR-ASSETS.md. Models are from official tessdata_fast commit 87416418657359cb625c412a48b6e1d6d41c29bd. The staging helper accepts only checksum-verified local files and refuses existing destinations. System engine redistribution/audit on all platforms, local model import/retention, abnormal-exit temp cleanup, hard parser isolation and broader accuracy/resource/device gates remain open.

## Recovery details

GitHub is authoritative; user messages have repeatedly reset the scratch checkout/toolchains. Read the remote branch before changing files and push source checkpoints frequently. The active checkout is universal-studio-current, not the older skeleton. Local Rust 1.99.0 now works after replacing a damaged installed LLVM library with the original bytes from the verified official archive. Local debugger ptrace was denied; no restriction was bypassed. SDKs remain transient; hosted builds provide independent evidence.

## Remaining launch work and blockers

OpenCV boundary/perspective/deskew and face assistance; Windows/Android OCR engines and searchable-PDF geometry; manual signature refinement/storage/PDF placement; remaining PDF forms/watermarks/numbering/compression/OCR geometry; flexible photo constraints and fuller print controls; editable application packs and managed cross-studio sources; drag/drop, complete localization, screen-reader/focus/reduced-motion/large-text checks and representative usability; hard isolation for PDF parsers; clean-device/runtime and full transitive license clearance; AppImage and production APK signing. Unchecked requirements are retained, not removed from scope.

PDF parsing remains in-process and is a production blocker. No perfect OCR, passport acceptance, universal compatibility, secure erasure or commercial-product parity claim.
