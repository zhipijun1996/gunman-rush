"""Independent native evidence reconsumption and exact source reconstruction only."""
from pathlib import Path
import json,hashlib,subprocess,zipfile
ROOT=Path(__file__).resolve().parents[4];OUT=Path(__file__).resolve().parent
P=ROOT/'docs/evidence/region_production_v3/root_bell_run_replay_fix'
N=ROOT/'build/region_production_v3/root_bell_run_replay_independent'
sha=lambda b:hashlib.sha256(b).hexdigest()
with zipfile.ZipFile(P/'actual_native_originals.zip') as z:
 for item in json.loads((P/'native_archive_index.json').read_text())['files']:
  raw=z.read(item['member']);assert sha(raw)==item['sha256'] and len(raw)==item['size']
 # Author failure records remain actual failure, never overwritten as passed.
 assert 'Parse Error' in z.read('audit_01.log').decode() or 'SCRIPT ERROR' in z.read('audit_01.log').decode()
 assert json.loads(z.read('audit_01.invocation.json'))['exit_code']==143
 assert json.loads(z.read('audit_02.invocation.json'))['exit_code']!=0
 author=json.loads(z.read('audit_03.json'))
 cases=['audit_01','audit_02','audit_03','campaign_01'];manifests={case:json.loads((P/'source_reconstruction'/f'{case}.json').read_text()) for case in cases}
 own={name:json.loads((N/(name+'.invocation.json')).read_text()) for name in ['audit_independent','campaign_independent']}
 requests=[];trees={}
 for m in manifests.values():
  base=m['reconstruction_base_commit']
  if base not in trees:
   tree={}
   for row in subprocess.check_output(['git','ls-tree','-r','-z',base],cwd=ROOT).split(b'\0'):
    if row:meta,path=row.split(b'\t');tree[path.decode()]=meta.decode().split()[2]
   trees[base]=tree
  requests.extend(b['blob'] for b in m['bindings'] if b['basis']=='git_blob')
 head=own['audit_independent']['actual_startup_HEAD']
 assert head==own['campaign_independent']['actual_startup_HEAD']=='7e253830129770fa8f9b4caaabd0b76c3ef275b5'
 tree={}
 for row in subprocess.check_output(['git','ls-tree','-r','-z',head],cwd=ROOT).split(b'\0'):
  if row:meta,path=row.split(b'\t');tree[path.decode()]=meta.decode().split()[2]
 trees[head]=tree
 for r in own.values():requests.extend(tree[p] for p in r['source_before'])
 ids=list(dict.fromkeys(requests));proc=subprocess.run(['git','cat-file','--batch'],cwd=ROOT,input=('\n'.join(ids)+'\n').encode(),capture_output=True,check=True);pos=0;blobs={}
 for oid in ids:
  end=proc.stdout.index(b'\n',pos);header=proc.stdout[pos:end].split();size=int(header[-1]);pos=end+1;blobs[oid]=proc.stdout[pos:pos+size];pos+=size+1
  assert header[0].decode()==oid and header[1]==b'blob'
 bindings=[]
 for case,m in manifests.items():
  r=json.loads(z.read(case+'.invocation.json'));inventory={}
  for b in m['bindings']:
   if b['basis']=='git_blob':assert trees[m['reconstruction_base_commit']][b['path']]==b['blob'];raw=blobs[b['blob']]
   else:
    path=(P/'source_reconstruction'/b['blob_file']).resolve();assert path.is_relative_to((P/'source_reconstruction/dirty_blobs').resolve());raw=path.read_bytes()
   assert sha(raw)==b['sha256'];inventory[b['path']]=b['sha256']
  assert len(inventory)==806 and inventory==r['source_before']==r['source_after']
  bindings.append({'case':case,'sources':len(inventory),'reconstruction_base':m['reconstruction_base_commit'],'dirty_overlays':m['overlay_count'],
                   'actual_startup_HEAD':'not_recorded_do_not_invent','exit_code':r['exit_code']})
 for name,r in own.items():
  assert len(r['source_before'])==806 and r['source_before']==r['source_after'] and r['exit_code']==0 and r['source_stable']
  assert sha((N/(name+'.log')).read_bytes())==r['runtime_log_sha256']
  assert all(sha(blobs[tree[p]])==h for p,h in r['source_before'].items())
  bindings.append({'case':name,'sources':806,'actual_startup_HEAD':head,'all_exact_Git_blob':True,'exit_code':0})

native=json.loads((N/'audit_independent.json').read_text());replay=native['run_manifest_replay']
assert native['failures']==[] and replay['passed'] and replay['failures']==[]
assert len(native['rows'])==40 and sum(r['candidate']['replaced'] for r in native['rows'])==1
assert len(native['physical_negatives']['refused'])==10 and native['physical_negatives']['failures']==[] and native['legacy_live_loader_compatibility']['passed']
assert len(replay['cases'])==5 and all(r['passed'] for r in replay['cases'])
assert len(replay['negatives'])==9 and all(r['refused'] for r in replay['negatives'])
assert replay['cases']==author['run_manifest_replay']['cases'] and replay['negatives']==author['run_manifest_replay']['negatives']
for mode,snapshot in replay['actual_snapshots'].items():
 version='plains-region-v11-root-bell-v2' if mode=='v2' else 'plains-region-v10'
 assert snapshot['versions']['generated_layout']==snapshot['versions']['encounters']==version
 assert len(snapshot['stages'])==2
 for stage in snapshot['stages']:
  o=stage['outputs'];assert o['stage_generator']['version']==o['enemy_layout']['version']==o['generated_layout']['version']==version
 assert snapshot['stages'][0]['outputs']['map_transition']=={'from_map':1.,'to_map':2.,'reason':'mini_boss_defeated','id':'plains/map_1/enter_map_2'}
 assert 'brake_boots' in snapshot['stages'][1]['outputs']['capability_snapshot']['items']
log=(N/'campaign_independent.log').read_text();assert 'PLAINS CAMPAIGN MAP: 3705 assertions, 0 failures' in log and 'ERROR' not in log
# Preserve old tests verbatim; append-only new test function and two runner lines.
old=(P/'before/root_bell_formal_tests.gd').read_bytes();new=(P/'after/root_bell_formal_tests.gd').read_bytes();assert new.startswith(old)
a=(P/'before/root_bell_formal_runner.gd').read_text();b=(P/'after/root_bell_formal_runner.gd').read_text();added='\tresult["run_manifest_replay"] = await suite.run_manifest_replay(self)\n\tif not result.run_manifest_replay.passed: result.failures.append("run_manifest_versioned_replay")\n';assert b.replace(added,'')==a
frozen=json.loads((P/'freeze.json').read_text());assert all(sha((ROOT/n).read_bytes())==h for n,h in frozen['source_sha256'].items())
errors=[s for s in (N/'audit_independent.log').read_text().splitlines() if 'ERROR:' in s or 'WARNING:' in s]
result={'reviewer':'/root/v3_ecology_admission','verdict':'ACCEPT_SCOPED_VERSIONED_RUNMANIFEST_COMPATIBILITY','original_author_receipts_and_new_independent_source_bindings':bindings,
        'new_independent_native_command_receipts':[str((N/(n+'.invocation.json')).relative_to(ROOT)) for n in own],
        'positive_cases':replay['cases'],'rejected_mutations':replay['negatives'],'old40_and_physical10_and_loader_retained':True,
        'old_test_function_prefix_exact':True,'runner_only_adds_new_test_dispatch':True,'campaign_original3705_assertions_pass':True,
        'actual_independent_snapshots':replay['actual_snapshots'],'audit_exit_diagnostics_retained':errors,
        'limits':['Author originalstartupHEADnotrecorded; actualreconstructionbase7e5+5overlaysisnotstartupauthentication.','Independent newruns actualstartupHEAD7e25383 recorded and806sourceexactGit before/after.','Currenttwo-map fixture usesrealDemoApp andRunManifest but explicitminiBossoutcome/itemDefinitionfixtures; notinput-onlytraversal/combat/rewardacquisition/diskload.','Oldexplicitmap2captures aretechnicalentrywithoutnormalmini transition, notretroactivelylegalfullcampaign RunManifest.','Mixedcontent rootv10/v11 intentionallyrejected; developerinjectedoldmap2stateintonewv11run notwhole-runarbitrarycompatibility.','20ObjectDB/17resourceexitdiagnosticsretained, nocleanlifecycle/performance/device/user/commercialacceptance.']}
(OUT/'audit_results.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print('Independent original4x806source projections + own2x806 exact7e25383 sources; native40+10+5positive+9negative and original3705 allverified; leakedresourcesretained.')
