# Captures only exact restored C2. Both Q6 art tasks remain genuinely blocked; no visual-quality promotion.
"""Final serial actual movies. No production/source edits except explicit old producer overlay."""
from pathlib import Path
import hashlib,json,os,shutil,subprocess,sys,time
ROOT=Path('/workspace/gunman-rush'); OLD=Path('/workspace/plains-redesign-baseline')
sys.path.insert(0,str(ROOT/'tools')); import level_formal
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for stage in ['reward-entry','scene-archive-completion']:
    state=json.loads((ROOT/f'build/verification/plains-redesign-{stage}/state.json').read_text())
    assert state['status']=='complete',(stage,state['status'])
# Failed art tasks remain blocked. Capture the exact restored C2 candidate without promoting Q6.
rollback=json.loads((ROOT/'build/plains_redesign/q6_rollback/execution.json').read_text())
assert rollback['status'] in {'restored_pending_actual_tests','revalidated'},rollback['status']
for row in rollback['rows']: assert hashlib.sha256((ROOT/row['path']).read_bytes()).hexdigest()==row['restored_sha256'],row['path']
assert json.loads((ROOT/'build/verification/plains-redesign-q6-cliff-asset/state.json').read_text())['status']=='blocked'
engines=[s for s in subprocess.check_output(['ps','-eo','pid,args'],text=True).splitlines() if 'Godot_v4.7.2-stable_linux.x86_64' in s and 'ps -eo' not in s]
assert not engines,engines
folder=ROOT/'build/plains_redesign/matched_movies'; assert not folder.exists(); folder.mkdir(parents=True)
overlay=json.loads((ROOT/'build/plains_redesign/final_comparison/before_overlay.json').read_text())
for name,v in overlay['unmodified_runtime_and_assets'].items(): assert sha(OLD/name)==v['sha256'],name
for name in level_formal.driver_source_paths()|level_formal.core_source_paths(): assert sha(OLD/name)==sha(ROOT/name),name
producer='tools/level_visual_capture.py'
record={'kind':'actual serial matched normal-speed software-GPU movies, not human/device acceptance','source_commit_after':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'producer_overlay':{'path':producer,'old_before':sha(OLD/producer),'after':sha(ROOT/producer),'scope':'Python recording producer only, not driver19 or old runtime/art'},'environment':{'LP_NUM_THREADS':'1','LIBGL_ALWAYS_SOFTWARE':'1'},'capture_wall_budget_seconds':900,'capture_api':'existing level_visual_capture.capture; same bounded900s both sides; no CLI timeout flag invented','budget_basis':'actual current820ticks/66.372wallsec and historical old creek7576ticks predict~613sec offline; original600s likely insufficient; no physics/threshold change','commands':[]}
shutil.copy2(ROOT/producer,OLD/producer); assert sha(OLD/producer)==record['producer_overlay']['after']
(folder/'execution.json').write_text(json.dumps(record,indent=2)+'\n')
cases=[('intro_fast','level-design-v2-baseline',1,'fast'),('creek_growth','level-design-v2-baseline',2,'growth'),('advanced_deep','level-design-v2-baseline/02',2,'deep'),('high_return','level-design-v2-baseline',1,'return')]
env=os.environ.copy();env.update(record['environment'])
frozen=level_formal.source_files()
for name,seed,map_index,strategy in cases:
    for side,work in [('before',OLD),('after',ROOT)]:
        rel=f'build/plains_redesign/matched_movies/{side}/{name}'; assert not (work/rel).exists()
        # The existing capture API exposes a finite wall-clock budget; CLI has no timeout flag.
        # Observed 820ticks/66s and old growth7576ticks predict >600s offline.
        # Same900s on both sides, unchanged simulation/driver/acceptance thresholds.
        code="import sys;sys.path.insert(0,'tools');from level_visual_capture import capture;capture(sys.argv[1],int(sys.argv[2]),sys.argv[3],sys.argv[4],max_ticks=18000,timeout=900,encounter_policy='kill_from_bank_v1')"
        command=['python3','-c',code,seed,str(map_index),strategy,rel]
        entry={'case':name,'side':side,'cwd':str(work),'argv':command,'started_utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),'loadavg_before':Path('/proc/loadavg').read_text().strip()};record['commands'].append(entry)
        (folder/'execution.json').write_text(json.dumps(record,indent=2)+'\n')
        log=folder/f'{side}_{name}.log'
        with log.open('w') as stream: result=subprocess.run(command,cwd=work,env=env,stdout=stream,stderr=subprocess.STDOUT)
        entry.update(exit_code=result.returncode,finished_utc=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),loadavg_after=Path('/proc/loadavg').read_text().strip())
        assert level_formal.source_files()==frozen,'Source drift'
        if side=='before' and (OLD/rel).exists(): shutil.copytree(OLD/rel,ROOT/rel)
        report=ROOT/rel/'rendered_report.json'
        if report.exists():
            data=json.loads(report.read_text());entry['rendered_report_sha256']=sha(report);entry['status']=data.get('status');entry['outcome']=data.get('outcome');entry['ticks']=data.get('tick_count');entry['route_reached']=data.get('route_reached')
            entry['producer']=data.get('producer');entry['render_environment']=data.get('render_environment')
        (folder/'execution.json').write_text(json.dumps(record,indent=2)+'\n')
        # A route failure is valid evidence. Process/capture-integrity failure stops;
        # preserve it and diagnose before creating a distinct follow-up attempt.
        if result.returncode: raise SystemExit(result.returncode)
import level_experience
record['actual_initial_capability_pairs']=[]
for name,seed,map_index,strategy in cases:
    pair={side:json.loads((folder/side/name/'capture.json').read_text()) for side in ['before','after']}
    bases={side:level_experience.capability_basis(data) for side,data in pair.items()}
    assert bases['before']==bases['after'],('Actual recorded initial capabilities differ',name)
    record['actual_initial_capability_pairs'].append({'case':name,'same_recorded_initial_basis':True,'basis':bases['before'],'outcomes':{side:pair[side]['outcome'] for side in pair},'final_capability':{side:pair[side].get('final_capability') for side in pair},'scope':'Same actual initial basis, not a promise equal earned rewards/final builds; preserve each recorded final state'})
record['finished_utc']=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime());record['status']='captured';(folder/'execution.json').write_text(json.dumps(record,indent=2)+'\n')
