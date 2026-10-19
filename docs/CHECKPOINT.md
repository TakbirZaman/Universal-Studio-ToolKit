# Continuation checkpoint — 2026-10-19 UTC

The full launch scope remains in REQUIREMENTS.md. This is functioning development software, not a completed launch. Continue ordinary work autonomously without phase approval. GitHub is authoritative; preserve unexpected edits and push checkpoints frequently because scratch has reset between sessions.

## Completed current runtime and saved downloads

Main integrates runtime 0d7d7a6f79a7b5f626235fc74f86850e17ae9178 through 3ecafeffe7132c8114f22faf6459ed23caa21721. Compared with that runtime source, the integration changes only documentation. It includes physical photo DPI, sequential scan processing/canonical previews, Android backup/development-signing protection, custom print sheets/guides, streamed PNG/JPEG byte limits, PDF page numbers/ASCII watermarks and editable existing-PDF text export.

All 66 Rust tests,32 selected Flutter tests and clean analysis/formatting pass. Independent pypdf/Poppler/Pillow/PDFium checks verify actual saved image/PDF/text geometry, bytes, Unicode text and no-clobber/source preservation. Desktop light and 390px dark/200% text workflow tests use real Rust processing and save actual files; only OS picker/destination selection is substituted. Local visual review found and fixed a truncated text-editor help line. No observed-user timing or assistive-technology acceptance is claimed.

All main 3ecafef workflows passed: Linux 39255218595, Windows 39255218711, Android 39255218508 and bridge39255218550. Main bridge artifact 12187912059 SHA-2567bd5fbf569fe6b0d0638f4231303ddf1c2adde56cf52476a14e99e2723c23962 was CRC/SHA/allowlist verified; all eight generated files exactly match committed source.

The four downloads were independently verified and successfully saved from runtime 0d7d7a6:
- Universal-Studio-Windows-x64.zip
- Universal-Studio-Linux-x64.tar.gz
- Universal-Studio-Android-debug.apk
- Universal-Studio-Android-development-release.apk

Evidence: evidence/development-builds-0d7d7a6.json. Candidate builds Linux 39253689705/artifact 12187705638, Windows 39253689586/artifact 12186777058 and Android 39253689489/artifact 12187945610 all passed. Archive hashes/CRCs,471 retained notice hashes, fonts and applicable native/OCR/CRT inventories verify independently. Android APKs pass native/ZIP 16 KiB alignment and compiled backup-policy checks; both installable signatures verify. The unsigned APK is a separate signing input, not the recommended installable download. Desktop startup is eight seconds on build hosts, not clean-system certification. Preserve historical 10d/1a output evidence.

## Active next feature — isolated scanner geometry

work/scan-perspective checkpoint 7cb8d1492d0410661fce84c93eba9ba91fadec41 starts from main a8a4e56. Source, CMake, build/verification scripts, ADR016 and independent evidence are pushed on that branch. It is not bundled or exposed in current downloads.

OpenCV 5.0.0 is pinned to upstream commit 40738fb16ceddb5fb3fea747585f7ce6abb0605b; archive SHA-25623affb17b8f7a46517a62b5e9fa637a8bc660acb5460bef9f130ee939df01ebb. Optional root WITH_* integrations are disabled; static/PIC core/imgproc also require geometry/flann/zlib in5.0. The geometry header must be included explicitly. Native/file/camera/codec/model/network/scripting entry points are not exposed by the adapter.

The Linux 4.3 MiB pixel-only C ABI adapter builds and passes independent ctypes/NumPy/Pillow checks: exact identity, measured perspective coordinates (maximum gradient error 0.736/255), unchanged original, invalid arguments leave output unchanged, blank images return no suggestion and a synthetic quadrilateral is detected within tolerance. ldd resolves the host C/C++/math/compiler runtimes. These checks do not establish Rust/UI integration or Windows/Android support.

Exact next action: retain/audit applicable native, transitive and embedded-font notices/provenance, then implement typed normalized corners and a safe dynamically loaded Rust adapter with buffer/geometry bounds. Integrate corrections before quarter rotation in scan preparation, preview and draft recovery; test actual image/PDF outputs. Regenerate typed bindings before adding the responsive accessible corner editor. Verify Windows/Android source builds, CRT/ABI/dependencies/alignment and runtime behavior before staging libraries or exposing controls.

SDK share/licenses includes SoftFloat, dlpack, Rubik OFL and zlib; FLANN headers carry additional BSD terms. Do not infer complete obligations from the root Apache license. Source build logs show no parallel backend and zlib as a third-party dependency; a generic upstream download-initialization message is not evidence of an actual download. Development source provisioning is separate from normal offline app processing.

## Remaining full scope and practical gates

Continue scanner boundaries/manual corners/perspective/deskew; editable application-pack slots and managed studio references; remaining photo/signature/PDF operations and flexible compression; platform OCR/searchable geometry; drag/drop, localization, keyboard/screen-reader/reduced-motion and representative first-use testing; isolation/orphan cleanup, complete licensing obligations, AppImage, private production signing and clean-device/printer acceptance. Requirements and feature matrix remain authoritative; no scope reduction is intended.

Linux OCR requires separately installed /usr/bin/tesseract and verified local models. Windows/Android OCR and searchable PDFs remain unavailable. Existing PDF text extraction can miss glyphs or have a different reading order; it does not run OCR. PDF imports reject unsupported forms/annotations/bookmarks/attachments/signatures/actions/XFA/tags/optional-content structures. In-process PDF parsing is an isolation blocker. Encoded/text-output bounds do not cap every internal allocation or sandbox native engines. Abnormal exits can leave temporary files. Notice integrity is not complete native/transitive licensing clearance.

Android builds target ARM64/API 24+ and use development signing identities. Actual device/camera/SAF/OEM/backup behavior remains unverified. Signing identity changes can require uninstalling, deleting local settings/drafts. No production-key, perfect OCR, passport acceptance, physical secure erasure or universal-compatibility claim.

## Local recovery details

Main checkout: universal-studio-main-recovery. Verified feature checkouts: universal-studio-pdf-overlays and universal-studio-pdf-text. Active new checkout: universal-studio-scan-perspective. Original universal-studio-current is an old 425c064 checkout with a script executable-mode difference; leave it untouched. Fetch refs and inspect local changes before updating any checkout.

Adjacent toolchains contain Rust 1.99.0, Flutter 3.47.7, official Android build-tools36.0.0, CMake 3.28.4 and Ninja 1.13.2. Use /bin/bash with login=false if the default shell fails. Shared Rust target is universal-studio-pdf-overlays/rust/target and currently contains the text-runtime bridge; rebuild the appropriate checkout before other FFI tests.

OpenCV source: toolchains/opencv-source/opencv-40738fb16ceddb5fb3fea747585f7ce6abb0605b. SDK: toolchains/opencv-linux-sdk. Native adapter: toolchains/vision-linux-build/libust_cv.so. Build log: /tmp/ust-opencv-build.log. CMake executable: toolchains/cmake-dev/cmake/data/bin/cmake; Ninja: toolchains/cmake-dev/bin/ninja. The new branch scripts accept explicitly supplied developer source/toolchains and never stage a library into the app automatically.

Never bypass permissions, automatic review or held-asset decisions. Do not commit credentials, keys, private artifact URLs or delivery identities. Synthetic image/PDF captures remain local verification intermediates, not uploaded deliverables.
