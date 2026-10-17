#!/usr/bin/env python3
"""Collect resolved dependency notices; source/hash integrity is not license approval."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tomllib
from urllib.parse import unquote, urlparse
from notice_provenance import add_hashes, dart_lock_records, verify, verify_sources

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'third_party'
PREFIXES = ('license', 'licence', 'copying', 'notice', 'copyright', 'authors')


def notice_files(folder):
    return sorted((p for p in folder.iterdir() if p.is_file() and p.name.lower().startswith(PREFIXES)), key=lambda p: p.name)


def retain(files, destination):
    destination.mkdir(parents=True, exist_ok=True)
    for file in files:
        shutil.copy2(file, destination / file.name)
    upstream = destination / 'UPSTREAM-LICENSE'
    retained = {destination / file.name for file in files}
    if upstream.exists():
        retained.add(upstream)
    return sorted(str(p.relative_to(ROOT)) for p in retained)


def package_folder(config, uri):
    return Path(unquote(urlparse(uri).path)) if uri.startswith('file:') else (config.parent / uri).resolve()


def collect():
    OUT.mkdir(exist_ok=True)
    cargo_lock = tomllib.loads((ROOT / 'rust/Cargo.lock').read_text())
    cargo_sources = {(p['name'], p['version']): p for p in cargo_lock['package']}
    dart_sources = dart_lock_records((ROOT / 'pubspec.lock').read_text())
    metadata = json.loads(subprocess.check_output(['cargo', 'metadata', '--locked', '--format-version', '1', '--manifest-path', str(ROOT / 'rust/Cargo.toml')]))
    records = []
    for package in metadata['packages']:
        if package['name'] == 'studio_core':
            continue
        folder = Path(package['manifest_path']).parent
        files = notice_files(folder)
        declared_file = package.get('license_file')
        if declared_file:
            specified = (folder / declared_file).resolve()
            if not specified.is_relative_to(folder.resolve()) or not specified.is_file():
                raise ValueError('Declared license file is missing or outside its package.')
            if specified not in [p.resolve() for p in files]:
                files.append(specified)
        destination = OUT / 'rust' / f"{package['name']}-{package['version']}"
        records.append({
            'ecosystem': 'rust', 'name': package['name'], 'version': package['version'],
            'declared_license': package.get('license'),
            'declared_license_file': Path(declared_file).name if declared_file else None,
            'repository': package.get('repository'),
            'source_lock_sha256': cargo_sources[(package['name'], package['version'])].get('checksum'),
            'files': retain(files, destination),
            'review': 'source license files collected; obligations require review',
        })
    config = ROOT / '.dart_tool/package_config.json'
    if not config.exists():
        raise ValueError('Run flutter pub get --enforce-lockfile before collecting notices.')
    packages = json.loads(config.read_text())['packages']
    flutter = next(p for p in packages if p['name'] == 'flutter')
    sdk_root = package_folder(config, flutter['rootUri']).parent.parent
    revision = subprocess.check_output(['git', '-C', str(sdk_root), 'rev-parse', 'HEAD'], text=True).strip()
    engine = (sdk_root / 'bin/internal/engine.version').read_text().strip()
    for package in packages:
        if package['name'] == 'universal_studio_toolkit':
            continue
        folder = package_folder(config, package['rootUri'])
        files = notice_files(folder)
        if not files and package['name'] in {'flutter_test', 'flutter_web_plugins'}:
            files = [sdk_root / 'LICENSE']
        locked = dart_sources[package['name']]
        records.append({
            'ecosystem': 'dart', 'name': package['name'], 'version': locked['version'],
            'source': locked['source'],
            'source_revision': revision if locked['source'] == 'sdk' else None,
            'engine_revision': engine if package['name'] == 'sky_engine' else None,
            'source_lock_sha256': locked.get('sha256'),
            'dependency_kind': locked.get('dependency'),
            'files': retain(files, OUT / 'dart' / package['name']),
            'review': 'source license files collected; obligations require review',
        })
    verify_sources(records, cargo_lock['package'], dart_sources)
    add_hashes(ROOT, records)
    report = verify(ROOT, records)
    temporary = OUT / 'inventory.json.tmp'
    temporary.write_text(json.dumps(records, indent=2) + '\n', encoding='utf-8')
    os.replace(temporary, OUT / 'inventory.json')
    print(json.dumps(report))


if __name__ == '__main__':
    collect()
