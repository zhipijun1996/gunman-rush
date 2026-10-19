from pathlib import Path
import json,hashlib,shutil,zipfile,re
r=Path('/workspace/gunman-rush-design');d=r/'docs/evidence/forest_grapple02/release03';sha=lambda b:hashlib.sha256(b).hexdigest()
report=json.loads((r/'build/forest_grapple02/browser_gui02/report.json').read_text());assert report['status']=='passed' and len(report['checks'])==20 and len(report['identities'])==8 and report['errors']==[]
paths=[p for p in sorted((r/'build/forest_grapple02/browser_gui02').rglob('*')) if p.is_file() and p.suffix!='.pck']+[r/'build/forest_grapple02/browser_gui02.cli.log',r/'build/forest_grapple02/browser_gui02.cli_receipt.json',r/'build/forest_grapple02/run_browser_gui02.py']
z=d/'gui02-public-success-originals01.zip';assert not z.exists();rows=[]
with zipfile.ZipFile(z,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as f:
 for p in paths:
  b=p.read_bytes();name=p.relative_to(r).as_posix();f.writestr(name,b);rows.append({'member':name,'bytes':len(b),'sha256':sha(b)})
 f.writestr('MEMBER_SHA256.json',json.dumps({'scope':'Original full GUI02 evidence; no PCK; public mouse/emulated touch, not physical device or whole native route','members':rows},indent=2)+'\n')
with zipfile.ZipFile(z) as f:
 for row in rows:
  b=f.read(row['member']);assert len(b)==row['bytes'] and sha(b)==row['sha256']
index={'archive':z.name,'sha256':sha(z.read_bytes()),'bytes':z.stat().st_size,'member_count':len(rows)+1,'full_member_sha256_verified':True,'members':rows};(d/'gui02-public-success-index01.json').write_text(json.dumps(index,indent=2)+'\n')
orig=d/'originals';orig.mkdir(exist_ok=True)
for source,name in [(r/'build/forest_grapple02/browser_gui02/report.json','gui02-report.json'),(r/'build/forest_grapple02/browser_gui02.cli_receipt.json','gui02-cli-receipt.json')]:shutil.copy2(source,orig/name)
for round in ['01','02']:
 for ext in ['json','md']:
  p=r/f'build/verification/verifier_migration_review/browser_menu_ocr_review{round}/review.{ext}';shutil.copy2(p,orig/f'browser_menu_ocr_review{round}.{ext}')
p=d/'README.md';t=p.read_text();cut=t.find('\n\n');t=t[cut+2:] if t.startswith('当前收口状态：') else t
header='''当前最终证据状态：S3 93c202568d154e37b1d57de1e08ba0c42820e828 的选定CI39207127333成功（core原89检查=serial18+parallel71，含原forest80；相关jobs及两docs成功）。这是CI job/API汇总范围，本归档未取得原CI inner ZIP，不冒称独立逐89原raw审查。公开GUI02唯一完整原组通过20 checks/8 identities/errors0，CLI exit0、378.77094069秒<原480；source93/build f7e22bcfaf40/actual V12，mouse与模拟DOM touch，不等于真实设备或全路线真人游玩。

publisher仍exit1 permission_or_policy：唯一正常artifact下载proxy403，live_verified=false，精确CI ZIP原包72未执行；不得用公开GUI通过倒填publisher或72。本机原80仍整体FAIL(timeout600.167)，59已完成通过、21未完成，旧inner无最终source_stable；与本次远端CI成功分账。fullJ→H无R成立、上层吸引力及parent设计REVISE保留，不能以技术绿称质量完成。

GUI01原失败、OCR初审REJECT/95误报及修后限定ACCEPT均保留。新增gui02-public-success-originals01.zip含完整原report/screens/log/receipt/wrapper，逐member SHA读回；小份原report/receipt及两轮OCR JSON/MD直读位于originals。工具SHA 3f542a8b4a97dd8678ab45d5ef185ce8c47f6f753ec4bb6ef52eb2408890e422前后不变；未重建公网游戏。实际受审tests/tools43条路径，不是44。以下所有pending/in-progress/仅ignored段落均是历史快照，已由本段及新GUI02原件更新；不修改旧ZIP/raw/原CI snapshot。

'''
p.write_text(header+t)
# Add package producer for exact reproducibility; it refuses overwriting immutable archive.
shutil.copy2('/tmp/final_gui02_release.py',d/'package_gui02_release03.py')
files=[{'path':p.relative_to(d).as_posix(),'sha256':sha(p.read_bytes()),'bytes':p.stat().st_size} for p in sorted(d.rglob('*')) if p.is_file() and p.name not in ['inventory.json','copy-plan.json']]
(d/'inventory.json').write_text(json.dumps({'scope':'S3 CI API successful status + public GUI02 actual success; original failures and limited OCR reviews retained; parent REVISE','source_commit':'93c202568d154e37b1d57de1e08ba0c42820e828','files':files},indent=2)+'\n')
(d/'copy-plan.json').write_text(json.dumps({'authorized':True,'destination':str(d.relative_to(r)),'copied_files':files,'excluded':'PCK/59large raw/oldZIP duplicates/live checkpoint signed URLs','frozen':True},indent=2)+'\n')
# Recheck every portable copy, archive unique members, and each available indexed member hash.
for row in files:assert sha((d/row['path']).read_bytes())==row['sha256']
for p in d.glob('*.zip'):
 with zipfile.ZipFile(p) as f:
  assert len(f.namelist())==len(set(f.namelist()))
  for n in f.namelist():
   b=f.read(n);assert not re.search(rb'https?://productionresultssa[^\s"<>]+|gh[upso]_[A-Za-z0-9]{20,}|https?://[^\s"<>]+[?&](?:sig|se|sp|sv)=',b),p.name
rec={'frozen':True,'scope':'Evidence collection only, no new tests/downloads; only authorized release03 tracked writes','files':len(files)+2,'bytes':sum(p.stat().st_size for p in d.rglob('*') if p.is_file()),'gui02_zip':{k:index[k] for k in ['sha256','bytes','member_count']},'key_files':[{ 'path':str(p.relative_to(r)),'sha256':sha(p.read_bytes())} for p in [d/'README.md',d/'inventory.json',orig/'gui02-report.json',orig/'gui02-cli-receipt.json',orig/'browser_menu_ocr_review01.json',orig/'browser_menu_ocr_review01.md',orig/'browser_menu_ocr_review02.json',orig/'browser_menu_ocr_review02.md']]}
(r/'build/forest_grapple02/ci_s3/release03-final-copy-receipt02.json').write_text(json.dumps(rec,indent=2)+'\n');print(json.dumps(rec))
