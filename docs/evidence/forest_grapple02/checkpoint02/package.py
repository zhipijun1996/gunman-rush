"""Archive sealed actual outputs only; run from repository root. No native execution."""
from pathlib import Path
import hashlib,json,zipfile,re
ROOT=Path.cwd();OUT=ROOT/'docs/evidence/forest_grapple02/checkpoint02'
sha=lambda b:hashlib.sha256(b).hexdigest()
folders=['air18_final01','matrix16_final01','north_side_ring_fix01','change_mind_fix01','canopy_rhr_trial','map2_representative00_fixed01','migrant_clearance01']
reports=['20261019T014950.176010Z','20261019T015430.683827Z','20261019T015847.026058Z','20261019T015951.654681Z']
selected={};receipts=[]
prior_blobs={}
if (OUT/'selected-originals.zip').is_file():
 with zipfile.ZipFile(OUT/'selected-originals.zip') as previous:
  prior_blobs={n.split('/')[-1]:previous.read(n) for n in previous.namelist() if n.startswith('source_blobs/')}
 assert all(sha(raw)==digest for digest,raw in prior_blobs.items())
def put(p):
 if p.is_file() and not p.is_symlink():selected[str(p.relative_to(ROOT))]=p.read_bytes()
def walk(p):
 for f in sorted(p.rglob('*')):
  if any(s in {'cache','import-cache','import-config','user-data','.godot','node_modules'} for s in f.relative_to(p).parts):continue
  if f.suffix.lower() in {'.json','.log','.txt','.gd','.py','.diff','.sha256','.png'}:put(f)
for folder in folders:
 p=ROOT/'build/forest_grapple02'/folder;walk(p)
 for name in ['summary.json','receipt.json']:
  if (p/name).is_file():receipts.append(p/name)
for rid in reports:
 p=ROOT/'build/verification/harness'/rid;walk(p);receipts.append(p/'report.json')
for f in (ROOT/'build/verification/forest_grapple02').glob('targeted_harness*.log'):put(f)
# Preserve historical normal movie identity, not large AVI or final-source film claims.
movies=[]
for folder in ['movie_map1_fast01','movie_map2_growth01']:
 p=ROOT/'build/forest_grapple02'/folder
 for f in sorted(p.rglob('*')):
  if f.suffix=='.avi':movies.append({'original_path':str(f.relative_to(ROOT)),'bytes':f.stat().st_size,'sha256':sha(f.read_bytes()),'bundled':False,'scope':'Historical normal-speed recording, not current/final source or whole-film independent approval'})
  elif f.suffix in {'.json','.log','.png'} and not any(x in {'cache','import-cache','import-config','user-data'} for x in f.relative_to(p).parts):put(f)
# Text source only when its bytes match an actual recorded input hash. No relabeling changed main.
custody=[]
for p in receipts:
 a=json.loads(p.read_text());inputs=a.get('source_before',a.get('source_files',{}));items={}
 for name,digest in inputs.items():
  if not (name.startswith(('scripts/','tests/','tools/')) and name.endswith(('.gd','.py','.sh')) or name in {'config/player_tuning.json','config/input_profile.json'}):continue
  f=ROOT/name
  raw=f.read_bytes() if f.is_file() and not f.is_symlink() else b''
  if sha(raw)!=digest:raw=prior_blobs.get(digest,b'')
  if sha(raw)==digest:
   key='source_blobs/'+digest;selected[key]=raw;items[name]={'sha256':digest,'member':key}
 custody.append({'receipt':str(p.relative_to(ROOT)),'authenticated_text_matches':items,'scope':'Only exact recorded-hash matches retained (current file or prior verified source blob); full source inventory remains in original receipt/report. Unmatched historical source not claimed bundled or replayable.'})
# Already-retained original before source for RHR is a selected original; no patching.
(OUT/'source-custody.json').write_text(json.dumps(custody,ensure_ascii=False,indent=2)+'\n')
(OUT/'movie-index.json').write_text(json.dumps(movies,ensure_ascii=False,indent=2)+'\n')
selected['derived/source-custody.json']=(OUT/'source-custody.json').read_bytes();selected['derived/movie-index.json']=(OUT/'movie-index.json').read_bytes()
# Prevent credential URL/token custody mistakes.
for name,raw in selected.items():
 if re.search(rb'[?&](?:sig|X-Amz-Signature)=|gh[pousr]_[A-Za-z0-9]{20}',raw):raise ValueError('Credential-like content requires explicit redacted derivative: '+name)
rows=[{'member':n,'bytes':len(d),'sha256':sha(d)} for n,d in sorted(selected.items())]
inner=json.dumps({'scope':'selected actual outputs plus documented source/text and movie identity indexes; not full project','members':rows},ensure_ascii=False,indent=2).encode()
archive=OUT/'selected-originals.zip'
with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for name,data in sorted(selected.items()):z.writestr(name,data)
 z.writestr('ARCHIVE-INVENTORY.json',inner)
with zipfile.ZipFile(archive) as z:
 assert len(z.namelist())==len(set(z.namelist()))==len(rows)+1
 for row in rows:assert sha(z.read(row['member']))==row['sha256'] and len(z.read(row['member']))==row['bytes']
 assert z.read('ARCHIVE-INVENTORY.json')==inner
inv={'scope':'historical checkpoints; no complete16/80/finalCI/release approval','archive_sha256':sha(archive.read_bytes()),'archive_bytes':archive.stat().st_size,'members':rows,'archive_inventory_sha256':sha(inner),'archive_member_count_including_inventory':len(rows)+1,'raw_bytes':sum(r['bytes'] for r in rows),'full_readback_verified':True}
(OUT/'inventory.json').write_text(json.dumps(inv,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:v for k,v in inv.items() if k!='members'},ensure_ascii=False))
