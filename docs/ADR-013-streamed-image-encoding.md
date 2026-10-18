# ADR 013 — streamed PNG and early encoded-byte limits

Status: 57 core tests and 27 interface tests pass locally; platform packaging pending.

The pinned png 0.18.1 Writer::write_image_data implementation constructs a complete compressed Vec before writing IDAT chunks. Adding only a bounded destination would therefore leave that temporary allocation in place. Use the pinned streaming writer instead: 16 KiB IDAT chunks, borrowed 8-bit source bytes and row-at-a-time big-endian conversion for 16-bit samples. This removes the full compressed intermediate and full copied 8-bit input/16-bit endian conversion buffers from this adapter. It does not cap the whole application or every codec allocation.

All generated PNG copies, including photo exports, scan adjustments and bounded source previews, use this path. Optional pHYs density is configured before encoding; eight/sixteen-bit channel samples and alpha are preserved. Reject an encoded copy beyond its byte budget without exposing partial output. Normal export budget is 64 MiB. A user maximum is enforced while writing; strict below limits permit one fewer byte than inclusive limits.

JPEG quality candidates also write through a bounded buffer. If a candidate exceeds the allowed prefix length, its eventual complete size cannot meet the bound, so discard that candidate and continue from the same prepared pixels. Retain the highest valid tested quality above the selected minimum; do not assume size/quality monotonicity or recompress a previous candidate. User-limit failure reports unmet constraints; system-budget failure identifies the 64 MiB processing limit. Overflowing byte constraints fail before image preparation.

Grow the bounded destination geometrically up to its budget rather than reallocating on every tiny codec write. This avoids a performance regression with encoders that emit many small writes while keeping requested encoded capacity within the configured bound. Source decoding/transformation memory and bridge copies remain separately bounded/limited; no hard process-wide memory or CPU guarantee is made.

Verification: exact-size encoding succeeds, a one-byte-smaller budget rejects the final copy, and all eight supported grayscale/RGB/alpha and 8/16-bit pixel layouts reopen with identical samples and requested/absent density. A noisy image forces rejected JPEG candidates before a valid lower-quality result; an independent fresh-pixel encoder produces identical bytes at the reported quality. PNG failure never returns a truncated image. Existing photo/scanner/print/OCR workflows pass through real typed FFI. No dependencies or API signatures changed.

Primary implementation checked locally in the locked png 0.18.1 source: encoder.rs Writer::write_image_data, Writer::stream_writer_with_size, StreamWriter::write/finish. Cargo lock and retained notice/archive hashes pin this source. No engine asset is downloaded during processing.
