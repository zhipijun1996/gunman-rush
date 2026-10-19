"""Archive terminal S1 CI failure and one local reproduction, without validation/network."""
from pathlib import Path
import hashlib,json,zipfile,re,subprocess
R=Path.cwd();O=R/'build/forest_grapple02/pending_release01';S=lambda x:hashlib.sha256(x).hexdigest();H='7ba2e92d2c3cb5449ac6648b820f79679548ee89';data={};origins=[]
oldzip=O/'s1-preflight-originals.zip';oldhash=S(oldzip.read_bytes());assert oldhash=='1b7a8bab69987f490b47f059d842fd3af4fc4d79570d3071a9ded07c94e627a7'
def add(p,n=None):
 raw=p.read_bytes();n=n or str(p.relative_to(R));assert not p.is_symlink()
 if re.search(rb'[?&](?:sig|X-Amz-Signature)=|gh[pousr]_[A-Za-z0-9]{20}|(?i:authorization)["\s:]+(?i:bearer)\s+[A-Za-z0-9]',raw):raise ValueError('Signed/token pattern must use explicit sanitized derivative: '+n)
 data[n]=raw;origins.append({'member':n,'source_path':str(p),'sha256':S(raw),'bytes':len(raw)})
for p in sorted((R/'build/forest_grapple02/ci_s1_failure01').iterdir()):
 if p.is_file():add(p)
for p in sorted((R/'build/verification/verifier_migration_review').iterdir()):
 if p.is_file() and p.name.startswith('commit_s1_ci_') and p.suffix in {'.json','.md','.py'}:add(p)
for base in [R/'build/verification/harness/20261019T041647.700006Z',R/'build/root_bell/formal_v2/1792383436490972147']:
 for p in sorted(base.rglob('*')):
  if any(s in {'.godot','cache','user-data','import-cache','import-user','import-config'} for s in p.relative_to(base).parts):continue
  if p.is_file() and p.suffix in {'.json','.log','.txt'}:add(p)
# Authenticated original S1 text, never the in-flight test fix in main.
source=[]
for name in ['tools/run_root_bell_formal.py','tools/test_root_bell_formal_verifier.py','config/player_tuning.json']:
 raw=subprocess.check_output(['git','show',H+':'+name]);member='S1-committed-source/'+name;data[member]=raw;source.append({'path':name,'commit':H,'git_blob':subprocess.check_output(['git','rev-parse',H+':'+name],text=True).strip(),'sha256':S(raw),'member':member})
notes={'scope':'Terminal failed S1 CI, partial successes and actual local diagnostic retained; no CI89/80/release pass','S1':H,'run_id':39194694146,'CI_terminal':'failure; publisher ci_failed; deploy skipped','source_inferred_prefix':'root-bell-tests at39 of71 => prior38 and later32 inferred only from source stop-on-failure; original phase report unavailable due artifact403','local_actual_failure':'strict_formal_python: historical fixed20% capture versus current15% focus_time_scale => ValueError Actual tuning mismatch focus_time_scale before Godot start. Remote annotation alone did not prove leak.','authority_fix':'test-only historical authority isolation being implemented; no new fix outcome or S2 approval here','metadata_custody':'parallel download403 and publisher terminal metadata are original existing redacted JSON, not raw signed redirects or downloaded phase report','original_preflight_SHA256_immutable':oldhash,'committed_source':source};data['derived/s1-failure-custody.json']=json.dumps(notes,indent=2).encode();(O/'s1-failure-custody.json').write_bytes(data['derived/s1-failure-custody.json'])
rows=[{'member':n,'bytes':len(raw),'sha256':S(raw)} for n,raw in sorted(data.items())];inside=json.dumps({'scope':notes['scope'],'members':rows},indent=2).encode();zp=O/'s1-failure-originals01.zip'
with zipfile.ZipFile(zp,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for n,raw in sorted(data.items()):z.writestr(n,raw)
 z.writestr('ARCHIVE-INVENTORY.json',inside)
with zipfile.ZipFile(zp) as z:
 assert len(z.namelist())==len(set(z.namelist()))==len(rows)+1
 for row in rows:assert S(z.read(row['member']))==row['sha256']
assert S(oldzip.read_bytes())==oldhash
idx={'scope':notes['scope'],'source_commit':H,'archive_sha256':S(zp.read_bytes()),'archive_bytes':zp.stat().st_size,'archive_member_count':len(rows)+1,'members':rows,'source_paths':origins,'inside_inventory_sha256':S(inside),'full_readback_verified':True,'preflight_archive_unchanged':oldhash};(O/'s1-failure-inventory01.json').write_text(json.dumps(idx,indent=2)+'\n');print(json.dumps({k:v for k,v in idx.items() if k not in ['members','source_paths']}))
