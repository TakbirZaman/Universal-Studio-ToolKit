"""Boundary checks use tiny synthetic bytes, never redistributed OCR assets."""
import hashlib
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import stage_ocr_models as subject

class StageTests(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory()
        self.addCleanup(self.scratch.cleanup)
        self.root = Path(self.scratch.name)
        self.source = self.root / 'input'
        self.source.mkdir()
        self.bundle = self.root / 'bundle'
        self.assets = {name: ('synthetic-' + name).encode() for name in subject.MODELS}
        for name, data in self.assets.items():
            (self.source / name).write_bytes(data)
        models = {name: (len(data), hashlib.sha256(data).hexdigest()) for name, data in self.assets.items()}
        self.mock = patch.object(subject, 'MODELS', models)
        self.mock.start()
        self.addCleanup(self.mock.stop)

    def test_verified_copies_include_license_and_refuse_overwrite(self):
        subject.stage(self.source, self.bundle)
        for name, data in self.assets.items():
            self.assertEqual((self.bundle / 'ocr/tessdata' / name).read_bytes(), data)
        with self.assertRaises(ValueError):
            subject.stage(self.source, self.bundle)

    def test_corruption_leaves_no_partial_models(self):
        (self.source / 'ben.traineddata').write_bytes(b'wrong')
        with self.assertRaises(ValueError):
            subject.stage(self.source, self.bundle)
        self.assertFalse((self.bundle / 'ocr').exists())

    def test_model_symlink_is_rejected(self):
        path = self.source / 'eng.traineddata'
        path.rename(self.source / 'real-model')
        path.symlink_to(self.source / 'real-model')
        with self.assertRaises(ValueError):
            subject.stage(self.source, self.bundle)

if __name__ == '__main__':
    unittest.main()
