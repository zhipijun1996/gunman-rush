"""Verify this selected evidence without engine, original repository, or media."""
from pathlib import Path
import argparse,hashlib,json,zipfile,zlib
BASE=Path(__file__).resolve().parent

def sha(p):
 h=hashlib.sha256()
 with Path(p).open('rb')as f:
  for b in iter(lambda:f.read(1024*1024),b''):h.update(b)
 return h.hexdigest()

def verify():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check-local-originals',type=Path);args=parser.parse_args()
 mpath=BASE/'manifest.json';assert (BASE/'manifest.sha256').read_text()==sha(mpath)+'  manifest.json\n';m=json.loads(mpath.read_text());assert m['status']=='PREPARATION_ONLY_NOT_PUBLISHED'and m['media_portability_claim']is False
 files={r['path']:r for r in m['files']};assert len(files)==len(m['files'])and len(files)==m['payload_file_count'];actual={str(p.relative_to(BASE))for p in (BASE/'payload').rglob('*')if p.is_file()};assert actual==set(files)
 member_count=0
 for entry in [*m['files'],*m['control_files']]:
  p=BASE/entry['path'];assert p.is_file()and p.stat().st_size==entry['bytes']and sha(p)==entry['sha256'],str(p)
  assert p.suffix.lower()not in ['.avi','.wav','.mp4']
  if'members'in entry:
   with zipfile.ZipFile(p)as z:
    assert z.testzip()is None and z.namelist()==[v['path']for v in entry['members']]
    for v in entry['members']:
     raw=z.read(v['path']);assert len(raw)==v['bytes']and hashlib.sha256(raw).hexdigest()==v['sha256']and z.getinfo(v['path']).CRC==(zlib.crc32(raw)&0xffffffff)==int(v['crc32'],16);member_count+=1
 # Bind selected full-HUD originals directly to the copied actual receipt.
 shoulder=BASE/'payload/rejected-root-shoulder';r=json.loads((shoulder/'actual6/receipt.json').read_text());assert len(r['images'])==6
 for name,expected in r['images'].items():assert sha(shoulder/'actual6'/name)==expected
 for challenge in ['F05','F08']:
  d=BASE/'payload'/challenge;r=json.loads((d/'receipt.json').read_text());assert r['source_before']==r['source_after']and r['source_stable']is True
  for k in r['keyframes']:assert sha(d/k['path'])==k['sha256']==r['artifacts'][k['path']]['sha256']
  with zipfile.ZipFile(d/'trace.json.zip')as z:raw=z.read('trace.json');assert len(raw)==r['artifacts']['trace.json']['bytes']and hashlib.sha256(raw).hexdigest()==r['artifacts']['trace.json']['sha256']
 for label in ['guardian','canopy','restore']:
  d=BASE/'payload/default-consumers'/label;r=json.loads((d/'receipt.json').read_text());assert r['passed']is True and r['source_guard']is True and r['source_before']==r['source_after']and r['verifier_before']==r['verifier_after']
  for name,expected in r['logs'].items():
   if name=='capture.json':
    with zipfile.ZipFile(d/'capture.json.zip')as z:assert hashlib.sha256(z.read(name)).hexdigest()==expected
   else:assert sha(d/name)==expected
 assert len(m['local_media_hash_only'])==6 and all(r['copied']is False and r['portable']is False and r['deleted']is False and r['reencoded']is False for r in m['local_media_hash_only'])
 if args.check_local_originals:
  for rel,info in m['original_input_custody'].items():
   p=args.check_local_originals/rel;assert p.is_file()and p.stat().st_size==info['bytes']and sha(p)==info['sha256'],str(p)
 print(json.dumps(dict(status='VERIFIED_SELECTED_BYTES_AND_RECEIPT_BINDINGS_ONLY',payload_files=len(files),archives=len(m['archive_verification']),archive_members=member_count,local_media_originals_excluded=6,local_originals_rechecked=bool(args.check_local_originals),manifest_sha256=sha(mpath))))
if __name__=='__main__':verify()
