"""Independent synthetic JPEG/PNG density/export check; no user documents or downloads."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
from PIL import Image


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cli', type=Path, required=True)
    args = parser.parse_args()
    cli = args.cli.resolve()
    report = {'scope': 'Synthetic saved outputs only; not printer or application acceptance testing', 'cases': []}
    with tempfile.TemporaryDirectory(prefix='ust-physical-smoke-') as directory:
        root = Path(directory)
        source = root / 'source.png'
        image = Image.new('RGBA', (80, 100))
        image.putdata([(x * 3, y * 2, 120, 0 if x < 10 else 255) for y in range(100) for x in range(80)])
        image.save(source)
        source_hash = hashlib.sha256(source.read_bytes()).hexdigest()
        for format in ['jpeg', 'png']:
            destination = root / format
            destination.mkdir()
            name = 'photo.jpg' if format == 'jpeg' else 'photo.png'
            request = {'operation': 'photo', 'input': str(source), 'directory': str(destination), 'filename': name,
                       'options': {'width': 413, 'height': 531, 'format': format, 'fit': 'contain', 'min_quality': 60,
                                   'max_bytes': {'value': 100, 'unit': 'ki_b', 'strict': True},
                                   'background': [255, 255, 255], 'flatten_transparency': format == 'jpeg',
                                   'rotate_quarters': 0, 'flip_horizontal': False, 'signature_threshold': None,
                                   'crop': None, 'output_dpi': 300}}
            request_path = root / 'request.json'
            request_path.write_text(json.dumps(request))
            result = subprocess.run([str(cli), str(request_path)], capture_output=True, timeout=30, check=True)
            info = json.loads(result.stdout)
            output = destination / name
            data = output.read_bytes()
            with Image.open(output) as decoded:
                decoded.load()
                assert decoded.size == (413, 531)
                assert decoded.format == format.upper()
                dpi = decoded.info['dpi']
                assert all(abs(value - 300) < 0.013 for value in dpi)
                assert not decoded.getexif()
                assert 'icc_profile' not in decoded.info
                if format == 'png':
                    assert decoded.convert('RGBA').getextrema()[3][0] == 0
            assert len(data) == info['bytes'] and len(data) < 102400
            assert abs(info['print_density']['x_dpi'] - dpi[0]) < 0.00001
            digest = hashlib.sha256(data).hexdigest()
            retry = subprocess.run([str(cli), str(request_path)], capture_output=True, timeout=30)
            assert retry.returncode != 0 and hashlib.sha256(output.read_bytes()).hexdigest() == digest
            assert hashlib.sha256(source.read_bytes()).hexdigest() == source_hash
            report['cases'].append({'format': format, 'pixels': [413, 531], 'pillow_dpi': dpi,
                                    'bytes': len(data), 'sha256': digest, 'original_unchanged': True,
                                    'existing_output_preserved': True, 'exif_absent': True, 'icc_absent': True})
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
