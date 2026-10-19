"""Retain pinned OpenCV candidate notices without staging a runtime library.

This is conservative source notice collection, not automatic legal clearance.
The source archive must first be verified against native/opencv/SOURCE.json.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re


def collect(source: Path, output: Path):
    root = Path(__file__).resolve().parents[1]
    policy = json.loads((root / 'native/opencv/SOURCE.json').read_text())
    full_files = [
        'LICENSE', 'doc/LICENSE_CHANGE_NOTICE.txt', 'doc/LICENSE_BSD.txt',
        'modules/core/3rdparty/SoftFloat/COPYING.txt', '3rdparty/dlpack/LICENSE',
        '3rdparty/zlib/LICENSE', 'modules/imgproc/fonts/Rubik_OFL.txt',
    ]
    output.mkdir(parents=True, exist_ok=True)
    entries = []
    for relative in full_files:
        data = (source / relative).read_bytes()
        name = relative.replace('/', '__')
        (output / name).write_bytes(data)
        entries.append({'source': relative, 'notice': name,
                        'sha256': hashlib.sha256(data).hexdigest()})
    # Preserve the complete, unmodified upstream file in addition to its notices.
    # This is conservative source retention for its redistribution-in-entirety
    # wording, not an assertion that every native obligation is cleared.
    geometry_source = (source / 'modules/geometry/src/geometry.cpp').read_bytes()
    (output / 'upstream-geometry.cpp.txt').write_bytes(geometry_source)
    entries.append({'source': 'modules/geometry/src/geometry.cpp',
                    'kind': 'complete_unmodified_source_retention',
                    'notice': 'upstream-geometry.cpp.txt',
                    'sha256': hashlib.sha256(geometry_source).hexdigest()})
    boost = root / 'third_party/opencv-candidate/Boost-1.0.txt'
    boost_data = boost.read_bytes()
    boost_sha = 'c9bff75738922193e67fa726fa225535870d2aa1059f91452c411736284ad566'
    if hashlib.sha256(boost_data).hexdigest() != boost_sha:
        raise ValueError('The separately retained Boost1.0 license does not match its verified copy.')
    (output / 'Boost-1.0.txt').write_bytes(boost_data)
    entries.append({'upstream_url': 'https://www.boost.org/LICENSE_1_0.txt',
                    'source_reference': 'modules/flann/include/opencv2/flann/any.h',
                    'notice': 'Boost-1.0.txt', 'sha256': boost_sha})
    # Keep entire copyright/license comment blocks, not only SPDX identifiers.
    # Includes tests/unused paths conservatively; exact linked-object applicability
    # remains a separate per-platform review.
    groups = {}
    for directory in ['modules/core', 'modules/imgproc', 'modules/geometry', 'modules/flann', '3rdparty/zlib']:
        for path in sorted((source / directory).rglob('*')):
            if not path.is_file() or path.suffix not in {'.h', '.hpp', '.c', '.cpp', '.cc', '.inl'}:
                continue
            content = path.read_text(encoding='utf-8', errors='strict')
            for block in re.findall(r'/\*.*?\*/|(?m:^\s*//[^\n]*(?:\n\s*//[^\n]*)*)', content, re.S):
                if not re.search(r'copyright|redistribution and use|permission is hereby granted', block, re.I):
                    continue
                digest = hashlib.sha256(block.encode()).hexdigest()
                group = groups.setdefault(digest, {'text': block, 'origins': []})
                relative = path.relative_to(source).as_posix()
                if relative not in group['origins']:
                    group['origins'].append(relative)
    for digest, group in sorted(groups.items()):
        name = 'source-notice-' + digest + '.txt'
        (output / name).write_text(group['text'], encoding='utf-8')
        entries.append({'sources': group['origins'], 'notice': name, 'sha256': digest})
    manifest = {'schema_version': 1, 'opencv_version': policy['version'],
                'opencv_source_commit': policy['commit'], 'archive_sha256': policy['archive_sha256'],
                'scope': 'Conservative candidate source notice retention; includes unused source notices.',
                'application_staging_complete': False, 'complete_license_clearance': False,
                'entries': entries}
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    return {'retained_notices': len(entries), 'complete_license_clearance': False}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(collect(args.source.resolve(), args.output.resolve()), indent=2))
