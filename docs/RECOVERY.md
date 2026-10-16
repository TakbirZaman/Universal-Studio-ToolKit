# Current checkpoint and exact next actions

GitHub is now the authoritative source checkpoint. The temporary workspace reset again; no source or toolchain should be assumed durable until pushed.

Hosted Linux verification succeeded at commit 2d080432cf78b3df7771875b0780b4661b0f963b (run 38861560809). Rust checks, Flutter analysis/behavioral tests, screen capture, release build, dependency resolution and bundle upload succeeded. Artifact 12029880512 contains the development Linux bundle and checksum; it expires 2026-10-19. Clean-device and interactive desktop validation remain outstanding. Golden captures are not regression tests because approved baseline uploads remain incomplete.

Transparent PNG checkerboard/light/dark backgrounds and local scan drafts have now been reconstructed in source. Drafts use bounded original byte copies, hash validation, versioned manifests, retention and guarded deletion; restoring damaged drafts leaves the current session unchanged. Fresh hosted verification of these recovered changes is pending.

Android's first hosted job failed because sdkmanager was not on PATH. The workflow now invokes it from the SDK's explicit command-line tools directory. Next: inspect the next Android run, fix build errors, verify the unsigned APK and device behavior; inspect the latest Linux run for the recovered draft and preview tests. Continue remaining scope in docs/REQUIREMENTS.md. Camera/OpenCV/OCR, advanced PDF tools, custom pack builder, Windows distribution, real-user accessibility and clean-device testing remain incomplete.
