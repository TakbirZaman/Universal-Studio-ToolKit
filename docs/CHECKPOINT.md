# Continuation checkpoint — 2026-10-18 UTC

The full launch scope remains in REQUIREMENTS.md. This is working development software, not a finished launch. Continue ordinary work autonomously; do not request phase approval.

## Current main and saved builds

Source: 10d46ccbac022da35cd7d8ea062732c60fad3aef (tree a2c4bb56879c947958fbf972dd45d2c7d8687168). Main includes physical photo DPI, sequential scan processing and canonical previews, Android local backup protection/development signing, custom physical print layouts/cutting guides, and bounded streamed PNG/JPEG encoding. All originals stay unchanged.

57 Rust tests and 27 selected Flutter tests pass, with clean analysis. All three main workflows passed: Linux 39167712992, Windows 39167713030, Android 39167713009. Independent artifact verification is in evidence/development-builds-10d46cc.json. Four downloads are saved: Windows ZIP, Linux tar.gz, Android debug APK and optimized development-signed Android APK. Native inventory, retained notice hashes, font/OCR provenance, Windows CRT inventory, Android compiled backup policy/signatures/alignment and build-host startup verify. No clean-system/device/user acceptance is claimed. The optimized Android APK uses an ephemeral development identity; changing identity can require uninstalling, which deletes local settings/drafts.

## Active feature and exact next action

work/pdf-overlays starts at backend 022e8d7e78289ad35488d034534190e7e574f3da. Its generated bridge artifact 12152125017 (SHA-256 8fb4a9f03d0d6801136dad8397f967596364940e920cb5ee25c231e2ee70b610) was verified and applied. Final UI, CLI and stricter crop/rotation/unit/version tests are in the universal-studio-pdf-overlays worktree. Preserve that worktree. Finish checks, push the candidate and inspect all three platform workflows before integration; preserve this newer main build evidence when copying feature files.

Candidate features: optional page numbers in final output order and visible ASCII watermarks, integrated with arrange/rotate/lossless optimization. Graphics-state/resource isolation preserves original text and avoids font-name collisions. Geometry handles inherited media/crop boxes, rotations and supported page units. Invalid text, geometry, clipping or version combinations fail before saving. Independent pypdf and Poppler verification checks text, fonts, geometry, escaping, no-clobber and failure behavior; actual user/device/printer interoperability remains pending. These overlays are not in the saved main10d packages.

## Remaining work and known limits

Continue OpenCV boundaries/manual corners/perspective/deskew; editable pack slots/recipes and managed studio references; remaining photo/signature/PDF operations; Windows/Android OCR packaging and searchable-PDF geometry; drag/drop, localization, keyboard/screen-reader/reduced-motion and representative first-use testing; worker isolation, orphan cleanup, complete license obligations, clean-device testing, AppImage and production signing. Do not expose unavailable controls as functional.

Linux OCR requires separately installed /usr/bin/tesseract and verified local models; no Windows/Android recognition or searchable PDF claim. PDF imports reject unsupported forms/annotations/bookmarks/attachments/digital signatures/actions/XFA/tags/optional-content structures. In-process PDF parsing is an isolation blocker. Encoded-write budgets do not establish a process-wide memory cap. Abnormal termination can leave temporary files. Notice integrity does not establish complete transitive/native licensing clearance. No perfect OCR, passport acceptance or universal compatibility claim.

## Recovery

GitHub is authoritative. Active checkout: universal-studio-current; candidate: universal-studio-pdf-overlays. Fetch refs and preserve unexpected edits before resetting any checkout. Older universal-studio-toolkit is obsolete. Rust 1.99.0 and Flutter 3.47.7 are transient adjacent toolchains. Shared rust/target currently contains the candidate native library; rebuild the appropriate checkout before running a different bridge. Local Linux release development packages are missing; hosted builds provide release/startup evidence. Never bypass permissions, automatic review or held-asset decisions. Do not commit credentials, private artifact URLs or signing keys.

## 2026-10-19 recovery checkpoint

Main evidence update 81d13b9 is pushed. The environment reverted scratch to an old checkout and removed the final unpushed candidate. Restored the candidate backend from 022e8d7 and its verified eight-file generated bridge artifact. Reconstructed the controls, orchestration, CLI, precise geometry/version tests and independent parser script; re-verification and platform CI are pending for this reconstructed source. Do not reuse yesterday's 62/29 pass counts as evidence for today's changes.

Active worktree: universal-studio-pdf-overlays (local recovery/pdf-overlays, remote work/pdf-overlays). Toolchains are adjacent; invoke /bin/bash with login=false if the default shell fails. Keep original universal-studio-current untouched (old425c064 plus executable-mode difference only). New main checkout is universal-studio-main-recovery.

Exact next action: finish Rust tests with UST_PDFIUM_LIBRARY, build native cdylib, complete locked Flutter restore, format/analyze and run actual overlay workflow tests. Fix any failures, run complete core/UI/independent PDF checks, then inspect all three platform workflows. Integrate only verified candidate files while preserving main81d evidence/checkpoint. Publish frequent source checkpoints to avoid repeated scratch loss.

Recovery verification: all 62 Rust tests pass with PDFium and real English/Bangla OCR. The independent pypdf/Poppler script passes; rendered crop-box output was inspected locally. Five Android policy/parser tests, the real-keytool lifecycle test and all 471 notice hashes pass. Flutter SDK 3.47.7 is restored, locked application package resolution is still running. The first candidate CI can fail on a recovered test finder; its correction and formatting are being pushed. Saved main10d downloads are unchanged.

Latest recovery checks: clean Flutter analysis and both actual overlay workflow/save variants pass. The regenerated bridge remains unchanged from its verified artifact. Corrected test setup to use synchronous temporary-directory creation outside fake asynchronous time and distinguish imported source previews from generated output. Full interface regression is running. Candidate CI now cancels superseded feature-branch builds while preserving main build completion.

Final local recovery result: 62 Rust tests, 29 selected Flutter tests, clean analysis/formatting/diff checks, five Android policy tests, actual development-key cleanup and 471 retained notice hashes pass. The independent saved-PDF report is committed in evidence/pdf-overlays-20261019.json. Push this corrected candidate and inspect all three NEW platform runs; earlier38d/939 runs had recovered test issues and must not be treated as passing artifacts. Integrate only after the corrected candidate passes.

## Next vertical slice: existing PDF text (2026-10-19)

work/pdf-text branches from overlay candidate1a657f6. New core adapter extracts the existing text layer using bundled PDFium with cumulative character preflight and actual UTF-8 byte bounds, explicit empty-scan/reading-order messages and shared plain-text validation. Three initial core tests pass; an oversized-layer test is entering verification. New API bindings are not generated yet. Generate with the pinned workflow, apply verified eight-file source artifact, implement responsive editable text/save UI and verify independently before integration. This backend is separate from the overlay platform builds currently running.
