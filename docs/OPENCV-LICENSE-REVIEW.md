# OpenCV candidate dependency review

Development candidate only. No OpenCV runtime is staged in the current application downloads. Source commit and archive checksum are in native/opencv/SOURCE.json. The archive was downloaded and its SHA-256 checked before extraction during the local Linux rebuild. All processing is local; source provisioning is a developer action.

| Component | Separate retained terms | Reviewed conditions and current handling |
| --- | --- | --- |
| OpenCV 5.0 core, geometry, imgproc | Apache-2.0 root license; historical BSD change notice and source copyright blocks | Retain license, applicable copyright and attribution notices; identify modifications. Adapter is separate project source. No upstream source edits made. Do not imply endorsement or trademark rights. |
| Required FLANN module | Source headers contain additional BSD redistribution conditions | Marius Muja/David Lowe header has two conditions, not three. Retain complete source/binary copyright, conditions and disclaimer. Other header notices are collected separately. |
| Berkeley SoftFloat 3c in core | BSD three-condition license | Retain Regents copyright, conditions and disclaimer; no endorsement. Full COPYING.txt retained. |
| dlpack headers | Apache-2.0 | Full separate license retained even though linked-object applicability is still under review. |
| Bundled zlib | zlib license | Commercial use explicitly permitted; do not misrepresent origin, mark altered source, preserve notice. Upstream source unchanged. Full notice retained. |
| Embedded Rubik regular/italic font data in imgproc | SIL OFL 1.1, 2015 Rubik Project Authors | Upstream CMake embeds both compressed fonts. Retain copyright and OFL with software; no standalone font sale, endorsement or relicensing. The supplied notice specifies no Reserved Font Name after its copyright. No font content/name edits made. Embedding is not assumed to remove OFL obligations. |
| libloading 0.9.0 | Existing separately retained ISC license | Already locked and inventoried as a PDFium transitive dependency. Added as an exact direct dependency without changing its version or notice. |

scripts/collect_vision_notices.py retains seven complete license/change files plus 145 deduplicated copyright/license comment blocks, with source-relative origins and SHA-256 hashes. This collection deliberately includes unused/test source notices. It is not a linker-derived dependency inventory or an automatic legal approval. No private document paths or test image contents occur in the manifest.

Before application staging: compare the complete platform build configuration and linked objects against the retained notices, review any additional inline/generated-code notices, verify Windows CRT/Android runtime obligations and include candidate notices in the ordinary package inventories. Check native platform redistribution and all transitive obligations separately. Current complete-license-clearance flag remains false. Other project dependencies retain their separate existing inventories and launch gates.
