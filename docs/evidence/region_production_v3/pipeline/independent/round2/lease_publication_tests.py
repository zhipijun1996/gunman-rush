"""Independent simulated host acceptance boundaries, no actual host execution."""
import sys,json
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0,str(Path.cwd()/'tools'))
import production_loop as p
OUT=Path('build/region_production_v3/independent/round2')
M={'schema_version':1,'objective':'SIMULATED final publication boundary','max_calls':4,'max_rounds':2,'call_timeout_seconds':60,'tasks':[{'id':'DRILL','goal':'SIMULATED','skills':['gameplay-reviewer'],'checks':['docs'],'read_only':True}]}
records=[]
for mode in ['parse-revoke','parse-expire-wall','validation-revoke','published-result-revoke','published-result-expire-mono','published-result-expire-wall']:
 root=OUT/mode;root.mkdir()
 mono=[100.0];wall=[1000.0]
 original_save=p.save;original_read=p.quality.read_json;original_validate=p.validate_result
 def change_boundary():
  if mode.endswith('revoke'):original_save(root/'lease_revoked.json',{'reason':'SIMULATED boundary revocation'})
  elif mode.endswith('mono'):mono[0]=161.0
  else:wall[0]=1061.0
 def reply(delay):
  r=original_read(root/'host_request.json')
  original_save(root/'host_response.json',{'schema_version':1,**{k:r[k] for k in ['request_hash','task_id','attempt','role']},'agent_id':'/SIMULATED/independent','result':{'status':'accept','summary':'SIMULATED host','findings':[]}})
 def read(path):
  data=original_read(path)
  if Path(path)==root/'host_response.json' and mode.startswith('parse-'):change_boundary()
  return data
 def validate(result,role):
  data=original_validate(result,role)
  if mode=='validation-revoke':change_boundary()
  return data
 def save(path,data):
  original_save(path,data)
  if Path(path)==root/'result.json' and mode.startswith('published-result-'):change_boundary()
 try:
  with patch.object(p,'snapshot',return_value={}),patch.object(p.time,'monotonic',side_effect=lambda:mono[0]),patch.object(p.time,'time',side_effect=lambda:wall[0]),patch.object(p.time,'sleep',side_effect=reply),patch.object(p.quality,'read_json',side_effect=read),patch.object(p,'validate_result',side_effect=validate),patch.object(p,'save',side_effect=save):
   result=p.invoke_host(M['tasks'][0],M,'review',root,'{}')
  record={'case':mode,'rejected':False,'status':result['status']}
 except RuntimeError as e:
  meta=original_read(root/'invocation.json')
  record={'case':mode,'rejected':True,'error':str(e),'accepted_result_exists':(root/'result.json').exists(),'rejected_result_retained':(root/'rejected_result.json').exists(),'exit_code':meta['exit_code'],'lease_status':meta['lease_status']}
  assert not record['accepted_result_exists'] and record['exit_code'] is None
  if mode.startswith('published-result-'):assert record['rejected_result_retained']
 assert record['rejected']
 records.append(record)
(OUT/'lease_publication_results.json').write_text(json.dumps({'scope':'SIMULATED acceptance-consumer only','cases':records},indent=2)+'\n')
print(json.dumps(records,indent=2))
