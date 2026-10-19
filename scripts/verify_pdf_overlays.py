"""Independent synthetic overlay verification; never downloads or overwrites inputs."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import subprocess
from pypdf import PdfReader, PdfWriter
from pypdf.generic import NameObject, NumberObject, RectangleObject
from reportlab.pdfgen import canvas


def verify(executable, output):
    root = Path(output).resolve()
    root.mkdir(parents=True, exist_ok=True)
    source = root / 'source.pdf'
    saved = root / 'overlays.pdf'
    if source.exists() or saved.exists():
        raise ValueError('Choose a fresh verification directory.')
    buffer = io.BytesIO()
    drawing = canvas.Canvas(buffer, pagesize=(220, 320), pdfVersion=(1, 7))
    for index in range(2):
        drawing.setFont('Helvetica', 12)
        drawing.drawString(40, 140, 'ORIGINAL PAGE ' + str(index + 1))
        drawing.showPage()
    drawing.save()
    writer = PdfWriter()
    writer.pdf_header = b'%PDF-1.7'
    for index, page in enumerate(PdfReader(buffer).pages):
        page.cropbox = RectangleObject([10, 20, 210, 300])
        page.rotate(90 if index == 0 else 270)
        page[NameObject('/UserUnit')] = NumberObject(2)
        writer.add_page(page)
    with source.open('xb') as stream:
        writer.write(stream)
    original = hashlib.sha256(source.read_bytes()).hexdigest()
    request = {'operation': 'decorate_pdf', 'input': str(source), 'directory': str(root),
               'filename': saved.name, 'page_numbers': True, 'watermark': r'Draft (copy) \ 42',
               'watermark_font_points': 14}

    def run(value):
        config = root / 'request.json'
        config.write_text(json.dumps(value), encoding='utf-8')
        return subprocess.run([str(Path(executable).resolve()), str(config)],
                              capture_output=True, timeout=30)

    result = run(request)
    if result.returncode:
        raise RuntimeError(result.stderr.decode('utf-8', errors='replace'))
    data = saved.read_bytes()
    document = PdfReader(io.BytesIO(data), strict=True)
    assert len(document.pages) == 2
    for index, page in enumerate(document.pages):
        assert page.rotation == (90 if index == 0 else 270)
        assert list(map(float, page.cropbox)) == [10, 20, 210, 300]
        assert int(page['/UserUnit']) == 2
        text = page.extract_text()
        assert 'ORIGINAL PAGE ' + str(index + 1) in text
        assert 'Page ' + str(index + 1) + ' of 2' in text
        assert request['watermark'] in text
        assert page['/Resources']['/Font']['/F1'].get_object()['/BaseFont'] == '/Helvetica'
    digest = hashlib.sha256(data).hexdigest()
    assert hashlib.sha256(source.read_bytes()).hexdigest() == original
    assert run(request).returncode != 0
    assert hashlib.sha256(saved.read_bytes()).hexdigest() == digest
    invalid = dict(request, watermark='বাংলা', filename='unsupported.pdf')
    assert run(invalid).returncode != 0 and not (root / invalid['filename']).exists()
    subprocess.run(['pdftoppm', '-cropbox', '-r', '120', '-png', str(saved),
                    str(root / 'overlay-preview')], check=True, capture_output=True, timeout=30)
    return {'pages': 2, 'rotations': [90, 270], 'crop_box': [10, 20, 210, 300], 'user_unit': 2,
            'original_text_and_fonts_preserved': True, 'escaped_watermark_text_roundtrips': True,
            'labels_in_saved_order': True, 'source_unchanged': True,
            'existing_output_preserved': True, 'invalid_constraints_saved_nothing': True,
            'bytes': len(data), 'sha256': digest, 'independent_parser': 'pypdf',
            'independent_renderer': 'Poppler', 'universal_pdf_compatibility_claimed': False}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--executable', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(verify(args.executable, args.output), indent=2))
