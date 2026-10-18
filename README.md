# Universal Studio Toolkit

Prepare photos, signatures, scans and PDFs locally. This is a working development build, **not the completed launch release**. See `docs/STATUS.md`, `docs/REQUIREMENTS.md` and `docs/LIMITATIONS.md` for exact implementation and platform evidence.

## Implemented workflows

- Resize JPEG/PNG images to exact pixels or physical mm/DPI dimensions with fit or crop, EXIF normalization, explicit transparency handling and measured size constraints.
- Clean a plain signature background and export transparent PNG.
- Combine, select, reorder and rotate supported PDF pages; render previews and export page PNGs using bundled PDFium.
- Import scan images, reorder pages, adjust brightness/contrast, rotate, apply grayscale or black-and-white, and produce PDF through bounded sequential page preparation. Quality warnings are advisory.
- Lay out repeated photos on an A4 print sheet with validated physical dimensions.
- Prepare the example photo/signature/certificate application ZIP with a validation report and hashed manifest.
- Save copies without overwriting existing files. SQLite stores theme/settings; history is disabled by default.

No account, service endpoint, telemetry or document upload is implemented. Processing uses the native Rust engine through typed asynchronous Flutter bindings. Original inputs are not modified.

Android delegated camera capture is compiled but still needs device validation. Perspective correction, platform-complete OCR, advanced PDF tools and editable pack presets remain unfinished. Saved photo recipes, batch retry and scan draft recovery are implemented. Existing forms, annotations, signatures and other unsupported PDF structures are rejected rather than silently discarded. ICC-profiled images are rejected pending validated colour management.

## Linux development bundle

When included in the delivery archive, extract `dist/universal-studio-linux-x64.tar.gz` into an empty folder, keep its `lib` and `data` directories beside the executable, then run `./universal_studio_toolkit`.

Built on Ubuntu 24.04 x86_64. Requires a graphical session and the usual GTK 3, GL/EGL, GLib, fontconfig and C/C++ runtime libraries. The packaged application created a window and survived an eight-second startup check on the Ubuntu build host. Clean-machine verification remains outstanding. Do not infer support for all Linux distributions.

`UST_PORTABLE=1 ./universal_studio_toolkit` requests settings storage in `studio-data` beside the executable. A non-writable folder currently falls back to application support storage; the Appearance and privacy dialog explains the fallback. Documents are saved only to the destination you select.

Windows x64 portable ZIP and Android ARM64 APK packaging pass their hosted workflows. Windows packaged-window startup passed on the build host. Android device/camera/document-provider behavior remains unverified. The debug APK is installable for development; an optimized release-mode APK is also installable with an explicitly temporary development identity. Production signing remains separate. No private signing key is included.

## Build and test

Tested toolchains: Flutter 3.47.7 / Dart 3.13.5, Rust 1.99.0, flutter_rust_bridge 2.13.0. Lockfiles are included. Building initially requires downloading development dependencies; normal processing does not.

```sh
export CI=true FLUTTER_SUPPRESS_ANALYTICS=true
flutter pub get --enforce-lockfile
cargo build --locked --manifest-path rust/Cargo.toml
export UST_PDFIUM_LIBRARY="$PWD/native/linux-x64/libpdfium.so"
cargo test --locked --manifest-path rust/Cargo.toml
# Approved visual baselines remain pending; run behavioral/native tests separately.
flutter test $(find test -name '*_test.dart' ! -name 'visual_test.dart' | sort)
flutter analyze
bash scripts/build_linux.sh
```

Install Flutter's Linux development prerequisites (Clang, CMake, Ninja, pkg-config, GTK 3 headers). `scripts/linux_sysroot_environment.sh` is an optional environment helper for a locally unpacked development sysroot; development packages are not redistributed as application dependencies. `scripts/dev_environment.sh` locates an adjacent development toolchain directory, optionally overridden by `UST_TOOLCHAIN_ROOT`. It is not needed to run the packaged application.

Regenerate bindings after Rust API changes using `flutter_rust_bridge_codegen generate` with the included configuration. Review generated changes and rebuild the native library before bridge tests.

## Command-line processing

`studio request.json` processes one request and prints actual output measurements as JSON. Example merge request:

```json
{"operation":"pdf","inputs":["first.pdf","second.pdf"],"directory":"output","filename":"combined.pdf","pages":null,"rotation":0}
```

Create the destination directory first. A file with the same name causes an error. A page list such as `[3,1,2]` selects/reorders pages in the combined input sequence. Pages are one-based.

## Verification and notices

`docs/evidence` contains test logs and independent output checks; `verification-outputs` contains synthetic examples, not user documents. `third_party` contains dependency license texts, inventory and native PDFium notices. Collection is not the same as complete redistribution/legal clearance; outstanding review is tracked in `docs/DEPENDENCIES.md`. Keep all notices with redistributed builds.

No representative user tests, accessibility certification, clean-device compatibility or full feature parity are claimed. Start further implementation at `docs/CHECKPOINT.md`.

### Lossless PDF optimization (CLI)

Use a request with `operation: "optimize_pdf"`, `input`, `directory`, and `filename`. This uses supported structural optimization only, never rasterizes, and keeps the original bytes if rewriting does not reduce size. Existing conservative PDF structure/protection checks apply. The Combine PDFs workspace exposes an opt-in lossless optimization control. It reports actual output size and never silently rasterizes.

### Hosted development builds

Open the repository Actions tab and select a successful Linux run to download its development artifact. Extract the ZIP, verify SHA256SUMS, then extract the contained tar.gz and run `./universal_studio_toolkit`. The executable needs its adjacent `lib`, `data`, and notices folders. These are development bundles, not clean-device-certified releases. Artifacts expire after three days; a new workflow run reproduces them.

The Android workflow produces an installable debug-signed ARM64 APK, an unsigned release candidate and an optimized development-signed release APK. The unsigned candidate requires signing; the development-signed APK is for testing and is not a production signing identity. Debug keys can differ across builds; uninstalling to resolve a signing mismatch deletes app-local drafts/settings. No keystore or signing credentials are stored in this repository.

### Experimental offline OCR (Linux)

The Linux OCR integration adds typed English/Bangla/mixed recognition, truthful job states/cancellation and an editable plain-text result screen in Scanner Studio. Its entry is available only with verified local models and `/usr/bin/tesseract`. Current Windows/Android OCR capability is false. This does not produce searchable PDFs.

Explicitly provision model files and their Apache-2.0 license as described in `docs/OCR-ASSETS.md`. `UST_OCR_MODEL_SOURCE=/absolute/local/models bash scripts/build_linux.sh` verifies and stages them beside the executable. Normal application processing never downloads anything. The system Tesseract engine remains a runtime prerequisite; it is not bundled. Recognition is approximate: review the result before saving a UTF-8 `.txt` copy. See `docs/CHECKPOINT.md` for the latest test/build evidence and remaining platform work.
