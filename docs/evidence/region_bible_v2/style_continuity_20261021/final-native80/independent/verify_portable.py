"""Stream-verify complete actual native80 artifacts; never run engine/extract corpus."""
from pathlib import Path
import argparse,hashlib,json,math,re,subprocess,zipfile,zlib
COMMIT='dec23450fb8e4ce6bca5643f1893c4bf91d14386';THRESHOLD=8*1024*1024

def filehash(path):
 with Path(path).open('rb')as f:return hashlib.file_digest(f,'sha256').hexdigest()

def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--harness-root',type=Path,required=True);ap.add_argument('--producer-root',type=Path);ap.add_argument('--git-root',type=Path);ap.add_argument('--report',type=Path);args=ap.parse_args();H=args.harness_root.resolve();checks=[]
 def ck(ok,label):
  checks.append(dict(passed=bool(ok),label=label))
  if not ok:raise AssertionError(label)
 h=json.loads((H/'report.json').read_text());ck(h['status']=='passed'and h['commit']==COMMIT and len(h['checks'])==1,'actual_outer_terminal_pass_exact_frozen_commit_and_one_check');c=h['checks'][0];ck(c['id']=='forest-depth-region'and c['status']=='passed'and type(c['exit_code'])is int and c['exit_code']==0 and c['failure_reason']is None and c['reused']is False,'actual_check_exit0_no_error_fresh_not_cached');ck(type(c['timeout_seconds'])is int and c['timeout_seconds']==600 and math.isfinite(c['duration_seconds'])and 0<c['duration_seconds']<=600 and h['wall_seconds']>=c['duration_seconds'],'original600_cap_and_actual_complete_check_duration');ck(abs(c['ended_at_unix']-c['started_at_unix']-c['duration_seconds'])<.001,'actual_check_timestamps_match_duration')
 argv=c['expanded_argv'];ck(len(argv)==5 and argv[1:4]==['tools/run_forest_depth_region.py','--corpus','--output'],'actual_corpus_command_no_layout_pin');prefix=Path(argv[-1]);ck(not prefix.is_absolute()and'..'not in prefix.parts and prefix.parts[:4]==('build','forest_depth','region','harness-matrix')and prefix.name=='harness-'+c['check_token'],'producer_relative_path_bound_to_actual_check_token');A=H/'artifacts'/c['id'];P=A/prefix;ck(A.is_dir()and not A.is_symlink()and(P/'receipt.json').is_file(),'portable_actual_artifact_suffix_locates_complete_original_receipt_without_live_producer')
 r=json.loads((P/'receipt.json').read_text());ck(r['status']=='passed'and r['source_head']==COMMIT and r['finite_fixed_root_corpus']is True and r['source_stable']is True,'producer_terminal_pass_and_exact_commit');ck(r['source_before']==r['source_after_import']==r['source_after']and len(r['source_before'])==3601 and r['import_source_guard']['passed']is True,'all_original3601_full_source_before_import_after_exact');ck(type(r['case_workers'])is int and r['case_workers']==2 and r['completed_case_indices']==list(range(80))and r['not_executed_case_indices']==[],'all80_complete_original_two_workers_no_omission');ck(r['requested_root_seeds']==[f'forest-depth-hollow-{n:02d}'for n in range(10)],'exact_original_ten_fixed_roots')
 routes=('fast','growth','high_return','change_mind');canonical=[(f'forest-depth-hollow-{n:02d}',m,t)for n,m in[(0,1),(2,1),(0,2),(2,2)]for t in routes]+[(f'forest-depth-hollow-{n:02d}',m,t)for n in range(10)if n not in(0,2)for m in(1,2)for t in routes];ck(len(r['runs'])==80 and[(x['seed'],x['map'],x['route'])for x in r['runs']]==canonical,'exact_original_canonical80_including_unchanged_first16_prefix');ck([(x['seed'],x['map'],x['route'])for x in r['requested_cases']]==canonical,'requested80_equals_actual80_exact_order')
 imp=r['import'];ck(imp['argv']==['bash','tools/godot.sh','--headless','--path','.','--editor','--quit']and imp['timeout_seconds']==90 and imp['exit_code']==0 and imp['errors']==[] and 0<imp['seconds']<=90 and filehash(P/'import.log')==imp['log_sha256'],'original_real_import90_completed_log_hash_bound');ck(filehash(A/'check.log')==filehash(H/c['log']),'portable_check_log_equals_original_outer_log')
 idx=json.loads((A/'large-json.index.json').read_text());archive=A/'large-json.zip';ck(idx['schema_version']==1 and idx['format']=='zip-deflate-level1'and idx['threshold_bytes']==THRESHOLD and filehash(archive)==idx['archive_sha256'],'actual_complete_lossless_zip_and_index_outer_binding');rows={x['path']:x for x in idx['members']};ck(len(rows)==len(idx['members'])==78,'actual78_large_JSON_members_unique');details=[]
 with zipfile.ZipFile(archive)as z:
  infos=z.infolist();ck(len(infos)==78 and{v.filename for v in infos}==set(rows),'exact_zip_member_set_no_duplicate_missing_or_extra');seen=[]
  for n,run in enumerate(r['runs']):
   expected_capture=prefix/f'{n:02d}-map{run["map"]}-{run["route"]}'/'capture.json';name=expected_capture.as_posix();native_args=run['argv'];expected_tail=['bash','tools/godot.sh','--headless','--fixed-fps','60','--path','.','--script','tests/forest_depth_region_runner.gd','--',f'--seed={run["seed"]}',f'--map={run["map"]}',f'--route={run["route"]}'];ck(native_args[:-1]==expected_tail and native_args[-1].startswith('--output=')and Path(native_args[-1].split('=',1)[1]).as_posix().endswith('/'+name),'original_actual_fixed60_native_command_case'+str(n));ck(run['status']=='passed'and type(run['exit_code'])is int and run['exit_code']==0 and run['errors']==[]and 0<run['seconds']<=240,'actual_native_exit0_original240_duration_case'+str(n));log=A/expected_capture.parent/'native.log';ck(filehash(log)==run['log_sha256'],'actual_native_log_sha_case'+str(n));digest=hashlib.sha256();size=0;crc=0
   if name in rows:
    row=rows[name];info=z.getinfo(name);ck(type(row['size'])is int and row['size']>=THRESHOLD and info.file_size==row['size']and info.compress_type==zipfile.ZIP_DEFLATED and not info.is_dir()and not((info.external_attr>>16)&0o170000)==0o120000,'actual_regular_full_size_zip_member_case'+str(n))
    with z.open(info)as stream:
     for chunk in iter(lambda:stream.read(1024*1024),b''):digest.update(chunk);size+=len(chunk);crc=zlib.crc32(chunk,crc)
    ck(size==row['size']and digest.hexdigest()==row['sha256']==run['capture_sha256']and(crc&0xffffffff)==info.CRC,'full_uncompressed_bytes_sha_size_CRC_equal_native_original_case'+str(n));seen.append(name);storage='ZIP_DEFLATED_full_original_bytes'
   else:
    raw=A/expected_capture;ck(raw.is_file()and not raw.is_symlink()and raw.stat().st_size<THRESHOLD,'small_original_raw_path_preserved_case'+str(n));size=raw.stat().st_size;digest=hashlib.sha256()
    with raw.open('rb')as stream:
     for chunk in iter(lambda:stream.read(1024*1024),b''):digest.update(chunk)
    ck(digest.hexdigest()==run['capture_sha256'],'full_raw_original_bytes_sha_equal_native_original_case'+str(n));storage='RAW_below8MiB_original_path'
   if args.producer_root:
    original=args.producer_root/expected_capture.relative_to(prefix);ck(original.is_file()and original.stat().st_size==size and filehash(original)==digest.hexdigest(),'owner_actual_live_producer_full_bytes_equal_case'+str(n))
   details.append(dict(case=n,seed=run['seed'],map=run['map'],route=run['route'],path=name,storage=storage,bytes=size,sha256=digest.hexdigest(),native_seconds=run['seconds']))
  ck(set(seen)==set(rows),'all78_archive_members_consumed_by_original80_no_hashonly_standin')
 git_bound=None
 if args.git_root:
  proc=subprocess.Popen(['git','cat-file','--batch'],cwd=args.git_root,stdin=subprocess.PIPE,stdout=subprocess.PIPE);count=0;capturer_source=None
  try:
   for name,expected in r['source_before'].items():
    assert'\n'not in name;proc.stdin.write((COMMIT+':'+name+'\n').encode());proc.stdin.flush();head=proc.stdout.readline().split();assert len(head)==3 and head[1]==b'blob',name;remaining=int(head[2]);digest=hashlib.sha256();pieces=[]
    while remaining:
     chunk=proc.stdout.read(min(1024*1024,remaining));assert chunk;digest.update(chunk);remaining-=len(chunk)
     if name=='tools/run_forest_depth_region.py':pieces.append(chunk)
    assert proc.stdout.read(1)==b'\n';assert digest.hexdigest()==expected,name;count+=1
    if pieces:capturer_source=b''.join(pieces).decode()
   ck(count==len(r['source_before']),'every_original_runtime_source_SHA_matches_exact_frozen_Git_dec_tree_not_later_docs');ck('timeout=240)'in capturer_source and 'max_workers=2'in capturer_source and 'workers=2 if args.corpus else 1'in capturer_source,'original240_native_and_two_worker_implementation_bound_to_dec_source');git_bound=COMMIT
  finally:proc.stdin.close();proc.stdout.close();proc.wait(timeout=30)
 portable_index=H.parent/'portable-index.json';portable=None
 if portable_index.is_file():
  pi=json.loads(portable_index.read_text());total=0
  for row in pi['files']:
   p=H.parent/row['path'];assert p.is_file()and p.stat().st_size==row['size']and filehash(p)==row['sha256'];total+=row['size']
  portable=dict(files=len(pi['files']),bytes=total,index_sha256=filehash(portable_index));ck(pi['source_commit']==COMMIT,'portable_selected_full_index_bound_to_frozen_source_commit')
 result=dict(verdict='ACCEPT_SCOPED_ACTUAL_THIRD_NATIVE80_OUTER_PASS_AND_COMPLETE_ARTIFACT_BYTES',scope='Outer native80 technical corpus+lossless artifact custody only; not full profiles, art/device/FUN/release',frozen_commit=COMMIT,harness_report=str(H/'report.json'),harness_report_sha256=filehash(H/'report.json'),producer_receipt_sha256=filehash(P/'receipt.json'),archive_sha256=idx['archive_sha256'],archive_bytes=archive.stat().st_size,index_sha256=filehash(A/'large-json.index.json'),outer_check_seconds=c['duration_seconds'],outer_wall_seconds=h['wall_seconds'],outer_cap_seconds=600,import_cap_seconds=90,native_cap_seconds=240,workers=2,source_entries=len(r['source_before']),source_git_dec_tree=git_bound,actual_capture_count=80,full_zip_capture_members=78,full_raw_small_captures=2,uncompressed_capture_bytes=sum(x['bytes']for x in details),capture_details=details,checks=checks,portable_package_index=portable,engine_executed=False,extracted_whole_corpus=False,current_source_rebinding=False,limitations=['Native script outcomes and complete archive bytes independently verified; no independent rerun of full80 gameplay semantic readers in this storage audit','Original failed/interrupted attempts remain unchanged and are not retroactively passed','Later documentation and evidence copies are not mistaken for in-run source drift','No claim that all80 are ZIP members:78>=8MiB archived, two<8MiB full raw paths retained','No art, player FUN, audio-listening, device or release acceptance'])
 if args.report:args.report.parent.mkdir(parents=True,exist_ok=True);args.report.write_text(json.dumps(result,indent=2)+'\n')
 print(json.dumps({k:v for k,v in result.items()if k not in ['capture_details','checks','limitations']}));print('INDEPENDENT_CHECKS',len(checks))
if __name__=='__main__':main()
