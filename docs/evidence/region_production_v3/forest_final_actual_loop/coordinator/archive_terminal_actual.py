from pathlib import Path
import json,hashlib,shutil,subprocess,datetime,re
root=Path.cwd();d=root/'build/forest_final_actual_loop_final_portable';d.mkdir(exist_ok=True);records=[]
def copy(p,relative):
 q=d/relative;q.parent.mkdir(parents=True,exist_ok=True);b=p.read_bytes();q.write_bytes(b);assert q.read_bytes()==b
 records.append({'original_path':str(p.relative_to(root)),'portable_path':str(relative),'sha256':hashlib.sha256(b).hexdigest(),'bytes':len(b)})
for source,prefix in [(root/'docs/evidence/region_production_v3/forest_final_actual_loop','implementation'),(root/'build/verification/forest_final_actual_loop','controller'),(root/'build/forest_final_actual_loop/independent','independent'),(root/'build/forest_h_slice/20261015T222615_850c9a8e','controller_native')]:
 for p in sorted(source.rglob('*')):
  if p.is_file():copy(p,Path(prefix)/p.relative_to(source))
for p in sorted((root/'build/forest_final_actual_loop').iterdir()):
 if p.is_file():copy(p,Path('coordinator')/p.name)
copy(root/'docs/quality/records/level-new_region-thorn_forest-prototype.json',Path('historical_live_quality_record.json'))
pattern=subprocess.check_output(['git','rev-parse','--git-path','info/sparse-checkout'],text=True).strip();p=Path(pattern)
if not p.is_absolute():p=root/p
b=p.read_bytes();q=d/'coordinator/actual_sparse_patterns.txt';q.write_bytes(b);records.append({'original_path':str(p),'portable_path':'coordinator/actual_sparse_patterns.txt','sha256':hashlib.sha256(b).hexdigest(),'bytes':len(b)})
s=json.loads((root/'build/verification/forest_final_actual_loop/state.json').read_text());assert s['status']=='complete' and s['calls']==2 and s['content_complete'] is False and not s.get('active_call')
manifest={'kind':'actual_bounded_short_request_host_loop_final_archive_not_full_forest','archived_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'source_commit':'b5b9be26357906333bdf53990a93935e5dbfd7e5','controller_pid':259786,'terminal_status':s['status'],'calls':s['calls'],'content_complete':s['content_complete'],'files':records,'limits':['Original source-bound child tracked files remain untouched by final archiving','Historical quality snapshot is inside evidence only, not a fresh ROOT quality declaration','Original absolute/repo paths inside raw receipts are provenance; mapping preserves portable placement','Full9 production packages remain pending; lifecycle leak defect remains open; no image/movie/device proof']}
(d/'artifact_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps({'archive':str(d),'files':len(records),'bytes':sum(x['bytes'] for x in records),'terminal':'complete','calls':2,'content_complete':False},indent=2))
