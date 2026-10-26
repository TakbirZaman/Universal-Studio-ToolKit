# Universal Studio Toolkit

**Direct downloads:** [Windows ZIP](https://github.com/TakbirZaman/Universal-Studio-ToolKit/releases/download/dev-1f50491c/Universal-Studio-Toolkit-1f50491c-Windows.zip) · [Linux bundle](https://github.com/TakbirZaman/Universal-Studio-ToolKit/releases/download/dev-1f50491c/Universal-Studio-Toolkit-1f50491c-Linux.tar.gz) · [Android APK](https://github.com/TakbirZaman/Universal-Studio-ToolKit/releases/download/dev-1f50491c/Universal-Studio-Toolkit-1f50491c-Android.apk)

Development preview · [Install / Android upgrade notes](https://github.com/TakbirZaman/Universal-Studio-ToolKit/releases/download/dev-1f50491c/INSTALL.txt) · [SHA-256 checksums](https://github.com/TakbirZaman/Universal-Studio-ToolKit/releases/download/dev-1f50491c/SHA256SUMS)

**Prepare photos, signatures, scans, PDFs and application packs locally on Windows, Linux and Android.**

[![Linux CI](https://github.com/TakbirZaman/Universal-Studio-ToolKit/actions/workflows/verify-linux.yml/badge.svg)](https://github.com/TakbirZaman/Universal-Studio-ToolKit/actions/workflows/verify-linux.yml)
[![Windows CI](https://github.com/TakbirZaman/Universal-Studio-ToolKit/actions/workflows/build-windows.yml/badge.svg)](https://github.com/TakbirZaman/Universal-Studio-ToolKit/actions/workflows/build-windows.yml)
[![Android CI](https://github.com/TakbirZaman/Universal-Studio-ToolKit/actions/workflows/build-android.yml/badge.svg)](https://github.com/TakbirZaman/Universal-Studio-ToolKit/actions/workflows/build-android.yml)

[Download](#download) · [Features](#features) · [Build from source](#build-from-source) · [Documentation](#documentation) · [Contributing](#contributing)

> **Development preview.** The implemented workflows are tested and packaged, while the full product remains in active development. See [project status](PROJECT_STATUS.md) and [known limitations](docs/LIMITATIONS.md) before relying on a build for a specific workflow.

## Download

These direct links download the verified **`dev-1f50491c`** development builds from GitHub Releases.

| Platform | Architecture | Direct download | Installation |
| --- | --- | --- | --- |
| Windows | x64 | [Download Windows ZIP](https://github.com/TakbirZaman/Universal-Studio-ToolKit/releases/download/dev-1f50491c/Universal-Studio-Toolkit-1f50491c-Windows.zip) | Extract the complete ZIP; run `universal_studio_toolkit.exe`. |
| Linux | x64 · Ubuntu 24.04 build | [Download Linux bundle](https://github.com/TakbirZaman/Universal-Studio-ToolKit/releases/download/dev-1f50491c/Universal-Studio-Toolkit-1f50491c-Linux.tar.gz) | Extract; run `./universal_studio_toolkit` with its adjacent `lib` and `data` folders. Requires a compatible GTK3 runtime. |
| Android | ARM64 | [Download Android APK](https://github.com/TakbirZaman/Universal-Studio-ToolKit/releases/download/dev-1f50491c/Universal-Studio-Toolkit-1f50491c-Android.apk) | Install the development APK on a compatible ARM64 device. |

[Release notes](https://github.com/TakbirZaman/Universal-Studio-ToolKit/releases/tag/dev-1f50491c) · [Installation guide](https://github.com/TakbirZaman/Universal-Studio-ToolKit/releases/download/dev-1f50491c/INSTALL.txt) · [SHA-256 checksums](https://github.com/TakbirZaman/Universal-Studio-ToolKit/releases/download/dev-1f50491c/SHA256SUMS)

**Android upgrade note:** development builds use disposable signing identities. If an older install cannot be updated in place, export saved presets as JSON and scan drafts as PDFs before uninstalling it. Uninstalling removes app-local data. Stable production signing and update distribution remain unfinished.

The download source is [`1f50491c`](https://github.com/TakbirZaman/Universal-Studio-ToolKit/commit/1f50491c5cbf0f92c89e8a76e9387b2824e39b7d). Release assets are separate from temporary Actions artifacts, which expire after three days.

## Features

| Workspace | Implemented capabilities |
| --- | --- |
| **Photo Studio** | JPEG/PNG resize, orientation correction, visual cropping, exact pixel and physical dimensions, horizontal/vertical recipe flips, measured compression, reusable recipes and batch recovery. |
| **Image inspection** | Original/prepared comparison, preview zoom up to 8×, pan, reset, and transparency backgrounds. Previews are bounded to 1200 pixels. |
| **Signature tools** | Plain-background cleanup and transparent PNG export with light, dark and checkerboard previews. |
| **PDF tools** | Combine, select, reorder, rotate and split supported PDFs; render pages, export PNGs, extract existing text, add visible page numbers and ASCII watermarks, and apply supported lossless structural optimization. |
| **Scanner Studio** | Import page images, adjust appearance, review boundaries, set corners, manually straighten, reorder pages and save recoverable drafts before PDF export. |
| **Application packs** | Required/optional image and PDF slots, measured constraints, JSON presets, an explicit local preset catalogue, verified ZIP exports, selective retry and checkpoint stop/resume. |
| **Print layouts** | Standard/custom paper sizes, physical photo dimensions, margins, spacing, copies, cutting guides and optional DPI resampling. |
| **Experimental Linux OCR** | Offline English/Bangla/mixed recognition with verified local models, system Tesseract and editable UTF-8 text export. |

See the [workflow guide](docs/WORKFLOWS.md) for step-by-step instructions.

### Local processing and document handling

- No account, document-upload service or telemetry is implemented.
- Processing runs through the native Rust engine; original inputs are preserved.
- Save copies to an explicit destination. Desktop exports refuse existing filenames.
- Retained pack documents are session-only; saved presets contain requirement settings, not selected document bytes.
- Native parsing remains in-process. Encoded-size quotas do not provide process-wide memory isolation.

Supported PDF operations reject protected or unsupported structures, including existing forms, annotations and signatures. ICC-profiled images are rejected pending validated colour management. Review the [format, resource and platform limits](docs/LIMITATIONS.md).

## Verification

The downloadable revision passed **12 CI workflows**:

| Check | Verified result |
| --- | --- |
| Native Rust suites | 95 tests on Linux; 93 on Windows |
| Flutter suites | 75 tests on Linux; 72 on Windows, with 3 platform-specific skips |
| Integration | Exact bridge regeneration; pack, preset, crop, flip, split and comparison regressions |
| Packaging | Windows ZIP, Linux bundle and Android APK checks; hosted desktop startup |
| Responsive journeys | Selected workflows tested at 390-pixel width and 100%/200% text scaling |

[Verification evidence](docs/evidence/image-inspection-20261027.json) records the source, workflow runs and package hashes. Screenshot baseline review, representative-user observation, clean-device testing, screen readers, printers and Android provider/camera acceptance remain outstanding.

## Build from source

The application uses **Flutter + Riverpod** for the interface and **Rust + flutter_rust_bridge** for processing, with native PDFium/OpenCV adapters and SQLite-backed settings.

Tested toolchains: **Flutter 3.47.7**, **Dart 3.13.5**, **Rust 1.99.0**, and **flutter_rust_bridge 2.13.0**. Dependency lockfiles are checked in.

```bash
git clone https://github.com/TakbirZaman/Universal-Studio-ToolKit.git
cd Universal-Studio-ToolKit
flutter pub get --enforce-lockfile
cargo build --locked --manifest-path rust/Cargo.toml
```

Native libraries and platform prerequisites must be staged before runtime tests or packaging. Follow the [development guide](docs/DEVELOPMENT.md) for Linux tests, scanner/OCR provisioning, bridge regeneration, Windows builds and Android signing. Building initially needs network access to obtain development dependencies; normal document processing does not.

### Repository structure

| Path | Responsibility |
| --- | --- |
| [`lib/`](lib) | Flutter interface, application workflows and typed Rust bindings |
| [`rust/`](rust) | Processing engine, validation, recipes, persistence and CLI |
| [`native/`](native) | Native adapter sources and platform integration inputs |
| [`test/`](test) | Flutter workflow and integration tests |
| [`scripts/`](scripts) | Packaging, provisioning, verification and notices |
| [`docs/`](docs) | Architecture decisions, evidence, requirements and limitations |
| [`third_party/`](third_party) | Dependency inventories, license texts and notices |

## Documentation

- [Project status](PROJECT_STATUS.md) and [remaining launch work](docs/REMAINING-WORK.md)
- [Workflow guide](docs/WORKFLOWS.md) and [development guide](docs/DEVELOPMENT.md)
- [Architecture](docs/ARCHITECTURE.md) and [requirements](docs/REQUIREMENTS.md)
- [Android builds](docs/ANDROID_BUILD.md), [OCR assets](docs/OCR-ASSETS.md), and [recovery](docs/RECOVERY.md)
- [Dependency review](docs/DEPENDENCIES.md) and [verification checkpoints](docs/CHECKPOINT.md)

Windows/Android OCR, searchable PDF geometry, advanced PDF/form/signature tools, persistent managed documents, localization, broader accessibility, worker isolation and production distribution are still in development. The roadmap tracks these separately from implemented features.

## Contributing

Open an [issue](https://github.com/TakbirZaman/Universal-Studio-ToolKit/issues) with your platform, architecture, build revision, reproduction steps and expected result. Use synthetic or redacted sample documents; avoid sharing personal files.

For code changes, keep the existing validation and no-overwrite behavior, update relevant documentation, and run the appropriate native/Flutter checks. Public Rust API changes must include genuinely regenerated bindings. See the [development guide](docs/DEVELOPMENT.md).

## License

Project code is provided under the [MIT License](LICENSE). Third-party components retain their own licenses and notices in [`third_party/`](third_party). Keep those notices with redistributed builds; complete native/transitive redistribution review remains tracked in [dependency decisions](docs/DEPENDENCIES.md).
