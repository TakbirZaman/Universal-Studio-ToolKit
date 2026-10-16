# Android development builds

Target: arm64-v8a, API 24+. This is a build configuration, not tested device compatibility.

Use Flutter 3.47.7, Rust 1.99.0 (aarch64-linux-android target), JDK 17, Android platform/build-tools 36, and NDK 28.2.13676358. The current staging/build script requires a Linux x86-64 host.

Download the non-V8 `pdfium-android-arm64.tgz` from the bblanchon/pdfium-binaries `chromium/8076` GitHub release. Set UST_PDFIUM_ANDROID_ARCHIVE to that local archive and ANDROID_HOME to the SDK, then run `bash scripts/build_android.sh`. The staging script checks SHA-256 b7a6919dc130dfdf7e409bd1762ed2a306408c4faee1173668837fc446217bf7 before extracting it. Downloads occur only in the explicit development workflow, never application document processing.

All collected notices are packaged as Android assets. Native libraries and copied assets are generated build inputs, excluded from Git. The workflow uses read-only repository permissions and short-lived development artifacts.

Release signing is not configured. The release APK is labelled unsigned and is not an installable production release. Configure your own private signing key outside the repository and back it up securely. Never commit keystores or passwords. Losing the signing key can prevent updates to installed releases.

Remaining gates: successful hosted APK build, signature verification, 16 KiB page-size compatibility, device startup, offline processing, camera, document-provider cancellation/partial writes, and clean-device validation. ARM64 Rust compilation alone does not satisfy these gates.
