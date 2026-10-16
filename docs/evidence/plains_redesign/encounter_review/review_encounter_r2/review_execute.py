import sys,json,hashlib,gzip,tarfile,subprocess,time,os
from pathlib import Path
ROOT=Path.cwd(); OUT=ROOT/'build/plains_redesign/review_encounter_r2';sys.path.insert(0,str(ROOT/'tools'))
import production_loop as loop,level_formal as formal,level_experience as exp,run_plains_encounter_policy_tests as specialty
H=lambda b:hashlib.sha256(b).hexdigest()
commands=[]
def execute(argv,label,env=None):
 t=time.time();r=subprocess.run(argv,cwd=ROOT,capture_output=True,text=True,env=env);(OUT/(label+'.log')).write_text(r.stdout+r.stderr);commands.append(dict(argv=argv,exit_code=r.returncode,duration_seconds=time.time()-t,log=label+'.log'));return r
request=json.loads((ROOT/'build/verification/plains-redesign-encounter/PLAINS-REDESIGN-ENCOUNTER-01/2/review/host_request.json').read_text())
assert loop.digest(loop.snapshot())==request['source_hash']
provenance={'reviewer':'/root/plains_spatial_audit','request_hash':request['request_hash'],'source_hash':request['source_hash'],'nonce':request['nonce'],'expires_at':request['expires_at'],'started':time.time()}
(OUT/'request.json').write_text(json.dumps(request,ensure_ascii=False,indent=2))
for entry in ['test_level_formal_receipts','test_level_experience']:
 r=execute(['python3','tests/'+entry+'.py'],entry+'_direct');assert r.returncode==0
 r=execute(['python3','-m','unittest','discover','-s','tests','-p',entry+'.py'],entry+'_discover');assert r.returncode==0
assert execute(['python3','build/plains_redesign/review_encounter/reproduce_claim_neighbors.py'],'original_four_current').returncode==0
old=OUT/'original_source';old.mkdir(exist_ok=True)
with tarfile.open('build/plains_redesign/review_encounter/reviewed_original_source.tar.gz') as archive:archive.extractall(old,filter='data')
env=dict(os.environ,REVIEWED_SOURCE_ROOT=str(old));assert execute(['python3','build/plains_redesign/review_encounter/reproduce_claim_neighbors.py'],'original_four_old',env).returncode==1
native=[]
for recovery,resource in [(False,''),(True,''),(True,'heart'),(True,'note')]:
 record,data=specialty.native_run(OUT,recovery,resource);native.append(record);print('ACTUAL',record['output'],data['assertions'],data['failures'],flush=True)
(OUT/'native_execution.json').write_text(json.dumps(native,indent=2));commands.extend([dict(argv=r['command'],exit_code=r['process']['exit_code'],log=r['log'],source='independent native_run') for r in native])
# All portable compressed/raw bytes and archived source members independently checked.
portable=[]
for relative in ['docs/evidence/plains_redesign/encounter/index.json','docs/evidence/plains_redesign/encounter/r2_repair/index.json']:
 path=ROOT/relative;idx=json.loads(path.read_text());count=0
 for e in idx['entries']:
  b=(ROOT/e['portable_path']).read_bytes();raw=gzip.decompress(b);assert H(b)==e['sha256'] and len(b)==e['bytes'] and H(raw)==e['raw_sha256'] and len(raw)==e['raw_bytes'];count+=1
 a=idx['source_archive'];archivepath=ROOT/a['path'];assert H(archivepath.read_bytes())==a['sha256']
 matches=0
 with tarfile.open(archivepath) as tar:
  for member in tar.getmembers():
   if not member.isfile():continue
   b=tar.extractfile(member).read();name=member.name
   if 'r2_repair' in relative:assert (ROOT/name).read_bytes()==b;matches+=1
 portable.append(dict(index=relative,index_sha256=H(path.read_bytes()),entries=count,archive_sha256=a['sha256'],current_archive_matches=matches))
assert portable[0]['index_sha256']=='368e69839e7ff6504b455c3f2e8b14985275c9433b517d118d7848cb6fba2cb9'
assert portable[0]['archive_sha256']=='c78f438eee66ea1d2097215badcc41848d4aa14a8d3e4cf08febd4babc9eb1bf'
(OUT/'portable_verification.json').write_text(json.dumps(portable,indent=2))
fresh=json.loads((ROOT/'build/verification/plains-encounter/run_j8vy1m2q/receipt.json').read_text());assert fresh['source_before']==fresh['source_after']==formal.source_files()
provenance.update(fresh_receipt='build/verification/plains-encounter/run_j8vy1m2q/receipt.json',fresh_receipt_sha256=H((ROOT/'build/verification/plains-encounter/run_j8vy1m2q/receipt.json').read_bytes()),fresh_source_count=len(fresh['source_before']),portable=portable,independent_native=native)
for run in fresh['runs']:
 assert formal.file_hash(ROOT/run['output'])==run['sha256'] and formal.file_hash(ROOT/run['log'])==run['log_sha256'];assert run['process']['exit_code']==0
(OUT/'commands.json').write_text(json.dumps(commands,indent=2));(OUT/'provenance.json').write_text(json.dumps(provenance,indent=2));print('REVIEW CORE EXECUTION PASS',flush=True)
