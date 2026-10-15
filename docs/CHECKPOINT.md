# Implementation checkpoint — 2026-10-15

The full requested scope is retained in REQUIREMENTS.md. This is an interim engineering delivery, not launch completion. No user approval is needed for ordinary next implementation tasks.

## Completed and verified

- Rust photo pipeline: JPEG/PNG, orientation normalization, fixed dimensions, fit/crop, rotation/flip, bounded same-source measured compression, transparent PNG/simple signature cleanup, metadata policy and safe export.
- Supported PDF merge/select/delete/reorder/rotate, image PDF and print sheets; PDFium page previews and page-to-PNG ZIP export. Unsupported protected/complex structures reject explicitly.
- Scan page modes/brightness/contrast/rotation, advisory quality heuristics; immutable source and derived output.
- Application example pack, typed constraints, saved-output validation report/manifest/hashes.
- Safe declarative recipe engine, serial jobs/cancellation stages, partial batch results; SQLite settings/recipes/presets/minimal optional history.
- Flutter/Riverpod/typed FRB interface with real processing, responsive light/dark home, six task workspaces, PDF previews, output comparison and save-copy. Theme persistence and portable-mode storage status.
- Android content URI save adapter source with write/readback verification, no broad storage permission. NOT compiled or device-tested.
- Linux release GUI bundle, Rust CLI and native libraries compiled. Release bridge tested with bundled libraries. Native desktop interaction remains blocked/unverified.
- 23 Rust integration tests; 6 Flutter tests; release native bridge separately; Flutter analysis clean. Synthetic output artifacts independently reopened and inspected with Pillow/pypdf/Poppler.
- 256 resolved dependency license files collected, font/icon and native PDFium notices present. This is an inventory, not final obligation clearance.

## Delivered files

`dist/universal-studio-linux-x64.tar.gz`: relocatable Linux GUI development bundle, runtime libraries/assets/notices. Keep all bundle contents together. Requires GTK 3 and graphics/system runtimes.

`dist/studio`: Linux x64 CLI. `README.md` documents usage. `verification-outputs` holds synthetic samples. `docs/evidence` holds actual logs. Platform sources and lockfiles are included.

## Exact blockers

- Native Linux GUI launch: Xvfb cannot bind local/unix display sockets under the execution environment. No attempt to bypass this restriction. Need an ordinary permitted graphical desktop for interactive/export-dialog verification.
- Windows executable: no Windows compiler/runtime test environment used yet.
- Android APK: Android SDK/NDK and signing build integration not set up; Kotlin adapter uncompiled; no emulator/device/provider testing. Do not ship a debug-signed release as verified.
- OpenCV/Tesseract and English/Bangla traineddata: not integrated or audited. Camera capture, geometry correction and OCR are absent, not simulated.
- In-process document parsing does not enforce hard process memory/time limits; hostile PDF decompression is a production blocker.

## Next concrete action

Implement a photo recipe interface backed by existing `saveRecipe`, `listRecipes`, and `runRecipe` in `lib/src/rust/api.dart` / `rust/src/api.rs`. Start with a separate `lib/application/recipes.dart` screen reachable from Photo Studio. Support explicit save/duplicate/edit/import/export, schema validation through Rust, filename preview and non-clobber output. Do not silently omit current rotation/transparency settings from saved recipes: either extend the schema with tests or clearly restrict supported steps. Existing recipe engine supports resize → compress → remove_metadata → rename → export only; schema version 1, strict unknown-field rejection. Existing SQLite storage upserts names, so distinguish explicit update from creating a colliding recipe.

Then continue PLAN.md phases: scanner drafts and Android camera/native adapters; OpenCV perspective/deskew; photo crop/refinement/physical controls and flexible compression; batch/selective retry; editable application slots and managed cross-studio sources; offline OCR; remaining PDF tools; accessibility/localization/clean-device release gates.

## Reproduce current checks

Use the public commands in README.md. Original workspace convenience: source `scripts/dev_environment.sh`; it points to workspace-restored Rust and Flutter SDKs, not system paths. Optional local Linux sysroot is `../toolchains/linux-sysroot`; set `UST_SYSROOT` and source `scripts/linux_sysroot_environment.sh`. The sysroot was unpacked from checksum-verified official Ubuntu Noble package indexes; it is not part of the app bundle.

Rust 1.99.0, Flutter 3.47.7 / Dart 3.13.5, FRB 2.13.0. Set CI=true to disable SDK metadata detection/analytics. All application runtime processing remains local. Rust profile codegen-units=1 avoids an observed LLVM parallel codegen artifact issue. Restored release cache once needed targeted cargo clean for fdeflate/crypto-common/linux-raw-sys; final release build succeeded.

For release bridge checking set UST_CORE_LIBRARY to `build/linux/x64/release/bundle/lib/libstudio_core.so`, UST_PDFIUM_LIBRARY to the same bundle's libpdfium.so, then run `flutter test test/native_bridge_test.dart`.

## Remaining launch gates

All unchecked/partial REQUIREMENTS entries remain. In particular: Windows/Android release packaging; complete recipe/batch UI; PDF forms/watermarks/numbering/signature placement/compression/OCR geometry; crop/manual signature masks/face assistance; camera/perspective/deskew/recovery; editable application pack presets; shared managed sources; screen-reader/keyboard/drop/localization/reduced-motion/contrast tests; representative usability observation; isolated resource-limited parsers; full dependency obligations and clean-device runtime checks. No feature, platform, passport acceptance or OCR perfection claim beyond the evidence above.
