import hashlib
from pathlib import Path
import tempfile
import unittest
from notice_provenance import add_hashes, dart_lock_records, notice_hash, verify, verify_sources

class NoticeTests(unittest.TestCase):
    def test_lock_versions_sources_and_checksums(self):
        sha = 'a' * 64
        records = dart_lock_records(f'''packages:
  sample:
    dependency: "direct main"
    description:
      sha256: "{sha}"
    source: hosted
    version: "1.2.3"
  flutter:
    dependency: "direct main"
    source: sdk
    version: "0.0.0"
sdks:
  dart: ">=3.0.0"
''')
        self.assertEqual(records['sample']['version'], '1.2.3')
        self.assertEqual(records['sample']['sha256'], sha)
        self.assertEqual(records['flutter']['source'], 'sdk')
        with self.assertRaises(ValueError):
            dart_lock_records('packages:\n  sample:\n    source: hosted\n')

    def test_notice_changes_missing_files_and_traversal_fail(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'third_party/sample').mkdir(parents=True)
            path = root / 'third_party/sample/LICENSE'
            path.write_text('Synthetic notice used only for integrity testing.')
            records = [{'ecosystem': 'test', 'name': 'sample', 'version': '1',
                        'files': ['third_party/sample/LICENSE']}]
            add_hashes(root, records)
            self.assertEqual(verify(root, records)['dependencies'], 1)
            self.assertFalse(verify(root, records)['license_obligations_cleared'])
            path.write_text('Changed notice')
            with self.assertRaises(ValueError):
                verify(root, records)
            path.unlink()
            with self.assertRaises(FileNotFoundError):
                verify(root, records)
            with self.assertRaises(ValueError):
                notice_hash(root, 'third_party/../../private')
            with self.assertRaises(ValueError):
                notice_hash(root, '/private')

    def test_lockfile_coverage_and_archive_changes_fail(self):
        sha = 'a' * 64
        cargo = [{'name':'studio_core','version':'1'}, {'name':'sample','version':'1','checksum':sha}]
        dart = {'plugin':{'version':'2','source':'hosted','sha256':sha}}
        records = [{'ecosystem':'rust','name':'sample','version':'1','source_lock_sha256':sha},
                   {'ecosystem':'dart','name':'plugin','version':'2','source':'hosted','source_lock_sha256':sha}]
        verify_sources(records,cargo,dart)
        with self.assertRaises(ValueError):
            verify_sources(records[:-1],cargo,dart)
        records[1]['source_lock_sha256'] = 'b' * 64
        with self.assertRaises(ValueError):
            verify_sources(records,cargo,dart)

    def test_duplicate_records_fail(self):
        record = {'ecosystem':'test','name':'sample','version':'1','files':['third_party/LICENSE'],
                  'license_files_sha256': {'third_party/LICENSE':hashlib.sha256(b'x').hexdigest()}}
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            (root/'third_party').mkdir()
            (root/'third_party/LICENSE').write_bytes(b'x')
            with self.assertRaises(ValueError):
                verify(root,[record,record])

if __name__ == '__main__':
    unittest.main()
