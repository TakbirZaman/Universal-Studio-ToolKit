# Requirements checklist — full target retained
Legend: [x] verified core implementation; [~] partial / implementation in progress; [ ] remaining. Core checks do not imply UI or platform release completion. See STATUS.md and verification logs.

- [~] 1. Four integrated studios; original branding; Windows/Linux/Android.
- [~] 2. Offline/no account/no telemetry/no paid services; dependency and asset license audit; notices; preserve originals.
- [x] 3. Inspect/initialize repository and toolchains; requirements, matrix, ADRs, plan, limitations; continue runnable slices.
- [ ] 4. Goal-first UX; measurable discoverability and usability checks with real users.
- [~] 5. Light/dark tokens, studio accents, polished responsive controls, reduced motion and scaling.
- [~] 6. Home/search, desktop keyboard/drop, mobile navigation, preview/save/results with actual measurements.
- [~] 7. Accessibility semantics/focus/contrast/targets/localization; five first-use scenarios; heuristic + real-user review.
- [~] 8. Flutter/Riverpod/Rust/FRB; image/lopdf; PDFium/OpenCV/Tesseract/SQLite adapters and platform integration.
- [~] 9. Typed documents/constraints/recipes/jobs/results/manifests/capabilities; bounded concurrency; staged outputs; URI support.
- [~] 10. PDF merge/extract/delete/reorder/rotate/images-to-PDF/text extraction; split UI, thumbnails/rendering, page geometry, watermarks/numbers, signature placement, form filling, searchable export, three compression modes and interoperability.
- [~] 11. Camera and permissions, import, multipage sessions, manual corners/perspective/deskew, modes/adjustments, non-destructive recovery and quality advisories.
- [~] 12. JPEG/PNG, EXIF normalization, resize/rotate/flip, fit/fill/padding, compression, metadata and transparency; physical mm/DPI export with verified JFIF/pHYs density implemented and platform-packaged; full crop gestures, comparison and face suggestions remain; custom print layouts are implemented; numeric recipe crop and batch controls implemented.
- [~] 13. Fixed compression constraints, KB/KiB/strict/inclusive, bounded same-source search and actual validation; flexible dimensions remain.
- [~] 14. Threshold signature background removal and transparent export; manual refinement/consented storage/PDF placement remain; numeric crop and preview backgrounds implemented.
- [~] 15. Verified ZIP with report/manifest; typed slots and complete constraint enforcement, preset provenance, builder UI remain.
- [~] 16. Declarative safe recipe schema/order checks; per-item core results; recipe persistence/import-export and selective batch retry implemented; broader recipe types and collision workflows remain.
- [~] 17. Validated standard/custom paper, physical photo sizes, optional DPI resampling, margins, spacing, copies, cutting guides, real PDF preview/export and actual-size instructions implemented and tested locally; main10d platform packaging passed; actual printer acceptance remains.
- [~] 18. Experimental Linux English/Bangla/mixed OCR, editable text and pinned model/license verification implemented; platform-complete engines, searchable-PDF geometry, face ambiguity handling and representative evaluation remain.
- [ ] 19. Managed internal references across all studios; integrated workflows and explicit lifetimes.
- [~] 20. No overwrite, safe filenames, no content logs, bounds; process isolation, cleanup/recovery, optional history and retention settings remain.
- [x] 21. Advanced Word conversion, certificate signing, secure redaction/encryption, cloud and monetization excluded from current completion claims.
- [~] 22. Windows portable ZIP, Linux runnable/AppImage, Android release APK, runtime verification, storage fallback, signing guide.

Specific remaining checks: original-file hash unchanged; output hashes match ZIP; page order/rotation/appearance; cancellation timing; nested/malformed PDF resource exhaustion; oversized images; EXIF 1–8; transparent edges; Unicode normalization/case collisions; ICC/gamma handling; Android provider full/partial writes; text scaling 200%; keyboard-only use; screen-reader use; clean-device licenses and runtime dependencies.

Verified scanner slice 2026-10-18: sequential per-page preparation, cumulative encoded-image/final-PDF byte limits, bounded canonical previews, reordered/adjusted PDF appearance and Bangla-named export. 48 Rust tests and 25 selected Flutter tests passed for that slice; platform/device acceptance is tracked separately. See ADR-011.

Current main10d: custom print layouts and streamed image encoders are packaged on all three targets; 57 Rust/27 selected Flutter tests pass. Current PDF overlay candidate: core and independent saved-output checks pass after recovery; interface/platform verification is pending. This does not complete item10.

Integrated existing PDF text2026-10-19: bounded PDFium text-layer extraction, editable results and real Unicode UTF-8 export passed66 Rust/32 Flutter checks and all three platform packaging workflows. Reading order/font mappings require review; this does not implement OCR or searchable-PDF geometry. PDF page numbers/ASCII watermarks are also integrated and verified. Item10 remains partial for the remaining PDF scope.

Scanner geometry candidate2026-10-19: normalized Rust corner validation, lazy serialized OpenCV calls, real corrected PNG/preview/PDF outputs, manual/keyboard/slider editor, undo/reset, advisory suggestions and compatible draft recovery pass local core/UI checks (70 Rust/35 selected Flutter). Native Linux/Windows adapter pixel CI passes. Android integration, app staging/downloads, remaining source-license applicability checks, deskew/face assistance and representative/device acceptance remain; item11 is still partial.

Manual scanner straightening2026-10-20 is implemented locally through the existing validated corner/perspective path with explicit crop warnings and undo. Actual tilted-line PNGs and desktop/narrow200% workflows pass focused checks; native small previews retain their original dimensions/pixels. It is manual, not automatic angle detection. Scanner platform packaging and real device/user acceptance remain partial.
