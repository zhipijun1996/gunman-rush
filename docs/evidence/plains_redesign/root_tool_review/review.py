import sys,json,subprocess,hashlib,time,copy,tarfile,difflib
from pathlib import Path
R=Path.cwd();O=R/'build/plains_redesign/review_root_revisions';sys.path.insert(0,str(R/'tools'))
import level_experience as e,level_formal as f
H=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest();commands=[]
assert subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()=='0f868c290ac3e250cd09375450399f4da4dc0e23'
for name in ['test_level_experience','test_level_formal_receipts']:
 argv=['python3','tests/'+name+'.py'];start=time.time();r=subprocess.run(argv,capture_output=True,text=True);(O/(name+'.log')).write_text(r.stdout+r.stderr);commands.append(dict(argv=argv,exit_code=r.returncode,duration_seconds=time.time()-start,log=name+'.log',source_sha256=H('tests/'+name+'.py')));assert r.returncode==0
# Actual historical final v1 reports must fully derive identically, not merely keep fingerprint.
history=[]
for label in ['before','after']:
 p=R/'build/verification/plains-encounter/run_ypk8st18'/(label+'_report.json');r=json.loads(p.read_text());before=H(p);assert 'analysis_version' not in r;e.validate_report(r);assert H(p)==before;history.append(dict(path=str(p.relative_to(R)),sha256=before,fingerprint=r['fingerprint'],exact_derived_valid=True))
# Actual retained one-case input can be reanalyzed in both versions without capture rewrite.
path=R/'build/verification/plains-encounter/run_cr_0wy4_/after/case_0/capture.json';v1=e.report([path],analysis_version=1);v2=e.report([path]);e.validate_report(v1);e.validate_report(v2);assert 'analysis_version' not in v1 and v2['analysis_version']==2
cases=[]
for name,a,b in [('v1_to_v2',v1,v2),('v2_to_v1',v2,v1)]:
 try:e.compare(a,b)
 except ValueError as error:cases.append(dict(case=name,rejected=True,reason=str(error)))
 else:raise AssertionError(name)
e.compare(v1,v1);e.compare(v2,v2)
# Rehash malicious target-count/label changes: validation must derive from raw again.
for name,mutate in [('forged_player_count',lambda r:r['cases'][0]['stats'].update(player_damage_events=999)),('relabel_v2_as_v1',lambda r:r.pop('analysis_version')),('unknown_version',lambda r:r.update(analysis_version=3)),('bool_version',lambda r:r.update(analysis_version=True))]:
 r=copy.deepcopy(v2);mutate(r);r['fingerprint']=e.fingerprint({k:v for k,v in r.items() if k!='fingerprint'})
 try:e.validate_report(r)
 except ValueError as error:cases.append(dict(case=name,rejected=True,reason=str(error)))
 else:raise AssertionError(name)
# Real damage-target partitions across a failed high-entry capture and successful current one.
damage=[]
for p in [R/'build/verification/plains-encounter/run_h65v_l8t/after/case_0/capture.json',path]:
 c=json.loads(p.read_text());a=e.analyze_capture(c);events=[x for x in c['events'] if x['kind']=='damage_committed'];expected=[sum(x.get('target')=='player' for x in events),sum(bool(x.get('target')) and x.get('target')!='player' for x in events),sum(not x.get('target') for x in events)];observed=[a['stats'][k] for k in ['player_damage_events','non_player_damage_events','unknown_target_damage_events']];assert observed==expected and sum(observed)==len(events);damage.append(dict(path=str(p.relative_to(R)),total=len(events),player=observed[0],non_player=observed[1],unknown=observed[2]))
# Root tool edits leave exact transitive driver/core bytes intact vs already-reviewed old content.
old=json.loads((R/'build/verification/plains-encounter/run_f5p7af_k/receipt.json').read_text())['source_before'];immutables=[]
for p in sorted(f.driver_source_paths()|f.core_source_paths()):
 committed=subprocess.check_output(['git','show','0f868c2:'+p]);assert hashlib.sha256(committed).hexdigest()==old[p];immutables.append(p)
(O/'analysis_results.json').write_text(json.dumps(dict(historical=history,negative_cases=cases,real_damage_partitions=damage,same_version_compare_passed=[1,2],driver_paths=len(f.driver_source_paths()),core_paths=len(f.core_source_paths()),committed_driver_core_unchanged=immutables),indent=2));(O/'commands.json').write_text(json.dumps(commands,indent=2));print('ROOT ANALYSIS CHECKED',len(history),'actual exact v1 reports;',len(cases),'rejections; driver/core',len(f.driver_source_paths()),len(f.core_source_paths()))
