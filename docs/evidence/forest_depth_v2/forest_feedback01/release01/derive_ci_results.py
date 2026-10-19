import json,re,subprocess,hashlib
from pathlib import Path
from datetime import datetime
r=Path('/workspace/gunman-rush-design');b=r/'build/forest_feedback/release5a9f';source='5a9f4bdaf846a635eb2659080d563b865758ab87';run=json.loads((b/'terminal-run-api.json').read_text());jobs=json.loads((b/'terminal-jobs-api.json').read_text());log=(b/'terminal-run.log').read_text();profiles=json.loads(subprocess.check_output(['git','show',source+':tools/harness/profiles.json'],cwd=r,text=True));expected=list(dict.fromkeys(profiles['profiles']['gameplay']+profiles['profiles']['art']));lanes={}
for lane in ['parallel','serial']:
 lines=[x for x in log.splitlines()if x.startswith(f'core_checks ({lane})\tRun python3 tools/harness.py --profile gameplay --profile art')]
 starts=[];passes=[];times={}
 for line in lines:
  m=re.search(r'\t([^\t ]+) Running ([\w-]+) \(fresh\);',line)
  if m:starts.append(m[2]);times.setdefault(m[2],{})['start']=m[1]
  m=re.search(r'\t([^\t ]+) ([\w-]+): passed$',line)
  if m:passes.append(m[2]);times.setdefault(m[2],{})['pass']=m[1]
 want=[n for n in expected if bool(profiles['checks'][n].get('serial'))==(lane=='serial')]
 assert starts==passes==want,(lane,len(starts),len(passes),len(want))
 lanes[lane]={'count':len(want),'fresh_start_ids':starts,'passed_ids':passes,'stdout_times':times}
assert run['id']==39160856629 and run['head_sha']==source and run['run_attempt']==1 and run['conclusion']=='success'
for name in ['prepare','web','windows','core_checks (parallel)','core_checks (serial)','core','deploy_web','verify_public']:assert any(j['name']==name and j['conclusion']=='success'for j in jobs['jobs'])
assert 'HARNESS LANES: verified complete fresh selected-profile coverage (technical only)'in log
case=profiles['checks']['forest-depth-region'];assert case['timeout_seconds']==600 and '--corpus'in case['argv'];t=lanes['parallel']['stdout_times']['forest-depth-region'];span=(datetime.fromisoformat(t['pass'])-datetime.fromisoformat(t['start'])).total_seconds()
result={'scope':'Derived from original official API and full CI stdout; not downloaded merged/raw artifact or independent rerun. Technical coverage only, not fun','source_commit':source,'run_id':run['id'],'attempt':1,'ci_conclusion':'success','selected_profiles':['gameplay','art'],'expected_unique_checks':len(expected),'lanes':lanes,'same_source_merge_observed':True,'region_original_timeout_seconds':600,'region_stdout_start_to_pass_seconds':span,'region_span_is_not_inner_native_duration':True,'original_local_600_timeout_retained':True,'actual_public_build':'5fd40a31c4be','original_api_and_log_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest()for p in [b/'terminal-run-api.json',b/'terminal-jobs-api.json',b/'terminal-run.log']},'artifact_zip_not_downloaded_due_to_proxy403':True,'publisher_live_verified':False,'commercial_fun_device_acceptance':False}
(b/'ci-results.json').write_text(json.dumps(result,indent=2));print({'checks':len(expected),'lanes':[len(lanes[x]['passed_ids'])for x in lanes],'region_stdout_seconds':span})
