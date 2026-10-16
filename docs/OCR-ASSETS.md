# Offline OCR assets — audited prerequisites, app integration pending

Official tessdata_fast commit 87416418657359cb625c412a48b6e1d6d41c29bd provides English `eng` and Bangla/Bengali `ben` integer LSTM models. Primary documentation requires OEM 1 for these models. The repository's Apache 2.0 license was read separately from the Tesseract engine license and Noto font license. Retain copyright/license notices when bundling; do not treat a free download alone as redistribution permission.

| File | Bytes | SHA-256 |
|---|---:|---|
| eng.traineddata | 4113088 | 7d4322bd2a7749724879683fc3912cb542f19906c83bcc1a52132556427170b2 |
| ben.traineddata | 855841 | 31163084c279aaebd376216f0c3d5c17ad4b5fee8db49dae79c20000b5de5964 |
| LICENSE | 11358 | cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30 |

Host Tesseract 5.3.4 recognized one clean synthetic English phrase and one clean synthetic Bangla phrase exactly with these models. Evidence: evidence/ocr-engine-model-smoke.json. This establishes only a small engine/model smoke check, not scan accuracy, memory limits, app integration or platform compatibility. The test images were created locally from project-owned test text with licensed Noto Sans Bengali; no user documents were used or uploaded.

Noto Sans Bengali is separately bundled as the app's offline fallback font, unchanged under SIL OFL 1.1, with copyright, license and pinned source/hash records in third_party. Sample glyph coverage was checked with FontTools. This does not establish complete Bangla localization or screen-reader support.

Remaining work: resource-limited Tesseract adapter, typed application workflow, editable OCR results, verified packaging of engine and its transitive native dependencies on each platform, local asset import/retention, broader printed-document accuracy/performance evaluation. Searchable PDF remains unavailable until geometry and reading order are validated. No OCR control is exposed as functional before integration.

Primary sources:
- https://github.com/tesseract-ocr/tessdata_fast/tree/87416418657359cb625c412a48b6e1d6d41c29bd
- https://tesseract-ocr.github.io/tessdoc/Data-Files.html
- https://tesseract-ocr.github.io/tessdoc/Command-Line-Usage.html
- https://github.com/google/fonts/tree/b9b4b56be4f67f120752a756f39299b47366223c/ofl/notosansbengali

Reproduce the development engine check with `python3 scripts/verify_ocr_engine.py --models /absolute/local/model-directory`. It requires locally installed Tesseract 5 and Pillow with RAQM, verifies both models and LICENSE first, generates only synthetic text images in an isolated temporary directory, and performs no downloads. Model tampering was separately rejected before engine execution. This script is not an application OCR adapter.
