from pathlib import Path
import hashlib,json,shutil,subprocess,zipfile,zlib
ROOT=Path.cwd();OUT=ROOT/'build/region_bible_v2/continuation-evidence-next';PAY=OUT/'payload';PAY.mkdir(exist_ok=True)
BASE='0483399b4cf0621d9dd9f8892661868f76799964';head=subprocess.check_output(['git','rev-parse','HEAD']).decode().strip();status=subprocess.check_output(['git','status','--porcelain']).decode();assert head==BASE
entries=[];inputs={};archive_checks=[];media=[];facts={}
def digest(p):
 h=hashlib.sha256()
 with Path(p).open('rb')as f:
  for block in iter(lambda:f.read(1024*1024),b''):h.update(block)
 return h.hexdigest()
def remember(p):
 p=Path(p);assert p.is_file(),str(p);value={'bytes':p.stat().st_size,'sha256':digest(p)}
 key=str(p.relative_to(ROOT));assert key not in inputs or inputs[key]==value;inputs[key]=value;return value

def cp(src,dest,kind):
 src=Path(src);src=src if src.is_absolute()else ROOT/src;info=remember(src);target=OUT/dest;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,target);assert remember(src)==info and target.stat().st_size==info['bytes']and digest(target)==info['sha256'];entries.append(dict(path=str(target.relative_to(OUT)),origin=str(src.relative_to(ROOT)),kind=kind,**info));return target

def zipped(src,dest,member,kind):
 src=Path(src);src=src if src.is_absolute()else ROOT/src;original=remember(src);target=OUT/dest;target.parent.mkdir(parents=True,exist_ok=True);raw=src.read_bytes();zi=zipfile.ZipInfo(member,date_time=(1980,1,1,0,0,0));zi.compress_type=zipfile.ZIP_DEFLATED;zi.external_attr=0o100644<<16
 with zipfile.ZipFile(target,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6)as z:z.writestr(zi,raw,compresslevel=6)
 with zipfile.ZipFile(target)as z:
  assert z.testzip()is None and z.namelist()==[member];info=z.getinfo(member);decoded=z.read(member);assert len(decoded)==original['bytes']and hashlib.sha256(decoded).hexdigest()==original['sha256']and info.CRC==zlib.crc32(raw)&0xffffffff
  memberinfo=dict(path=member,bytes=info.file_size,sha256=hashlib.sha256(decoded).hexdigest(),crc32=f'{info.CRC:08x}')
 assert remember(src)==original
 entries.append(dict(path=str(target.relative_to(OUT)),origin=str(src.relative_to(ROOT)),kind=kind,bytes=target.stat().st_size,sha256=digest(target),members=[memberinfo]));archive_checks.append(dict(path=str(target.relative_to(OUT)),member_count=1,testzip_passed=True,all_full_member_sha256_verified=True));return target

def load(p):remember(ROOT/p);return json.loads((ROOT/p).read_text())
# Preserve the exact rejected delta; never reconstruct it from restored production.
srcroot=Path('build/region_bible_v2/root-shoulder-rework-stop-first');stop=load(srcroot/'receipt.json');assert stop['decision']=='REWORK_STOP'and stop['base_commit']==BASE and len(stop['files'])==18
zsrc=ROOT/srcroot/'exact-shoulder-source-delta.zip';assert digest(zsrc)==stop['archive_sha256'];zipmembers=[]
with zipfile.ZipFile(zsrc)as z:
 assert z.testzip()is None and len(z.infolist())==19 and set(z.namelist())==set(stop['files'])|{'tracked.patch'}
 for info in z.infolist():
  raw=z.read(info.filename);sha=hashlib.sha256(raw).hexdigest();assert info.CRC==(zlib.crc32(raw)&0xffffffff)
  if info.filename in stop['files']:assert len(raw)==stop['files'][info.filename]['bytes']and sha==stop['files'][info.filename]['sha256']
  else:assert raw==(ROOT/srcroot/'tracked.patch').read_bytes();remember(ROOT/srcroot/'tracked.patch')
  zipmembers.append(dict(path=info.filename,bytes=len(raw),sha256=sha,crc32=f'{info.CRC:08x}'))
target=cp(zsrc,'payload/rejected-root-shoulder/exact-shoulder-source-delta.zip','original lossless19-member rejected source delta');entries[-1]['members']=zipmembers;archive_checks.append(dict(path=str(target.relative_to(OUT)),member_count=19,testzip_passed=True,all_full_member_sha256_verified=True))
cp(srcroot/'receipt.json','payload/rejected-root-shoulder/archive-receipt.json','original REWORK_STOP archive receipt')
golden=Path('build/region_bible_v2/root-shoulder-golden-first');gr=load(golden/'receipt.json');assert gr['source_stable']is True and gr['sources_before']==gr['sources_after']and gr['exit_code']==0 and gr['native_exit_code']==0
pngs=sorted((ROOT/golden).glob('*.png'));assert len(pngs)==6
for p in pngs:cp(p,'payload/rejected-root-shoulder/actual6/'+p.name,'original full-HUD rejected-candidate PNG')
for name in ['capture.json','receipt.json','native.log','display.log']:cp(golden/name,'payload/rejected-root-shoulder/actual6/'+name,'original actual6 receipt/capture/log')
cp('build/region_bible_v2/root-shoulder-import-first/import.log','payload/rejected-root-shoulder/import.log','original shoulder editor-import log')
for name in ['review.json','review.md']:cp('build/region_bible_v2/visual-review-root-shoulder-first/'+name,'payload/rejected-root-shoulder/independent-review/'+name,'original independent REWORK_STOP review')
vr=load(Path('build/region_bible_v2/visual-review-root-shoulder-first/review.json'));assert vr['verdict']=='REWORK_STOP_ROOT_SHOULDER_INTERNAL_PATCH_DIRECTION'
facts['rejected_root_shoulder']=dict(decision=stop['decision'],source_delta_files=18,zip_members=19,actual_pngs=6,actual_source_inventory_entries=len(gr['sources_before']),source_inventory_before_after_equal=True,base_commit=BASE,source_provenance='Original rejected shoulder freeze; production was restored to048 afterwards. Not current art admission.')
# Selected source studies: source boards and supporting evidence, not another bulk source archive.
studies=Path('build/region_bible_v2/forest-art/root-shoulder-one-candidate')
study_names=['root_shoulder.native.png','source-board-native1x.png','source-board-display4x.png','host-attachment-source1x.png','source-family-comparison1x.png','provenance.json','REVIEW.md','host-alpha-footprint-proof.json','palette.json','shoulder.authored.rows']
for label,directory in [('v1',studies),('v2',studies/'refinement-v2')]:
 for name in study_names:
  # v2 exact native/rows/palette already live inside the single exact19 source delta.
  if label=='v2'and name in ['root_shoulder.native.png','palette.json','shoulder.authored.rows']:continue
  cp(directory/name,'payload/rejected-root-shoulder/source-studies/'+label+'/'+name,'original source-study board/proof; not actual-game acceptance')
for name in ['v1-v2-source-comparison1x.png','shape-change-proof.json']:cp(studies/'refinement-v2'/name,'payload/rejected-root-shoulder/source-studies/v2/'+name,'original v1-v2 source refinement evidence')
# Two actual AV runs. Copy only evidence, never media or shader/user cache bulk.
for challenge,stem,keyframe_count in [('F05','f05-map1-actualmovie-first',6),('F08','f08-map2-actualmovie-first',5)]:
 d=Path('build/region_bible_v2')/stem;r=load(d/'receipt.json');trace=load(d/'trace.json');reviewdir=Path('build/region_bible_v2/actual-av-review-first')/challenge;review=load(reviewdir/'review.json')
 assert r['source_stable']is True and r['source_before']==r['source_after']and r['exit_code']==0 and len(r['source_before'])==3600
 assert review['head']==BASE and review['source_files']==3600 and review['raw_trace_unmodified']is True and review['verdict']=='SCOPED_ACCEPT_actual_'+challenge+'_AV'
 assert len(r['keyframes'])==keyframe_count and len(list((ROOT/d/'keyframes').glob('*.png')))==keyframe_count
 traceinfo=remember(ROOT/d/'trace.json');assert traceinfo==r['artifacts']['trace.json'];zipped(d/'trace.json','payload/'+challenge+'/trace.json.zip','trace.json','full original trace, byte-lossless DEFLATE')
 for p in sorted((ROOT/d).iterdir()):
  if p.is_file()and p.suffix in ['.json','.log']and p.name!='trace.json':cp(p,'payload/'+challenge+'/'+p.name,'original complete AV receipt/probe/log')
 for row in r['keyframes']:
  p=ROOT/d/row['path'];assert digest(p)==row['sha256'];cp(p,'payload/'+challenge+'/'+row['path'],'exact original selected frame PNG')
 for p in sorted((ROOT/reviewdir).iterdir()):
  if p.is_file():cp(p,'payload/'+challenge+'/independent-review/'+p.name,'original independent AV review/probe')
 for name in ['original.avi','original.wav','playback.mp4']:
  p=ROOT/d/name;info=remember(p);assert info==r['artifacts'][name]
  media.append(dict(challenge=challenge,original_path=str(p.relative_to(ROOT)),**info,retained_local_original=True,copied=False,deleted=False,reencoded=False,portable=False))
 assert trace['failures']==[]and trace['manual_motor_step']is False
 if challenge=='F05':assert trace['position_or_resource_injection']is False
 else:assert trace['resource_or_health_override']is False and trace['direct_claim_or_grant']is False and trace['initial_fixture_spawn_override']is False and trace['fixture']=={}
 facts[challenge]=dict(base_commit=BASE,source_inventory_entries=len(r['source_before']),source_inventory_before_after_equal=True,trace_physics_frames=len(trace['frames']),completed_legs=len(trace['completed']),events=len(trace['events']),requests=len(trace['requests']),pointer_rows=len(trace['pointer_events']),paused_modal_rows=len(trace['modal_frames']),keyframe_pngs=keyframe_count,selected_video_frames=[k['frame']for k in r['keyframes']],video_frames=review['video_frame_count'],native_budget_seconds=review['native_budget_seconds'],native_log_recorded_seconds=review['native_log_recorded_seconds'],wrapper_total_seconds=r['elapsed_seconds'],independent_verdict=review['verdict'],scope='Full trace/timeline and selected stills only; no full continuous visual watch, listening, device, beauty or whole-art acceptance.')
 if'reader_modal_frames'in trace:facts[challenge]['reader_modal_rows']=len(trace['reader_modal_frames'])
 if challenge=='F08':facts[challenge]['reader_rendered_modal_visual_acceptance']='Not sampled among the five frames; actual Reader interaction/effect is timeline evidence only.'
cp('build/region_bible_v2/actual-av-review-first/audit_actual.py','payload/av-independent-audit_actual.py','shared original AV audit implementation, copied once')
# Three whole native captures, preserving each original source range.
consumerreview=load(Path('build/region_bible_v2/default-consumers-independent-first/review.json'))
for kind,src in [('guardian','build/forest_depth/campaign/v15-guardian-first'),('canopy','build/forest_depth/campaign/v15-canopy-first'),('restore','build/forest_depth/restore/v15-current-first')]:
 d=Path(src);r=load(d/'receipt.json');capture=load(d/'capture.json');ind=consumerreview['reports'][kind]
 assert r['passed']is True and r['source_guard']is True and r['source_before']==r['source_after']and r['verifier_before']==r['verifier_after']
 assert digest(ROOT/d/'capture.json')==ind['capture_sha256']and digest(ROOT/d/'receipt.json')==ind['receipt_sha256']
 assert ind['actual_existing_reader_passed']is True and ind['current_pass_claim']is False
 assert capture['failures']==([]if kind!='restore'else 0)
 for name,expected in r['logs'].items():
  assert digest(ROOT/d/name)==expected
  if name=='capture.json':zipped(d/name,'payload/default-consumers/'+kind+'/capture.json.zip',name,'complete original native capture, byte-lossless DEFLATE')
  else:cp(d/name,'payload/default-consumers/'+kind+'/'+name,'original receipt-declared complete auxiliary capture/log')
 cp(d/'receipt.json','payload/default-consumers/'+kind+'/receipt.json','original complete source and verifier receipt')
 fact=dict(original_base_commit=r['base_commit'],original_source_inventory_entries=len(r['source_before']),source_and_verifier_before_after_equal=True,native_check_rows=len(capture['checks']),independent_current_pass_claim=False,source_provenance='Rejected shoulder freeze; not clean048/current whole-source acceptance.'if kind=='guardian'else'Original clean048 freeze; no rebind to later/current source.',provenance_limit=ind['provenance_limit'])
 if kind!='restore':
  actualroute=capture['route'];fact.update(route_legs=len(actualroute['completed']),route_frames=len(actualroute['frames']),route_layout=actualroute['manifest']['layout_version'],route_map=actualroute['manifest']['map_index'])
 else:fact.update(assertions=capture['assertions'],cases=len(capture['cases']),capture_schema_limit=ind['capture_schema_limit'])
 if kind=='guardian':
  covered=[p for p in stop['files']if p in r['source_before']];assert len(covered)==12 and all(r['source_before'][p]==stop['files'][p]['sha256']for p in covered)
  fact['exact_shoulder_archive_source_inventory_coverage']=dict(matched_members=covered,count=12,archive_source_members=18,uncovered_members=[p for p in stop['files']if p not in r['source_before']],limit='Do not claim the Guardian inventory independently hashes all18 archive files; six binary/rows/compiler/import/UID entries are outside that inventory.')
 facts[kind]=fact
for name in ['review.json','review.md']:cp('build/region_bible_v2/default-consumers-independent-first/'+name,'payload/default-consumers/independent-review/'+name,'original three-consumer independent review')
# Check byte custody for every copied or compressed member a second time.
for entry in entries:
 target=OUT/entry['path'];assert target.stat().st_size==entry['bytes']and digest(target)==entry['sha256']
 if'members'in entry:
  with zipfile.ZipFile(target)as z:
   assert z.testzip()is None
   for m in entry['members']:
    raw=z.read(m['path']);assert len(raw)==m['bytes']and hashlib.sha256(raw).hexdigest()==m['sha256']and z.getinfo(m['path']).CRC==int(m['crc32'],16)
for path,info in inputs.items():assert (ROOT/path).stat().st_size==info['bytes']and digest(ROOT/path)==info['sha256'],path
assert subprocess.check_output(['git','rev-parse','HEAD']).decode().strip()==head and subprocess.check_output(['git','status','--porcelain']).decode()==status,'Git/source metadata changed during preparation'
manifest=dict(schema_version=1,status='PREPARATION_ONLY_NOT_PUBLISHED',scope='Selected portable original JSON/PNG/receipts and exact rejected delta; no production/docs/Git write, engine run or new acceptance.',base_commit_at_preparation=head,source_rebinding=False,art_status='REWORK_STOP / whole forest macro form remains unfinished and unverified',facts=facts,files=entries,archive_verification=archive_checks,local_media_hash_only=media,media_portability_claim=False,originals_mutated=False,all_original_selected_inputs_rehashed_unchanged=True,original_input_custody=inputs,omissions=['AVI/WAV/MP4 retained local and excluded from portable payload; hashes only','Shader cache/user-data bulk intentionally excluded; original full receipts retain original artifact lists','No duplicated whole source archive; only exact rejected19-member delta plus selected source-study boards','Optional earlier TREE/source-only proposal omitted to avoid presenting a superseded suggestion as acceptance'],limitations=['F05/F08 full timelines and selected stills do not establish continuous smooth camera/wind/animation or whole-route spatial beauty','No perceptual audio listening, physical device acceptance, release/FUN or whole-art pass','F08 opened Reader page is not among five visual samples','Guardian retains shoulder source provenance; canopy/restore retain their separate clean048 provenance','Restore capture schema limitations preserved in original independent report'],payload_file_count=len(entries),payload_total_bytes=sum(x['bytes']for x in entries))
manifest['control_files']=[dict(path=name,bytes=(OUT/name).stat().st_size,sha256=digest(OUT/name))for name in ['README.md','prepare.py','verify.py']]
manifest['manifest_self_integrity']='Full SHA-256 in manifest.sha256 sidecar; manifest and sidecar intentionally do not recursively index themselves.'
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2,ensure_ascii=False)+'\n');(OUT/'manifest.sha256').write_text(digest(OUT/'manifest.json')+'  manifest.json\n')
print(json.dumps(dict(files=len(entries),payload_bytes=manifest['payload_total_bytes'],archives=len(archive_checks),media_originals_excluded=len(media),manifest_sha256=digest(OUT/'manifest.json'))))
