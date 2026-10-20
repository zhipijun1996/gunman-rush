from pathlib import Path
import json,hashlib,re,collections,subprocess
O=Path('build/forest_revision04/forest-versions-review');D=Path('build/forest_revision04/versions-C2-diagnosis');V=Path('build/forest_depth/versions/diagnosis-C2-verbose');T=Path('build/forest_depth/versions/diagnosis-C2-runtime-comparator')
def load(p):return json.loads(Path(p).read_text())
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def exact(a,b,p=''):
 assert type(a) is type(b),p+':type'
 if isinstance(a,dict):
  assert a.keys()==b.keys(),p+':keys'
  for k in a:exact(a[k],b[k],p+'/'+k)
 elif isinstance(a,list):
  assert len(a)==len(b),p+':len'
  for i,(x,y) in enumerate(zip(a,b)):exact(x,y,p+'/'+str(i))
 else:assert a==b,p+':value'
old=load(V/'capture.json');trial=load(T/'capture.json');data=load(D/'data-only.json');app=load(D/'app-only.json');results=load(D/'domain-results.json')
for key in ['checks','cases','exit_lifecycle']:exact(old[key],trial[key])
assert load(T/'receipt.json')['passed'] is False and load(T/'receipt.json')['source_guard']
counts=[]
for f in [V/'native.log',T/'native.log']:
 c=dict(collections.Counter(re.findall(r'^Leaked instance: ([^:]+):',f.read_text(),re.M)));counts.append(c);assert sum(c.values())==223
assert counts[0]==counts[1]
assert data['assertions']==280 and app['assertions']==47 and data['failures']==app['failures']==0
exact(data['checks'],old['checks'][:276]+old['checks'][323:]);exact(app['checks'],old['checks'][276:323]);exact(data['cases'],old['cases'][:-2]);exact(app['cases'],old['cases'][-2:]);exact(data['exit_lifecycle'],old['exit_lifecycle'])
assert len(data['cases'])==22 and len(app['cases'])==2 and all(r['error'] is None for r in results)
for mode in ['data-only','app-only']:
 log=(D/(mode+'.log')).read_text();assert not any(k in log for k in ['Leaked instance:','ObjectDB instances','resources still in use','SCRIPT ERROR:','Parse Error:','SHADER ERROR:','ERROR:'])
original=subprocess.check_output(['git','show','3affbc89011bce1ef206ce377f9ebdfc724880d4:tests/forest_depth_version_runner.gd'],text=True)
s=original.replace('\tfor map_index: int in [1,2]:\n\t\tawait app_case(map_index)\n','');start=s.index('func app_case(');end=s.index('func check_recorded_layouts(',start);s=s[:start]+s[end:];assert s==(D/'data-only.gd').read_text()
assert (D/'runner-original.gd').read_text()==original
p='load("res://scripts/generation/random_stage_generator.gd").new()';tried=(D/'runtime-comparator-tried.gd').read_text();normalized=tried.replace('var equality: Variant = '+p,'var equality := RandomStageGenerator.new()').replace(p,'RandomStageGenerator.new()');assert normalized==original
files=[V/'capture.json',V/'native.log',V/'receipt.json',T/'capture.json',T/'native.log',T/'receipt.json']+[D/n for n in ['data-only.gd','data-only.json','data-only.log','app-only.gd','app-only.json','app-only.log','domain-results.json','run-domains.py','runtime-comparator-tried.gd']]
r={'decision':'DIAGNOSTIC_ONLY__SEPARATE_DOMAINS_CLEAN__FORMAL_PROTOCOL_PENDING','source_commit':'3affbc89011bce1ef206ce377f9ebdfc724880d4','original_combined_and_runtime_comparator':{'both_327_business_pass':True,'all_assertions_cases_lifecycle_typed_exact':True,'same_223_leak_class_counts':counts[0],'runtime_same_script_loading_experiment_not_a_fix':True,'saved_original_and_tried_source_normalization_verified':True},'independent_domain_partition':{'data_assertions':280,'app_assertions':47,'data_cases':22,'app_cases':2,'exact_original_full327_ledger':'data first276 + app47 + data last4 = original327, all labels/passed fields and scalar types equal','exact_original_full24cases':'data22 + app2 = original24, all fields/scalar types equal, no dynamic-field exclusions','actual_data_lifecycle_equal_original':True,'data_script_exact_original_minus_app_calls_and_app_case_function':True,'same_actual_App_helper_unchanged_for_probe':True,'actual_strict_domains':results,'each_diagnostic_native_budget':90,'diagnostic_caps_not_a_formal_shared_budget_proof':True},'next_formal_requirements':['Preserve unique original CLI import90/outer180 and native shared90 monotonic total across two true processes, not90 each','Exact327 checks reconstructed in original276+47+4 order and24 cases/schema6 through unchanged original validator','Fresh run/PID/phase/script/source/raw identities; strict failures cannot produce aggregate; actual negative and artifact refusals','Preserve combined original and runtime-call failed trials; no production change or resource-cache purge'], 'raw_hashes':[{'path':str(p),'sha256':sha(p),'bytes':p.stat().st_size} for p in files],'reviewer_started_native_or_changed_tracked_files':False}
(O/'C2_domain_partition_review.json').write_text(json.dumps(r,indent=2)+'\n');print('PASS domain exact typed partition; formal pending')
