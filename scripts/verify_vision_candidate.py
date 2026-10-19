"""Developer/CI source build and independent pixel verification, never app startup."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tarfile
import urllib.request


def run(platform, work, toolchain=None):
    root = Path(__file__).resolve().parents[1]
    policy = json.loads((root / 'native/opencv/SOURCE.json').read_text())
    work.mkdir(parents=True, exist_ok=True)
    archive = work / 'opencv.tar.gz'
    urllib.request.urlretrieve('https://github.com/opencv/opencv/archive/' + policy['commit'] + '.tar.gz', archive)
    if archive.stat().st_size != policy['archive_bytes'] or hashlib.file_digest(archive.open('rb'), 'sha256').hexdigest() != policy['archive_sha256']:
        raise ValueError('OpenCV source archive does not match the pin.')
    with tarfile.open(archive) as package:
        package.extractall(work / 'source', filter='data')
    source = work / 'source' / ('opencv-' + policy['commit'])
    cmake, ninja = shutil.which('cmake'), shutil.which('ninja')
    if not cmake or not ninja:
        raise ValueError('Install pinned CMake3.28.4 and Ninja1.13.2 developer tools.')
    if subprocess.check_output([cmake, '--version'], text=True).splitlines()[0] != 'cmake version 3.28.4':
        raise ValueError('Unexpected CMake version.')
    if subprocess.check_output([ninja, '--version'], text=True).strip() != '1.13.2.git.kitware.jobserver-pipe-1':
        raise ValueError('Unexpected Ninja version.')
    command = [sys.executable, str(root / 'scripts/build_vision_adapter.py'), '--source', str(source),
                    '--work', str(work / 'build'), '--install', str(work / 'sdk'), '--cmake', cmake,
                    '--ninja', ninja, '--platform', platform, '--jobs', '4']
    if platform == 'android-arm64':
        if toolchain is None or not toolchain.is_file():
            raise ValueError('Supply the pinned NDK28.2.13676358 CMake toolchain.')
        command += ['--toolchain', str(toolchain.resolve())]
    subprocess.run(command, check=True)
    filename = 'ust_cv.dll' if platform == 'windows-x64' else 'libust_cv.so'
    libraries = list((work / 'build/adapter').rglob(filename))
    if len(libraries) != 1:
        raise ValueError('Expected one candidate adapter.')
    if platform == 'android-arm64':
        ndk = toolchain.resolve().parents[2]
        properties = (ndk / 'source.properties').read_text()
        if not re.search(r'Pkg.Revision\s*=\s*28\.2\.13676358\b', properties):
            raise ValueError('Unexpected Android NDK revision.')
        readelf = ndk / 'toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-readelf'
        library = libraries[0]
        header = subprocess.check_output([str(readelf), '-h', str(library)], text=True)
        if not re.search(r'Class:\s+ELF64', header) or not re.search(r'Machine:\s+AArch64', header):
            raise ValueError('The Android adapter is not ARM64 ELF64.')
        programs = subprocess.check_output([str(readelf), '-lW', str(library)], text=True)
        loads = [line.split() for line in programs.splitlines() if line.strip().startswith('LOAD ')]
        if not loads or any(int(line[-1], 16) < 0x4000 for line in loads):
            raise ValueError('The Android adapter needs at least16KiB LOAD alignment.')
        dynamic = subprocess.check_output([str(readelf), '-d', str(library)], text=True)
        needed = sorted(re.findall(r'\(NEEDED\).*?\[([^]]+)\]', dynamic))
        if not set(needed) <= {'libc.so', 'libm.so', 'libdl.so', 'liblog.so', 'libandroid.so'}:
            raise ValueError('Unexpected Android runtime dependency: ' + ','.join(needed))
        symbols = subprocess.check_output([str(readelf), '--dyn-syms', '-W', str(library)], text=True)
        for name in ['ust_cv_abi_version', 'ust_cv_engine_version', 'ust_cv_warp_rgba', 'ust_cv_suggest_rgba']:
            if not re.search(r'\b' + name + r'\s*$', symbols, re.M):
                raise ValueError('Missing Android adapter entry point: ' + name)
        notice = ndk / 'NOTICE'
        report = {'platform': platform, 'source_archive_verified': True, 'opencv': policy['version'],
                  'ndk': '28.2.13676358', 'elf64_aarch64': True, 'minimum_load_alignment': min(int(line[-1], 16) for line in loads),
                  'required_symbols_present': True, 'needed_libraries': needed,
                  'library_bytes': library.stat().st_size,
                  'library_sha256': hashlib.file_digest(library.open('rb'), 'sha256').hexdigest(),
                  'ndk_notice_sha256': hashlib.file_digest(notice.open('rb'), 'sha256').hexdigest(),
                  'runtime_pixel_processing_verified': False, 'application_staging_complete': False,
                  'complete_license_clearance': False}
        (work / 'pixel-verification.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
        print(json.dumps(report, indent=2))
        return
    report = subprocess.check_output([sys.executable, str(root / 'scripts/verify_vision_adapter.py'), '--library', str(libraries[0])], text=True)
    parsed = json.loads(report)
    # Generic verification script never certifies app/platform integration.
    parsed['tested_adapter_platform'] = platform
    parsed['source_archive_verified'] = True
    (work / 'pixel-verification.json').write_text(json.dumps(parsed, indent=2) + '\n', encoding='utf-8')
    print(report)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--platform', choices=['linux-x64', 'windows-x64', 'android-arm64'], required=True)
    parser.add_argument('--work', type=Path, required=True)
    parser.add_argument('--toolchain', type=Path)
    args = parser.parse_args()
    run(args.platform, args.work.resolve(), args.toolchain)
