"""Build-only, checksum-verified Windows PDFium staging. No network access."""
import hashlib
import pathlib
import shutil
import sys
import tarfile
import tempfile
archive=pathlib.Path(sys.argv[1])
with archive.open('rb') as f:
    if hashlib.file_digest(f,'sha256').hexdigest()!='808d36da9bc5a3104315fb307c80998121f565ee53953633bf33e80d7429e5ac':
        raise SystemExit('Windows PDFium archive checksum mismatch.')
root=pathlib.Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='ust-pdfium-') as temporary:
    with tarfile.open(archive) as t:t.extractall(temporary,filter='data')
    source=pathlib.Path(temporary)
    matches=list(source.rglob('pdfium.dll'))
    if len(matches)!=1:raise SystemExit('Expected exactly one PDFium DLL.')
    target=root/'native/windows-x64'
    target.mkdir(parents=True,exist_ok=True)
    shutil.copy2(matches[0],target/'pdfium.dll')
    shutil.copytree(source/'licenses',root/'third_party/pdfium-windows-x64',dirs_exist_ok=True)
