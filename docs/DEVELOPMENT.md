# Development guide

Run commands from the repository root. Use the pinned SDK versions and checked-in lockfiles; see the platform workflows for the complete hosted provisioning sequence.

## Toolchains

| Component | Tested version |
| --- | --- |
| Flutter | 3.47.7 |
| Dart | 3.13.5 (included with the pinned Flutter SDK) |
| Rust | 1.99.0 |
| flutter_rust_bridge | 2.13.0 |

Building initially downloads development dependencies. Normal document processing runs locally.

## Linux build and tests

Install Clang, CMake, Ninja, pkg-config and GTK3 development headers. Provision PDFium and, for scanner geometry, the verified OpenCV adapter described below. The complete sequence is in [the Linux workflow](../.github/workflows/verify-linux.yml).

```bash
export CI=true FLUTTER_SUPPRESS_ANALYTICS=true
flutter pub get --enforce-lockfile
cargo build --locked --manifest-path rust/Cargo.toml
export UST_CORE_LIBRARY="$PWD/rust/target/debug/libstudio_core.so"
export UST_PDFIUM_LIBRARY="$PWD/native/linux-x64/libpdfium.so"
cargo test --locked --manifest-path rust/Cargo.toml
flutter analyze --no-pub
mapfile -t tests < <(rg --files test -g '*_test.dart' -g '!visual_test.dart' | sort)
flutter test --no-pub "${tests[@]}"
bash scripts/build_linux.sh
```

The three native scanner-adapter tests are ignored without explicit provisioning. After setting `UST_VISION_LIBRARY` to the verified adapter, run Cargo tests with `-- --include-ignored` as CI does. Linux OCR tests also require verified models, Tesseract and synthetic fixtures; follow the Linux workflow and [OCR assets guide](OCR-ASSETS.md). Missing runtime libraries are not a passing platform acceptance result.

Visual tests currently produce captures. Approved baseline review is pending, so a capture-only run does not establish visual regression coverage.

## Windows and Android

Use [the Windows workflow](../.github/workflows/build-windows.yml) for native staging, runtime DLLs, tests and portable ZIP packaging. See [Android development builds](ANDROID_BUILD.md) for SDK/NDK versions, ARM64 packaging, manifest checks and disposable development signing. Keep production signing keys outside the repository.

## Native scanner provisioning

The three platform CI workflows explicitly build and verify the pinned narrow OpenCV adapter and stage it with complete retained notices. Normal application use never downloads an engine, model or source archive. Desktop packages run independent pixel checks on build hosts; Android receives structural/symbol/alignment checks and still requires device testing.

For a Linux development build, install CMake3.28.4/Ninja1.13.2/NumPy2.3.5/Pillow12.3.0, then run `python3 scripts/verify_vision_candidate.py --platform linux-x64 --work /your/development/work`. Set `UST_VISION_LIBRARY` to its `build/adapter/libust_cv.so` and `UST_VISION_BUILD_REPORT` to its `pixel-verification.json` before `bash scripts/build_linux.sh`. Both paths must refer to the same verified build. Native Rust tests require this explicit library and `cargo test --locked --manifest-path rust/Cargo.toml -- --include-ignored`; otherwise they report themselves as ignored. See ADR017–019 and docs/CHECKPOINT.md for precise source/build evidence.

## Experimental Linux OCR

The Linux OCR integration adds typed English/Bangla/mixed recognition, truthful job states/cancellation and an editable plain-text result screen in Scanner Studio. Its entry is available only with verified local models and `/usr/bin/tesseract`. Current Windows/Android OCR capability is false. This does not produce searchable PDFs.

Explicitly provision model files and their Apache-2.0 license as described in `docs/OCR-ASSETS.md`. `UST_OCR_MODEL_SOURCE=/absolute/local/models bash scripts/build_linux.sh` verifies and stages them beside the executable. Normal application processing never downloads anything. The system Tesseract engine remains a runtime prerequisite; it is not bundled. Recognition is approximate: review the result before saving a UTF-8 `.txt` copy. See `docs/CHECKPOINT.md` for the latest test/build evidence and remaining platform work.

## Typed Rust bridge

After changing a public Rust API, run `flutter_rust_bridge_codegen generate` using the included configuration. Commit the genuine generated output, rebuild the native library and run the bridge tests. The [bridge workflow](../.github/workflows/generate-bridge.yml) checks regeneration consistency.

## Command-line interface

`studio request.json` processes one request and prints actual output measurements as JSON. Example merge request:

```json
{"operation":"pdf","inputs":["first.pdf","second.pdf"],"directory":"output","filename":"combined.pdf","pages":null,"rotation":0}
```

Create the destination directory first. A file with the same name causes an error. A page list such as `[3,1,2]` selects/reorders pages in the combined input sequence. Pages are one-based.

## Dependency notices

`docs/evidence` contains test logs and independent output checks; `verification-outputs` contains synthetic examples, not user documents. `third_party` contains dependency license texts, inventory and native PDFium notices. Collection is not the same as complete redistribution/legal clearance; outstanding review is tracked in `docs/DEPENDENCIES.md`. Keep all notices with redistributed builds.

No representative user tests, accessibility certification, clean-device compatibility or full feature parity are claimed. Start further implementation at `docs/CHECKPOINT.md`.

## Publishing the verified development preview

[The development publisher](../.github/workflows/publish-development.yml) retrieves the exact successful source checks and original CI artifacts recorded in the verification evidence. It checks package sizes and SHA-256 values before publishing the versioned prerelease assets. It does not rebuild or replace binaries and does not overwrite an existing release. Normal platform CI jobs retain read-only repository permissions; the publisher alone requests contents-write and actions-read permissions.

Future releases need a reviewed source/evidence record, installation notes, package hashes and a new immutable version tag. Do not relabel development signing as production signing.
