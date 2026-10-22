from pathlib import Path
import hashlib,json,zipfile,shutil
root=Path('/workspace/gunman-rush');out=root/'docs/evidence/forest_variety_03'
folders=[(root/'build/region_bible_v2/forest-varied-feedback/first-permanent','first-permanent-before-strict-guard'),(Path('/tmp/gunman-forest-variety-03/round12'),'strict-guard-first-rejection')]
rows=[]
with zipfile.ZipFile(out/'feedback.zip','x',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for folder,prefix in folders:
  for p in sorted(folder.rglob('*')):
   if p.is_file():
    data=p.read_bytes();name=prefix+'/'+p.relative_to(folder).as_posix();z.writestr(name,data);rows.append({'member':name,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()})
with zipfile.ZipFile(out/'feedback.zip') as z:
 for r in rows:assert hashlib.sha256(z.read(r['member'])).hexdigest()==r['sha256']
(out/'feedback-index.json').write_text(json.dumps({'scope':'Original permanent wrapper pass predates strict map-variety guard. New strict guard rejects same support arrangement on both maps; do not relabel old native paths or claim completed random map generation. All archive members restored and byte verified.','archive':'feedback.zip','sha256':hashlib.sha256((out/'feedback.zip').read_bytes()).hexdigest(),'members':rows},indent=2)+'\n')
review=root/'build/region_bible_v2/forest-feedback-r2-design'
shutil.copytree(review,out/'independent-reviews',dirs_exist_ok=True)
for source in ['archive-iterations.py','archive-final-feedback.py','twelfth-world-coordinator.py']:
 shutil.copyfile(Path('/tmp/gunman-forest-variety-03')/source,out/source)
print(json.dumps({'bytes':(out/'feedback.zip').stat().st_size,'members':len(rows)}))
