"""Notice integrity/provenance, not an automatic license or legal approval."""
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import tomllib

MAX_NOTICE_BYTES = 4 * 1024 * 1024


def dart_lock_records(text):
    """Read scalar package metadata from pub's generated lockfile format.

    Fail closed on missing versions/sources; never evaluate YAML objects.
    """
    packages = {}
    current = None
    for line in text.splitlines():
        match = re.fullmatch(r'  ([A-Za-z0-9_]+):', line)
        if match:
            current = match.group(1)
            if current in packages:
                raise ValueError('Duplicate Dart lockfile package.')
            packages[current] = {}
            continue
        if line and not line.startswith((' ', '#')):
            current = None
        if current:
            field = re.fullmatch(r'    (version|source|dependency): [\"\']?([^\"\']+?)[\"\']?', line)
            if field:
                packages[current][field.group(1)] = field.group(2)
            checksum = re.fullmatch(r'      sha256: [\"\']?([a-f0-9]{64})[\"\']?', line)
            if checksum:
                packages[current]['sha256'] = checksum.group(1)
    for package in packages.values():
        if not package.get('version') or package.get('source') not in {'hosted', 'sdk', 'git', 'path'}:
            raise ValueError('Dart lockfile package has no supported source/version.')
        if package['source'] == 'hosted' and not package.get('sha256'):
            raise ValueError('Hosted Dart package has no locked checksum.')
    return packages


def notice_hash(root, relative):
    path = PurePosixPath(relative)
    if (not path.parts or path.is_absolute() or path.parts[0] != 'third_party'
            or '..' in path.parts or '\\' in relative or str(path) != relative):
        raise ValueError('Notice path must stay in third_party.')
    destination = Path(root)
    for component in path.parts:
        destination = destination / component
        if destination.is_symlink():
            raise ValueError('Notice paths cannot use symbolic links.')
    with destination.open('rb') as source:
        content = source.read(MAX_NOTICE_BYTES + 1)
    if len(content) > MAX_NOTICE_BYTES:
        raise ValueError('Notice exceeds the supported size.')
    return hashlib.sha256(content).hexdigest()


def add_hashes(root, records):
    for record in records:
        record['license_files_sha256'] = {path: notice_hash(root, path) for path in record['files']}
    return records


def verify(root, records):
    if not isinstance(records, list) or not records or len(records) > 5000:
        raise ValueError('Invalid dependency notice inventory.')
    identities = set()
    file_count = 0
    for record in records:
        identity = (record['ecosystem'], record['name'], record['version'])
        if identity in identities:
            raise ValueError('Duplicate dependency in notice inventory.')
        identities.add(identity)
        if not record['files'] or len(set(record['files'])) != len(record['files']):
            raise ValueError('Dependency notices are missing or duplicated.')
        expected = record['license_files_sha256']
        if set(expected) != set(record['files']):
            raise ValueError('Notice hash coverage is incomplete.')
        for path in record['files']:
            if notice_hash(root, path) != expected[path]:
                raise ValueError('Dependency notice changed; refresh and review provenance.')
            file_count += 1
    return {'dependencies': len(records), 'notice_files_verified': file_count,
            'license_obligations_cleared': False}


def verify_sources(records, cargo_packages, dart_packages):
    rust = {(p['name'], p['version']): p for p in cargo_packages if p['name'] != 'studio_core'}
    recorded_rust = {(p['name'], p['version']): p for p in records if p['ecosystem'] == 'rust'}
    recorded_dart = {p['name']: p for p in records if p['ecosystem'] == 'dart'}
    if set(rust) != set(recorded_rust) or set(dart_packages) != set(recorded_dart):
        raise ValueError('Notice inventory does not cover the current lockfiles.')
    for key, locked in rust.items():
        if not locked.get('checksum') or recorded_rust[key].get('source_lock_sha256') != locked['checksum']:
            raise ValueError('Rust notice provenance does not match the locked source archive.')
    for name, locked in dart_packages.items():
        record = recorded_dart[name]
        if record['version'] != locked['version'] or record.get('source') != locked['source']:
            raise ValueError('Dart notice version/source does not match the lockfile.')
        if locked['source'] == 'hosted' and record.get('source_lock_sha256') != locked['sha256']:
            raise ValueError('Dart notice provenance does not match the locked source archive.')
        if locked['source'] == 'sdk' and not re.fullmatch(r'[a-f0-9]{40}', record.get('source_revision', '')):
            raise ValueError('SDK notices need their actual framework source revision.')


if __name__ == '__main__':
    root = Path(__file__).resolve().parents[1]
    records = json.loads((root / 'third_party/inventory.json').read_text())
    verify_sources(records, tomllib.loads((root / 'rust/Cargo.lock').read_text())['package'], dart_lock_records((root / 'pubspec.lock').read_text()))
    print(json.dumps(verify(root, records)))
