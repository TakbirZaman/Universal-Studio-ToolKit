# ADR 009 — explicit physical photo size and verified print-density metadata

Status: implementation in progress on work/photo-density; not a shipped feature claim.

Convert requested millimetres and integer DPI (1–2400) into bounded whole-pixel dimensions in Rust. Process a fresh orientation-normalized source, retaining existing fit/crop, transparency consent and byte-limit rules. Report pixel rounding and the physical size computed from the saved pixels and actual density; never promise that printer settings or external application acceptance are guaranteed.

Retain print density only after an explicit request. It is technical print metadata, separate from personal metadata and ICC colour management. Continue stripping personal metadata and rejecting ICC profiles until colour-managed conversion is validated. Default pixel-mode exports do not silently retain source density.

Use image 0.25.10's JpegEncoder::set_pixel_density(PixelDensity::dpi(...)), verified against the pinned crate source. For PNG, image's simple writer does not expose pHYs configuration, so use the already resolved png 0.18.1 crate through a narrow encoder adapter. Its documented Encoder::set_pixel_dims writes pixels per metre; quantify its integer conversion when reporting actual DPI. Both formats include density before actual-byte constraint checks, never as an unmeasured post-processing addition.

The png crate is newly declared as a direct dependency at the existing locked version, with default features disabled. It adds no package/version to the resolved dependency set. Its complete MIT and Apache license texts are already retained; the MIT alternative explicitly permits commercial use/redistribution with copyright and permission notices retained. No new model, font or native SDK is introduced.

Add typed optional print density to output metadata and FRB results. Reopen the actual encoded output, read its JFIF/pHYs units and density, and reject absent, malformed, ambiguous or forged density claims. Keep absent density backward compatible in stored JSON/manifests. Validate both source pixel count and generated dimensions before processing.

A DTO change requires regenerated bindings. Until regeneration and native/Flutter tests pass, this branch must not be described as runnable through the new Flutter API. Do not hand-edit generated files. Require independent Pillow density/pixel/byte checks in addition to Rust round-trip tests before completion claims.

Primary references: pinned image 0.25.10 src/codecs/jpeg/encoder.rs and png 0.18.1 sources; https://docs.rs/png/0.18.1/png/struct.Encoder.html#method.set_pixel_dims. Future physical-size presets must identify their source/revision or be clearly marked examples.
