from pathlib import Path
import json,subprocess,hashlib,itertools
R=Path.cwd();b=R/'build/forest_revision04/ci-H3-57b3d468';out=R/'build/forest_revision04/main-M-review';M='9757ddf2ee20b5620c4a34ecc5d51186f018513b';H='57b3d468df26d378d0321fb2ff7b8b9be2533bcd';S='61df05218d1a4c928cafd2ed6b91b53ff88c1659';D='dbc6ba081321637a3eef71979ecf2cf564eb6064';sha=lambda b:hashlib.sha256(b).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],text=True).strip()
assert git('rev-parse',M+'^1')==D and git('rev-parse',M+'^2')==H
assert git('rev-parse',M+'^{tree}')==git('rev-parse',H+'^{tree}')=='862ff38626b8e1f258ca71983857e22e87cc20e9'
assert git('rev-parse','HEAD')==M and git('branch','--show-current')=='main' and git('status','--porcelain')==''
api=json.loads((b/'terminal-API-originals.json').read_text());assert api['requested_exact_head']==H
workflow=[];jobs=[]
for run in api['workflow_runs']['workflow_runs']:
 assert run['head_sha']==H and run['status']=='completed' and run['conclusion']=='success'
 workflow.append({k:run[k] for k in ['id','name','event','head_sha','status','conclusion']})
 for j in api['jobs'][str(run['id'])]['jobs']:
  assert j['status']=='completed' and j['conclusion'] in ['success','skipped']
  assert j['conclusion']!='skipped' or j['name'] in ['deploy_web','android','verify_public']
  jobs.append({k:j[k] for k in ['id','name','status','conclusion']})
assert len(workflow)==4
prov=json.loads((b/'PR-push-Git-tree-provenance.json').read_text());assert prov['actual_PR_checkout']==S and prov['requested_head']==H
assert all(c['response']['tree']['sha']==git('rev-parse',H+'^{tree}') for c in prov['commits'])
m=json.loads(subprocess.check_output(['git','show',H+':tools/harness/profiles.json']));msha=sha(subprocess.check_output(['git','show',H+':tools/harness/profiles.json']))
checks=[];proofs={};matrix=[]
for event,commit in [('PR',S),('push',H)]:
 ids=[]
 for lane,num in [('serial',39),('parallel',81),('web',41)]:
  base=b/('artifact-'+event+'-'+lane)
  p=next(base.glob('*/report.json')) if lane=='web' else next(base.glob('verification/harness/*/report.json'))
  d=json.loads(p.read_text());assert d['commit']==commit and d['status']=='passed' and len(d['checks'])==num and d['release'] is True and d['git_status']=='' and d['manifest_sha256']==msha
  if lane!='web':assert d['source_files']==d['source_files_after'] and d['toolchain']==d['toolchain_after']
  tokens=[]
  for c in d['checks']:
   spec=m['checks'][c['id']];assert c['argv']==spec['argv'] and c['timeout_seconds']==spec['timeout_seconds']
   assert c['status']=='passed' and c['exit_code']==0 and c['reused'] is False and c['duration_seconds']<c['timeout_seconds'];tokens.append(c['check_token'])
  assert len(tokens)==len(set(tokens))
  if lane!='web':ids.extend(c['id'] for c in d['checks'])
  else:assert [c['id'] for c in d['checks']]==m['profiles']['web']
  checks.append({'event':event,'lane':lane,'execution_commit':commit,'count':num,'status':'passed','fresh_release':True,'wall_seconds':d['wall_seconds'],'report_sha256':sha(p.read_bytes()),'report_path':str(p.relative_to(R))})
  if lane=='parallel':
   c=next(c for c in d['checks'] if c['id']=='forest-depth-region');receipt=next(p for p in base.rglob('receipt.json') if '/forest_depth/region/'in str(p));r=json.loads(receipt.read_text())
   assert r['source_head']==commit and r['status']=='passed' and r['source_stable'] is True and r['import_source_guard']['passed'] is True and not r['import_source_guard']['original_source_changed_or_deleted'] and not r['import_source_guard']['unexpected_new_source'] and r['source_before']==r['source_after']
   assert r['completed_case_indices']==list(range(80)) and r['not_executed_case_indices']==[] and len(r['runs'])==80 and r['case_workers']==2
   expected={(f'forest-depth-hollow-{i:02}',j,k) for i in range(10) for j in [1,2] for k in ['fast','growth','high_return','change_mind']}
   assert {(x['seed'],x['map'],x['route']) for x in r['requested_cases']}==expected
   assert {(x['seed'],x['map'],x['route']) for x in r['runs']}==expected
   assert all(x['status']=='passed' and x['exit_code']==0 and x['errors']==[] and x['log_sha256'] and x['capture_sha256'] and x['seconds']<240 for x in r['runs'])
   assert c['timeout_seconds']==600
   matrix.append({'event':event,'execution_commit':commit,'count':80,'terminal_passes':80,'not_executed':0,'workers':2,'original_harness_cap':600,'actual_check_seconds':c['duration_seconds'],'source_stable':True,'receipt_sha256':sha(receipt.read_bytes()),'audit_scope':'Receipt identities/status/80 exact requests/per-case exit and declared raw SHA fields only; no bulk capture SHA/frame re-audit in this light review.'})
 assert len(ids)==len(set(ids))==120 and set(ids)==set(m['profiles']['gameplay'])|set(m['profiles']['art'])
 log=(b/('core-118568189414.log' if event=='PR' else 'push-core-118568541464.log')).read_bytes();assert b'HARNESS LANES: verified complete fresh selected-profile coverage (technical only)'in log
 proofs[event]={'fresh_disjoint_serial_parallel_union':120,'exact_selected_profile_set':True,'actual_coverage_gate_log_sha256':sha(log)}
result={'decision':'SCOPED_ACCEPT','scope':'Normal actual main merge source closure and H3 remote CI original metadata/log light audit','actual_main_commit':M,'merge_parents':[D,H],'entire_tree_equal_H3':True,'Git_tree':'862ff38626b8e1f258ca71983857e22e87cc20e9','local_main_clean_at_review':True,'H3_workflows':workflow,'jobs':jobs,'CI_execution_tree_mapping':{'PR_source':S,'push_source':H,'same_tree_as_actual_main':True,'not_relabelled_as_main_execution':True},'fresh_reports':checks,'coverage':proofs,'current_v2_matrix':matrix,'strict_provenance_limit':'Used original fetched API metadata, extracted small report/receipts and coverage logs. Did not open ZIPs or bulk rehash/revalidate case captures. Native guard pass is the original consumer result, not new reviewer execution.','preserved_local_failure':'T local80/600 timeout remains78 terminal pass plus2 active killed; distinct successful H3 remote hosts do not rewrite it. No performance cause established.','pending_not_signed':['Actual main M fresh CI run39405664436','M fresh movies/actual pixel review','Public deployed M bytes and GUI','Physical devices/audio listening/user and whole-region aesthetic acceptance'],'reviewer_actions':'Light Git/JSON/log reads and ignored report only; no native/browser/network/tracked writes.'}
(out/'M_merge_and_H3_CI_light_review.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');(out/'M_merge_and_H3_CI_light_review.md').write_text(f'''SCOPED_ACCEPT — actual main merge and H3 CI light audit

ActualM `{M}` is an ordinary two-parent merge of originalmainD andH3. Its complete Git tree equalsH3 `862ff38626b8e1f258ca71983857e22e87cc20e9`; localmain is clean. PR executionS `{S}` and pushH3 retain their own identities, with the same tree.

Original API records show all4 H3 workflows successful. Both events have fresh39serial+81parallel disjoint consumers covering the exact120 selected-profile set, original caps and successful coverage gates; Web41 is fresh and passed. Docs andWindows jobs succeed; deployment/Android/public verification are explicitly skipped. Extracted current-v2 receipts each request exact80 cases, complete80/0 with2workers and stable source under original600 cap (PR{matrix[0]['actual_check_seconds']}s;push{matrix[1]['actual_check_seconds']}s).

This light audit checks metadata, small reports/receipts and original coverage logs; it does not bulk-rehash/revalidate all raw captures or open large ZIPs. OriginalT600timeout remains its own failed local run. ActualM newCI, M films/pixels, public package and devices remain unsigned.
''');print(json.dumps({'M':M,'four_H3_workflows':'success','fresh_per_event':'39+81=120;web41','80':matrix,'report':str(out/'M_merge_and_H3_CI_light_review.json')},ensure_ascii=False))
