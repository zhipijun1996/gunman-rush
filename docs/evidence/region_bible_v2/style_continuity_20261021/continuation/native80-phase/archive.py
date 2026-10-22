from pathlib import Path
import hashlib,json,zipfile,zlib,stat,shutil,tempfile,importlib.util,filecmp,os
ROOT=Path.cwd();OUT=ROOT/'build/region_bible_v2/continuation-evidence-next/native80-phase';PROD=ROOT/'build/forest_depth/region/harness-matrix/harness-1581b63be33c47a0af6295646118c50d';receipt=PROD/'receipt.json';archive=OUT/'full-native80-captures.zip';assert not archive.exists(),'single unique archive already exists';r=json.loads(receipt.read_text())
def sha(p):
 h=hashlib.sha256()
 with Path(p).open('rb')as f:
  for b in iter(lambda:f.read(1048576),b''):h.update(b)
 return h.hexdigest()
assert r['status']=='passed'and r['source_stable']is True and r['source_before']==r['source_after']and len(r['source_before'])==3600 and len(r['runs'])==80 and all(x['status']=='passed'for x in r['runs'])and r['not_executed_case_indices']==[];receiptsha=sha(receipt);rows=[];free_before=shutil.disk_usage(ROOT).free
for run in r['runs']:
 cap=Path(next(a.split('=',1)[1]for a in run['argv']if a.startswith('--output=')));assert cap.is_relative_to(PROD)and cap.name=='capture.json'and cap.is_file();st=cap.stat();assert sha(cap)==run['capture_sha256']and sha(cap.parent/'native.log')==run['log_sha256'];rows.append(dict(original_relative_path=str(cap.relative_to(ROOT)),member=str(cap.relative_to(PROD)),bytes=st.st_size,sha256=run['capture_sha256'],metadata=dict(mode=stat.S_IMODE(st.st_mode),uid=st.st_uid,gid=st.st_gid,atime_ns=st.st_atime_ns,mtime_ns=st.st_mtime_ns)))
assert len(rows)==80 and len({x['member']for x in rows})==80
with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=1)as z:
 for row in rows:
  raw=(ROOT/row['original_relative_path']).read_bytes();assert hashlib.sha256(raw).hexdigest()==row['sha256'];info=zipfile.ZipInfo(row['member'],date_time=(1980,1,1,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED;info.external_attr=0o100644<<16;z.writestr(info,raw,compresslevel=1);row['crc32']=f'{zlib.crc32(raw)&0xffffffff:08x}'
index=dict(status='VERIFIED_NATIVE80_ARCHIVE_RAW_DELETION_NOT_AUTHORIZED',scope='Original producer native80 PASS; outer harness artifact collector interrupted, no harness approval',original_producer=str(PROD.relative_to(ROOT)),original_receipt_sha256=receiptsha,archive_relative_to_index='full-native80-captures.zip',archive_sha256=sha(archive),archive_bytes=archive.stat().st_size,compression='ZIP_DEFLATED level1',entries=rows,raw_originals_retained=True,raw_deletion_requires_additional_root_GO=True)
(OUT/'restore-index.json').write_text(json.dumps(index,indent=2)+'\n');template=ROOT/'build/region_bible_v2/continuation-evidence-next/corpus-phase/storage-relief/restore.py';shutil.copyfile(template,OUT/'restore.py');spec=importlib.util.spec_from_file_location('native80_restore',OUT/'restore.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);scratch=Path(tempfile.mkdtemp(prefix='native80-proof-',dir=OUT));proof=[]
with zipfile.ZipFile(archive)as z:
 assert z.testzip()is None and z.namelist()==[row['member']for row in rows]
 for row in rows:
  raw=z.read(row['member']);original=ROOT/row['original_relative_path'];assert len(raw)==row['bytes']and hashlib.sha256(raw).hexdigest()==row['sha256']and z.getinfo(row['member']).CRC==(zlib.crc32(raw)&0xffffffff)==int(row['crc32'],16);assert raw==original.read_bytes();assert module.restore_one(z,row,scratch)=='restored_exact';temp=scratch/row['original_relative_path'];assert filecmp.cmp(original,temp,shallow=False);st=temp.stat();assert st.st_mtime_ns==row['metadata']['mtime_ns']and stat.S_IMODE(st.st_mode)==row['metadata']['mode'];assert module.restore_one(z,row,scratch)=='already_present_exact';temp.unlink();temp.write_bytes(b'wrong existing cannot be overwritten')
  try:module.restore_one(z,row,scratch)
  except FileExistsError:assert temp.read_bytes()==b'wrong existing cannot be overwritten'
  else:raise AssertionError('conflicting file overwritten')
  temp.unlink();proof.append(dict(path=row['original_relative_path'],crc_full_sha_and_real_original_bytes_equal=True,actual_restore_byte_compare=True,idempotent=True,wrong_existing_refused_unchanged=True,mtime_mode_preserved=True))
shutil.rmtree(scratch)
for row in rows:assert (ROOT/row['original_relative_path']).is_file()and sha(ROOT/row['original_relative_path'])==row['sha256']
assert sha(receipt)==receiptsha
shutil.copyfile(receipt,OUT/'producer-receipt.json');shutil.copyfile(PROD/'import.log',OUT/'import.log')
for run in r['runs']:
 cap=Path(next(a.split('=',1)[1]for a in run['argv']if a.startswith('--output=')));target=OUT/'native-logs'/cap.parent.name/'native.log';target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(cap.parent/'native.log',target);assert sha(target)==run['log_sha256']
H=ROOT/'build/verification/harness/20261021T061859.284733Z';h=json.loads((H/'report.json').read_text());assert h['status']=='interrupted'and h['checks']==[]
for name in ['report.json','forest-depth-region.log']:
 target=OUT/'outer-harness'/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(H/name,target)
shutil.copyfile(ROOT/'build/region_bible_v2/corpus-artifact-space-first/duplicate-relief.json',OUT/'outer-harness/duplicate-relief.json')
report=dict(status='COMPLETE_BYTE_VERIFIED_ARCHIVE_READY_FOR_ROOT_GO',native_producer_status='passed',native_runs=80,source_inventory_count=3600,original_source_before_after_equal=True,outer_harness_status='interrupted',outer_harness_checks=[],harness_pass_claim=False,archive_sha256=index['archive_sha256'],archive_bytes=archive.stat().st_size,original_capture_bytes=sum(x['bytes']for x in rows),raw_originals_still_present=80,originals_unlinked=0,free_before_bytes=free_before,free_after_bytes=shutil.disk_usage(ROOT).free,tests=proof,requires_additional_GO_before_any_raw_unlink=True)
(OUT/'archive-verification.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:v for k,v in report.items()if k!='tests'}))
