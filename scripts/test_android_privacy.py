import shutil
from pathlib import Path
import tempfile
import unittest
import xml.etree.ElementTree as ET
from verify_android_privacy import ANDROID, DOMAINS, exclusions, verify_source, resource_paths, xmltree_policy

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

class CompiledResourceTests(unittest.TestCase):
    def test_resource_ids_resolve_optimized_paths_and_all_variants(self):
        table = """    resource 0x7f0e0000 xml/backup_rules
      () (file) res/rU.xml type=XML
      (v31) (file) res/aB.xml type=XML
    resource 0x7f0e0001 xml/other
      () (file) res/unrelated.xml type=XML
"""
        self.assertEqual(resource_paths(table, '0x7f0e0000'), ['res/aB.xml', 'res/rU.xml'])
        with self.assertRaises(ValueError):
            resource_paths(table, '0x7f0e0002')
        with self.assertRaises(ValueError):
            resource_paths(table.replace('res/rU.xml','res/../escape.xml'), '0x7f0e0000')

    def test_compiled_hierarchy_must_exclude_each_domain_in_each_transport(self):
        def section(name, domains):
            lines = ['  E: ' + name + ' (line=2)']
            for domain in sorted(domains):
                lines += ['    E: exclude (line=3)', '      A: domain="' + domain + '" (Raw: "' + domain + '")', '      A: path="." (Raw: ".")']
            return '\n'.join(lines)
        text = 'E: data-extraction-rules (line=1)\n' + section('cloud-backup', DOMAINS) + '\n' + section('device-transfer', DOMAINS - {'database'})
        root = xmltree_policy(text)
        exclusions(root.find('cloud-backup'))
        with self.assertRaises(ValueError):
            exclusions(root.find('device-transfer'))

if __name__ == '__main__':
    unittest.main()
