import pathlib,os,zipfile,sys
root=pathlib.Path(__file__).resolve().parents[1];out=pathlib.Path(sys.argv[1]).resolve()
with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED,strict_timestamps=False) as z:
 for base,dirs,names in os.walk(root):
  dirs[:]=[d for d in dirs if d not in {'.git','.dart_tool','build','target','ephemeral','.idea','.gradle','__pycache__'} and not (pathlib.Path(base)/d).is_symlink()]
  for name in names:
   p=pathlib.Path(base)/name
   if p==out or p.is_symlink() or name in {'local.properties','key.properties','.flutter-plugins-dependencies'} or p.suffix in {'.jks','.keystore','.iml'}:continue
   z.write(p,'universal-studio-toolkit/'+str(p.relative_to(root)))
with zipfile.ZipFile(out) as z:assert z.testzip() is None
print(out.stat().st_size)
