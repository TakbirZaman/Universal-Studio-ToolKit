import shutil
from pathlib import Path
import tempfile
import unittest
import xml.etree.ElementTree as ET
from verify_android_privacy import ANDROID, DOMAINS, exclusions, verify_source

class PrivacyTests(unittest.TestCase):
    def test_actual_source_excludes_private_data(self):
        verify_source(Path(__file__).resolve().parents[1])

    def test_missing_transfer_or_domain_does_not_silently_enable_backup(self):
        with self.assertRaises(ValueError):
            exclusions(None)
        element = ET.Element('cloud-backup')
        for domain in sorted(DOMAINS - {'database'}):
            ET.SubElement(element, 'exclude', domain=domain, path='.')
        with self.assertRaises(ValueError):
            exclusions(element)
        ET.SubElement(element, 'exclude', domain='database', path='.')
        exclusions(element)
        ET.SubElement(element, 'include', domain='file', path='.')
        with self.assertRaises(ValueError):
            exclusions(element)

    def test_manifest_regression_is_rejected(self):
        source = Path(__file__).resolve().parents[1] / 'android/app/src/main'
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            target=root/'android/app/src/main'
            (target/'res/xml').mkdir(parents=True)
            for name in ['backup_rules.xml','data_extraction_rules.xml']:
                shutil.copy2(source/'res/xml'/name,target/'res/xml'/name)
            manifest=ET.parse(source/'AndroidManifest.xml')
            manifest.getroot().find('application').set(ANDROID+'allowBackup','true')
            manifest.write(target/'AndroidManifest.xml')
            with self.assertRaises(ValueError):
                verify_source(root)

if __name__ == '__main__':
    unittest.main()
