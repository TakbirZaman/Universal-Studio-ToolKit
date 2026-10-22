# Universal Studio Toolkit — active development

Verified integration 2026-10-22. Windows x64, Linux x64 and Android ARM64 development builds are verified. The full requested product is not launch-complete.

Main 6c997730e9e72641dc1538eef364e57367253d37 adds named PDF split groups to the existing flexible compression, saved-copy actions, custom packs, session document reuse and visual photo cropping. PR5 tested source 0a7cbe665b1f79049dd2f9ac381a8aee402c0b7b passed all eight workflows: Windows 39740722417, Linux 39740722398, Android 39740722406, bridge 39740722404, notices 39740722407, custom packs 39740722511, photo crop 39740722443 and PDF split 39740722427.

PDF splitting accepts ordered pages/ranges, independent filenames and previews, selective preparation/retry and verified no-clobber saves. Successful parts survive failures in other groups. Up to 32 parts and 64 MiB of prepared copies remain only for the screen's session. The existing native PDF rules preserve supported text/vectors and reject unsupported/protected structures. No form, signature or searchable-OCR support is implied.

Provisioned native suites pass 84 Linux/82 Windows tests; the complete Flutter integration suites and static analysis pass. Four focused split checks include actual native saves at 100%/200% text scale, page-order checks and collision preservation. Custom pack and crop regressions pass; regenerated bridge sources match committed bindings. Packaged desktop startup passes on hosted build systems. Development artifacts and digests are recorded in docs/evidence/pdf-split-20261022.json. See ADR022–024 for current behavior.

Packs support editable required/optional JPEG/PNG/PDF slots, filenames, exact image pixels, strict byte/page limits, JSON preset import/export and verified ZIP manifests. Session document copies are limited to 16 items/64 MiB with remove/clear controls. Cropping supports draggable handles, selection movement, aspect locks, exact corrected-original coordinates, undo and keyboard controls, with Photo Studio source handoff.

Remaining scope includes advanced signature/photo/PDF tools, persistent preset catalogue and managed sources, pack-specific selective retries, Windows/Android OCR and searchable PDF geometry, localization/accessibility/user/device acceptance, worker isolation and cleanup, complete redistribution obligations, AppImage/printers and private production signing. See docs/REMAINING-WORK.md and REQUIREMENTS.md. CI artifacts are temporary development outputs and do not replace older saved installers.
