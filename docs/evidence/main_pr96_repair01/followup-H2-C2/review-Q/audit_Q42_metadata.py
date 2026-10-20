from pathlib import Path
import json,subprocess,hashlib,re
R=Path.cwd();out=R/'build/forest_revision04/queen-campaign-review';sha=lambda b:hashlib.sha256(b).hexdigest();Q='4be8eeb932d24866a49379f0d33f16f00125711d'
def load(p):return json.loads((R/p).read_text())
reportpath='build/verification/harness/20261020T090304.282833Z/report.json';r=load(reportpath);outer=load('build/forest_revision04/remaining42-prepared/outer-receipt.json');previous=load('build/forest_revision04/remaining44-T/outer-receipt.json');mbytes=subprocess.check_output(['git','show',Q+':tools/harness/profiles.json']);m=json.loads(mbytes)
assert sha(mbytes)==r['manifest_sha256'];assert r['status']=='passed' and r['commit']==Q and r['release'] is True and r['jobs']==1
assert all(r[k]=='' for k in ['git_status','diff','untracked']) and r['working_files']=={}
assert outer['head_before']==outer['head_after']==Q and outer['git_status_before']==outer['git_status_after']=='' and outer['exit_code']==0
assert len(r['checks'])==len(outer['ids'])==42 and [c['id'] for c in r['checks']]==outer['ids']==[x for x in previous['ids'] if x not in ['forest-depth-campaign-guardian','forest-depth-campaign-queen']]
assert all(x in previous['ids'] for x in ['forest-depth-campaign-guardian','forest-depth-campaign-queen'])
rows=[];tokens=set();bad=[]
folder=R/Path(reportpath).parent
for c in r['checks']:
 spec=m['checks'][c['id']];assert c['argv']==spec['argv'] and c['timeout_seconds']==spec['timeout_seconds']
 assert c['status']=='passed' and type(c['exit_code']) is int and c['exit_code']==0 and c['reused'] is False and c['failure_reason'] is None
 assert 0<=c['duration_seconds']<c['timeout_seconds'] and abs(c['duration_seconds']-(c['ended_at_unix']-c['started_at_unix']))<.001
 assert c['check_token'] and c['check_token'] not in tokens;tokens.add(c['check_token'])
 log=(folder/c['log']).read_bytes();assert log==(Path(c['artifact_directory'])/'check.log').read_bytes()
 text=log.decode(errors='replace')
 hits=[s for s in ['SCRIPT ERROR','SHADER ERROR','ObjectDB instances leaked at exit','resources still in use at exit','Leaked instance:'] if s in text]
 if hits:bad.append({'id':c['id'],'markers':hits})
 rows.append({'id':c['id'],'timeout_seconds':c['timeout_seconds'],'duration_seconds':c['duration_seconds'],'exit_code':0,'fresh':True,'log_sha256':sha(log),'bytes':len(log)})
assert not bad,bad
harness=subprocess.check_output(['git','show',Q+':tools/harness.py']).decode();assert 'if input_digest({"argv": []}, source_files(), identity) != source_before:' in harness
result={'decision':'SCOPED_ACCEPT','scope':'Q original remaining42 actual fresh consumer execution only','source_commit':Q,'report':reportpath,'report_sha256':sha((R/reportpath).read_bytes()),'original_previous44_exact_remaining_order':True,'count':42,'all_exit_zero':True,'all_fresh_release':True,'all_argv_and_caps_exact_Git_Q_manifest':True,'clean_source_before_after':True,'source_guard_method':'Original reviewed harness checks source before/after every check, then final full-byte source digest; successful report/outer cleanQ retained. Did not reread whole repository or rerun native.','outer_seconds':outer['elapsed'],'harness_seconds':r['wall_seconds'],'unique_actual_execution_tokens':len(tokens),'strict_engine_diagnostic_scan':bad,'checks':rows,'exclusions':['Not a fresh complete120 run.','T80 remains600timeout:78 terminal pass/2 uncompleted.','Does not approve full CI, main merge or public/device/user acceptance.']}
(out/'Q_remaining42_local_review.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
(out/'Q_remaining42_local_review.md').write_text(f'''Q remaining42: SCOPED_ACCEPT

Exact Q `{Q}` original42 checks all passed with fresh release execution, unique execution tokens and actual exit0. Exact IDs equal the original44 request with the two executed Guardian/Queen consumers removed; remaining order unchanged. Every argv and timeout matches GitQ manifest; every duration is below its original cap. Original log copies match artifacts and strict engine/leak markers are absent. Outer631.118s/harness630.846s; cleanQ before and after, final full-byte source guard retained.

This is only this42-check batch. T80/600 timeout remains78 completed passes and2 uncompleted; batches do not become one complete120 pass. No new native or full-repository hash pass was run for this review.
''')
indexpath='docs/evidence/main_pr96_repair01/followup-H2-C2/final-copy-index.json';ix=load(indexpath);assert ix['reviewed_source']==Q
for f in ix['files']:
 b=(R/f['path']).read_bytes();assert len(b)==f['bytes'] and sha(b)==f['sha256'],f['path']
cards=[]
for name in ['MAIN-PR96-REPAIR-01','FOREST-FRUIT-ROUTES-04']:
 d=load('docs/quality/records/'+name+'.json');assert d['reviewed_commit']==Q and d['workflow']=='review'
 assert all(x['status']=='unverified' for x in d['gates'].values())
 assert [k for k,v in d['dimensions'].items() if v['status']=='passed']==['independent_review']
 for e in d['evidence']:
  if e['id']=='Q-final-code-closure-review':
   assert e['source_commit']==Q and e['independent'] is True and e['verdict']=='ACCEPT' and sha((R/e['path']).read_bytes())==e['sha256']
  if e['id'].startswith(('Q-','T-','C2-','H2-')):assert sha((R/e['path']).read_bytes())==e['sha256']
 cards.append({'task_id':name,'reviewed_commit':Q,'workflow':'review','only_passed_dimension':'independent_review','all_gates_unverified':True})
changed=subprocess.check_output(['git','diff','--name-only',Q],text=True).splitlines();assert all(p.startswith('docs/') for p in changed),changed
meta={'decision':'SCOPED_ACCEPT','scope':'Current uncommitted docs archive/cards content and exact copies, not future Git commit or runtime acceptance','reviewed_code':Q,'final_copy_index':indexpath,'verified_file_count':len(ix['files']),'verified_total_bytes':sum(f['bytes'] for f in ix['files']),'quality_cards':cards,'tracked_changes_docs_only':changed,'findings':[],'claim_review':'New checkpoints distinguish H2 CI failures/cancellation, T80 timeout, Queen repair and Q42; do not relabel KWeb/Hfilm or claim complete120/fullCI/main/public/device.','limitations':'Existing CI packet claims are retained historical summaries; this audit verifies archived bytes and metadata scope, not a fresh redownload of every remote native artifact.'}
(out/'Q_followup_docs_precommit_review.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n')
(out/'Q_followup_docs_precommit_review.md').write_text(f'''Q follow-up docs: SCOPED_ACCEPT

Verified all{len(ix['files'])} files and{sum(f['bytes'] for f in ix['files'])} bytes against final-copy-index SHA256. Both cards reference exactQ `{Q}` for bounded source review, remain workflow review, and keep all technical/design/device gates unverified. Only independent_review is passed with explicit limited scope. New docs distinguish original failures, Q42 success and pending fullCI/main/public delivery; no old KWeb/Hfilm provenance is upgraded.

Tracked differences fromQ are docs only. This is a precommit metadata/content review, not a signature on a future Git tree or new runtime tests.
''')
print(json.dumps({'remaining42':'SCOPED_ACCEPT','archive_files':len(ix['files']),'archive_bytes':meta['verified_total_bytes'],'docs':'SCOPED_ACCEPT'}))
