"""Verify and stage an explicitly supplied build-time PDFium archive; no network."""
import hashlib
import pathlib
import shutil
import sys
import tarfile
import tempfile

EXPECTED = 'b7a6919dc130dfdf7e409bd1762ed2a306408c4faee1173668837fc446217bf7'
archive = pathlib.Path(sys.argv[1])
with archive.open('rb') as source:
    if hashlib.file_digest(source, 'sha256').hexdigest() != EXPECTED:
        raise SystemExit('PDFium checksum mismatch; nothing staged.')
root = pathlib.Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='ust-pdfium-') as temporary:
    with tarfile.open(archive) as package:
        package.extractall(temporary, filter='data')
    source = pathlib.Path(temporary)
    target = root / 'android/app/src/main/jniLibs/arm64-v8a'
    target.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source / 'lib/libpdfium.so', target / 'libpdfium.so')
    shutil.copytree(source / 'licenses', root / 'third_party/pdfium-android-arm64', dirs_exist_ok=True)
