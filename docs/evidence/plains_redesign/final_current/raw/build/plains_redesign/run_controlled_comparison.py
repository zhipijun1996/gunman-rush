# Captures only exact restored C2. Both Q6 art tasks remain genuinely blocked; no visual-quality promotion.
"""Prepared final same-source-policy cohort, not yet executed. Original observations never overwritten."""
from pathlib import Path
import sys,os,json,hashlib,subprocess,shutil,time
ROOT=Path('/workspace/gunman-rush');OLD=Path('/workspace/plains-redesign-baseline')
sys.path.insert(0,str(ROOT/'tools'));import level_formal
for name in ['reward-entry','scene-archive-completion']:
 d=json.loads((ROOT/f'build/verification/plains-redesign-{name}/state.json').read_text());assert d['status']=='complete',(name,d['status'])
# Failed art tasks remain blocked. Capture the exact restored C2 candidate without promoting Q6.
rollback=json.loads((ROOT/'build/plains_redesign/q6_rollback/execution.json').read_text())
assert rollback['status'] in {'restored_pending_actual_tests','revalidated'},rollback['status']
for row in rollback['rows']: assert hashlib.sha256((ROOT/row['path']).read_bytes()).hexdigest()==row['restored_sha256'],row['path']
assert json.loads((ROOT/'build/verification/plains-redesign-q6-cliff-asset/state.json').read_text())['status']=='blocked'
# Refuse concurrent engine runs: control offline input wall-clock and preserve ordinary input TTL.
processes=subprocess.check_output(['ps','-eo','pid,args'],text=True)
engines=[s for s in processes.splitlines() if 'Godot_v4.7.2-stable_linux.x86_64' in s and 'ps -eo' not in s]
assert not engines,'Finish other actual engine work first; do not kill or race it: '+repr(engines)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
paths=sorted(level_formal.driver_source_paths());shared={p:sha(ROOT/p) for p in paths}
assert all(sha(OLD/p)==v for p,v in shared.items()),'Driver differs; explicit overlay provenance required, no mismatched comparison'
overlay=json.loads((ROOT/'build/plains_redesign/final_comparison/before_overlay.json').read_text())
for name,v in overlay['unmodified_runtime_and_assets'].items():assert sha(OLD/name)==v['sha256'],name
for name in level_formal.core_source_paths():assert sha(ROOT/name)==sha(OLD/name),('Core changed',name)
folder=ROOT/'build/plains_redesign/controlled_comparison';assert not folder.exists(),'Preserve previous complete/failed attempt; use a distinct reviewed path instead';folder.mkdir(parents=True)
env=os.environ.copy();env['LP_NUM_THREADS']='1'
record={'kind':'actual sequential controlled comparison; no parallel game/test/movie run','shared_driver_sources':shared,'environment':{'LP_NUM_THREADS':env['LP_NUM_THREADS'],'cpu_max':Path('/sys/fs/cgroup/cpu.max').read_text().strip()},'commands':[],'scope':'Synthetic real Router/Motor, same10roots/two maps/four goals and source-byte policy; not human success/fun/device/performance','started_utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime())}
for side,work in [('before',OLD),('after',ROOT)]:
 rel=f'build/plains_redesign/controlled_comparison/{side}';assert not (work/rel).exists()
 command=['python3','tools/level_formal.py','--seed','level-design-v2-baseline','--seed-count','10','--maps','1','2','--strategies','fast','growth','deep','return','--encounter-policy','kill_from_bank_v1','--jobs','2','--max-ticks','18000','--output',rel]
 before=level_formal.source_files();entry={'side':side,'cwd':str(work),'argv':command,'started_utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),'loadavg_before':Path('/proc/loadavg').read_text().strip()};record['commands'].append(entry)
 with (folder/f'{side}.log').open('w') as log:r=subprocess.run(command,cwd=work,env=env,stdout=log,stderr=subprocess.STDOUT)
 entry.update(exit_code=r.returncode,loadavg_after=Path('/proc/loadavg').read_text().strip());(folder/'execution.json').write_text(json.dumps(record,indent=2)+'\n')
 assert level_formal.source_files()==before,'Root actual code/source drift during pair'
 if work==OLD and (OLD/rel).exists():shutil.copytree(OLD/rel,ROOT/rel)
 if r.returncode:raise SystemExit(r.returncode)
for side in ['before','after']:
 command=['python3','tools/level_experience.py','analyze','--batch',str(folder/side/'batch.json'),'--output',str(folder/f'{side}_experience.json')]
 with (folder/f'{side}_analysis.log').open('w') as log:r=subprocess.run(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
 record['commands'].append({'cwd':str(ROOT),'argv':command,'exit_code':r.returncode});(folder/'execution.json').write_text(json.dumps(record,indent=2)+'\n')
 if r.returncode:raise SystemExit(r.returncode)
command=['python3','tools/level_experience.py','compare','--before',str(folder/'before_experience.json'),'--after',str(folder/'after_experience.json'),'--output',str(folder/'comparison.json')]
with (folder/'compare.log').open('w') as log:r=subprocess.run(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
record['commands'].append({'cwd':str(ROOT),'argv':command,'exit_code':r.returncode});record['finished_utc']=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime());(folder/'execution.json').write_text(json.dumps(record,indent=2)+'\n');(folder/'exit_code.txt').write_text(str(r.returncode));raise SystemExit(r.returncode)
