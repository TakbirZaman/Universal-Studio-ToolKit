"""Independent saved-print geometry check using Pillow, pypdf and Poppler.

Development verification only. Never downloads; produces synthetic temporary
inputs and a PDF inside an explicitly supplied output directory.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import subprocess
from PIL import Image
from pypdf import PdfReader


def verify(executable, destination):
    destination = Path(destination).resolve()
    destination.mkdir(parents=True, exist_ok=True)
    source = destination / 'synthetic-print-source.png'
    if source.exists() or (destination / 'print-sheet.pdf').exists():
        raise ValueError('Choose a fresh verification directory; originals are never overwritten.')
    image = Image.new('RGB', (150, 100))
    image.putdata([(30 + x, 40 + y, 150) for y in range(100) for x in range(150)])
    image.save(source)
    digest = hashlib.sha256(source.read_bytes()).hexdigest()
    request = {'operation': 'print', 'input': str(source), 'directory': str(destination),
               'filename': 'print-sheet.pdf', 'paper': {'width_mm': 120, 'height_mm': 90, 'margin_mm': 5},
               'width_mm': 30, 'height_mm': 20, 'spacing_mm': 10, 'copies': 9,
               'cutting_guides': True, 'raster_dpi': 300}

    def run(value):
        request_path = destination / 'request.json'
        request_path.write_text(json.dumps(value))
        return subprocess.run([str(Path(executable).resolve()), str(request_path)],
                              text=True, capture_output=True, timeout=30)
    completed = run(request)
    if completed.returncode:
        raise RuntimeError('The native print verification request failed.')
    info = json.loads(completed.stdout)
    output = destination / 'print-sheet.pdf'
    data = output.read_bytes()
    assert len(data) == info['bytes'] and info['format'] == 'pdf' and info['pages'] == 1
    reader = PdfReader(io.BytesIO(data), strict=True)
    assert len(reader.pages) == 1
    page = reader.pages[0]
    width, height = float(page.mediabox.width) * 25.4 / 72, float(page.mediabox.height) * 25.4 / 72
    assert abs(width - 120) < .001 and abs(height - 90) < .001
    operations = page.get_contents().operations
    transforms = [list(map(float, operands)) for operands, operator in operations if operator == b'cm']
    assert len(transforms) == 9
    assert sum(operator == b'Do' for _, operator in operations) == 9
    assert sum(operator == b'l' for _, operator in operations) == 72
    placements = []
    for index, matrix in enumerate(transforms):
        w, b, c, h, x, y = [number * 25.4 / 72 for number in matrix]
        expected_x, expected_y = 5 + (index % 3) * 40, 65 - (index // 3) * 30
        assert max(abs(w - 30), abs(h - 20), abs(x - expected_x), abs(y - expected_y), abs(b), abs(c)) < .001
        placements.append([round(x, 4), round(y, 4), round(w, 4), round(h, 4)])
    resources = page['/Resources']['/XObject']
    assert len(resources) == 1
    embedded = resources['/Photo'].get_object()
    assert (int(embedded['/Width']), int(embedded['/Height'])) == (354, 236)
    assert Image.open(io.BytesIO(embedded.get_data())).size == (354, 236)
    assert hashlib.sha256(source.read_bytes()).hexdigest() == digest
    # Repeat and invalid constraints must preserve the saved file and create no partial output.
    output_digest = hashlib.sha256(data).hexdigest()
    assert run(request).returncode != 0 and hashlib.sha256(output.read_bytes()).hexdigest() == output_digest
    for key, value in [('copies', 10), ('spacing_mm', 2)]:
        invalid = dict(request, filename='invalid-' + key + '.pdf')
        invalid[key] = value
        assert run(invalid).returncode != 0
        assert not (destination / invalid['filename']).exists()
    subprocess.run(['pdftoppm', '-r', '150', '-png', '-singlefile', str(output), str(destination / 'print-preview')],
                   check=True, capture_output=True, timeout=30)
    return {'paper_mm': [round(width, 4), round(height, 4)], 'copies': 9, 'cutting_segments': 72,
            'embedded_pixels': [354, 236], 'placements_mm': placements,
            'bytes': len(data), 'sha256': output_digest, 'source_unchanged': True,
            'existing_output_preserved': True, 'invalid_constraints_saved_nothing': True,
            'independent_parser': 'pypdf', 'independent_render': 'Poppler',
            'printer_acceptance_verified': False}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--executable', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(verify(args.executable, args.output), indent=2))
