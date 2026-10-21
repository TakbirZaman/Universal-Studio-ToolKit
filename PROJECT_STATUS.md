# Universal Studio Toolkit — active development

Updated 2026-10-21. Windows x64, Linux x64 and Android ARM64 development builds are verified. The full requested product is not launch-complete.

Integrated source80a02e7 includes flexible image compression, explicit saved-copy actions, editable application packs and direct reuse of prepared studio/recipe documents. All checks on its feature sourceaf4f5a6 passed: Windows39640061789, Linux39640061791, Android39640061755, bridge39640061787, notices39640061771 and focused pack workflows39640061813. Earlier PR1/PR2 verification and integration are retained in Git history.

Custom packs support required/optional JPEG/PNG/PDF slots, safe filenames, exact image pixels, strict KiB and PDF page limits, source review/replacement, preset JSON import/export and verified ZIP manifests/reports. Prepared outputs can be explicitly retained for the current session, bounded to16 items/64MiB, then selected directly in packs. Remove/clear controls release collection references; this is not persistent signature storage or memory zeroization. See ADR022.

Six native pack/CLI tests, three session ownership/quota tests and two actual preset import/export/ZIP-save/recovery workflows at100%/200% text pass. Local native suite:79 passed,3 scanner-adapter tests ignored; the provisioned platform workflows run their native checks separately. An independent CLI inspection verifies archive inventory, image dimensions/bytes, SHA256 and no overwrite. The 200% format-selector overflow found by testing was fixed before integration.

The next development candidate is visual photo cropping. Full remaining scope remains in docs/REMAINING-WORK.md and REQUIREMENTS.md: advanced photo/signature/PDF tools, platform-complete OCR/searchable export, persistent managed sources and selective retries, localization/accessibility/user/device acceptance, isolation/cleanup, full license obligations and production distribution/signing. Existing development artifacts and previously delivered downloads are separate; no durable installer replacement or production-readiness claim is made here.
