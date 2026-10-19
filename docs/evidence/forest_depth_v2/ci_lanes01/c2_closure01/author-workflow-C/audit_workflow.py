from pathlib import Path
import yaml,json,hashlib,subprocess,copy,tempfile,os,textwrap
R=Path('/workspace/gunman-rush-design');D=Path(__file__).resolve().parent
before=(D/'environment.before.yml.txt').read_text();after=(R/'.github/workflows/environment.yml').read_text();a=yaml.safe_load(before);b=yaml.safe_load(after)
old=a['jobs']['core'];phase=b['jobs']['core_checks'];aggregate=b['jobs']['core'];assert phase['strategy']=={'fail-fast':False,'matrix':{'lane':['parallel','serial']}}
assert old['timeout-minutes']==phase['timeout-minutes']==60 and aggregate['timeout-minutes']==10
assert {k:v for k,v in a['jobs'].items() if k!='core'}=={k:v for k,v in b['jobs'].items() if k not in {'core','core_checks'}}
old_setup=old['steps'][:next(i for i,s in enumerate(old['steps']) if str(s.get('run','')).startswith('python3 tools/harness.py'))]
new_setup=phase['steps'][:len(old_setup)]
normalized=json.loads(json.dumps(new_setup).replace('${{ github.job }}-${{ matrix.lane }}','${{ github.job }}'))
assert old_setup==normalized,'Original setup differs beyond matrix cache/artifact disambiguation'
old_extra=[s for s in old['steps'] if 'run_wood_platform_tests.py' in s.get('run','') or 'run_audio_lifecycle_tests.py' in s.get('run','')];new_extra=[s for s in phase['steps'] if 'run_wood_platform_tests.py' in s.get('run','') or 'run_audio_lifecycle_tests.py' in s.get('run','')]
assert len(old_extra)==len(new_extra)==5
for o,n in zip(old_extra,new_extra):
 assert n['if']=="matrix.lane == 'serial'";c=copy.deepcopy(n);del c['if'];assert c==o
assert next(s for s in phase['steps'] if s.get('name')=='Show failed Harness checks without requiring artifact download')==next(s for s in old['steps'] if s.get('name')=='Show failed Harness checks without requiring artifact download')
manifest=json.loads((R/'tools/harness/profiles.json').read_text());ids=list(dict.fromkeys(sum((manifest['profiles'][p] for p in ['gameplay','art']),[])));parallel=[x for x in ids if not manifest['checks'][x].get('serial',False)];serial=[x for x in ids if manifest['checks'][x].get('serial',False)];assert len(ids)==85 and set(parallel).isdisjoint(serial) and set(parallel+serial)==set(ids)
assert phase['needs']=='prepare' and set(aggregate['needs'])=={'prepare','core_checks'} and aggregate['if']=='always()'
assert aggregate['steps'][0]['run']=='test "$LANES_RESULT" = success && test "$PREPARE_RESULT" = success'
assert not any('godot' in s.get('run','') or 'cloud_setup' in s.get('run','') for s in aggregate['steps'])
assert any(s.get('with',{}).get('name')=='validated-foundry' and s['with']['path']=='resources/foundry/' for s in aggregate['steps'])
assert '--verify-lanes build/verification/ci-lane-proof/parallel/report.json build/verification/ci-lane-proof/serial/report.json' in next(s['run'] for s in aggregate['steps'] if '--verify-lanes' in s.get('run',''))
for job in ['deploy_web','android']:assert b['jobs'][job]['needs']==a['jobs'][job]['needs']
# Execute actual inline collector on representative files; no mocked I/O or native.
collector=next(s['run'] for s in phase['steps'] if s.get('name')=='Collect the unique original phase report and check stdout logs');code=collector.split("python3 - <<'PYCODE'\n",1)[1].rsplit('\nPYCODE',1)[0];compile(code,'workflow-proof-collector','exec');probes=[]
for label in ['valid','missing_report','two_reports','missing_log','escape_log']:
 with tempfile.TemporaryDirectory(prefix='ci-lane-proof-') as tmp:
  root=Path(tmp);folder=root/'build/verification/harness/run';folder.mkdir(parents=True)
  if label!='missing_report':
   log='../outside.log' if label=='escape_log' else 'first.log';(folder/'report.json').write_text(json.dumps({'checks':[{'log':log}]}))
   if label=='two_reports':other=folder.parent/'other';other.mkdir();(other/'report.json').write_text('{}')
   if label!='missing_log':(folder/'first.log').write_bytes(b'PASS: original stdout\n')
  env=os.environ.copy();env['HARNESS_LANE']='parallel';p=subprocess.run(['python3','-c',code],cwd=root,env=env,capture_output=True,text=True);expected=0 if label=='valid' else 1;assert (p.returncode==0)==(expected==0),(label,p.stderr)
  if label=='valid':
   dest=root/'build/verification/ci-lane-proof/parallel';assert (dest/'report.json').read_bytes()==(folder/'report.json').read_bytes();assert (dest/'first.log').read_bytes()==(folder/'first.log').read_bytes()
  probes.append({'case':label,'exit_code':p.returncode,'accepted':p.returncode==0,'reason':p.stderr.strip()})
result={'scope':'Workflow static/inline-collector I/O validation; no native or GitHub Actions run','workflow_sha256':hashlib.sha256(after.encode()).hexdigest(),'profile_manifest_sha256':hashlib.sha256((R/'tools/harness/profiles.json').read_bytes()).hexdigest(),'total_profile_checks':len(ids),'parallel':parallel,'serial':serial,'coverage_unique_complete':True,'extra_checks_serial_only_unchanged_commands_env_count':len(new_extra),'original_setup_preserved_except_unique_lane_keys':True,'original_failure_tail_preserved':True,'original_noncore_jobs_preserved':True,'per_phase_minutes':60,'aggregate_minutes':10,'proof_collector_actual_io_cases':probes,'native_executed':False}
(D/'workflow-audit.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'profile_checks':len(ids),'parallel':len(parallel),'serial':len(serial),'extra_serial':len(new_extra),'collector_cases':len(probes)}))
