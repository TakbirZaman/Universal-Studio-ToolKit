#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${ANDROID_HOME:?Set ANDROID_HOME to the installed Android SDK}"
: "${UST_PDFIUM_ANDROID_ARCHIVE:?Supply the audited PDFium Android arm64 archive}"
export CI=true FLUTTER_SUPPRESS_ANALYTICS=true
ndk="$ANDROID_HOME/ndk/28.2.13676358/toolchains/llvm/prebuilt/linux-x86_64/bin"
test -x "$ndk/aarch64-linux-android24-clang"
export CC_aarch64_linux_android="$ndk/aarch64-linux-android24-clang"
export AR_aarch64_linux_android="$ndk/llvm-ar"
export CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER="$CC_aarch64_linux_android"
cargo build --locked --release --manifest-path rust/Cargo.toml --target aarch64-linux-android
python3 scripts/stage_android_pdfium.py "$UST_PDFIUM_ANDROID_ARCHIVE"
cp rust/target/aarch64-linux-android/release/libstudio_core.so android/app/src/main/jniLibs/arm64-v8a/
mkdir -p android/app/src/main/assets/third_party
cp -R third_party/. android/app/src/main/assets/third_party/
cp LICENSE android/app/src/main/assets/third_party/PROJECT-LICENSE
flutter pub get --enforce-lockfile
flutter build apk --release --no-pub --target-platform android-arm64
mkdir -p dist
cp build/app/outputs/flutter-apk/app-release.apk dist/universal-studio-android-arm64-unsigned.apk
