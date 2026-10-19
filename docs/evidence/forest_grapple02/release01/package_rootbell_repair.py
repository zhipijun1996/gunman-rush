"""Plan/seal only actual repair evidence with SHA object dedup; no verification execution."""
from pathlib import Path
import json,hashlib,zipfile,subprocess,argparse,re
R=Path.cwd();O=R/'build/forest_grapple02/pending_release01';S=lambda d:hashlib.sha256(d).hexdigest();P=argparse.ArgumentParser();P.add_argument('--seal',action='store_true');args=P.parse_args();files={};mapping=[];objects={}
roots=['build/verification/harness/20261019T042508.784146Z','build/root_bell/formal_v2/1792383939193794710','build/root_bell/verifier_focus15_reader01']
for root in roots:
 base=R/root
 for p in sorted(base.rglob('*')):
  if any(s in {'.godot','cache','user-data','import-user','import-cache','import-config','fontconfig'} for s in p.relative_to(base).parts):continue
  if p.is_file() and not p.is_symlink() and p.suffix in {'.json','.log','.txt','.md','.py','.gd'}:files[str(p.relative_to(R))]=p
review=R/'build/verification/verifier_migration_review'
for p in sorted(review.glob('rootbell_historical*')):
 if p.is_file():files[str(p.relative_to(R))]=p
for p in sorted(review.glob('rootbell_native*')):
 if p.is_file():files[str(p.relative_to(R))]=p
extra=R/'build/forest_grapple02/ci_s1_failure01/test_repair_gameplay_equivalence01.json';files[str(extra.relative_to(R))]=extra
source=['tools/test_root_bell_formal_verifier.py','tests/root_bell_formal_tests.gd','tests/fixtures/root_bell/pre_focus_15_player_tuning.json','tools/harness/profiles.json']
for name in source:files['candidate-source/'+name]=R/name
for name,p in sorted(files.items()):
 raw=p.read_bytes();digest=S(raw)
 if re.search(rb'[?&](?:sig|X-Amz-Signature)=|gh[pousr]_[A-Za-z0-9]{20}|(?i:authorization)["\s:]+(?i:bearer)\s+[A-Za-z0-9]',raw):raise ValueError('Credential-like content needs explicit derivative: '+name)
 member='objects/'+digest;objects.setdefault(digest,{'path':p,'bytes':len(raw)});mapping.append({'original_path':name,'actual_source_path':str(p),'member':member,'sha256':digest,'bytes':len(raw),'mode':oct(p.stat().st_mode&0o777)})
# Snapshot exact immutable S1 old bytes for the three preexisting files; fixture is newly added.
old={};oldrows=[];H='7ba2e92d2c3cb5449ac6648b820f79679548ee89'
for name in source:
 q=subprocess.run(['git','show',H+':'+name],capture_output=True)
 if q.returncode:oldrows.append({'path':name,'exists_at_S1':False});continue
 raw=q.stdout;digest=S(raw);old[digest]=raw;oldrows.append({'path':name,'exists_at_S1':True,'sha256':digest,'member':'objects/'+digest,'bytes':len(raw)})
plan={'scope':'Actual precommit S1+dirty test repair; not futureS2 fresh native, wholeCI/gameplay approval','HEAD':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'mapped_original_files':len(mapping),'unique_object_count':len(set(objects)|set(old)),'mapped_bytes':sum(x['bytes'] for x in mapping),'unique_bytes':sum(x['bytes'] for x in objects.values())+sum(len(raw) for h,raw in old.items() if h not in objects),'files':mapping,'S1_original_source':oldrows,'source_guard_caveat':'Production scopes unchanged; tests/tools/fixture/profile changed. Not all2127 unchanged.','reconstruct':'For each files row, read ZIP member and require sha256/bytes, then restore only original_path into a fresh directory. Multiple paths intentionally refer to same original-byte object; no original data deleted.'};(O/'s1-rootbell-repair-plan01.json').write_text(json.dumps(plan,indent=2)+'\n')
print(json.dumps({k:v for k,v in plan.items() if k not in ['files','S1_original_source']}))
if not args.seal:raise SystemExit(0)
zpath=O/'s1-rootbell-repair01.zip';inside=json.dumps(plan,indent=2).encode()
with zipfile.ZipFile(zpath,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for digest,row in sorted(objects.items()):
  raw=row['path'].read_bytes();assert S(raw)==digest;z.writestr('objects/'+digest,raw)
 for digest,raw in old.items():
  if digest not in objects:z.writestr('objects/'+digest,raw)
 z.writestr('FILE-MAP-INVENTORY.json',inside)
with zipfile.ZipFile(zpath) as z:
 assert len(z.namelist())==len(set(z.namelist()))==plan['unique_object_count']+1
 for row in mapping:assert S(z.read(row['member']))==row['sha256'] and len(z.read(row['member']))==row['bytes']
 for row in oldrows:
  if row['exists_at_S1']:assert S(z.read(row['member']))==row['sha256']
index={'scope':plan['scope'],'archive_sha256':S(zpath.read_bytes()),'archive_bytes':zpath.stat().st_size,'archive_member_count':plan['unique_object_count']+1,'original_path_count':len(mapping),'inside_map_sha256':S(inside),'full_readback_verified':True};(O/'s1-rootbell-repair-index01.json').write_text(json.dumps(index,indent=2)+'\n');print(json.dumps(index))
