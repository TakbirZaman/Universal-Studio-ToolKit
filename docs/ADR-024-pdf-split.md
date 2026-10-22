# Independent PDF parts and selective recovery

2026-10-22. The PDF workspace can send its prepared result, or selected original when no prepared result exists, to a dedicated split screen. Each part has an independent ordered one-based page group and filename. Comma-separated pages and ascending ranges are expanded without sorting. Empty, malformed, out-of-range and repeated pages within a part are rejected before processing. Separate parts may overlap intentionally.

The existing native combine/arrange API produces each part without rasterizing. Its existing unsupported/protected-structure rejection remains authoritative. Original/source and prepared-part previews use the guarded PDF renderer. This does not add form support, signature preservation, thumbnails for dragging, or searchable OCR export.

Preparation runs sequentially. Successful parts remain available when another part fails; preparing unfinished parts skips successful outputs. Editing one page group invalidates only that part's output and saved receipt. Renaming only resets its receipt. Individual retries and saves remain available. Export uses the common native validation, platform destination picker and no-clobber path. Cancelling a destination keeps the prepared output available.

The screen owns a source copy for its route lifetime. It holds at most 32 parts and 64 MiB of prepared outputs, has no persistent catalogue, and disables mutation/navigation during native processing and saving. These retained-byte bounds are not whole-process memory isolation. Removing parts or leaving the screen releases owned references for collection.

Focused tests cover ordered range parsing, boundary/malformed inputs and real native split/save journeys at 100% and 200% text scale. Saved PDFs are reopened for text/order checks; successful parts survive failed peers; filename collision preserves the saved bytes. Complete platform, bridge and notice checks gate integration.
