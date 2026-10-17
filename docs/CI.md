# Reproducible Linux verification

The Linux workflow uses a standard Ubuntu 24.04 GitHub-hosted runner on this public repository. It requires no paid CI or account credentials. Flutter and Rust versions, action revisions, and dependency lockfiles are pinned. Workflow token permissions are read-only.

The workflow runs the Rust integration suite (including PDFium), Flutter analyzer and behavioral/native bridge tests, then builds a portable Linux bundle with notices. It checks runtime library resolution on the build host and uploads only the bundle and checksum for three days. This does not establish clean-system compatibility or desktop usability.

Golden images were held from repository upload by automatic review. The visual job renders new screenshots as capture-only output; it is explicitly not a regression comparison. Screenshots and sample documents are not uploaded as workflow artifacts. Restore and review the original baselines before claiming golden-regression coverage on a fresh checkout.

Status: workflow authored; first hosted execution and bundle verification pending. Android and Windows pipelines remain separate future build gates.

An Android arm64 workflow is now authored separately. Its unsigned release output is development-only; artifact structure checks do not imply installability or device compatibility.

Windows pipeline: added a standard windows-2022 runner with pinned Flutter/Rust, checksum-verified Windows PDFium, Rust/native bridge tests and portable ZIP packaging. A procedural original four-studio icon avoids a missing external binary asset. Windows verification is pending the first run; no clean-system runtime claim is made.

Windows import-table inspection found required Microsoft CRT DLLs missing from the first ZIP. Packaging now stages only the official release redistributable CRT directory from the licensed Visual Studio installation, records hashes/versions, and includes a separate runtime notice. The rebuilt ZIP must be checked before claiming the dependency issue resolved. `dartjni.dll` also references JVM libraries; its actual load behavior on a clean Windows system remains to be tested before imposing or ruling out a Java prerequisite.

## Verified 2026-10-16 checkpoint

Commit 7257778 passed Linux run 38900451000, Windows run 38900451112 and Android run 38900451024. Both desktop bundles created windows in eight-second startup checks. Linux/Windows passed 26 Rust integration tests and selected Flutter behavioral/native tests. Android produced debug-signed and unsigned APKs with ABI, native inventory, signature and 16 KiB gates. This supersedes the earlier pending-build notes above; clean-system and interactive device acceptance remain outstanding.

The separate read-only bridge generation job pins cargo-expand 1.0.118 and FRB codegen 2.13.0, generates typed sources without upgrading dependencies, analyzes them and uploads only six allowlisted source files (including OCR language and job-state enums) in JSON. Generated output must be reviewed and committed before treating a clean checkout as equivalent to that build.

## Experimental OCR integration gate

`verify-ocr-flutter.yml` runs only on the experimental OCR branch. It explicitly fetches pinned development models and LICENSE, verifies their hashes, creates ephemeral synthetic English/Bangla pages, tests the actual native Flutter bridge/editor, and builds a Linux bundle with verified local model staging. The engine remains an Ubuntu system prerequisite, not a bundled dependency. Artifacts contain the application/model/license bundle and startup evidence, never the synthetic pages or OCR text. Local capture-only visual checks use `test/ocr_visual_capture.dart` with explicit model/fixture environment variables; they do not establish golden regression coverage.
