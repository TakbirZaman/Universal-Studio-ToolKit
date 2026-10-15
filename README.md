# Universal Studio Toolkit

Prepare photos, signatures, scans and PDFs locally. This is a working development build, **not the completed launch release**. See `docs/STATUS.md`, `docs/REQUIREMENTS.md` and `docs/LIMITATIONS.md` for exact implementation and platform evidence.

## Implemented workflows

- Resize JPEG/PNG images to exact pixel dimensions with fit or crop, EXIF normalization, explicit transparency handling and measured size constraints.
- Clean a plain signature background and export transparent PNG.
- Combine, select, reorder and rotate supported PDF pages; render previews and export page PNGs using bundled PDFium.
- Import scan images, reorder pages, adjust brightness/contrast, rotate, apply grayscale or black-and-white, and produce PDF. Quality warnings are advisory.
- Lay out repeated photos on an A4 print sheet with validated physical dimensions.
- Prepare the example photo/signature/certificate application ZIP with a validation report and hashed manifest.
- Save copies without overwriting existing files. SQLite stores theme/settings; history is disabled by default.

No account, service endpoint, telemetry or document upload is implemented. Processing uses the native Rust engine through typed asynchronous Flutter bindings. Original inputs are not modified.

Camera capture, perspective correction, OCR, advanced PDF tools, editable pack presets and the complete recipe/batch interface remain unfinished. Existing forms, annotations, signatures and other unsupported PDF structures are rejected rather than silently discarded. ICC-profiled images are rejected pending validated colour management.

## Linux development bundle

When included in the delivery archive, extract `dist/universal-studio-linux-x64.tar.gz` into an empty folder, keep its `lib` and `data` directories beside the executable, then run `./universal_studio_toolkit`.

Built on Ubuntu 24.04 x86_64. Requires a graphical session and the usual GTK 3, GL/EGL, GLib, fontconfig and C/C++ runtime libraries. The binary and its library resolution were checked in the build environment; desktop launch and clean-machine verification remain outstanding because display-server sockets were blocked there. Do not infer support for all Linux distributions.

`UST_PORTABLE=1 ./universal_studio_toolkit` requests settings storage in `studio-data` beside the executable. A non-writable folder currently falls back to application support storage; the Appearance and privacy dialog explains the fallback. Documents are saved only to the destination you select.

Windows and Android source projects are included, but no verified Windows executable or Android APK is supplied. The Android SAF save adapter still needs compilation and device/provider tests. Release signing must use a private key; no key is included.

## Build and test

Tested toolchains: Flutter 3.47.7 / Dart 3.13.5, Rust 1.99.0, flutter_rust_bridge 2.13.0. Lockfiles are included. Building initially requires downloading development dependencies; normal processing does not.

```sh
export CI=true FLUTTER_SUPPRESS_ANALYTICS=true
flutter pub get --enforce-lockfile
cargo build --locked --manifest-path rust/Cargo.toml
export UST_PDFIUM_LIBRARY="$PWD/native/linux-x64/libpdfium.so"
cargo test --locked --manifest-path rust/Cargo.toml
flutter test
flutter analyze
bash scripts/build_linux.sh
```

Install Flutter's Linux development prerequisites (Clang, CMake, Ninja, pkg-config, GTK 3 headers). `scripts/linux_sysroot_environment.sh` is an optional environment helper for a locally unpacked development sysroot; development packages are not redistributed as application dependencies. `scripts/dev_environment.sh` describes the original workspace only, not a portable installation path.

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

Use a request with `operation: "optimize_pdf"`, `input`, `directory`, and `filename`. This uses supported structural optimization only, never rasterizes, and keeps the original bytes if rewriting does not reduce size. Existing conservative PDF structure/protection checks apply. The desktop interface for this operation is pending.
