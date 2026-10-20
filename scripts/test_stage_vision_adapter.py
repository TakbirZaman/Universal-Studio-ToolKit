"""Actual engine staging and tamper/no-clobber checks; provision explicitly."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

import stage_vision_adapter as staging


@unittest.skipUnless(os.environ.get('UST_VISION_LIBRARY'), 'Provision UST_VISION_LIBRARY for actual native staging tests')
class NativeStagingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        from verify_vision_adapter import verify
        cls.library = Path(os.environ['UST_VISION_LIBRARY'])
        cls.platform = 'windows-x64' if os.name == 'nt' else 'linux-x64'
        cls.report = verify(cls.library)
        cls.report.update(source_archive_verified=True, tested_adapter_platform=cls.platform,
                          opencv_source_commit=json.loads((staging.ROOT / 'native/opencv/SOURCE.json').read_text())['commit'])

    def test_actual_staged_library_loads_and_notices_match(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            report = root / 'report.json'
            report.write_text(json.dumps(self.report))
            result = staging.stage(self.platform, self.library, report, root / 'lib', root / 'notices')
            copied = root / 'lib' / result['library']
            # A child process releases mapped DLLs before TemporaryDirectory cleanup on Windows.
            actual = json.loads(subprocess.check_output([sys.executable, str(staging.ROOT / 'scripts/verify_vision_adapter.py'), '--library', str(copied)], text=True))
            self.assertEqual(actual['library_sha256'], self.report['library_sha256'])
            self.assertTrue((root / 'notices/opencv-candidate/upstream-geometry.cpp.txt').is_file())
            self.assertEqual(result['platform'], self.platform)
            self.assertNotIn(str(self.library), json.dumps(result))
            from verify_packaged_vision import verify as verify_package
            # Match the actual platform bundle layout for independent inspection.
            if self.platform == 'linux-x64':
                bundle = root / 'bundle'
                bundle.mkdir()
                (root / 'lib').rename(bundle / 'lib')
                (root / 'notices').rename(bundle / 'third_party')
            else:
                bundle = root / 'lib'
                (root / 'notices').rename(bundle / 'third_party')
            inspection = verify_package(self.platform, bundle)
            self.assertEqual(inspection['packaged_library_sha256'], self.report['library_sha256'])
            self.assertEqual(inspection['retained_notice_records'], 155)
            retained = bundle / 'third_party/opencv-candidate/Boost-1.0.txt'
            retained.write_text('tampered')
            with self.assertRaisesRegex(ValueError, 'content mismatch'):
                verify_package(self.platform, bundle)

    def test_changed_binary_report_is_rejected_before_writing(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            report = root / 'report.json'
            report.write_text(json.dumps(dict(self.report, library_sha256='0' * 64)))
            with self.assertRaisesRegex(ValueError, 'does not match'):
                staging.stage(self.platform, self.library, report, root / 'lib', root / 'notices')
            self.assertFalse((root / 'lib').exists())

    @unittest.skipIf(os.name == 'nt', 'Windows symlink privileges are not assumed')
    def test_symlink_destination_is_rejected_without_touching_target(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            report = root / 'report.json'
            report.write_text(json.dumps(self.report))
            (root / 'lib').mkdir()
            outside = root / 'original'
            outside.write_bytes(b'unchanged')
            (root / 'lib/libust_cv.so').symlink_to(outside)
            with self.assertRaisesRegex(ValueError, 'symbolic link'):
                staging.stage(self.platform, self.library, report, root / 'lib', root / 'notices')
            self.assertEqual(outside.read_bytes(), b'unchanged')


if __name__ == '__main__':
    unittest.main()
