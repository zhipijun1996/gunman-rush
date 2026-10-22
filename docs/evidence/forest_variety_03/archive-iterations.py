from pathlib import Path
import hashlib,json,zipfile
base=Path('/tmp/gunman-forest-variety-03')
out=Path('/workspace/gunman-rush/docs/evidence/forest_variety_03');out.mkdir(exist_ok=True)
folders=[(base/f'round{i:02}',f'round{i:02}') for i in [1,2,4,5,6,7,8,9,10,11]]
folders.append((base/'module-runtime-snapshot/build/variety-round03','round03-isolated'))
rows=[]
with zipfile.ZipFile(out/'iterations.zip','x',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for folder,prefix in folders:
  for p in sorted(folder.rglob('*')):
   if not p.is_file():continue
   name=prefix+'/'+p.relative_to(folder).as_posix();data=p.read_bytes();z.writestr(name,data);rows.append({'member':name,'original_path':str(p),'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()})
 for p in sorted(base.glob('*coordinator.py')):
  data=p.read_bytes();name='coordinators/'+p.name;z.writestr(name,data);rows.append({'member':name,'original_path':str(p),'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()})
 p=base/'full-checkout-copy-failed.json';data=p.read_bytes();z.writestr('full-checkout-copy-failed.json',data);rows.append({'member':p.name,'original_path':str(p),'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()})
with zipfile.ZipFile(out/'iterations.zip') as z:
 assert len(z.namelist())==len(rows)
 for row in rows:assert hashlib.sha256(z.read(row['member'])).hexdigest()==row['sha256']
index={'scope':'Original actual local/final candidate traces, whole source closures, failures and actual staged GPU images; all members reconstructed and independently SHA checked during archive. Never a release/FUN approval. Originals retained.','archive':'iterations.zip','archive_sha256':hashlib.sha256((out/'iterations.zip').read_bytes()).hexdigest(),'members':rows}
(out/'iterations-index.json').write_text(json.dumps(index,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'members':len(rows),'bytes':(out/'iterations.zip').stat().st_size,'sha256':index['archive_sha256']}))
