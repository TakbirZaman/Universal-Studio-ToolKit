"""Structural APK check, not device compatibility or signing verification."""
import hashlib
import pathlib
import sys
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
    for name in required:
        if apk.getinfo(name).file_size == 0:
            raise SystemExit(f'Empty APK entry: {name}')
p.with_suffix('.sha256').write_text(hashlib.sha256(p.read_bytes()).hexdigest() + '  ' + p.name + '\n')
print('APK entries, notices and CRC verified. Signing and device tests remain pending.')
