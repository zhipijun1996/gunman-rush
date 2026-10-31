from pathlib import Path
import importlib.util,copy,json,hashlib,subprocess
R=Path('/workspace/gunman-rush')
spec=importlib.util.spec_from_file_location('planner_test',R/'tests/test_production_plan.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
C=m.ProductionPlanTests;C.setUpClass();method='test_physical_lanes_require_the_exact_original_full_set';rows=[]
def run(name,mutate=None,plan_mutate=None):
 t=C(method);t.manifest=copy.deepcopy(C.manifest);t.policy=copy.deepcopy(C.policy)
 if mutate:mutate(t.manifest)
 if plan_mutate:
  original=t.plan
  def plan(paths,stage='development',policy=None):
   p=original(paths,stage,policy)
   if paths==['scripts/demo/demo_app.gd'] and stage=='integration':plan_mutate(p)
   return p
  t.plan=plan
 try:
  getattr(t,method)();rejected=False;detail='accepted'
 except (AssertionError,ValueError,KeyError,IndexError) as e:rejected=True;detail=str(e)[:200]
 expected=name!='actual';rows.append(dict(case=name,rejected=rejected,expected_rejected=expected,passed=rejected==expected,observation=detail))
def swap(seq,i,j):seq[i],seq[j]=seq[j],seq[i]
run('actual')
run('restore-old-default',lambda d:d['profiles']['full'].__setitem__(74,'forest-depth-versions'))
run('duplicate-current',lambda d:d['profiles']['full'].__setitem__(73,'forest-current-registry'))
run('append-current',lambda d:d['profiles']['full'].append('forest-current-registry'))
run('move-current',lambda d:swap(d['profiles']['full'],73,74))
run('drop-other-original',lambda d:d['profiles']['full'].pop(30))
run('reorder-other-original',lambda d:swap(d['profiles']['full'],30,31))
run('replace-other-with-duplicate',lambda d:d['profiles']['full'].__setitem__(30,d['profiles']['full'][31]))
run('remove-frozen-legacy',lambda d:d['profiles']['legacy-compat'].remove('forest-depth-versions'))
run('put-current-in-legacy',lambda d:d['profiles']['legacy-compat'].append('forest-current-registry'))
run('change-current-budget',lambda d:d['checks']['forest-current-registry'].__setitem__('timeout_seconds',211))
run('move-current-to-serial',lambda d:d['checks']['forest-current-registry'].__setitem__('serial',True))
run('reorder-additions',lambda d:swap(d['profiles']['full'],144,145))
run('drop-structure-native',lambda d:d['profiles']['full'].pop())
run('plan-current-slot-shift',plan_mutate=lambda p:swap(p['checks'],84,85))
run('plan-other-original-order',plan_mutate=lambda p:swap(p['checks'],30,31))
run('plan-additions-order',plan_mutate=lambda p:swap(p['checks'],144,145))
run('plan-lane-overlap',plan_mutate=lambda p:p['ci_lane_checks']['serial'].append(p['ci_lane_checks']['parallel'][0]))
run('plan-lane-omission',plan_mutate=lambda p:p['ci_lane_checks']['parallel'].remove('forest-current-registry'))
result=dict(source_commit=subprocess.check_output(['git','rev-parse','a72a313a'],cwd=R,text=True).strip(),test_sha256=hashlib.sha256((R/'tests/test_production_plan.py').read_bytes()).hexdigest(),manifest_sha256=hashlib.sha256((R/'tools/harness/profiles.json').read_bytes()).hexdigest(),checks=len(rows),failures=sum(not r['passed'] for r in rows),tamper_rejections=sum(r['rejected'] for r in rows),rows=rows)
Path('/tmp/plains_planner_scope_mutations.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items() if k!='rows'},indent=2))
if result['failures']:print(json.dumps([r for r in rows if not r['passed']],indent=2));raise SystemExit(1)
