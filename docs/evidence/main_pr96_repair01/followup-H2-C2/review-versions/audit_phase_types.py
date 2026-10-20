from pathlib import Path
import sys,importlib.util,json,copy
sys.path.insert(0,'tools');import run_forest_depth_versions as v
spec=importlib.util.spec_from_file_location('phase_tests','tools/test_forest_depth_versions.py');t=importlib.util.module_from_spec(spec);spec.loader.exec_module(t);t.NATIVE_DIR=Path('build/forest_depth/versions/split-C2-positive-r2').resolve()
controls=[]
mutations={
 'receipt_nested_PID_float':lambda c:c.receipts['world']['native_identity'].update(engine_pid=float(c.receipts['world']['engine_pid'])),
 'receipt_top_PID_float':lambda c:c.receipts['world'].update(engine_pid=float(c.receipts['world']['engine_pid'])),
 'sequence_float':lambda c:c.receipts['world'].update(sequence=1.0),
 'sequence_bool':lambda c:c.receipts['data'].update(sequence=False),
 'exit_code_bool':lambda c:c.receipts['world'].update(exit_code=False),
}
for key in ['shared_elapsed_start','shared_elapsed_end','timeout_seconds','duration_seconds']:
 for name,value in [('bool',True),('nan',float('nan')),('inf',float('inf')),('string','0'),('null',None)]:mutations[key+'_'+name]=lambda c,k=key,x=value:c.receipts['world'].update({k:x})
def report_edit(c,fn):fn(c.reports['world']);c.resign_report('world')
mutations['report_PID_float']=lambda c:report_edit(c,lambda r:r['identity'].update(engine_pid=float(r['identity']['engine_pid'])))
mutations['case_map_float']=lambda c:report_edit(c,lambda r:r['cases'][0].update(map=1.0))
mutations['check_passed_int']=lambda c:report_edit(c,lambda r:r['checks'][0].update(passed=1))
mutations['assertion_count_float']=lambda c:report_edit(c,lambda r:r.update(assertions=47.0))
mutations['engine_major_float']=lambda c:report_edit(c,lambda r:r['engine'].update(major=float(r['engine']['major'])))
def no_engines(c):
 for phase in v.PHASES:c.reports[phase]['engine']=None;c.resign_report(phase)
mutations['both_engine_metadata_null']=no_engines
for name,fn in mutations.items():
 c=t.NativeAggregationTests('test_exact_original327_and24');c.setUp()
 try:
  fn(c)
  try:c.call()
  except (ValueError,RuntimeError,KeyError,TypeError) as e:controls.append({'name':name,'accepted':False,'reason':str(e)})
  else:controls.append({'name':name,'accepted':True})
 finally:c.doCleanups()
O=Path('build/forest_revision04/forest-versions-review');(O/'phase_types_pre_native_audit.json').write_text(json.dumps(controls,indent=2)+'\n');print('accepted', [x['name'] for x in controls if x['accepted']],'tested',len(controls))
