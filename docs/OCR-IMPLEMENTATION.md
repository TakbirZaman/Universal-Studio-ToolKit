# Experimental offline OCR adapter

This source is on work/offline-ocr. It is not in the downloadable GUI checkpoint 98dbeac. Flutter OCR controls, engine/model bundling and Windows/Android OCR are not implemented.

The Linux Rust CLI now supports the `ocr` operation with `language` set to `english`, `bangla` or `mixed`. It accepts only the fixed system executable /usr/bin/tesseract. No recipe or request can supply shell commands or executable paths. The engine reads only newly verified model copies in the private job directory, preventing replacement of imported model files after verification. Set UST_OCR_TESSDATA to a local directory holding the pinned eng.traineddata, ben.traineddata and LICENSE in OCR-ASSETS.md; normal recognition performs no downloads.

Example request fields: operation=ocr, input=page.png, directory=an existing output folder, filename=recognized.txt, language=bangla. Invoke the built studio executable with a JSON request file. The shared export service verifies UTF-8 and actual bytes and never overwrites an existing output.

Processing normalizes the image through the bounded Rust JPEG/PNG decoder, writes a fresh PNG in a private per-job temporary directory, verifies the exact local model hashes, runs Tesseract without a shell, and validates non-empty UTF-8 output below 4 MiB. Original files stay unchanged. OCR is approximate; review/edit the text. No searchable PDF or text-position claim.

Linux child limits: 768 MiB address space, CPU soft/hard 30/31 seconds, output-file size 4 MiB, core dumps disabled, one OpenMP thread, 60 seconds wall time. Cancellation checks before processing and while waiting; cancellation/error kills and waits for the owned child before the temporary directory is deleted. No instantaneous-cancellation or full sandbox claim. PDF parsing remains in-process and is a separate production blocker.

Local Rust suite: 32 tests, including five new boundary/schema tests (verification log records the actual run). Tests cover corrupt models, non-blocking pipe/device rejection, pre-cancellation, Unicode UTF-8 export, invalid encoding/metadata and existing-file preservation. Real Linux CLI recognition on clean synthetic English and Bangla phrases is recorded in evidence/rust-ocr-cli-smoke.json. Engine tests use Tesseract 5.3.4; OS process sampling was unavailable, so configured limits and actual memory-usage measurements are not conflated.

The local Rust SDK initially failed with SIGBUS because its installed LLVM library differed from the checksum-verified distribution archive. Restoring the original bytes fixed the compiler. Debugger ptrace was denied and no restriction was bypassed. Hosted compilation remains the separate platform check.

Next: inspect the experimental core CI on Linux and Windows; fix failures; add typed asynchronous OCR/capability APIs and regenerate FRB bindings; stage verified local models with their license into the Linux bundle; add an editable-result screen only where the engine is available. Keep unavailable platform controls hidden. Package/audit native engines for Windows/Android separately. Add cancellation, timeout, resource and representative printed-document evaluations before launch claims.

The child also requests parent-death termination and no-new-privileges on Linux. This is process hardening, not a full filesystem/network sandbox. Normal cancellation cleans the job directory; parent/process crashes can leave a private temporary directory, so startup cleanup/retention remains a launch gate.
