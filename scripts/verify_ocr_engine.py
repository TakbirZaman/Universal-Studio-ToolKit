"""Development-only OCR check on synthetic text; no application OCR claim.

Requires Pillow with RAQM, a local Tesseract 5 executable and locally supplied,
checksum-verified English/Bangla tessdata_fast files. Never downloads assets.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time

from PIL import Image, ImageDraw, ImageFont, features

MODELS = {
    "eng.traineddata": (4113088, "7d4322bd2a7749724879683fc3912cb542f19906c83bcc1a52132556427170b2"),
    "ben.traineddata": (855841, "31163084c279aaebd376216f0c3d5c17ad4b5fee8db49dae79c20000b5de5964"),
    "LICENSE": (11358, "cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30"),
}


def verify_models(directory):
    for name, (length, digest) in MODELS.items():
        with (directory / name).open("rb") as source:
            data = source.read(length + 1)
        if len(data) != length or hashlib.sha256(data).hexdigest() != digest:
            raise ValueError("Local OCR asset failed verification: " + name)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--models", type=Path, required=True)
    parser.add_argument("--engine", default="tesseract")
    args = parser.parse_args()
    verify_models(args.models)
    if not features.check("raqm"):
        raise RuntimeError("RAQM shaping is required for a meaningful Bangla test.")
    version = subprocess.run(
        [args.engine, "--version"], capture_output=True, timeout=5, check=True,
    ).stdout.decode("utf-8").splitlines()[0]
    if not version.startswith("tesseract 5."):
        raise RuntimeError("This check requires a Tesseract 5 engine.")
    font_path = Path(__file__).resolve().parents[1] / "assets/fonts/NotoSansBengali.ttf"
    if hashlib.sha256(font_path.read_bytes()).hexdigest() != "dcd42978094e584a849c84a51450eeac40c8826057d566ea6d4b9627a403a05a":
        raise ValueError("The test font does not match its pinned provenance.")
    font = ImageFont.truetype(str(font_path), 64)
    report = {
        "engine": version + " host command; not integrated in app",
        "model_commit": "87416418657359cb625c412a48b6e1d6d41c29bd",
        "raqm": True,
        "cases": [],
    }
    with tempfile.TemporaryDirectory(prefix="ust-ocr-smoke-") as directory:
        for lang, text in [("eng", "UNIVERSAL STUDIO 123"), ("ben", "আমার বাংলা ভাষা")]:
            image = Image.new("RGB", (1600, 250), "white")
            ImageDraw.Draw(image).text(
                (40, 50), text, font=font, fill="black",
                language="bn" if lang == "ben" else "en",
            )
            path = Path(directory) / (lang + ".png")
            image.save(path, dpi=(300, 300))
            start = time.monotonic()
            result = subprocess.run(
                [args.engine, str(path), "stdout", "--tessdata-dir", str(args.models),
                 "-l", lang, "--oem", "1", "--psm", "6"],
                capture_output=True, timeout=30,
                env={**os.environ, "OMP_THREAD_LIMIT": "1"},
            )
            actual = result.stdout.decode("utf-8").strip()
            report["cases"].append({
                "language": lang, "synthetic_expected": text, "recognized": actual,
                "exact_match": actual == text, "exit_code": result.returncode,
                "seconds": round(time.monotonic() - start, 3),
                "model_sha256": MODELS[lang + ".traineddata"][1],
            })
    print(json.dumps(report, ensure_ascii=False, indent=2))
    if any(not case["exact_match"] or case["exit_code"] for case in report["cases"]):
        raise SystemExit("Synthetic OCR check did not meet its expected text; inspect the report.")


if __name__ == "__main__":
    main()
