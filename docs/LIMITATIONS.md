# Known limitations — not launch complete

- This checkpoint is partial software, not full iLovePDF/CamScanner parity or a production release.
- Core Linux tests do not establish Windows or Android compatibility. No clean-device validation.
- PDFium and SQLite are now integrated on the tested Linux host. OpenCV and Tesseract are not integrated. No OCR, perspective correction or face detection yet. Manual Android camera capture compiles through a scoped system-camera adapter, but device behavior remains unverified. Local scan draft recovery is implemented. SQLite theme persistence is implemented; history recording remains off in the UI.
- PDF manipulation rejects unsupported structures; no forms, annotations, bookmarks, attachments, digital signatures, optional content or tagged documents. Only page manipulation of supported simple PDFs is offered. No render/appearance guarantee for arbitrary PDFs.
- PDF parsing is in-process. Encoded-size, page-count, object-count and nesting checks do not provide hard protection against decompression bombs or parser resource exhaustion. Process isolation is a production blocker.
- Photo inputs are JPEG/PNG, up to 24 megapixels/64 MiB. ICC profiles are rejected rather than silently changed; unprofiled pixel data is assumed sRGB. PNG gamma/chromaticity policy needs fuller validation. No flexible-dimension compression yet.
- Background removal is a brightness threshold for plain backgrounds, not ML segmentation; no manual refinement UI. Dark backgrounds and shadows may need external correction.
- No secure redaction, encryption/unlocking, certificate-backed signing, Word conversion, remote AI, cloud synchronization or monetization.
- Declarative recipes/core batches and print layouts exist; editing/persistence and serial batch retry interfaces are implemented; broader recipes remain.
- Application pack UI is an explicitly unverified example with fixed photo/signature geometry. It does not claim compliance with any official application.
- Android content-provider saving compiles in the built APK but is not device-tested. Camera cancellation/denial and activity-recreation flows need device testing. Desktop save-copy is tested.
- Linux GUI release bundle compiles and its release bridge passes tests. Packaged Linux GUI startup passed on an Ubuntu 24.04 hosted virtual display; local display restrictions still prevent interactive inspection here. Windows ZIP and Android APK builds passed hosted gates. Windows startup created a window; clean-device and complete interactive workflows remain unverified.
- History/signature retention is not enabled; reusable local signature storage is not implemented. No promise of physical secure erasure.
