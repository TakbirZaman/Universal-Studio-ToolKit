# Checkpoint — 2026-10-16 UTC

Full scope remains in REQUIREMENTS.md. This is functioning development software, not launch completion. Continue ordinary implementation without phase-by-phase approval.

## Stable application checkpoint

Application source 98dbeacac7c9e558205eb9bb8fc990594f122543 passed:
- Linux run 38943392106: 27 Rust tests, selected Flutter behavioral/native/contrast/keyboard tests, analysis, release bundle, library resolution and an eight-second packaged-window startup check on Ubuntu 24.04 x64.
- Windows run 38943392637: Rust/native Flutter tests, portable ZIP with release CRT provenance, packaged-window startup on the windows-2022 build host.
- Android run 38943392331: ARM64 debug-signed and unsigned release APKs; signature, native contents and ZIP/ELF 16 KiB checks. Device behavior is unverified.

All three downloads were independently checked against artifact SHA-256, ZIP CRC, native/font/notice inventories and desktop startup reports. Exact inner/outer hashes: evidence/development-builds-98dbeac.json. User-facing saved downloads are Universal-Studio-Windows-x64.zip, Universal-Studio-Linux-x64.tar.gz and Universal-Studio-Android-debug.apk. They include lossless PDF controls, keyboard shortcuts, guarded saves, distinct dark accents, original Android/Windows icons, scoped Android camera capture, scan drafts and licensed Bangla fallback typography. They do not include the experimental OCR adapter.

Golden rendering is capture-only; approved regression baselines remain unavailable. No representative users, clean-device workflows or accessibility certification have been claimed. Debug APK keys can differ between CI builds; uninstalling to resolve a signature mismatch deletes app-local data.

## Work in progress: work/offline-ocr

The experimental branch contains a real Linux Rust CLI Tesseract adapter, UTF-8 text validation/export, bounded model verification, private job staging and child limits. It uses only /usr/bin/tesseract; request/recipe files cannot specify executables or shell commands. It has no Flutter controls yet and no Windows/Android OCR engine packaging. See that branch's OCR-IMPLEMENTATION.md and rust-ocr-cli-smoke.json. The local full suite and actual English/Bangla CLI output checks are recorded separately; do not confuse those with app OCR support.

Exact next action: inspect Verify experimental OCR core on the branch (Linux and Windows compile/boundary tests). Fix failures. Then implement typed asynchronous OCR/capability APIs, regenerate FRB bindings with the pinned workflow, stage only checksum-verified local models and LICENSE for Linux, and add editable recognized-text results only where engine capability is available. Add truthful cancellation, resource/timeout tests, representative accuracy/performance checks and separately audited platform engine packaging before completion claims.

Models were checked from official tessdata_fast commit 87416418657359cb625c412a48b6e1d6d41c29bd. See OCR-ASSETS.md for all hashes and license requirements. Reproducible development-only engine smoke: scripts/verify_ocr_engine.py. No app or test helper silently downloads models.

## Recovery details

GitHub is authoritative; user messages have repeatedly reset the scratch checkout/toolchains. Read the remote branch before changing files and push source checkpoints frequently. The active checkout is universal-studio-current, not the older skeleton. Local Rust 1.99.0 now works after replacing a damaged installed LLVM library with the original bytes from the verified official archive. Local debugger ptrace was denied; no restriction was bypassed. SDKs remain transient; hosted builds provide independent evidence.

## Remaining launch work and blockers

OpenCV boundary/perspective/deskew and face assistance; OCR GUI and native engines; manual signature refinement/storage/PDF placement; remaining PDF forms/watermarks/numbering/compression/OCR geometry; flexible photo constraints and fuller print controls; editable application packs and managed cross-studio sources; drag/drop, complete localization, screen-reader/focus/reduced-motion/large-text checks and representative usability; hard isolation for PDF parsers; clean-device/runtime and full transitive license clearance; AppImage and production APK signing. Unchecked requirements are retained, not removed from scope.

PDF parsing remains in-process and is a production blocker. No perfect OCR, passport acceptance, universal compatibility, secure erasure or commercial-product parity claim.
