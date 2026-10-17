"""Verify explicit backup policy. This is not OEM/device transport testing."""
from pathlib import Path
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

DOMAINS = {'root', 'file', 'database', 'sharedpref', 'external',
           'device_root', 'device_file', 'device_database', 'device_sharedpref'}
ANDROID = '{http://schemas.android.com/apk/res/android}'


def exclusions(element):
    if element is None or element.findall('include'):
        raise ValueError('Backup policy must not include private app data.')
    found = {(e.get('domain'), e.get('path')) for e in element.findall('exclude')}
    if found != {(domain, '.') for domain in DOMAINS}:
        raise ValueError('Backup exclusions must cover every app-data domain.')


def verify_source(root):
    source = Path(root) / 'android/app/src/main'
    application = ET.parse(source / 'AndroidManifest.xml').getroot().find('application')
    expected = {'allowBackup': 'false', 'backupAgent': '.LocalOnlyBackupAgent',
                'fullBackupContent': '@xml/backup_rules', 'dataExtractionRules': '@xml/data_extraction_rules'}
    if application is None or any(application.get(ANDROID + key) != value for key, value in expected.items()):
        raise ValueError('Android manifest must opt out of app-data backup and declare explicit rules.')
    legacy = ET.parse(source / 'res/xml/backup_rules.xml').getroot()
    if legacy.tag != 'full-backup-content':
        raise ValueError('Invalid legacy backup rules.')
    exclusions(legacy)
    modern = ET.parse(source / 'res/xml/data_extraction_rules.xml').getroot()
    if modern.tag != 'data-extraction-rules':
        raise ValueError('Invalid modern backup rules.')
    exclusions(modern.find('cloud-backup'))
    exclusions(modern.find('device-transfer'))


def verify_compiled(apk, aapt2):
    result = subprocess.run([str(aapt2), 'dump', 'xmltree', str(apk), '--file', 'AndroidManifest.xml'],
                            capture_output=True, text=True, timeout=30, check=True)
    lines = result.stdout.splitlines()
    backup = next((line for line in lines if re.search(r'\bandroid:allowBackup\b', line)), '')
    if not re.search(r'(?:false|0x0+)\s*$', backup):
        raise ValueError('Compiled APK does not explicitly disable Android backup.')
    if any(permission in result.stdout for permission in ['android.permission.MANAGE_EXTERNAL_STORAGE', 'android.permission.READ_EXTERNAL_STORAGE', 'android.permission.WRITE_EXTERNAL_STORAGE']):
        raise ValueError('Broad filesystem permissions are not needed for document-provider access.')
    debugging = next((line for line in lines if 'android:debuggable' in line), '')
    is_debug = bool(re.search(r'(?:true|0xffffffff)\s*$', debugging))
    if not is_debug and 'android.permission.INTERNET' in result.stdout:
        raise ValueError('Release processing must not request network permission.')
    for key in ['backupAgent', 'fullBackupContent', 'dataExtractionRules']:
        if not any('android:' + key in line for line in lines):
            raise ValueError('Compiled manifest is missing the backup-policy adapter/rules.')
    for resource, sections in [('backup_rules.xml', ['full-backup-content']),
                               ('data_extraction_rules.xml', ['cloud-backup', 'device-transfer'])]:
        xml = subprocess.run([str(aapt2), 'dump', 'xmltree', str(apk), '--file', 'res/xml/' + resource],
                             capture_output=True, text=True, timeout=30, check=True).stdout
        if any(section not in xml for section in sections) or 'include ' in xml:
            raise ValueError('Compiled APK backup rules failed verification.')
        for domain in DOMAINS:
            if not re.search(r'domain="' + re.escape(domain) + r'"', xml):
                raise ValueError('Compiled backup-rule domains are incomplete.')


if __name__ == '__main__':
    verify_source(Path(__file__).resolve().parents[1])
    if len(sys.argv) == 3:
        verify_compiled(Path(sys.argv[1]), Path(sys.argv[2]))
    elif len(sys.argv) != 1:
        raise SystemExit('Usage: verify_android_privacy.py [APK AAPT2]')
    print('Explicit Android backup opt-out and exclusion policy verified; device transport testing remains outstanding.')
