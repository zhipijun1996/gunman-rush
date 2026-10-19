"""Archive actual representative16 completion, referencing prior exact source archive."""
from pathlib import Path
import json,hashlib,zipfile,re
R=Path.cwd();O=R/'docs/evidence/forest_grapple02/checkpoint05';B=R/'build/forest_grapple02/matrix16_final02';S=lambda d:hashlib.sha256(d).hexdigest();a=json.loads((B/'receipt.json').read_text());old=json.loads((R/'build/forest_grapple02/migrant_hollow05/receipt.json').read_text());assert a['status']=='passed' and a['source_stable'] and a['source_before']==old['source_before'] and len(a['runs'])==len(a['requested_cases'])==16
assert all(x['status']=='passed' and x['exit_code']==0 and not x['errors'] for x in a['runs'])
data={}
for f in sorted(B.rglob('*')):
 if any(p in {'cache','user-data','import-user','import-cache','import-config','.godot'} for p in f.relative_to(B).parts):continue
 if f.is_file() and not f.is_symlink() and f.suffix in {'.json','.log'}:data[str(f.relative_to(R))]=f.read_bytes()
for case in a['runs']:
 capture=next(x for x in case['argv'] if x.startswith('--output='));capture=Path(capture.split('=',1)[1]);log=capture.parent/'native.log';assert S(capture.read_bytes())==case['capture_sha256'] and S(log.read_bytes())==case['log_sha256']
ref={'scope':'Source inventory exactly equal to checkpoint04 migrant_hollow05; no duplicate source blob copies','source_before_exact_equal':True,'original_input_count':len(a['source_before']),'prior_archive':'docs/evidence/forest_grapple02/checkpoint04/selected-originals.zip','prior_archive_sha256':S((R/'docs/evidence/forest_grapple02/checkpoint04/selected-originals.zip').read_bytes()),'prior_source_custody':'docs/evidence/forest_grapple02/checkpoint04/source-custody.json','prior_source_custody_sha256':S((R/'docs/evidence/forest_grapple02/checkpoint04/source-custody.json').read_bytes()),'prior_run_member':'build/forest_grapple02/migrant_hollow05/receipt.json','exact_source_texts_in_prior_archive':972}
data['derived/source-reference.json']=json.dumps(ref,indent=2).encode();(O/'source-reference.json').write_bytes(data['derived/source-reference.json'])
rows=[{'member':p,'bytes':len(d),'sha256':S(d)} for p,d in sorted(data.items())];inner=json.dumps({'scope':'actual2Seeds2Maps4Routes representative16, not80/fullCI','members':rows},indent=2).encode();zp=O/'matrix16-originals.zip'
for raw in data.values():assert not re.search(rb'[?&](?:sig|X-Amz-Signature)=|gh[pousr]_[A-Za-z0-9]{20}',raw)
with zipfile.ZipFile(zp,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for p,raw in sorted(data.items()):z.writestr(p,raw)
 z.writestr('ARCHIVE-INVENTORY.json',inner)
with zipfile.ZipFile(zp) as z:
 assert len(z.namelist())==len(set(z.namelist()))==len(rows)+1
 for row in rows:assert S(z.read(row['member']))==row['sha256']
inv={'scope':'actual16representativePASS, original80/600/fullCI89 pending','archive_bytes':zp.stat().st_size,'archive_sha256':S(zp.read_bytes()),'archive_member_count':len(rows)+1,'archive_inventory_sha256':S(inner),'members':rows,'source_reference':ref,'full_readback_verified':True};(O/'inventory.json').write_text(json.dumps(inv,indent=2)+'\n');print(json.dumps({k:v for k,v in inv.items() if k not in ['members','source_reference']}))
