#!/usr/bin/env bash
set -euo pipefail
studio_stage="initialization"
trap 'printf "Android packaging failed during: %s (line %s)\n" "$studio_stage" "$LINENO" >&2' ERR
cd "$(dirname "$0")/.."
: "${ANDROID_HOME:?Set ANDROID_HOME to the installed Android SDK}"
: "${UST_PDFIUM_ANDROID_ARCHIVE:?Supply the audited PDFium Android arm64 archive}"
export CI=true FLUTTER_SUPPRESS_ANALYTICS=true
python3 scripts/notice_provenance.py
python3 scripts/test_android_signing.py
python3 scripts/test_android_privacy.py
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
if [ -n "${UST_VISION_LIBRARY:-}" ] || [ -n "${UST_VISION_BUILD_REPORT:-}" ]; then
  : "${UST_VISION_LIBRARY:?Supply a verified native scanner library}"
  : "${UST_VISION_BUILD_REPORT:?Supply its source build and verification report}"
  python3 scripts/stage_vision_adapter.py --platform android-arm64 --library "$UST_VISION_LIBRARY" --report "$UST_VISION_BUILD_REPORT" --library-directory android/app/src/main/jniLibs/arm64-v8a --notices-directory android/app/src/main/assets/third_party
fi
flutter pub get --enforce-lockfile
flutter build apk --release --no-pub --target-platform android-arm64
mkdir -p dist
cp build/app/outputs/flutter-apk/app-release.apk dist/universal-studio-android-arm64-unsigned.apk
# A standard debug key is generated locally by Android tooling, never committed.
flutter build apk --debug --no-pub --target-platform android-arm64
cp build/app/outputs/flutter-apk/app-debug.apk dist/universal-studio-android-arm64-debug.apk
studio_stage="debug APK signature verification"
"$ANDROID_HOME/build-tools/36.0.0/apksigner" verify dist/universal-studio-android-arm64-debug.apk

studio_stage="unsigned release 16 KiB ZIP alignment"
"$ANDROID_HOME/build-tools/36.0.0/zipalign" -c -v -P 16 4 dist/universal-studio-android-arm64-unsigned.apk
studio_stage="debug APK 16 KiB ZIP alignment"
"$ANDROID_HOME/build-tools/36.0.0/zipalign" -c -v -P 16 4 dist/universal-studio-android-arm64-debug.apk

# Installable optimized development build. Uses only the standard, locally
# generated development identity; production signing remains a separate private step.
# Do not assume Gradle uses $HOME/.android: Android user-home overrides vary
# between SDK/CI installations. This key belongs only to this build.
studio_stage="ephemeral development signing identity"
studio_signing_dir="$(mktemp -d)"
trap 'rm -f -- "$studio_signing_dir/development.keystore"; rmdir -- "$studio_signing_dir"' EXIT
studio_debug_key="$studio_signing_dir/development.keystore"
keytool -genkeypair -keystore "$studio_debug_key" -storetype JKS \
  -alias androiddebugkey -storepass android -keypass android \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -dname "CN=Universal Studio Development,O=Development,C=US" -noprompt
chmod 600 "$studio_debug_key"
studio_stage="optimized development APK signing"
"$ANDROID_HOME/build-tools/36.0.0/apksigner" sign \
  --ks "$studio_debug_key" --ks-key-alias androiddebugkey \
  --ks-pass pass:android --key-pass pass:android --v4-signing-enabled false \
  --out dist/universal-studio-android-arm64-development-release.apk \
  dist/universal-studio-android-arm64-unsigned.apk
"$ANDROID_HOME/build-tools/36.0.0/apksigner" verify dist/universal-studio-android-arm64-development-release.apk
"$ANDROID_HOME/build-tools/36.0.0/zipalign" -c -P 16 4 dist/universal-studio-android-arm64-development-release.apk
studio_stage="backup privacy policy verification"
python3 scripts/test_android_privacy.py
for studio_apk in dist/universal-studio-android-arm64-unsigned.apk dist/universal-studio-android-arm64-debug.apk dist/universal-studio-android-arm64-development-release.apk; do
  python3 scripts/verify_android_privacy.py "$studio_apk" "$ANDROID_HOME/build-tools/36.0.0/aapt2"
  if [ -n "${UST_VISION_LIBRARY:-}" ]; then
    python3 scripts/verify_packaged_vision.py --platform android-arm64 --package "$studio_apk"
  fi
done
