from pathlib import Path
import argparse,hashlib,json,zipfile,zlib
ROOT=Path(__file__).resolve().parent

def sha(p):
 h=hashlib.sha256()
 with Path(p).open('rb')as f:
  for b in iter(lambda:f.read(1048576),b''):h.update(b)
 return h.hexdigest()

def main():
 parser=argparse.ArgumentParser();parser.add_argument('--check-local-originals',type=Path);args=parser.parse_args();p=ROOT/'manifest.json';assert(ROOT/'manifest.sha256').read_text()==sha(p)+'  manifest.json\n';m=json.loads(p.read_text());assert m['status']=='PREPARATION_ONLY_INDEPENDENT_NARROW_REVIEW_INCLUDED'and m['current_new80_result']=='RUNNING_NOT_INCLUDED_NO_COMPLETION_CLAIM';expected={r['path']for r in m['files']};assert expected=={str(p.relative_to(ROOT))for p in(ROOT/'payload').rglob('*')if p.is_file()};members=0
 for row in [*m['files'],*m['control_files']]:
  p=ROOT/row['path'];assert p.is_file()and p.stat().st_size==row['bytes']and sha(p)==row['sha256']
  if'members'in row:
   with zipfile.ZipFile(p)as z:
    assert z.testzip()is None and z.namelist()==[r['path']for r in row['members']]
    for r in row['members']:
     raw=z.read(r['path']);assert len(raw)==r['bytes']and hashlib.sha256(raw).hexdigest()==r['sha256']and z.getinfo(r['path']).CRC==(zlib.crc32(raw)&0xffffffff)==int(r['crc32'],16);members+=1
 first=ROOT/'payload/failed-original19';r=json.loads((first/'receipt.json').read_text());single=ROOT/'payload/single-repair-actual-second';s=json.loads((single/'receipt.json').read_text());assert r['status']=='failed'and len(r['runs'])==19 and r['source_stable']is True and r['source_before']==r['source_after'];assert s['status']=='passed'and s['source_stable']is True and s['source_before']==s['source_after'];assert set(r['source_before'])==set(s['source_before'])and[p for p in r['source_before']if r['source_before'][p]!=s['source_before'][p]]==['tests/forest_bible_trace_support.gd']
 with zipfile.ZipFile(first/'full-original19-captures.zip')as z:
  for run in r['runs']:
   cap=Path(next(a.split('=',1)[1]for a in run['argv']if a.startswith('--output=')));member=cap.parent.name+'/capture.json';assert hashlib.sha256(z.read(member)).hexdigest()==run['capture_sha256']and sha(first/cap.parent.name/'native.log')==run['log_sha256']
 with zipfile.ZipFile(single/'capture.json.zip')as z:assert hashlib.sha256(z.read('capture.json')).hexdigest()==s['runs'][0]['capture_sha256']
 assert sha(single/'native.log')==s['runs'][0]['log_sha256']
 storage=json.loads((ROOT/m['authorized_lossless_storage']['restore_index']).read_text());archived={r['original_relative_path']:r for r in storage['entries']};assert len(archived)==18 and storage['original_failed17_retained_raw']is True
 if args.check_local_originals:
  with zipfile.ZipFile(first/'full-original19-captures.zip')as z:
   for rel,row in m['original_input_custody'].items():
    p=args.check_local_originals/rel
    if p.is_file():assert p.stat().st_size==row['bytes']and sha(p)==row['sha256'],rel
    else:
     assert rel in archived and archived[rel]['bytes']==row['bytes']and archived[rel]['sha256']==row['sha256'],rel
     raw=z.read(archived[rel]['member']);assert len(raw)==row['bytes']and hashlib.sha256(raw).hexdigest()==row['sha256'],rel
 print(json.dumps(dict(status='VERIFIED_SELECTED_PARTIAL_FAILURE_AND_SINGLE_REPAIR_BYTES_ONLY',files=len(m['files']),archive_members=members,new80_final_claim=False,manifest_sha256=sha(ROOT/'manifest.json'))))
if __name__=='__main__':main()
