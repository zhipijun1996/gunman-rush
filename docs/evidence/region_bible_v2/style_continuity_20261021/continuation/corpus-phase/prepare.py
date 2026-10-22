from pathlib import Path
import difflib,hashlib,json,shutil,subprocess,zipfile,zlib
ROOT=Path.cwd();OUT=ROOT/'build/region_bible_v2/continuation-evidence-next/corpus-phase';P=OUT/'payload';P.mkdir(exist_ok=True);items=[];custody={}
def sha(p):
 h=hashlib.sha256()
 with Path(p).open('rb')as f:
  for raw in iter(lambda:f.read(1048576),b''):h.update(raw)
 return h.hexdigest()
def original(rel):
 p=ROOT/rel;assert p.is_file();d=dict(bytes=p.stat().st_size,sha256=sha(p));custody[str(rel)]=d;return p,d

def copy(rel,dest):
 p,d=original(rel);q=OUT/dest;q.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,q);assert q.stat().st_size==d['bytes']and sha(q)==d['sha256'];items.append(dict(path=str(q.relative_to(OUT)),origin=str(rel),**d))
def archive(members,dest):
 target=OUT/dest;target.parent.mkdir(parents=True,exist_ok=True);mi=[]
 with zipfile.ZipFile(target,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6)as z:
  for rel,name in members:
   p,d=original(rel);raw=p.read_bytes();info=zipfile.ZipInfo(name,date_time=(1980,1,1,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED;info.external_attr=0o100644<<16;z.writestr(info,raw,compresslevel=6);mi.append(dict(path=name,original=str(rel),crc32=f'{zlib.crc32(raw)&0xffffffff:08x}',**d))
 with zipfile.ZipFile(target)as z:
  assert z.testzip()is None and z.namelist()==[x['path']for x in mi]
  for d in mi:
   raw=z.read(d['path']);assert len(raw)==d['bytes']and hashlib.sha256(raw).hexdigest()==d['sha256']and z.getinfo(d['path']).CRC==int(d['crc32'],16)
 items.append(dict(path=str(target.relative_to(OUT)),bytes=target.stat().st_size,sha256=sha(target),members=mi,full_sha_crc_and_size_verified=True))
first=Path('build/forest_depth/region/harness-matrix/harness-4c5c04ba9bcf4f61a945eddda0a13130');single=Path('build/forest_depth/region/v15-seed01-growth-second');diag=Path('build/region_bible_v2/v15-seed01-growth-diagnostic-first');harness=Path('build/verification/harness/20261021T061113.236582Z');r=json.loads((ROOT/first/'receipt.json').read_text());s=json.loads((ROOT/single/'receipt.json').read_text());assert r['status']=='failed'and r['source_stable']is True and r['source_before']==r['source_after']and len(r['source_before'])==3600;assert len(r['runs'])==19 and sum(x['status']=='passed'for x in r['runs'])==18 and len(r['not_executed_case_indices'])==61
caps=[]
for run in r['runs']:
 args=run['argv'];name=next(a.split('=',1)[1]for a in args if a.startswith('--output='));cap=Path(name).relative_to(ROOT);assert sha(ROOT/cap)==run['capture_sha256']and sha(ROOT/cap.parent/'native.log')==run['log_sha256'];caps.append((cap,str(cap.relative_to(first))));copy(cap.parent/'native.log','payload/failed-original19/'+str(cap.parent.relative_to(first))+'/native.log')
archive(sorted(caps,key=lambda pair:pair[1]),'payload/failed-original19/full-original19-captures.zip');copy(first/'receipt.json','payload/failed-original19/receipt.json');copy(first/'import.log','payload/failed-original19/import.log')
for name in ['report.json','forest-depth-region.log']:copy(harness/name,'payload/original-failed-harness/'+name)
h=json.loads((ROOT/harness/'report.json').read_text());assert h['status']=='failed'and len(h['checks'])==1 and h['checks'][0]['status']=='failed'
assert s['status']=='passed'and len(s['runs'])==1 and s['runs'][0]['status']=='passed'and s['source_stable']is True and s['source_before']==s['source_after']and len(s['source_before'])==3600
run=s['runs'][0];cap=single/'00-map1-growth/capture.json';assert sha(ROOT/cap)==run['capture_sha256']and sha(ROOT/cap.parent/'native.log')==run['log_sha256'];archive([(cap,'capture.json')],'payload/single-repair-actual-second/capture.json.zip')
for rel,dest in [(single/'receipt.json','receipt.json'),(single/'import.log','import.log'),(cap.parent/'native.log','native.log')]:copy(rel,'payload/single-repair-actual-second/'+dest)
for name in ['analysis.json','patch-freeze.json','original-source-inventory.json']:copy(diag/name,'payload/diagnostic/'+name)
path='tests/forest_bible_trace_support.gd';prefile=diag/'failed-source'/path;copy(prefile,'payload/diagnostic/prefile/'+path);copy(Path(path),'payload/diagnostic/postfile/'+path)
f=json.loads((ROOT/diag/'patch-freeze.json').read_text());assert sha(ROOT/prefile)==f['sha256_before']and sha(ROOT/path)==f['sha256_after'];assert r['source_before'][path]==f['sha256_before']and s['source_before'][path]==f['sha256_after'];delta=[p for p in set(r['source_before'])|set(s['source_before'])if p not in r['source_before']or p not in s['source_before']or r['source_before'][p]!=s['source_before'][p]];assert delta==[path]
raw=''.join(difflib.unified_diff((ROOT/prefile).read_text().splitlines(True),(ROOT/path).read_text().splitlines(True),fromfile='before/'+path,tofile='after/'+path));q=P/'diagnostic/support-probe.patch';q.write_text(raw);items.append(dict(path=str(q.relative_to(OUT)),bytes=q.stat().st_size,sha256=sha(q),derived_from=[str(prefile),path],kind='derived exact source diff; original files retained'))
review=Path('build/region_bible_v2/seed01-aim-edge-independent-first');review_present=(ROOT/review/'review.json').is_file()and(ROOT/review/'review.md').is_file()
if review_present:
 for name in ['review.json','review.md']:copy(review/name,'payload/independent-review/'+name)
facts={}
for label,p in [('failed17',first/'17-map1-growth/capture.json'),('single_actual_second',cap)]:
 d=json.loads((ROOT/p).read_text());facts[label]=dict(physics_frames=len(d['frames']),completed_legs=len(d['completed_legs']),itinerary_legs=len(d['itinerary']),failures=d['failures'],min_health=min(v['health']for v in d['frames']))
for path,d in custody.items():assert (ROOT/path).stat().st_size==d['bytes']and sha(ROOT/path)==d['sha256']
manifest=dict(status='PREPARATION_ONLY_INDEPENDENT_NARROW_REVIEW_INCLUDED'if review_present else'PREPARATION_ONLY_INDEPENDENT_NARROW_REVIEW_PENDING',scope='Original partial failed80 and one repaired actual case only; no final current80 or art claim',original_partial=dict(requested=80,executed=19,passed=18,failed=1,not_executed=61,status='failed',source_inventory_count=3600,source_stable=True),single_actual_second=dict(executed=1,passed=1,source_inventory_count=3600,source_stable=True),actual_capture_facts=facts,source_inventory_only_changed_path=delta,current_new80_result='RUNNING_NOT_INCLUDED_NO_COMPLETION_CLAIM',independent_narrow_review_included=review_present,files=items,original_input_custody=custody,originals_mutated=False,engine_executed=False,production_docs_or_git_writes=False,limitations=['Original first80 failure and its19 full native capture originals stay immutable','Single actual second pass does not establish new80 outcome','Only TEST support helper changed; earlier AV evidence remains clean048 and is not rebound','Other diagnostic source-copy bulk excluded; exact relevant support prefile/postfile/patch and original full source inventory included'])
manifest['control_files']=[dict(path=name,bytes=(OUT/name).stat().st_size,sha256=sha(OUT/name))for name in ['README.md','prepare.py','verify.py']]
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');(OUT/'manifest.sha256').write_text(sha(OUT/'manifest.json')+'  manifest.json\n');print(json.dumps(dict(files=len(items),archives=sum('members'in x for x in items),payload_bytes=sum(x['bytes']for x in items),independent_review_present=review_present,manifest_sha256=sha(OUT/'manifest.json'))))
