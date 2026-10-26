# Workflow guide

Practical instructions for the implemented studios. For current platform support and limits, see [project status](../PROJECT_STATUS.md) and [known limitations](LIMITATIONS.md).

## Custom application packs

Prepare Application includes a custom pack editor for required/optional image and PDF slots. Set each output filename, JPEG/PNG dimensions, optional strict KiB limit, and PDF page range. Review selected sources, prepare the ZIP, inspect measured results, and save a copy. Preset JSON contains settings only and can be exported/imported separately. The editor accepts one output format per slot and strict KiB limits; unsupported imported constraints are rejected. Image preparation uses fit/padding; signature cleanup remains a separate studio step.

Use **Keep for application pack** on a prepared studio or photo-recipe result to reuse it directly. Session documents are held only in memory, capped at 16 items/64 MiB, and can be removed in Prepare Application. Close the app to end the session. These controls do not save signatures permanently.

The CLI accepts `{"operation":"pack","preset":"preset.json","inputs":["photo.jpg",null],"directory":"output","filename":"application.zip"}`. Inputs follow preset slot order; `null` omits an optional slot. Every output must satisfy its constraints before the ZIP is written. The integrated feature passes native, UI, bridge and Windows/Linux/Android build checks. Development builds remain separate from production device acceptance and signing.

## Visual photo cropping

Choose **Crop and resize** after selecting an image in Photo Studio, or open **Crop visually** in a photo recipe. Drag either corner, move the selection, choose an aspect ratio, or enter exact orientation-corrected pixel bounds. Focus a handle and use arrow keys; Shift changes ten pixels. Review and choose **Use crop**, then prepare the actual recipe output before saving. Cancelling leaves the recipe unchanged. Cropping uses the original image before resizing; display thumbnails are never exported.

The editor supports free, 1:1, 3:4, 4:3 and 35:45 selection, bounded undo/reset and 48-pixel edge targets. Physical/rotation settings from another workspace are not inherited. Face assistance and manual signature masks remain unfinished. Source and actual-output workflows are checked at 100%/200% text; representative-user and real-device acceptance remains outstanding.

## Split a PDF

In Combine PDFs, select a source (or prepare the combined result first), then choose **Split into separate PDFs**. Add a named part for each output and enter pages such as `1-3,5` or `3,1`. Preview the original and each prepared part before saving. **Prepare unfinished parts** preserves successful results while you correct other groups; each part has its own save and retry controls. Leaving the screen releases the session-only results. The original stays unchanged, and existing files are never overwritten.

## Reuse application presets on this device

In Custom application pack, choose **Save preset on this device** to keep the requirement settings, including the preset name and requirements-source text. Selected photos, signatures, PDFs and their locations are excluded. **Load saved preset** opens the catalogue and clears selected sources when you use a preset. Delete a saved preset from that catalogue when it is no longer needed; current editor settings and exported files stay unchanged. Existing names are never silently replaced: rename a changed preset or explicitly delete the saved version first. Up to 64 presets of at most 64 KiB each are retained until deletion. JSON import/export still works when local storage is unavailable.

## Mirror or flip a photo

Open **Photo recipes**, select a JPEG/PNG, and enable **Mirror left to right**, **Flip top to bottom**, or both. Flips apply after orientation correction and optional cropping, before resizing and compression. Choose **Keep original dimensions** when you want no resize, prepare the preview, inspect text/signatures and save a copy. Exported, saved and batch recipes capture these settings as version4; recipes without flips retain their previous schema versions. Changing a flip invalidates the old prepared result.

## Recover an application pack without repeating successful documents

**Prepare and validate pack** prepares unfinished documents independently. A failed document shows its own error and **Retry document** action; ready documents are retained. Replace a failed source or edit its settings, then prepare again. Only changed or failed documents are processed again; the final ZIP reopens and checks every retained result before assembly. Selected optional documents that fail are never silently dropped: repair them or clear their source explicitly. An empty optional slot is omitted. **Stop after current operation** waits for the active native operation, keeps its successful result, and skips later work. Prepare again to resume. These results last only for the editor session, with a 64 MiB aggregate prepared-byte quota separate from the 64 MiB source quota; they are not persistent document storage or a process-wide memory limit.

## Compare and inspect images

After preparing a photo, signature or photo recipe, choose **Compare images**. Switch between **Original** and **Prepared**; each side starts fitted to its own geometry. Pinch to zoom, drag when enlarged, or use the focusable **Zoom in**, **Zoom out** and **Reset zoom** controls. Transparency backgrounds remain display-only.

Previews are bounded to 1200 pixels and zoom is limited to 8×; this enlarges the preview rather than decoding full-resolution pixels. Comparison does not change the source or saved output. See [ADR-028](ADR-028-image-inspection.md).

## Lossless PDF optimization (CLI)

Use a request with `operation: "optimize_pdf"`, `input`, `directory`, and `filename`. This uses supported structural optimization only, never rasterizes, and keeps the original bytes if rewriting does not reduce size. Existing conservative PDF structure/protection checks apply. The Combine PDFs workspace exposes an opt-in lossless optimization control. It reports actual output size and never silently rasterizes.
