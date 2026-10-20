# ADR 019: Application-pack recovery and actual export feedback

Date: 2026-10-20.
Status: implemented locally; focused core and responsive workflows pass; platform candidate pending.

The current pack remains an explicitly labelled example with three required slots. Previously a chosen slot could not be replaced, the preview showed only a generic icon, and a size/decoder failure did not identify its document. This made mistakes expensive to recover from.

A selected photo, signature or certificate can now be replaced individually. Cancelling selection retains all three documents and existing results. The combined import budget subtracts the replaced source before adding the new bytes. Labels distinguish slot roles. Original selected images/PDF pages have real canonical previews labelled as originals. No source is represented as a processed export.

The core names Photo, Signature or Certificate in preparation errors. A verified pack result lists actual archived filenames, bytes, dimensions/page counts alongside the existing ZIP verification. These measurements come from the same manifest entries whose archived bytes are reopened and hashed. There is no duplicate processing implementation in Dart.

Save failures appear beside the filename and save control with a live semantic region. Changing the filename clears stale save feedback without discarding the prepared output. Save remains no-clobber. A narrow/200% signature workflow exposed overflow in the preview-background dropdown; the expanded control now fits its available width while retaining full semantic text.

Checks substitute only operating-system file/directory dialogs. Real typed Rust processing and filesystem writes cover individual replacement, picker cancellation, existing-file recovery, Unicode ZIP save, exact archived measurements, transparent signature PNG and desktop/narrow dark200% layouts. Independent Python ZIP/Pillow/pypdf checks verify saved files and private-path omissions. This is a heuristic/automated review, not representative user observation. Editable/custom/optional slots, managed cross-studio sources and preset workflows remain outstanding.
