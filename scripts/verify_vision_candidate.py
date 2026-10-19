"""Developer/CI source build and independent pixel verification, never app startup."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import urllib.request


def run(platform, work):
    root = Path(__file__).resolve().parents[1]
    policy = json.loads((root / 'native/opencv/SOURCE.json').read_text())
    work.mkdir(parents=True, exist_ok=True)
    archive = work / 'opencv.tar.gz'
    urllib.request.urlretrieve('https://github.com/opencv/opencv/archive/' + policy['commit'] + '.tar.gz', archive)
    if archive.stat().st_size != policy['archive_bytes'] or hashlib.file_digest(archive.open('rb'), 'sha256').hexdigest() != policy['archive_sha256']:
        raise ValueError('OpenCV source archive does not match the pin.')
    with tarfile.open(archive) as package:
        package.extractall(work / 'source', filter='data')
    source = work / 'source' / ('opencv-' + policy['commit'])
    cmake, ninja = shutil.which('cmake'), shutil.which('ninja')
    if not cmake or not ninja:
        raise ValueError('Install pinned CMake3.28.4 and Ninja1.13.2 developer tools.')
    if subprocess.check_output([cmake, '--version'], text=True).splitlines()[0] != 'cmake version 3.28.4':
        raise ValueError('Unexpected CMake version.')
    if subprocess.check_output([ninja, '--version'], text=True).strip() != '1.13.2':
        raise ValueError('Unexpected Ninja version.')
    subprocess.run([sys.executable, str(root / 'scripts/build_vision_adapter.py'), '--source', str(source),
                    '--work', str(work / 'build'), '--install', str(work / 'sdk'), '--cmake', cmake,
                    '--ninja', ninja, '--platform', platform, '--jobs', '4'], check=True)
    filename = 'ust_cv.dll' if platform == 'windows-x64' else 'libust_cv.so'
    libraries = list((work / 'build/adapter').rglob(filename))
    if len(libraries) != 1:
        raise ValueError('Expected one candidate adapter.')
    report = subprocess.check_output([sys.executable, str(root / 'scripts/verify_vision_adapter.py'), '--library', str(libraries[0])], text=True)
    parsed = json.loads(report)
    # Generic verification script never certifies app/platform integration.
    parsed['tested_adapter_platform'] = platform
    parsed['source_archive_verified'] = True
    (work / 'pixel-verification.json').write_text(json.dumps(parsed, indent=2) + '\n', encoding='utf-8')
    print(report)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--platform', choices=['linux-x64', 'windows-x64'], required=True)
    parser.add_argument('--work', type=Path, required=True)
    args = parser.parse_args()
    run(args.platform, args.work.resolve())
