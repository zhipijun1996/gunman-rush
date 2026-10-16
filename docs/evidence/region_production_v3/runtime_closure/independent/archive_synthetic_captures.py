from pathlib import Path
import json,hashlib,zipfile,os
root=Path('/workspace/gunman-rush');base=root/'build/root_bell/independent_runtime_closure/1792099640445243231/strict_formal_python';out=root/'build/region_production_v3/independent/runtime_closure_review';archive=out/'independent_synthetic_captures.zip';manifest=out/'independent_synthetic_captures.json'
assert not archive.exists() and not manifest.exists()
report=json.loads((base/'report.json').read_text());assert report['status']=='passed' and report['scope']=='Actual Python main negatives with explicitly synthetic transport, NO NATIVE/MOVIE execution'
files=sorted(base.glob('*/capture.json'));assert len(files)==9
rows=[{'original_path':str(p.relative_to(root)),'member':str(p.relative_to(base)),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in files]
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for p,row in zip(files,rows):z.write(p,row['member'])
with zipfile.ZipFile(archive) as z:
 assert z.testzip() is None
 for row in rows:
  data=z.read(row['member']);assert len(data)==row['bytes'] and hashlib.sha256(data).hexdigest()==row['sha256']
result={'scope':'Parent-authorized lossless archival of reviewer-owned terminal SYNTHETIC transport captures only; no native/old lease/report/source removed','archive':str(archive.relative_to(root)),'archive_bytes':archive.stat().st_size,'archive_sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),'uncompressed_bytes':sum(r['bytes'] for r in rows),'crc_and_decoded_sha_verified':True,'files':rows}
manifest.write_text(json.dumps(result,indent=2)+'\n')
for p,row in zip(files,rows):
 assert hashlib.sha256(p.read_bytes()).hexdigest()==row['sha256'];p.unlink()
print(json.dumps({'before':result['uncompressed_bytes'],'zip_bytes':result['archive_bytes'],'verified_deleted_owned_raw_files':len(files)}))
