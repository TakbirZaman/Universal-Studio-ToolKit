"""Exercise the real development-key lifecycle without an Android SDK."""
from pathlib import Path
import os
import subprocess
import tempfile
import unittest


class DevelopmentSigningTests(unittest.TestCase):
    def test_ephemeral_identity_signs_and_is_removed(self):
        script = (Path(__file__).resolve().parent / 'build_android.sh').read_text()
        start = script.index('studio_stage="ephemeral development signing identity"')
        end = script.index('studio_stage="backup privacy policy verification"')
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            tools = root / 'sdk/build-tools/36.0.0'
            tools.mkdir(parents=True)
            # No conventional Gradle debug key exists. Real keytool still creates
            # the explicit short-lived development identity, then EXIT removes it.
            signer = tools / 'apksigner'
            signer.write_text('''#!/usr/bin/env python3
import pathlib, subprocess, sys
args=sys.argv[1:]
if args[0]=='sign':
    key=pathlib.Path(args[args.index('--ks')+1])
    assert key.is_file()
    assert key.stat().st_mode & 0o077 == 0
    subprocess.run(['keytool','-list','-keystore',str(key),'-storepass','android','-alias','androiddebugkey'],check=True,capture_output=True)
    pathlib.Path('key-location.txt').write_text(str(key))
    pathlib.Path(args[args.index('--out')+1]).write_bytes(b'test signing boundary')
else:
    assert pathlib.Path(args[-1]).is_file()
''')
            signer.chmod(0o700)
            aligner = tools / 'zipalign'
            aligner.write_text('#!/bin/sh\ntest -f "$6"\n')
            aligner.chmod(0o700)
            (root / 'dist').mkdir()
            (root / 'dist/universal-studio-android-arm64-unsigned.apk').write_bytes(b'test input')
            env = dict(os.environ, ANDROID_HOME=str(root / 'sdk'), HOME=str(root))
            # Make the mock zipalign accept its actual final path argument.
            aligner.write_text('#!/bin/bash\ntest -f "${@: -1}"\n')
            subprocess.run(['bash', '-euc', script[start:end]], cwd=root, env=env,
                           check=True, capture_output=True, text=True, timeout=30)
            key = Path((root / 'key-location.txt').read_text())
            self.assertFalse(key.exists())
            self.assertFalse(key.parent.exists())
            self.assertTrue((root / 'dist/universal-studio-android-arm64-development-release.apk').is_file())


if __name__ == '__main__':
    unittest.main()
