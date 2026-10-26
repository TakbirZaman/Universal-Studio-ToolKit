# ADR-028: bounded image inspection

Photo Studio and recipe results offer a separate original/prepared comparison route. Switching sides resets the viewport because crop, rotation and resize may change image geometry. This is a labelled toggle, not a synchronized pixel alignment or difference calculation.

All displayed images continue through SafeImagePreview's native canonical preview conversion (maximum 1200 pixels). Zoom enlarges that bounded preview; it does not claim full-resolution pixel inspection. Encoded source and prepared bytes are never modified by inspection.

Canonical image previews and transparency previews provide pinch zoom, drag pan at enlarged scale, keyboard-focusable zoom in/out buttons and reset. Scale is bounded from 1× through 8×. Button zoom is centred on the viewport, and changing image identity resets the transform. Background controls affect display only. Controls wrap on narrow screens and with enlarged text.

Hosted tests exercise actual native JPEG/PNG preview conversion, side selection, zoom limits, panning, resetting, replacement image state, invalid-source rejection, navigation and unchanged source/output bytes at 100% and 200% text. Real screen reader, device gesture and representative-user acceptance remain outstanding. This does not complete the remaining launch scope.
