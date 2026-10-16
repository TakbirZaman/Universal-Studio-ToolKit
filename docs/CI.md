# Reproducible Linux verification

The Linux workflow uses a standard Ubuntu 24.04 GitHub-hosted runner on this public repository. It requires no paid CI or account credentials. Flutter and Rust versions, action revisions, and dependency lockfiles are pinned. Workflow token permissions are read-only.

The workflow runs the Rust integration suite (including PDFium), Flutter analyzer and behavioral/native bridge tests, then builds a portable Linux bundle with notices. It checks runtime library resolution on the build host and uploads only the bundle and checksum for three days. This does not establish clean-system compatibility or desktop usability.

Golden images were held from repository upload by automatic review. The visual job renders new screenshots as capture-only output; it is explicitly not a regression comparison. Screenshots and sample documents are not uploaded as workflow artifacts. Restore and review the original baselines before claiming golden-regression coverage on a fresh checkout.

Status: workflow authored; first hosted execution and bundle verification pending. Android and Windows pipelines remain separate future build gates.

An Android arm64 workflow is now authored separately. Its unsigned release output is development-only; artifact structure checks do not imply installability or device compatibility.

Windows pipeline: added a standard windows-2022 runner with pinned Flutter/Rust, checksum-verified Windows PDFium, Rust/native bridge tests and portable ZIP packaging. A procedural original four-studio icon avoids a missing external binary asset. Windows verification is pending the first run; no clean-system runtime claim is made.
