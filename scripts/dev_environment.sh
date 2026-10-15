# Source only for this hosted workspace. End-user builds use normal SDK installations.
export CARGO_HOME=/workspace/scratch/72c326c6fe81/toolchains/cargo
export RUSTUP_HOME=/workspace/scratch/72c326c6fe81/toolchains/rustup
export PATH="$CARGO_HOME/bin:/workspace/scratch/72c326c6fe81/toolchains/flutter/bin:$PATH"
export CI=true FLUTTER_SUPPRESS_ANALYTICS=true TAR_OPTIONS=--no-same-owner
export UST_PDFIUM_LIBRARY=/workspace/scratch/72c326c6fe81/universal-studio-toolkit/native/linux-x64/libpdfium.so
