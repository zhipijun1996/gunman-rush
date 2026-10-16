from pathlib import Path
import json,gzip,shutil,hashlib,subprocess,tarfile,sys
ROOT=Path.cwd();base=ROOT/'build/plains_redesign';out=ROOT/'docs/evidence/plains_redesign/scene/completion_r1';out.mkdir(parents=True,exist_ok=True);items=[]
def sha(b):return hashlib.sha256(b).hexdigest()
def cp(p,rel=None):
 p=Path(p)
 if not p.is_file():return
 dst=out/(rel or str(p.relative_to(base)))
 if p.suffix=='.json':dst=dst.with_suffix('.json.gz')
 dst.parent.mkdir(parents=True,exist_ok=True);raw=p.read_bytes();dst.write_bytes(gzip.compress(raw,compresslevel=1,mtime=0) if p.suffix=='.json' else raw)
 items.append({'original_path':str(p.relative_to(ROOT)),'portable_path':str(dst.relative_to(ROOT)),'raw_sha256':sha(raw),'stored_sha256':sha(dst.read_bytes()),'encoding':'gzip' if p.suffix=='.json' else 'identity'})
for name in ['run_mc1nqmqz','run_vzsf83hr','run_y14li0nt','run_55jkzjkc','run_f30_w7et','run_88ix08rd','run_16jp0xow','run_gayoppet','run_ppltk_vy','run_pt8so5ek','run_lo0a897t','run_us9izlj2']:
 for p in (base/'scene'/name).glob('*'):cp(p)
for p in (base/'scene_completion').glob('*'):
 if p.suffix in ('.log','.py','.gd','.json'):cp(p)
for name in ['extra_movie','repair_movie','clock_movie','growth_movie','current_extra_touch','current2_extra_touch','current3_extra_touch']:
 folder=base/'scene_completion'/name
 for p in folder.glob('*'):
  if p.suffix in ('.json','.log'):cp(p)
 for p in folder.glob('frames/*.png'):
  if any(n in p.name for n in ['000600','000720','000840','000960','001348','001440','001680','003000']):cp(p)
 if name=='current3_extra_touch':cp(folder/'gameplay.mp4')
latest={}
for kind,pattern in [('scene','scene/run_*/receipt.json'),('spatial','spatial/run_*/receipt.json')]:
 paths=sorted(base.glob(pattern),key=lambda p:p.stat().st_mtime)
 for p in reversed(paths):
  r=json.loads(p.read_text())
  if r.get('status')=='passed':latest[kind]=str(p.relative_to(ROOT));break
 if kind in latest:
  for p in (ROOT/latest[kind]).parent.glob('*'):cp(p)
sys.path.insert(0,'tools');import level_formal
source=level_formal.source_files();source.update({n:sha(Path(n).read_bytes()) for n in ['tools/run_plains_redesign_scene_tests.py','tools/run_plains_redesign_spatial_tests.py']})
(out/'current_source.json').write_text(json.dumps({'files':source,'scope':'Exact final working-tree source; individual older movies retain their own source and are not current'},indent=2)+'\n')
with tarfile.open(out/'current_source.tar.gz','w:gz',compresslevel=1) as tar:
 for n in source:
  if Path(n).is_file():tar.add(n,arcname=n,recursive=False)
core=sorted(level_formal.core_source_paths());drivers=sorted(level_formal.driver_source_paths());changed=[]
for n in core+drivers:
 try:b=subprocess.check_output(['git','show','HEAD:'+n],stderr=subprocess.DEVNULL)
 except subprocess.CalledProcessError:changed.append(n);continue
 if sha(b)!=sha(Path(n).read_bytes()):changed.append(n)
(out/'core_driver_invariance.json').write_text(json.dumps({'core_count':len(core),'driver_closure_count':len(drivers),'changed':changed,'method':'Actual SHA256 against HEAD bytes'},indent=2)+'\n')
old=ROOT/'docs/evidence/plains_redesign/scene/index.json';oldindex=json.loads(old.read_text());mismatches=[i['portable_path'] for i in oldindex['items'] if sha((ROOT/i['portable_path']).read_bytes())!=i['stored_sha256']]
index={'schema_version':1,'task_id':'PLAINS-REDESIGN-SCENE-01','lease_request':'9fbcf366720629b0b173f1443667342deddea8b492f19a1b2d31c8558b504564','latest_passed':latest,'current_source':'docs/evidence/plains_redesign/scene/completion_r1/current_source.json','old_index_sha256':sha(old.read_bytes()),'old_member_mismatches':mismatches,'items':items,'scope':'G0/G1 technical candidate; no whole aesthetic/fun/device acceptance','limitations':['Clockwise upper return kill and bait fail at first uncleared fan+sentry bank; only tested counterclockwise full circuit passed','Pre-touch four identity movies retain exact older source; no retag to current','Current combined overlay/toast/extra clip is a finite observation window, not all-strategy/device acceptance','Repair is open cottage forecourt, not completed compressed corridor','DEEP DROP prototype label remains outside lease','Physical controls, complete audio listening, user fun/aesthetic approval and formal independent review pending','Transport-orphan no-receipt native artifacts and interrupted competing-risk clip are rejected history']}
(out/'index.json').write_text(json.dumps(index,ensure_ascii=False,indent=2)+'\n');print('PACKAGED',len(items),'old mismatches',mismatches,'latest',latest)
