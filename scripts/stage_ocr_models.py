"""Stage verified, explicitly supplied OCR models. Never downloads assets.

The Linux engine remains a separately installed /usr/bin/tesseract dependency.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import tempfile

MODELS = {
    'eng.traineddata': (4113088, '7d4322bd2a7749724879683fc3912cb542f19906c83bcc1a52132556427170b2'),
    'ben.traineddata': (855841, '31163084c279aaebd376216f0c3d5c17ad4b5fee8db49dae79c20000b5de5964'),
    'LICENSE': (11358, 'cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30'),
}

def stage(source: Path, bundle: Path):
    destination = bundle / 'ocr' / 'tessdata'
    if destination.exists() or destination.is_symlink():
        raise ValueError('OCR destination already exists; build a fresh bundle.')
    verified = {}
    for name, (length, digest) in MODELS.items():
        path = source / name
        if path.is_symlink() or not path.is_file():
            raise ValueError('OCR model must be a regular local file.')
        # O_NONBLOCK prevents a swapped FIFO from blocking this development tool.
        flags = os.O_RDONLY | getattr(os, 'O_NOFOLLOW', 0) | getattr(os, 'O_NONBLOCK', 0)
        with os.fdopen(os.open(path, flags), 'rb') as file:
            import stat
            if not stat.S_ISREG(os.fstat(file.fileno()).st_mode):
                raise ValueError('OCR model must be a regular local file.')
            data = file.read(length + 1)
        if len(data) != length or hashlib.sha256(data).hexdigest() != digest:
            raise ValueError('OCR asset checksum mismatch; no model files were staged.')
        verified[name] = data
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = Path(tempfile.mkdtemp(prefix='.staging-', dir=destination.parent))
    try:
        for name, data in verified.items():
            with (temporary / name).open('xb') as output:
                output.write(data)
                output.flush()
                os.fsync(output.fileno())
            if (temporary / name).read_bytes() != data:
                raise IOError('Staged OCR file failed read-back verification.')
        provenance = {
            'source': 'https://github.com/tesseract-ocr/tessdata_fast',
            'revision': '87416418657359cb625c412a48b6e1d6d41c29bd',
            'license': 'Apache-2.0; see LICENSE',
            'files': {name: {'bytes': length, 'sha256': digest} for name, (length, digest) in MODELS.items()},
            'engine': 'Not bundled; requires system /usr/bin/tesseract on Linux',
        }
        (temporary / 'PROVENANCE.json').write_text(json.dumps(provenance, indent=2) + '\n', encoding='utf-8')
        temporary.rename(destination)
    finally:
        if temporary.exists():
            shutil.rmtree(temporary)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--bundle', type=Path, required=True)
    args = parser.parse_args()
    stage(args.source, args.bundle)
    print('Verified English/Bangla models and Apache-2.0 license staged. No downloads performed.')
