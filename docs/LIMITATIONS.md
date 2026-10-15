# Known limitations — not launch complete

- This checkpoint is partial software, not full iLovePDF/CamScanner parity or a production release.
- Core Linux tests do not establish Windows or Android compatibility. No clean-device validation.
- PDFium and SQLite are now integrated on the tested Linux host. OpenCV and Tesseract are not integrated. No OCR, camera capture, perspective correction, face detection or draft recovery yet. SQLite theme persistence is implemented; history recording remains off in the UI.
- PDF manipulation rejects unsupported structures; no forms, annotations, bookmarks, attachments, digital signatures, optional content or tagged documents. Only page manipulation of supported simple PDFs is offered. No render/appearance guarantee for arbitrary PDFs.
- PDF parsing is in-process. Encoded-size, page-count, object-count and nesting checks do not provide hard protection against decompression bombs or parser resource exhaustion. Process isolation is a production blocker.
- Photo inputs are JPEG/PNG, up to 24 megapixels/64 MiB. ICC profiles are rejected rather than silently changed; unprofiled pixel data is assumed sRGB. PNG gamma/chromaticity policy needs fuller validation. No flexible-dimension compression yet.
- Background removal is a brightness threshold for plain backgrounds, not ML segmentation; no manual refinement UI. Dark backgrounds and shadows may need external correction.
- No secure redaction, encryption/unlocking, certificate-backed signing, Word conversion, remote AI, cloud synchronization or monetization.
- Declarative recipes/core batches and print layouts exist; full editing/persistence/retry interfaces remain.
- Application pack UI is an explicitly unverified example with fixed photo/signature geometry. It does not claim compliance with any official application.
- Android content-provider saving source is implemented but not built/device-tested. Camera permission flows are pending. Desktop save-copy is tested.
- Linux GUI release bundle compiles and its release bridge passes tests. Native GUI launch is blocked in this environment by display socket restrictions. Windows and Android builds remain unverified.
- History/signature retention is not enabled; reusable local signature storage is not implemented. No promise of physical secure erasure.
