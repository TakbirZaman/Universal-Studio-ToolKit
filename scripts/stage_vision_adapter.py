"""Stage an explicitly verified scanner engine and pinned notices; never download."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import struct
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def digest(data):
    return hashlib.sha256(data).hexdigest()


def read_inventory(directory, expected_sha):
    manifest = directory / 'manifest.json'
    if directory.is_symlink() or manifest.is_symlink():
        raise ValueError('Notice inventories must not be symbolic links.')
    raw = manifest.read_bytes()
    if digest(raw) != expected_sha:
        raise ValueError('Notice manifest does not match the reviewed policy.')
    entries = json.loads(raw)['entries']
    if not entries or len(entries) > 512:
        raise ValueError('Unexpected notice inventory size.')
    result, total, names = [('manifest.json', raw)], len(raw), set()
    for entry in entries:
        name = entry['notice']
        if not re.fullmatch(r'[A-Za-z0-9_.-]+', name) or name in {'.', '..', 'manifest.json'} or name in names:
            raise ValueError('Unsafe or duplicate notice filename.')
        names.add(name)
        path = directory / name
        if path.is_symlink() or not path.is_file() or path.stat().st_size > 4 * 1024 * 1024:
            raise ValueError('Missing, linked or oversized notice.')
        data = path.read_bytes()
        total += len(data)
        if total > 16 * 1024 * 1024 or digest(data) != entry['sha256']:
            raise ValueError('Notice content does not match its inventory.')
        result.append((name, data))
    return result


def verify_header(data, platform):
    if platform == 'windows-x64':
        if len(data) < 64 or data[:2] != b'MZ':
            raise ValueError('Expected a Windows PE library.')
        offset = struct.unpack_from('<I', data, 60)[0]
        if offset + 26 > len(data) or data[offset:offset + 4] != b'PE\0\0':
            raise ValueError('Invalid PE header.')
        if struct.unpack_from('<H', data, offset + 4)[0] != 0x8664 or struct.unpack_from('<H', data, offset + 24)[0] != 0x20b:
            raise ValueError('Expected a 64-bit x86 Windows library.')
        return
    if len(data) < 64 or data[:6] != b'\x7fELF\x02\x01':
        raise ValueError('Expected a little-endian ELF64 library.')
    kind, machine = struct.unpack_from('<HH', data, 16)
    if kind != 3 or machine != (183 if platform == 'android-arm64' else 62):
        raise ValueError('Unexpected ELF architecture or type.')
    if platform == 'android-arm64':
        offset = struct.unpack_from('<Q', data, 32)[0]
        size, count = struct.unpack_from('<HH', data, 54)
        if size < 56 or not 1 <= count <= 128 or offset + size * count > len(data):
            raise ValueError('Invalid Android program header table.')
        loads = [struct.unpack_from('<Q', data, offset + i * size + 48)[0]
                 for i in range(count) if struct.unpack_from('<I', data, offset + i * size)[0] == 1]
        if not loads or min(loads) < 16384:
            raise ValueError('Android library requires 16 KiB LOAD alignment.')


def stage(platform, library, report_path, library_directory, notices_directory):
    if platform not in {'linux-x64', 'windows-x64', 'android-arm64'}:
        raise ValueError('Unsupported scanner platform.')
    policy = json.loads((ROOT / 'native/opencv/NOTICE-POLICY.json').read_text())
    source = json.loads((ROOT / 'native/opencv/SOURCE.json').read_text())
    if policy.get('identified_notice_conditions_reviewed') is not True or policy['opencv_source_commit'] != source['commit']:
        raise ValueError('The identified native notice conditions need review.')
    inventories = [('opencv-candidate', policy['notice_manifest_sha256'])]
    if platform == 'android-arm64':
        inventories.append(('opencv-android-runtime', policy['android_runtime_manifest_sha256']))
    retained = [(name, sha, read_inventory(ROOT / 'third_party' / name, sha)) for name, sha in inventories]
    if library.is_symlink() or not library.is_file() or not 1024 <= library.stat().st_size <= 128 * 1024 * 1024:
        raise ValueError('Supply one regular, bounded native library.')
    report = json.loads(report_path.read_text())
    if report.get('source_archive_verified') is not True or report.get('opencv_source_commit') != source['commit']:
        raise ValueError('The source build report does not match the pinned source.')
    if report.get('tested_adapter_platform', report.get('platform')) != platform:
        raise ValueError('The build report is for a different platform.')
    if platform == 'android-arm64':
        if not (report.get('elf64_aarch64') is True and report.get('required_symbols_present') is True
                and report.get('minimum_load_alignment', 0) >= 16384 and report.get('ndk') == '28.2.13676358'):
            raise ValueError('Android structure verification is incomplete.')
    else:
        checks = ['identity_exact_pixels', 'source_unchanged', 'invalid_inputs_leave_output_unchanged',
                  'blank_has_no_suggestion', 'synthetic_quad_suggestion_verified']
        if not (report.get('abi') == 1 and report.get('opencv_version') == 50000
                and all(report.get(key) is True for key in checks)
                and 0 <= report.get('perspective_max_gradient_error', float('inf')) <= 2):
            raise ValueError('Build-host pixel verification is incomplete.')
    data = library.read_bytes()
    if digest(data) != report.get('library_sha256'):
        raise ValueError('The library does not match the verified build report.')
    verify_header(data, platform)
    for directory in [library_directory, notices_directory]:
        if directory.is_symlink():
            raise ValueError('Build destination must not be a symbolic link.')
        directory.mkdir(parents=True, exist_ok=True)
    filename = 'ust_cv.dll' if platform == 'windows-x64' else 'libust_cv.so'
    destination = library_directory / filename
    if destination.is_symlink():
        raise ValueError('Library destination must not be a symbolic link.')
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=library_directory, delete=False) as stream:
            temporary = Path(stream.name)
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        if digest(temporary.read_bytes()) != report['library_sha256']:
            raise ValueError('Staged library failed read-back verification.')
        os.replace(temporary, destination)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
    for name, sha, files in retained:
        target = notices_directory / name
        if target.is_symlink():
            raise ValueError('Notice destination must not be a symbolic link.')
        target.mkdir(exist_ok=True)
        for filename, content in files:
            out = target / filename
            if out.is_symlink():
                raise ValueError('Notice destination must not be a symbolic link.')
            out.write_bytes(content)
        read_inventory(target, sha)
    provenance = {'schema_version': 1, 'platform': platform, 'opencv_version': source['version'],
                  'opencv_source_commit': source['commit'], 'library': destination.name,
                  'bytes_before_packager_strip': len(data), 'sha256_before_packager_strip': digest(data),
                  'notice_manifest_sha256': dict(inventories),
                  'pixel_processing_tested_on_build_host': platform != 'android-arm64',
                  'android_device_processing_verified': False, 'complete_application_license_clearance': False}
    provenance_path = notices_directory / 'opencv-build-provenance.json'
    if provenance_path.is_symlink():
        raise ValueError('Provenance destination must not be a symbolic link.')
    provenance_path.write_text(json.dumps(provenance, indent=2) + '\n', encoding='utf-8')
    return provenance


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--platform', choices=['linux-x64', 'windows-x64', 'android-arm64'], required=True)
    for name in ['library', 'report', 'library-directory', 'notices-directory']:
        parser.add_argument('--' + name, type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(stage(args.platform, args.library, args.report, args.library_directory, args.notices_directory), indent=2))
