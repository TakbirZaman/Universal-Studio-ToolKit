# ADR 007: delegated Android page capture

2026-10-16 — implementation awaiting hosted compilation and device acceptance.

Use the installed system camera through ACTION_IMAGE_CAPTURE with EXTRA_OUTPUT. FileProvider grants temporary access only to an app-private camera-captures cache directory. Do not request broad storage access or CAMERA permission: the camera app owns capture permission. Missing/denied camera access produces a recoverable error and image import remains available. No network processing is added.

Reuse AndroidX core FileProvider already present through the Flutter Android embedding; no new Dart or Rust dependency. Complete Gradle transitive version locking/license review remains a release gate. Do not mistake the existing Rust/Dart license inventory for complete Android dependency clearance.

Copy full-size JPEG bytes back on a worker, capped at 64 MiB, 24 MP and 12000 pixels per side. Preserve EXIF for Rust normalization. Delete the app-owned temporary copy and revoke grants after success/cancellation/error. Stale interrupted captures older than one day are cleaned when capture next starts. No user gallery originals are deleted.

Limitations: process death during the camera activity does not restore the pending Flutter call/session. Save a local draft before leaving for capture if the current work matters. Device camera implementations and deny/cancel/recreation flows still require physical/emulator testing. This is manual capture, not automatic stability detection or OpenCV correction.

Primary API sources consulted:
- https://developer.android.com/guide/components/intents-common (camera EXTRA_OUTPUT and returned full-size image)
- https://developer.android.com/reference/androidx/core/content/FileProvider (scoped content URI grants)
- https://developer.android.com/media/camera/camera-deprecated/photobasics (delegated camera permission behavior)

Adapter contract tests use a mocked channel only to verify cancellation/error/byte handling. They do not establish real camera behavior. Android compilation and device evidence must be reported separately.
