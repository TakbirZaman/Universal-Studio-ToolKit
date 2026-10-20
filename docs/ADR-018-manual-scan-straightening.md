# ADR 018: Non-destructive manual scan straightening

Date: 2026-10-20.
Status: local implementation and focused actual-output tests pass; new platform packages pending.

Manual straightening reuses the validated normalized page outline and existing native perspective operation. Rotating the selected source outline makes its text direction become horizontal in the corrected output. Rotation uses pixel aspect rather than treating normalized axes as equally long. A uniform shrink keeps corners inside the source; individual points are never clipped into a distorted outline. Angles are bounded to ±10 degrees and invalid/tiny outlines are rejected.

The corner editor exposes this as a collapsed “Straighten tilted text” section. It explains possible edge cropping, shows the outline angle and requires the existing apply-and-preview action. Undo restores the previous selection. Manual corner edits, suggestions and reset establish a new angle baseline. Original bytes are never rewritten. Drafts persist the resulting corners, so this needs no new schema or generated bridge change. This is manual correction, not automatic text-angle detection or page dewarping.

Small canonical previews now retain their original dimensions and pixels instead of being enlarged. Large canonical previews remain bounded; the editor angle follows the displayed image geometry and the saved result must be reviewed at full size. Interpolation can soften fine text and crops can remove edge content; the UI explains these trade-offs.

Verification includes actual ±7-degree synthetic line images passed through Flutter→Rust→OpenCV→PNG, with corresponding line starts at separated columns agreeing within one native output pixel. Geometry checks cover portrait/landscape/square, ±5/±10 degrees, bounds, aspect preservation and invalid values. Desktop light and narrow dark/200% corner workflows exercise the slider and undo before actual preview/PDF/Unicode save. Native small-preview regression checks exact dimensions/pixels. Representative users, screen readers, automatic angle detection and Android device behavior remain separate.
