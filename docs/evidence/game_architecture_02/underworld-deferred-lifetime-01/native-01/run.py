from pathlib import Path
import subprocess,json,time,hashlib,re,signal,os
root=Path('/workspace/gunman-rush-refactor');out=Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
files=['tests/plains_cohesion_lifecycle_runner.gd','tests/plains_campaign_fixture.gd','tests/plains_campaign_map_runner.gd','tests/plains_exploration_expansion_runner.gd','tests/plains_region_boss_runner.gd','game/presentation/world/underworld_plains/underworld_presentation.gd','tests/underworld_plains/test_underworld_formal.gd','tests/quality_review_runner.gd']
freeze={n:sha(root/n) for n in files}
manifest=json.loads((root/'tools/harness/profiles.json').read_text())
ids=['underworld-formal','quality-review-engine']
report={'source_head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),'source_is_wip':True,'frozen_files':freeze,'scope':'Two original wrappers for independent deferred lifecycle defect and current Boss contact fixture; original commands, full contents and budgets','runs':[],'status':'running'}
start=time.monotonic()
def save():
 report['elapsed_seconds']=round(time.monotonic()-start,3);(out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
save()
for name in ids:
 c=manifest['checks'][name];row={'id':name,'command':c['argv'],'timeout_seconds':c['timeout_seconds'],'success_pattern':c['success_pattern'],'status':'running'};report['runs'].append(row);save();t=time.monotonic();log=out/(name+'.log')
 with log.open('wb') as f:
  p=subprocess.Popen(c['argv'],cwd=root,stdout=f,stderr=subprocess.STDOUT,start_new_session=True)
  try:code=p.wait(timeout=c['timeout_seconds'])
  except subprocess.TimeoutExpired:os.killpg(p.pid,signal.SIGKILL);p.wait();code=124
 raw=log.read_text(errors='replace');error=re.search(r'SCRIPT ERROR:|Parse Error:|SHADER ERROR:|^ERROR:|ObjectDB.*leaked|resources? still in use at exit',raw,re.M)
 row.update(exit_code=code,seconds=round(time.monotonic()-t,3),log_sha256=sha(log),completion_found=bool(re.search(c['success_pattern'],raw,re.M)),strict_errors=bool(error))
 row['status']='passed' if code==0 and row['completion_found'] and not error else 'failed';save();print(json.dumps(row),flush=True)
 if row['status']!='passed':report['status']='failed';save();raise SystemExit(1)
report['source_unchanged']=freeze=={n:sha(root/n) for n in files};report['status']='passed' if report['source_unchanged'] else 'failed';save()
