# Source for an explicitly restored workspace SDK; normal SDK installs need not use this.
ust_repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ust_tools_dir="${UST_TOOLCHAIN_ROOT:-$(dirname "$ust_repo_dir")/toolchains}"
export PATH="$ust_tools_dir/rust/bin:$ust_tools_dir/frb/bin:$ust_tools_dir/flutter/bin:$PATH"
export CI=true FLUTTER_SUPPRESS_ANALYTICS=true TAR_OPTIONS=--no-same-owner
export UST_PDFIUM_LIBRARY="$ust_repo_dir/native/linux-x64/libpdfium.so"
export UST_CORE_LIBRARY="$ust_repo_dir/rust/target/debug/libstudio_core.so"
unset ust_repo_dir ust_tools_dir
