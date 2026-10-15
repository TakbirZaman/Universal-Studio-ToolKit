# Optional development-only environment for unpacked Linux development packages.
# Usage: export UST_SYSROOT=/absolute/path/to/sysroot; source this file
: "${UST_SYSROOT:?Set UST_SYSROOT to the unpacked development sysroot}"
export PATH="$UST_SYSROOT/usr/bin:$UST_SYSROOT/usr/lib/llvm-18/bin:$PATH"
export LD_LIBRARY_PATH="$UST_SYSROOT/usr/lib/x86_64-linux-gnu:$UST_SYSROOT/usr/lib/llvm-18/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export PKG_CONFIG_SYSROOT_DIR="$UST_SYSROOT"
export PKG_CONFIG_LIBDIR="$UST_SYSROOT/usr/lib/x86_64-linux-gnu/pkgconfig:$UST_SYSROOT/usr/share/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/share/pkgconfig"
