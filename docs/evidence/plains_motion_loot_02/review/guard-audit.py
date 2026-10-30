import ast,hashlib,json,re,subprocess
from pathlib import Path
R=Path('/workspace/gunman-rush');checks=[]
def check(ok,label):
 checks.append({'label':label,'passed':bool(ok)})
 if not ok: raise AssertionError(label)
def raw(p):return (R/p).read_bytes()
def old(p):return subprocess.check_output(['git','show','2ac54f9f:'+p],cwd=R)
def methods(src):
 t=ast.parse(src);return {n.name:ast.get_source_segment(src,n) for c in t.body if isinstance(c,ast.ClassDef) for n in c.body if isinstance(n,(ast.FunctionDef,ast.AsyncFunctionDef)) and n.name.startswith('test_')}
head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=R,text=True).strip()
paths=['tests/test_production_plan.py','tests/test_region_bible.py','tests/test_region_creative_direction.py','tests/plains_cohesion_drops_runner.gd','tools/harness/profiles.json','tools/run_integration_four_tests.py']
files={p:hashlib.sha256(raw(p)).hexdigest() for p in paths}
for p in paths:check(raw(p)==subprocess.check_output(['git','show','HEAD:'+p],cwd=R),'reviewed path matches exact HEAD: '+p)
archive='docs/evidence/plains_motion_loot_02/guard-migration/planner/'
before=raw(archive+'test_production_plan.before.py.txt').decode();current=raw(paths[0]).decode();bm,cm=methods(before),methods(current)
check(len(bm)==21 and len(cm)==22 and bm.keys()<=cm.keys(),'planner retains original21 methods and adds exactly1')
unchanged=[n for n in bm if bm[n]==cm[n]]
check(len(unchanged)==20,'planner20 original methods remain byte-identical')
changed=set(bm)-set(unchanged)
check(changed=={'test_physical_lanes_require_the_exact_original_full_set'},'planner only existing exact-full-suffix method migrates')
for digest in re.findall(r'[a-f0-9]{64}',before):check(digest in current,'planner historical digest preserved '+digest)
for p,expected in [('tests/test_region_bible.py',34),('tests/test_region_creative_direction.py',12)]:
 original=old(p).decode();live=raw(p).decode();om,lm=methods(original),methods(live)
 check(len(om)==expected and len(lm)==expected+1 and om.keys()<=lm.keys(),'all original methods retained plus1: '+p)
 for digest in re.findall(r'[a-f0-9]{64}',original):check(digest in live,'frozen historical SHA literal retained: '+digest)
 frozen='docs/creative_direction/archive/creative-v23-before-plains-motion-loot/'+Path(p).name+'.txt'
 check(raw(frozen)==old(p),'immutable original test snapshot matches exact2ac: '+p)
root='docs/creative_direction/archive/creative-v23-before-plains-motion-loot/'
manifest=json.loads(raw(root+'manifest.json'))
for row in manifest['files']:
 b=raw(root+row['path']);check(len(b)==row['bytes'] and hashlib.sha256(b).hexdigest()==row['sha256'],'frozen archive exact bytes: '+row['path'])
old_manifest=json.loads(old('tools/harness/profiles.json'));live_manifest=json.loads(raw('tools/harness/profiles.json'))
check(set(live_manifest['checks'])-set(old_manifest['checks'])=={'plains-motion-loot-02'},'only one real native check appended')
for key,item in old_manifest['checks'].items():
 if key=='region-bible-tests':
  a=dict(item);b=dict(live_manifest['checks'][key]);ai=a.pop('inputs');bi=b.pop('inputs')
  check(a==b and len(ai)==368 and len(bi)==381 and bi[:368]==ai,'Bible inputs exact368 prefix and13 finite additions; all remaining fields equal')
 else:check(live_manifest['checks'][key]==item,'original check unchanged: '+key)
for name,seq in old_manifest['profiles'].items():
 check(live_manifest['profiles'][name]==seq+(['plains-motion-loot-02'] if name in ['gameplay','art','full'] else []),'original profile preserved: '+name)
check(len(live_manifest['profiles']['full'])==167,'full inventory actual167')
original=raw('docs/evidence/plains_motion_loot_02/guard-migration/plains_cohesion_drops.before.gd.txt').decode();live=raw('tests/plains_cohesion_drops_runner.gd').decode()
labels=lambda x:re.findall(r'check\([^\n]*?,\s*"([^"\n]+)"\)',x)
old_labels=labels(original);new_labels=labels(live)
check(len(old_labels)==17 and all(s in new_labels for s in old_labels),'old17 assertion labels retained')
frames=lambda s:re.findall(r'await frames\((\d+)\)',s)
check(frames(original)==frames(live),'all original bounded frame waits preserve exact order')
app=raw('tests/plains_motion_loot_02_app.gd').decode();runner=raw('tests/plains_motion_loot_02_runner.gd').decode()
check('automatic counterpart' in app and 'actual App automatic tick queues and commits' in app and 'actual app tick/queue/commit' in app.lower(),'native actual automatic-counterpart retained with early and ready queue/commit checks')
for f in ['motion','loot','audio','app']:
 check('load("res://tests/plains_motion_loot_02_'+f+'.gd").run(' in runner,'real helper called by registered native runner: '+f)
region=raw('tools/run_plains_region_tests.py').decode();check('tests/plains_cohesion_drops_runner.gd' in region,'migrated old drop runner remains in original region suites')
adapter_old=old('tools/run_integration_four_tests.py').decode();adapter=raw('tools/run_integration_four_tests.py').decode()
bo=ast.parse(adapter_old);ba=ast.parse(adapter)
functions=lambda t:{n.name:ast.dump(n,include_attributes=False) for n in t.body if isinstance(n,ast.FunctionDef)}
check(functions(bo)==functions(ba),'adapter original execution/strict exit functions unchanged')
native=json.loads(raw('build/plains-motion-loot-02-native-07.json'))
check(native['assertions']==343 and not native['failures'],'observed original native07 artifact343/0 (not newly executed)')
samples=[{'assertions':s.get('assertions'),'failures':s.get('failures'),'scope':s.get('scope')} for s in native['samples'] if isinstance(s,dict) and 'assertions' in s]
for name in ['native-07','old-drop-02']:
 log=raw('build/plains-motion-loot-02-'+name+'.log').decode()
 check(not re.search(r'^ERROR:|SCRIPT ERROR:|SHADER ERROR:|ObjectDB.*leaked|resources? still in use',log,re.M),'observed original clean strict exit log: '+name)
result={'reviewer':'/root/guard_review_recovery','source_commit':head,'files':files,'checks':checks,'assertions':len(checks),'failures':[x for x in checks if not x['passed']],'original_native_artifact_samples':samples,'independence':'New reviewer, authored none of the reviewed production, tests, profiles, adapters or provenance. Read-only except /tmp review outputs. No Godot execution.'}
Path('/tmp/plains_motion_loot_02_guard_proof.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'checks':len(checks),'failures':len(result['failures']),'source_commit':head,'native_samples':samples},ensure_ascii=False))
