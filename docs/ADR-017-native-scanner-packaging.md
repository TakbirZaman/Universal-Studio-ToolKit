# ADR 017: Verified native scanner staging

Status: implemented packaging candidate; platform bundle verification pending.
Date: 2026-10-20.

The scanner editor and Rust processing path exist, but previous application builds omit the native adapter. Those builds correctly hide unavailable controls. Packaging must explicitly stage the native engine without downloading anything during application use.

Build workflows provision the exact OpenCV source and locked build tools, build the narrow adapter, and produce a checksum-bound verification report. Linux and Windows run independent pixel checks; Android validates AArch64 ELF structure, required entry points, runtime dependencies and 16 KiB LOAD alignment. Android compilation does not establish device processing correctness.

The staging tool validates the platform, header, source commit, report, library checksum, reviewed notice policy and every retained notice before copying. It stages the library through a temporary file with flush/fsync/read-back and replacement. It rejects linked destinations and writes a provenance record without private source paths. Package stripping can change the native hash, so provenance explicitly labels the build input hash as before packager stripping. Actual packaged hashes still require inspection.

The scoped component review retains 155 OpenCV notice/source records and the complete unmodified Android NDK NOTICE and NOTICE.toolchain for static runtime components. Full geometry source retention addresses its entirety wording conservatively. System libraries and SDK executables are not bundled. Retaining aggregate SDK notices does not impose SDK-tool GPL terms on independent application code. This review does not establish blanket application or transitive license clearance.

Native Rust integration tests are explicitly ignored by default and require an explicitly provisioned engine when included. Linux and Windows application CI must include these tests. Missing engines must never produce a successful test that did no native work.

Original source files and saved documents are unaffected. Routine offline application processing does not fetch code, assets or licenses. Existing baseline builds may omit the adapter, but must retain truthful capability reporting.

Follow-up verification: a separate package inspector validates the saved library header, ELF dynamic entry points, source/platform provenance and every pinned notice. It records the actual packaged hash and compares desktop bytes to the staged input. For Android it allows ordinary packager stripping, verifies retained entry points and records the changed hash explicitly. This is structural package evidence; it does not execute Android processing. The actual staged Linux layout and tampered-notice rejection pass local regression.
