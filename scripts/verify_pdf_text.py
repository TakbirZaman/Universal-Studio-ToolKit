"""Reopen Unicode PDF text with independent tools and verify actual saved UTF-8."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import subprocess
from pypdf import PdfReader
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas


def verify(executable, destination, font):
    root = Path(destination).resolve()
    root.mkdir(parents=True, exist_ok=True)
    source = root / 'text-source.pdf'
    output = root / 'extracted.txt'
    if source.exists() or output.exists():
        raise ValueError('Choose a fresh verification directory.')
    pdfmetrics.registerFont(TTFont('VerifiedBengali', str(font)))
    drawing = canvas.Canvas(str(source), pagesize=(595, 842), pdfVersion=(1, 7))
    lines = ['Certificate number 123', 'সনদ নম্বর ১২৩']
    for line in lines:
        drawing.setFont('VerifiedBengali', 16)
        drawing.drawString(40, 700, line)
        drawing.showPage()
    drawing.save()
    original = hashlib.sha256(source.read_bytes()).hexdigest()
    independent = '\n'.join(p.extract_text() for p in PdfReader(source, strict=True).pages)
    assert all(line in independent for line in lines)
    config = root / 'request.json'
    config.write_text(json.dumps({'operation': 'extract_pdf_text', 'input': str(source),
                                 'directory': str(root), 'filename': output.name}))
    result = subprocess.run([str(Path(executable).resolve()), str(config)], capture_output=True, timeout=30)
    if result.returncode:
        raise RuntimeError(result.stderr.decode('utf-8', errors='replace'))
    data = output.read_bytes()
    text = data.decode('utf-8')
    assert all(line in text for line in lines)
    assert text.index(lines[0]) < text.index(lines[1])
    assert original == hashlib.sha256(source.read_bytes()).hexdigest()
    repeated = subprocess.run([str(Path(executable).resolve()), str(config)], capture_output=True, timeout=30)
    assert repeated.returncode != 0 and output.read_bytes() == data
    return {'unicode_english_bangla_text_verified': True, 'page_order_verified': True,
            'source_unchanged': True, 'no_clobber_verified': True, 'ocr_used': False,
            'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest(),
            'independent_parser': 'pypdf', 'native_engine': 'PDFium',
            'reading_order_guaranteed': False}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--executable', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--font', type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(verify(args.executable, args.output, args.font), indent=2))
