"""Create development-only synthetic pages for native OCR integration tests."""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, features

def create(directory: Path):
    if not features.check('raqm'):
        raise RuntimeError('Bangla fixtures require RAQM shaping.')
    font_path = Path(__file__).resolve().parents[1] / 'assets/fonts/NotoSansBengali.ttf'
    if hashlib.sha256(font_path.read_bytes()).hexdigest() != 'dcd42978094e584a849c84a51450eeac40c8826057d566ea6d4b9627a403a05a':
        raise ValueError('Test font checksum mismatch.')
    directory.mkdir(parents=True, exist_ok=True)
    font = ImageFont.truetype(str(font_path), 64)
    cases = {'eng': 'UNIVERSAL STUDIO 123', 'ben': 'আমার বাংলা ভাষা'}
    for language, text in cases.items():
        image = Image.new('RGB', (1600, 250), 'white')
        ImageDraw.Draw(image).text((40, 50), text, font=font, fill='black', language='bn' if language == 'ben' else 'en')
        image.save(directory / (language + '.png'), dpi=(300, 300))
    (directory / 'expected.json').write_text(json.dumps(cases, ensure_ascii=False), encoding='utf-8')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    create(parser.parse_args().output)
