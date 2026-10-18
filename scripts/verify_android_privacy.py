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


def resource_paths(table, resource_id):
    """Resolve compiled IDs rather than assuming optimizer-preserved filenames."""
    current = None
    paths = []
    for line in table.splitlines():
        header = re.search(r'^\s*resource (0x[0-9a-fA-F]+)\b', line)
        if header:
            current = int(header.group(1), 16)
        if current == int(resource_id, 16):
            value = re.search(r'\(file\) (\S+) type=XML\s*$', line)
            if value:
                path = value.group(1)
                if not path.startswith('res/') or '..' in path.split('/') or '\\' in path:
                    raise ValueError('Invalid compiled XML resource path.')
                paths.append(path)
    if not paths:
        raise ValueError('Compiled backup XML resource has no resolvable file.')
    return sorted(set(paths))


def xmltree_policy(text):
    """Read the element hierarchy in SDK aapt2 xmltree output."""
    stack = []
    root = None
    for line in text.splitlines():
        element = re.match(r'^(\s*)E: ([A-Za-z0-9_.-]+)(?:\s|$)', line)
        if element:
            depth = len(element.group(1))
            while stack and stack[-1][0] >= depth:
                stack.pop()
            node = ET.Element(element.group(2))
            if stack:
                stack[-1][1].append(node)
            elif root is None:
                root = node
            else:
                raise ValueError('Multiple compiled XML roots.')
            stack.append((depth, node))
        else:
            attribute = re.match(r'^\s*A: (domain|path)(?:\([^)]*\))?="([^"\n]*)"', line)
            if attribute and stack:
                stack[-1][1].set(attribute.group(1), attribute.group(2))
    if root is None:
        raise ValueError('Could not parse compiled backup XML.')
    return root


def verify_compiled(apk, aapt2):
    def dump(*args):
        return subprocess.run([str(aapt2), 'dump', *args], capture_output=True,
                              text=True, timeout=30, check=True).stdout
    manifest = dump('xmltree', str(apk), '--file', 'AndroidManifest.xml')
    lines = manifest.splitlines()
    backup = next((line for line in lines if re.search(r'\bandroid:allowBackup\b', line)), '')
    if not re.search(r'(?:false|0x0+)\s*$', backup):
        raise ValueError('Compiled APK does not explicitly disable Android backup.')
    if any(permission in manifest for permission in ['android.permission.MANAGE_EXTERNAL_STORAGE', 'android.permission.READ_EXTERNAL_STORAGE', 'android.permission.WRITE_EXTERNAL_STORAGE']):
        raise ValueError('Broad filesystem permissions are not needed for document-provider access.')
    debugging = next((line for line in lines if 'android:debuggable' in line), '')
    is_debug = bool(re.search(r'(?:true|0xffffffff)\s*$', debugging))
    if not is_debug and 'android.permission.INTERNET' in manifest:
        raise ValueError('Release processing must not request network permission.')
    agent = next((line for line in lines if 'android:backupAgent' in line), '')
    if not re.search(r'="(?:dev\.universalstudio\.universal_studio_toolkit)?\.LocalOnlyBackupAgent"', agent):
        raise ValueError('Compiled manifest is missing the local-only backup adapter.')
    table = dump('resources', str(apk))
    for key in ['fullBackupContent', 'dataExtractionRules']:
        value = next((line for line in lines if 'android:' + key in line), '')
        resource = re.search(r'=\s*@(0x[0-9a-fA-F]+)\b', value)
        if not resource:
            raise ValueError('Compiled manifest is missing a backup-rule resource reference.')
        for path in resource_paths(table, resource.group(1)):
            root = xmltree_policy(dump('xmltree', str(apk), '--file', path))
            if key == 'fullBackupContent':
                if root.tag != 'full-backup-content':
                    raise ValueError('Invalid compiled legacy backup rules.')
                exclusions(root)
            else:
                if root.tag != 'data-extraction-rules':
                    raise ValueError('Invalid compiled modern backup rules.')
                exclusions(root.find('cloud-backup'))
                exclusions(root.find('device-transfer'))


if __name__ == '__main__':
    verify_source(Path(__file__).resolve().parents[1])
    if len(sys.argv) == 3:
        verify_compiled(Path(sys.argv[1]), Path(sys.argv[2]))
    elif len(sys.argv) != 1:
        raise SystemExit('Usage: verify_android_privacy.py [APK AAPT2]')
    print('Explicit Android backup opt-out and exclusion policy verified; device transport testing remains outstanding.')
