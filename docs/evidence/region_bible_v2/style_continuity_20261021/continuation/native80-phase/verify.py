from pathlib import Path
import argparse,hashlib,json,zipfile,zlib
ROOT=Path(__file__).resolve().parent

def sha(p):
 h=hashlib.sha256()
 with Path(p).open('rb')as f:
  for b in iter(lambda:f.read(1048576),b''):h.update(b)
 return h.hexdigest()

def main():
 parser=argparse.ArgumentParser();parser.add_argument('--check-local-originals',type=Path);args=parser.parse_args();p=ROOT/'manifest.json';assert(ROOT/'manifest.sha256').read_text()==sha(p)+'  manifest.json\n';m=json.loads(p.read_text());expected={r['path']for r in m['files']};actual={str(p.relative_to(ROOT))for p in ROOT.rglob('*')if p.is_file()and p.name not in ['manifest.json','manifest.sha256']};assert actual==expected
 for row in m['files']:
  p=ROOT/row['path'];assert p.is_file()and p.stat().st_size==row['bytes']and sha(p)==row['sha256'],str(p)
 index=json.loads((ROOT/'restore-index.json').read_text());archive=ROOT/index['archive_relative_to_index'];assert sha(archive)==index['archive_sha256']==m['archive_sha256'];r=json.loads((ROOT/'producer-receipt.json').read_text());assert sha(ROOT/'producer-receipt.json')==index['original_receipt_sha256'];assert r['status']=='passed'and len(r['runs'])==80 and r['source_before']==r['source_after']and r['source_stable']is True and r['not_executed_case_indices']==[];rows=index['entries'];assert len(rows)==80
 with zipfile.ZipFile(archive)as z:
  assert z.testzip()is None and z.namelist()==[v['member']for v in rows]
  for row,run in zip(rows,r['runs']):
   raw=z.read(row['member']);assert len(raw)==row['bytes']and hashlib.sha256(raw).hexdigest()==row['sha256']==run['capture_sha256']and z.getinfo(row['member']).CRC==(zlib.crc32(raw)&0xffffffff)==int(row['crc32'],16);assert sha(ROOT/'native-logs'/Path(row['member']).parent/'native.log')==run['log_sha256']
   if args.check_local_originals:
    rawpath=args.check_local_originals/row['original_relative_path']
    if rawpath.exists():assert rawpath.is_file()and rawpath.stat().st_size==row['bytes']and sha(rawpath)==row['sha256']
    log=rawpath.parent/'native.log';assert log.is_file()and sha(log)==run['log_sha256']
 h=json.loads((ROOT/'outer-harness/report.json').read_text());assert h['status']=='interrupted'and h['checks']==[];u=json.loads((ROOT/'unlink-report.json').read_text());assert u['raw_capture_json_unlinked']==80 and u['exact_archived_original_bytes']==sum(v['bytes']for v in rows)and u['archive_sha256']==index['archive_sha256'];assert u['all_receipts_logs_outer_interrupted_and_oldfailed17_still_same']is True and u['all6_AV_media_bytes_still_same']is True
 print(json.dumps(dict(status='VERIFIED_NATIVE80_ARCHIVED_BYTES_ONLY_NOT_OUTER_HARNESS_PASS',capture_members=80,files=len(m['files']),archive_sha256=index['archive_sha256'],manifest_sha256=sha(ROOT/'manifest.json'))))
if __name__=='__main__':main()
