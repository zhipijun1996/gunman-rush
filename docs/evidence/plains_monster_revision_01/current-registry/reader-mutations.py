from pathlib import Path
import sys,json,copy,hashlib,subprocess
R=Path('/workspace/gunman-rush');sys.path.insert(0,str(R/'tools'))
import run_forest_current_registry_tests as w
p=R/'build/forest_current_registry/native/dev-04/capture.json';actual=json.loads(p.read_text());original=hashlib.sha256(p.read_bytes()).hexdigest();rows=[]
w.validate(actual);rows.append({'case':'actual_dev04_report_with_final_reader','passed':True})
def rejection(name,fn):
 d=copy.deepcopy(actual);fn(d)
 try:w.validate(d)
 except (ValueError,KeyError,TypeError):rows.append({'case':name,'passed':True,'rejected':True})
 else:rows.append({'case':name,'passed':False,'rejected':False})
negatives={
 'zero_assertions':lambda d:d.update(assertions=0),
 'missing_ledger':lambda d:d.update(checks=[]),
 'false_ledger':lambda d:d['checks'][0].update(passed=False),
 'true_integer_ledger':lambda d:d['checks'][0].update(passed=1),
 'missing_case':lambda d:d['cases'].pop(),
 'extra_case':lambda d:d['cases'].append(copy.deepcopy(d['cases'][0])),
 'row_map_bool':lambda d:d['cases'][0].update(map=True),
 'manifest_map_bool':lambda d:d['cases'][0]['manifest'].update(map_index=True),
 'schema_bool':lambda d:d.update(schema_version=True),
 'failures_false':lambda d:d.update(failures=False),
 'failures_nonzero':lambda d:d.update(failures=1),
 'assertions_float':lambda d:d.update(assertions=88.0),
 'wrong_scope':lambda d:d.update(scope='original327'),
 'missing_seed':lambda d:d['cases'][0].update(seed='wrong'),
 'duplicate_data_identity':lambda d:d['cases'].__setitem__(1,copy.deepcopy(d['cases'][0])),
 'wrong_layout':lambda d:d['cases'][0].update(layout='forest-fruit-routes-v14'),
 'wrong_version':lambda d:d['cases'][0].update(version='thorn-forest-region-v1'),
 'strict_validation_false':lambda d:d['cases'][0].update(strict_validation=False),
 'complete_output_false':lambda d:d['cases'][0].update(complete_output_equal=False),
 'unsupported_rehash_accepted':lambda d:d['cases'][0].update(unsupported_rehashed_rejected=False),
 'missing_manifest':lambda d:d['cases'][0].update(manifest={}),
}
for name,fn in negatives.items():rejection(name,fn)
ri=next(i for i,r in enumerate(actual['cases']) if r['id']=='registry_refusals');ai=next(i for i,r in enumerate(actual['cases']) if r['id']=='current_app')
rejection('missing_refusal',lambda d:d['cases'][ri]['negative_cases'].pop())
rejection('duplicate_refusal',lambda d:d['cases'][ri]['negative_cases'].__setitem__(1,copy.deepcopy(d['cases'][ri]['negative_cases'][0])))
rejection('refusal_false',lambda d:d['cases'][ri]['negative_cases'][0].update(refused=False))
rejection('refusal_kind_reordered',lambda d:d['cases'][ri]['negative_cases'].reverse())
rejection('app_map_bool',lambda d:d['cases'][ai].update(map=True))
rejection('duplicate_app_map',lambda d:d['cases'][-1].update(map=1))
for field in ['home_unknown_unchanged','home_empty_unchanged','active_unchanged','unknown_snapshot_refused','malformed_snapshot_refused','reload_same_manifest','reload_same_state','reload_ledgers_health','complete_output_equal']:
 rejection('app_'+field+'_false',lambda d,k=field:d['cases'][ai].update({k:False}))
for field in ['saved_health','restored_health']:
 for name,value in [('nan',float('nan')),('infinity',float('inf')),('bool',True),('zero',0),('string','2')]:
  rejection(field+'_'+name,lambda d,k=field,v=value:d['cases'][ai].update({k:v}))
rejection('equal_bool_health_masquerades_one',lambda d:d['cases'][ai].update(saved_health=1,restored_health=True))
assert hashlib.sha256(p.read_bytes()).hexdigest()==original
m=json.loads((R/'tools/harness/profiles.json').read_text());before=json.loads(subprocess.check_output(['git','show','b479775383c46527096ebc6e4e284924f66ccf48:tools/harness/profiles.json'],cwd=R));assert m['checks']['forest-depth-versions']==before['checks']['forest-depth-versions'];assert set(m['checks'])==set(before['checks'])|{'forest-current-registry'}
for name,profile in before['profiles'].items():
 expected=[('forest-current-registry' if x=='forest-depth-versions' else x) for x in profile] if name in ['gameplay','full'] else profile+['forest-depth-versions'] if name=='legacy-compat' else profile
 assert m['profiles'][name]==expected,name
for name in before['checks']:assert m['checks'][name]==before['checks'][name],name
assert len(m['profiles']['full'])==166 and len(m['profiles']['gameplay'])==151
assert len(set(m['profiles']['docs']+m['profiles']['gameplay']+m['profiles']['art']))==163
oldfiles=['tools/run_forest_depth_versions.py','tests/forest_depth_version_runner.gd','tests/forest_depth_version_world_runner.gd','tests/forest_depth_version_app_case.gd','tools/test_forest_depth_versions.py']+[str(p.relative_to(R)) for p in (R/'tests/fixtures/forest_recorded_layouts').glob('*.json')]
for name in oldfiles:assert (R/name).read_bytes()==subprocess.check_output(['git','show','b479775383c46527096ebc6e4e284924f66ccf48:'+name],cwd=R),name
result={'scope':'Read-only final-reader/actual-report mutation and profile/source-preservation review; no Godot by reviewer','checks':len(rows),'failures':sum(not x['passed'] for x in rows),'results':rows,'actual_report_sha256':original,'actual_native_receipt':json.loads((p.parent/'receipt.json').read_text()),'old_sources_unchanged_count':len(oldfiles),'full_count':166,'gameplay_count':151,'selected_union_count':163,'source_sha256':{n:hashlib.sha256((R/n).read_bytes()).hexdigest() for n in ['tests/forest_current_registry_runner.gd','tests/forest_current_registry_runner.gd.uid','tools/run_forest_current_registry_tests.py','tools/harness/profiles.json']}}
# Keep the compact facts; original receipt already remains at native source path.
result['actual_native_receipt']={k:result['actual_native_receipt'].get(k) for k in ['base_commit','passed','source_stable','seconds','assertions']}
Path('/tmp/plains_revision_current_registry_regression.json').write_text(json.dumps(result,indent=2)+'\n');print({k:v for k,v in result.items() if k not in ['results','source_sha256']});raise SystemExit(1 if result['failures'] else 0)
