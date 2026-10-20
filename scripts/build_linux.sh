#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CI=true FLUTTER_SUPPRESS_ANALYTICS=true
python3 scripts/notice_provenance.py
cargo build --manifest-path rust/Cargo.toml --release --locked
flutter pub get --enforce-lockfile
flutter build linux --release --no-pub
bundle=build/linux/x64/release/bundle
cp rust/target/release/libstudio_core.so "$bundle/lib/"
test -f native/linux-x64/libpdfium.so
cp native/linux-x64/libpdfium.so "$bundle/lib/"
cp -R third_party "$bundle/third_party"
if [ -n "${UST_VISION_LIBRARY:-}" ] || [ -n "${UST_VISION_BUILD_REPORT:-}" ]; then
  : "${UST_VISION_LIBRARY:?Supply a verified native scanner library}"
  : "${UST_VISION_BUILD_REPORT:?Supply its source build and verification report}"
  python3 scripts/stage_vision_adapter.py --platform linux-x64 --library "$UST_VISION_LIBRARY" --report "$UST_VISION_BUILD_REPORT" --library-directory "$bundle/lib" --notices-directory "$bundle/third_party"
fi
if [ -n "${UST_OCR_MODEL_SOURCE:-}" ]; then
  python3 scripts/stage_ocr_models.py --source "$UST_OCR_MODEL_SOURCE" --bundle "$bundle"
fi
cp LICENSE README.md "$bundle/"
cp docs/LIMITATIONS.md "$bundle/KNOWN-LIMITATIONS.md"
mkdir -p dist
tar -czf dist/universal-studio-linux-x64.tar.gz -C "$bundle" .
printf 'Bundle created. Clean-system runtime validation is still required.\n'
