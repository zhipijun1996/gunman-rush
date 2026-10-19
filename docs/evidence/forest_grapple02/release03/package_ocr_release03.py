from pathlib import Path
import hashlib,json,zipfile,shutil,re
r=Path('/workspace/gunman-rush-design');s=r/'build/forest_grapple02/ci_s3/release03_skeleton';d=r/'docs/evidence/forest_grapple02/release03';sha=lambda b:hashlib.sha256(b).hexdigest()
roots=['build/forest_grapple02/browser_menu_ocr01','build/forest_grapple02/browser_menu_ocr02','build/verification/verifier_migration_review/browser_menu_ocr_review01','build/verification/verifier_migration_review/browser_menu_ocr_review02']
rows=[];blobs={}
for directory in roots:
 for p in sorted((r/directory).rglob('*')):
  if p.is_file() and '__pycache__' not in p.parts:
   b=p.read_bytes();h=sha(b);blobs.setdefault(h,b);rows.append({'original_path':str(p.relative_to(r)),'sha256':h,'bytes':len(b),'member':'blobs/'+h})
p=r/'tools/verify_forest_browser.py';b=p.read_bytes();assert sha(b)=='3f542a8b4a97dd8678ab45d5ef185ce8c47f6f753ec4bb6ef52eb2408890e422';blobs[sha(b)]=b;rows.append({'original_path':str(p.relative_to(r)),'sha256':sha(b),'bytes':len(b),'member':'blobs/'+sha(b)})
z=s/'ocr-repair-goldens-and-reviews01.zip';assert not z.exists()
with zipfile.ZipFile(z,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as f:
 for h,b in sorted(blobs.items()):f.writestr('blobs/'+h,b)
 f.writestr('PATH_SHA256_MANIFEST.json',json.dumps({'scope':'Original frozen writer/reviewer evidence; reject01 and rejected95 preserved; SHA-addressed dedup text/pixels, no tests rerun','files':rows},indent=2)+'\n')
 f.writestr('RESTORE.txt','Read PATH_SHA256_MANIFEST.json, verify each blobs/<sha256> byte length and SHA, then copy to original_path beneath a new empty chosen directory. Reject absolute paths or .. components. Do not overwrite current workspace.\n')
with zipfile.ZipFile(z) as f:
 for row in rows:
  b=f.read(row['member']);assert sha(b)==row['sha256'] and len(b)==row['bytes']
(s/'ocr-repair-index01.json').write_text(json.dumps({'archive':z.name,'sha256':sha(z.read_bytes()),'bytes':z.stat().st_size,'original_files':len(rows),'unique_blobs':len(blobs),'zip_members':len(blobs)+2,'all_member_sha256_readback':True,'files':rows,'excluded':'__pycache__ only; no PCK, native AVI, old ZIP or59raw copied'},indent=2)+'\n')
p=s/'README-draft.md';t=p.read_text();t+='''
## OCR采证修复（GUI02仍pending）

新增ocr-repair-goldens-and-reviews01.zip按SHA去重封存writer browser_menu_ocr01/02与不同作者review01/02全部原文/像素（不含可再生__pycache__），含95阈值源码误报、第一次REJECT及其反例、第二次限定ACCEPT。PATH_SHA256_MANIFEST.json给原路径到真实blob的完整恢复映射，逐条SHA/长度读回；这不是重新执行golden。当前helper SHA 3f542a8b4a97dd8678ab45d5ef185ce8c47f6f753ec4bb6ef52eb2408890e422。

修复只属采证工具，不重建公网游戏；当前实际受审tests/tools仍43路径（42旧+已在该集合的helper新SHA），不是44。原完整GUI02保持20 checks/8 gestures/480预算，此时实际在跑，未有终态，不签通过。原GUI01失败保留，不能用像素黄金或限定工具审查替代完整GUI02。
''';p.write_text(t)
shutil.copy2('/tmp/package_ocr_release03.py',s/'package_ocr_release03.py')
files=[]
for p in sorted(s.rglob('*')):
 if p.is_file() and p.name not in ['inventory.json','copy-plan.json']:
  name=p.relative_to(s).as_posix();name='README.md' if name=='README-draft.md' else name
  files.append({'path':name,'source':str(p.relative_to(r)),'sha256':sha(p.read_bytes()),'bytes':p.stat().st_size})
(s/'inventory.json').write_text(json.dumps({'source_commit':'93c202568d154e37b1d57de1e08ba0c42820e828','scope':'CI API successful statuses, GUI01 failure and OCR bounded repair evidence; GUI02 pending','files':files},indent=2)+'\n')
(s/'copy-plan.json').write_text(json.dumps({'authorized_now':True,'destination':str(d.relative_to(r)),'files':files,'pending':'GUI02 actual terminal; no pre-sign'},indent=2)+'\n')
d.mkdir(parents=True,exist_ok=True)
for x in files:
 p=d/x['path'];p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(r/x['source'],p);assert sha(p.read_bytes())==x['sha256']
for n in ['inventory.json','copy-plan.json']:shutil.copy2(s/n,d/n)
for p in d.rglob('*'):
 if p.is_file():
  blocks=[p.read_bytes()]
  if p.suffix=='.zip':
   with zipfile.ZipFile(p) as f:blocks=[f.read(n) for n in f.namelist()]
  for b in blocks:assert not re.search(rb'https?://productionresultssa|gh[upso]_[A-Za-z0-9]{20,}|https?://[^\s"<>]+[?&](?:sig|se|sp|sv)=',b),p.name
receipt={'scope':'Authorized release03 copy; GUI02 pending; no tracked writes outside this directory','files':len(files)+2,'bytes':sum(p.stat().st_size for p in d.rglob('*') if p.is_file()),'ocr_archive':{'sha256':sha(z.read_bytes()),'bytes':z.stat().st_size,'original_files':len(rows),'unique_blobs':len(blobs)},'readme_sha256':sha((d/'README.md').read_bytes()),'inventory_sha256':sha((d/'inventory.json').read_bytes()),'copies_verified':True,'secret_pattern_hits':0}
(r/'build/forest_grapple02/ci_s3/release03-copy-receipt01.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(receipt))
