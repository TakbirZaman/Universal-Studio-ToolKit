# Usability and accessibility evidence

No representative users have been observed. The ten-second home discoverability target is unmeasured. This is a heuristic review and automated widget/layout testing, not universal accessibility certification.

| Scenario | Current path | Issues / remaining evidence |
|---|---|---|
| Photo 300×300 below limit | Resize Photo → choose → dimensions/maximum size → prepare → inspect measured result → save copy | Defaults match 300×300; KiB and strict limit explained. Need real users, keyboard and screen-reader observation. |
| Three-page scan and reorder | Scan Documents → add page images → move up → prepare PDF → save | Desktop import only. Modes, brightness/contrast and PDFium visual preview are connected. Camera, thumbnails, drag reorder, perspective correction and draft recovery remain. |
| Merge two PDFs | Combine PDFs → add PDFs → prepare → page-count result → save | Structure limitations explained. PDFium visual result preview is connected; page selector currently comma-separated integers, no thumbnail manipulation. |
| Transparent signature | Clean Signature → import → threshold → prepare PNG → save | Threshold adjustable and PNG enforced; manual mask/crop and light/dark/checkerboard preview remain. |
| Application pack | Prepare Application → photo → signature → PDF → limit → prepare ZIP → save | Explicit example requirements. Required three slots validated. Editable presets and cross-studio managed sources remain. |

Implemented UI design decisions: native controls with semantic text labels; tooltip labels on icon buttons; no colour-only success state; light/dark Material themes; nonfixed card heights and scrollable pages; 52px primary controls; source and actual result size separate; original unchanged message; errors beside processing controls; no fake progress percentages; no destructive overwrite control; no mandatory onboarding.

Remaining gates: 200% scaling on every tool, narrow-window and long-filename checks, contrast measurement for custom accent text, complete localization extraction, screen-reader traversal, focus restoration, keyboard shortcuts, drop targets, Android reachability, font/glyph availability, reduce-motion behavior, user observation on all five scenarios. Current strings are English and require extraction into ARB before localization-ready status.
