#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CI=true FLUTTER_SUPPRESS_ANALYTICS=true
cargo build --manifest-path rust/Cargo.toml --release --locked
flutter pub get --enforce-lockfile
flutter build linux --release --no-pub
bundle=build/linux/x64/release/bundle
cp rust/target/release/libstudio_core.so "$bundle/lib/"
test -f native/linux-x64/libpdfium.so
cp native/linux-x64/libpdfium.so "$bundle/lib/"
cp -R third_party "$bundle/third_party"
cp docs/LIMITATIONS.md "$bundle/KNOWN-LIMITATIONS.md"
mkdir -p dist
tar -czf dist/universal-studio-linux-x64.tar.gz -C "$bundle" .
printf 'Bundle created. Clean-system runtime validation is still required.\n'
