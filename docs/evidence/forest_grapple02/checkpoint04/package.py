"""Read-only custody of terminal return rejection and complete passing integration; no engine calls."""
from pathlib import Path
import hashlib,json,zipfile,re
R=Path.cwd();O=R/'docs/evidence/forest_grapple02/checkpoint04';S=lambda b:hashlib.sha256(b).hexdigest();data={};custody=[]
for name in ['migrant_hollow04','migrant_hollow05']:
 base=R/'build/forest_grapple02'/name
 for f in sorted(base.rglob('*')):
  if any(p in {'cache','user-data','import-user','import-cache','import-config','.godot'} for p in f.relative_to(base).parts):continue
  if f.is_file() and not f.is_symlink() and f.suffix in {'.json','.log','.txt','.diff'}:data[str(f.relative_to(R))]=f.read_bytes()
 a=json.loads((base/'receipt.json').read_text());assert a['status']==('failed' if name=='migrant_hollow04' else 'passed') and a['source_stable']
 entries=[]
 for path in sorted(a['source_before']):
  if not path.startswith(('scripts/','tests/','tools/','resources/','scenes/','config/')) or Path(path).suffix not in {'.gd','.py','.sh','.tres','.tscn','.json','.cfg'}:continue
  digest=a['source_before'].get(path);f=R/path;raw=f.read_bytes() if f.is_file() else b'';match=bool(digest and S(raw)==digest)
  entry={'path':path,'recorded_sha256':digest,'exact_text_bundled':match}
  if match:entry['member']='source_blobs/'+digest;data[entry['member']]=raw
  entries.append(entry)
 custody.append({'run':name,'inputs':entries,'scope':'Only actual recorded hash matches are source text; other historical code not claimed bundled. Original full hash inventory retained in receipt.'})
data['derived/source-custody.json']=json.dumps(custody,ensure_ascii=False,indent=2).encode()
rows=[{'member':p,'sha256':S(raw),'bytes':len(raw)} for p,raw in sorted(data.items())]
for raw in data.values():assert not re.search(rb'[?&](?:sig|X-Amz-Signature)=|gh[pousr]_[A-Za-z0-9]{20}',raw)
inner=json.dumps({'scope':'actual04 strictFAIL and05 complete40legs PASS, no full matrix/CI','members':rows},indent=2).encode();zpath=O/'selected-originals.zip'
with zipfile.ZipFile(zpath,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for p,raw in sorted(data.items()):z.writestr(p,raw)
 z.writestr('ARCHIVE-INVENTORY.json',inner)
with zipfile.ZipFile(zpath) as z:
 assert len(z.namelist())==len(set(z.namelist()))==len(rows)+1
 for row in rows:assert S(z.read(row['member']))==row['sha256']
(O/'source-custody.json').write_bytes(data['derived/source-custody.json'])
inv={'scope':'terminal return rejection and complete passing integration; whole matrix/CI not passed','archive_sha256':S(zpath.read_bytes()),'archive_bytes':zpath.stat().st_size,'archive_member_count':len(rows)+1,'members':rows,'archive_inventory_sha256':S(inner),'full_readback_verified':True,'checkpoint02_unchanged_sha256':S((R/'docs/evidence/forest_grapple02/checkpoint02/selected-originals.zip').read_bytes())};(O/'inventory.json').write_text(json.dumps(inv,indent=2)+'\n');print(json.dumps({k:v for k,v in inv.items() if k!='members'}))
