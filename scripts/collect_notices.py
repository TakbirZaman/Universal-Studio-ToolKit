#!/usr/bin/env python3
"""Collect actual resolved dependency licenses; missing files remain release blockers."""
import json, subprocess, pathlib, shutil, os
root=pathlib.Path(__file__).resolve().parents[1]
out=root/'third_party';out.mkdir(exist_ok=True)
metadata=json.loads(subprocess.check_output(['cargo','metadata','--locked','--format-version','1','--manifest-path',str(root/'rust/Cargo.toml')]))
records=[]
for p in metadata['packages']:
 if p['name']=='studio_core':continue
 folder=pathlib.Path(p['manifest_path']).parent
 matches=[f for f in folder.iterdir() if f.is_file() and f.name.lower().startswith(('license','licence','copying','notice','copyright','authors'))]
 destination=out/'rust'/f"{p['name']}-{p['version']}";destination.mkdir(parents=True,exist_ok=True)
 for f in matches:shutil.copy2(f,destination/f.name)
 upstream=destination/'UPSTREAM-LICENSE'
 if upstream.exists():matches.append(upstream)
 records.append({'ecosystem':'rust','name':p['name'],'version':p['version'],'declared_license':p.get('license'),'repository':p.get('repository'),'files':[str((destination/f.name).relative_to(root)) for f in matches],'review': 'source license files collected; obligations require review' if matches else 'BLOCKED: no root license file collected'})
config=root/'.dart_tool/package_config.json'
if config.exists():
 from urllib.parse import urlparse,unquote
 for p in json.loads(config.read_text())['packages']:
  if p['name']=='universal_studio_toolkit':continue
  uri=p['rootUri'];folder=pathlib.Path(unquote(urlparse(uri).path)) if uri.startswith('file:') else (config.parent/uri).resolve()
  matches=[f for f in folder.iterdir() if f.is_file() and f.name.lower().startswith(('license','licence','copying','notice','copyright','authors'))]
  if not matches and p['name'] in ['flutter_test','flutter_web_plugins']:
   sdk_license=folder.parent.parent/'LICENSE'
   if sdk_license.exists():matches=[sdk_license]
  destination=out/'dart'/p['name'];destination.mkdir(parents=True,exist_ok=True)
  for f in matches:shutil.copy2(f,destination/f.name)
  records.append({'ecosystem':'dart','name':p['name'],'files':[str((destination/f.name).relative_to(root)) for f in matches],'review':'source license files collected; obligations require review' if matches else 'BLOCKED: no root license file collected'})
(out/'inventory.json').write_text(json.dumps(records,indent=2))
missing=[r['name'] for r in records if not r['files']]
print(json.dumps({'dependencies':len(records),'missing_license_files':missing}))
