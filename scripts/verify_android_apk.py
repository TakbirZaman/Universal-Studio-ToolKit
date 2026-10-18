"""Structural APK check, not device compatibility or signing verification."""
import hashlib
import pathlib
import sys
import struct
import zipfile
p = pathlib.Path(sys.argv[1])
with zipfile.ZipFile(p) as apk:
    if apk.testzip() is not None:
        raise SystemExit('APK CRC failure')
    names = set(apk.namelist())
    required = {'lib/arm64-v8a/libstudio_core.so', 'lib/arm64-v8a/libpdfium.so', 'assets/third_party/PROJECT-LICENSE', 'AndroidManifest.xml'}
    if not required.issubset(names):
        raise SystemExit(f'Missing required APK entries: {sorted(required - names)}')
    if not any(n.startswith('assets/third_party/pdfium-android-arm64/') for n in names):
        raise SystemExit('PDFium notices missing')
    unexpected = [n for n in names if n.startswith('lib/') and not n.startswith('lib/arm64-v8a/')]
    if unexpected:
        raise SystemExit(f'Unsupported ABI entries must not be advertised: {unexpected}')
    for name in names:
        if not (name.startswith('lib/arm64-v8a/') and name.endswith('.so')):
            continue
        binary = apk.read(name)
        if binary[:6] != b'\x7fELF\x02\x01':
            raise SystemExit(f'Expected little-endian ELF64: {name}')
        offset = struct.unpack_from('<Q', binary, 32)[0]
        size, count = struct.unpack_from('<HH', binary, 54)
        alignments = [struct.unpack_from('<Q', binary, offset + i * size + 48)[0]
                      for i in range(count)
                      if struct.unpack_from('<I', binary, offset + i * size)[0] == 1]
        if not alignments or min(alignments) < 16384:
            raise SystemExit(f'16 KiB ELF alignment gate failed: {name}')
    for name in required:
        if apk.getinfo(name).file_size == 0:
            raise SystemExit(f'Empty APK entry: {name}')
p.with_suffix('.sha256').write_text(hashlib.sha256(p.read_bytes()).hexdigest() + '  ' + p.name + '\n')
print('APK entries, notices, CRC and ELF alignment verified. Device compatibility requires separate testing.')
