# ADR 008 — capability-gated Linux OCR and typed job ownership

Status: implemented in the experimental branch; cross-platform completion pending.

Use the existing Rust byte-source boundary for OCR. The first adapter launches the fixed system `/usr/bin/tesseract` without a shell, using verified private copies of pinned English/Bangla tessdata_fast models and normalized image bytes. Input/recipe JSON cannot select an executable or engine arguments. Use OEM 1, bounded image decoding, one processing slot, child CPU/address-space/file/time limits and cleanup-before-return. These limits do not establish a filesystem or network sandbox.

A single-use opaque FRB handle owns cancellation and a small synchronized state. Synchronous state/cancel calls perform only short mutex/atomic work; recognition and UTF-8 validation use asynchronous worker calls. Cancellable queue acquisition must not wait for unrelated running jobs. Accepted cancellation wins completion races; engine shutdown/reaping precedes a cancelled return. Dropping a Dart wrapper alone is not cancellation.

Expose only English, Bangla and mixed language enum values. Expose the Scanner Studio entry only when the Linux engine path exists and all pinned model/license hashes validate. This presence check is not an engine-version or representative-accuracy certification; tested versions are recorded in evidence. Keep Windows and Android capability false until their adapters, libraries, licenses and device behavior are verified.

Use top-level Dart worker functions for UTF-8 transfers. Closures in a widget's asynchronous method can capture unsendable state; the real-engine widget test caught that failure. Do not report “ready” merely because the Rust engine finished: the editor must be populated first. Keep recognized text editable, preserve prior text after retry failure and validate the actual edited UTF-8 bytes before the shared non-clobber save service.

Stage models only from explicitly supplied local files during packaging; the development CI fetch is visible and checksum pinned. Retain Apache-2.0 license/provenance. Do not silently download at runtime. The system engine is not bundled yet, so the experimental OCR bundle has a declared runtime prerequisite. Model import UI, transitive engine redistribution and orphaned-temp retention still need work.

This output is plain text. Searchable PDFs remain unavailable until geometry, coordinate transforms and reading order have independent tests. The small synthetic English/Bangla tests demonstrate integration, not general scan accuracy or handwriting support.
