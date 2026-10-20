"""Inspect actual packaged scanner libraries and notices, including post-strip APKs.

No engine or document is executed. Desktop pixel execution remains a separate
check; APK inspection does not establish Android device behavior.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import sys
import zipfile

from stage_vision_adapter import ROOT, verify_header

SYMBOLS = {'ust_cv_abi_version', 'ust_cv_engine_version', 'ust_cv_warp_rgba', 'ust_cv_suggest_rgba'}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def elf_exports(data):
    """Bounded ELF64 dynamic-symbol inspection without loading foreign code."""
    offset = struct.unpack_from('<Q', data, 40)[0]
    size, count = struct.unpack_from('<HH', data, 58)
    if size < 64 or not 1 <= count <= 4096 or offset + size * count > len(data):
        raise ValueError('Invalid ELF section table.')
    sections = [struct.unpack_from('<IIQQQQIIQQ', data, offset + i * size) for i in range(count)]
    found = set()
    for section in sections:
        _, kind, _, _, start, length, link, _, _, entry = section
        if kind != 11:  # SHT_DYNSYM
            continue
        if entry < 24 or length % entry or length // entry > 100000 or start + length > len(data) or link >= count:
            raise ValueError('Invalid dynamic symbol table.')
        strings = sections[link]
        string_start, string_length = strings[4:6]
        if strings[1] != 3 or string_start + string_length > len(data) or string_length > 16 * 1024 * 1024:
            raise ValueError('Invalid symbol string table.')
        table = data[string_start:string_start + string_length]
        for i in range(length // entry):
            name, info, other, defined = struct.unpack_from('<IBBH', data, start + i * entry)
            if defined == 0 or info >> 4 not in {1, 2} or other & 3 not in {0, 3}:
                continue
            if name >= len(table):
                raise ValueError('Invalid symbol name offset.')
            end = table.find(b'\0', name)
            if end < 0:
                raise ValueError('Unterminated symbol name.')
            raw = table[name:end]
            if raw in {item.encode('ascii') for item in SYMBOLS}:
                found.add(raw.decode('ascii'))
    return found


def verify(platform, package, execute_host=False):
    if execute_host and platform == 'android-arm64':
        raise ValueError('Foreign Android code cannot be executed on the build host.')
    policy = json.loads((ROOT / 'native/opencv/NOTICE-POLICY.json').read_text())
    archive = None
    if platform == 'android-arm64':
        archive = zipfile.ZipFile(package)
        names = archive.namelist()
        if len(names) != len(set(names)) or archive.testzip() is not None:
            archive.close()
            raise ValueError('Duplicate APK entries or CRC failure.')
        def read(name, limit):
            info = archive.getinfo(name)
            if info.file_size > limit:
                raise ValueError('Oversized packaged scanner entry.')
            return archive.read(name)
        prefix = 'assets/third_party/'
        library_path = 'lib/arm64-v8a/libust_cv.so'
    else:
        if package.is_symlink() or not package.is_dir():
            raise ValueError('Supply the extracted desktop bundle directory.')
        def read(name, limit):
            current = package
            for part in Path(name).parts:
                current = current / part
                if current.is_symlink():
                    raise ValueError('Linked packaged scanner entry.')
            if not current.is_file() or current.stat().st_size > limit:
                raise ValueError('Missing or oversized packaged scanner entry.')
            return current.read_bytes()
        prefix = 'third_party/'
        library_path = 'ust_cv.dll' if platform == 'windows-x64' else 'lib/libust_cv.so'
    try:
        binary = read(library_path, 128 * 1024 * 1024)
        verify_header(binary, platform)
        if platform != 'windows-x64' and elf_exports(binary) != SYMBOLS:
            raise ValueError('Required scanner exports are missing from the packaged ELF.')
        provenance = json.loads(read(prefix + 'opencv-build-provenance.json', 16384))
        if provenance.get('schema_version') != 1 or provenance.get('platform') != platform or provenance.get('opencv_source_commit') != policy['opencv_source_commit']:
            raise ValueError('Packaged scanner provenance does not match the platform/source pin.')
        expected = {'opencv-candidate': policy['notice_manifest_sha256']}
        if platform == 'android-arm64':
            expected['opencv-android-runtime'] = policy['android_runtime_manifest_sha256']
        if provenance.get('notice_manifest_sha256') != expected:
            raise ValueError('Packaged notice policy differs from the reviewed policy.')
        count, total = 0, 0
        for folder, expected_hash in expected.items():
            manifest_bytes = read(prefix + folder + '/manifest.json', 1024 * 1024)
            if sha(manifest_bytes) != expected_hash:
                raise ValueError('Packaged notice manifest hash mismatch.')
            manifest = json.loads(manifest_bytes)
            if not 1 <= len(manifest['entries']) <= 512:
                raise ValueError('Unexpected packaged notice count.')
            for item in manifest['entries']:
                name = item['notice']
                # Only exact names from the locally hash-pinned manifest are read.
                if '/' in name or '\\' in name or name in {'.', '..'}:
                    raise ValueError('Unsafe packaged notice filename.')
                content = read(prefix + folder + '/' + name, 4 * 1024 * 1024)
                total += len(content)
                if total > 16 * 1024 * 1024 or sha(content) != item['sha256']:
                    raise ValueError('Packaged notice content mismatch.')
                count += 1
        actual = sha(binary)
        if platform != 'android-arm64' and actual != provenance.get('sha256_before_packager_strip'):
            raise ValueError('Desktop library changed after verified staging.')
        if execute_host:
            tested = json.loads(subprocess.check_output([
                sys.executable, str(ROOT / 'scripts/verify_vision_adapter.py'),
                '--library', str((package / library_path).resolve()),
            ], text=True))
            if tested['library_sha256'] != actual:
                raise ValueError('Executed package library differs from inspected bytes.')
        return {'schema_version': 1, 'platform': platform, 'library': library_path,
                'packaged_library_bytes': len(binary), 'packaged_library_sha256': actual,
                'build_input_sha256': provenance['sha256_before_packager_strip'],
                'packager_changed_binary': actual != provenance['sha256_before_packager_strip'],
                'retained_notice_records': count, 'notice_content_verified': True,
                'required_elf_exports_verified': platform != 'windows-x64',
                'packaged_pixels_verified_on_build_host': execute_host,
                'device_processing_verified': False}
    finally:
        if archive is not None:
            archive.close()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--platform', choices=['linux-x64', 'windows-x64', 'android-arm64'], required=True)
    parser.add_argument('--package', type=Path, required=True)
    parser.add_argument('--execute-host', action='store_true', help='Run independent pixel checks in a child process on desktop only')
    args = parser.parse_args()
    print(json.dumps(verify(args.platform, args.package, args.execute_host), indent=2))
