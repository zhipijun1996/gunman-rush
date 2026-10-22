import ast, hashlib, importlib.util, json, subprocess, sys
from pathlib import Path
ROOT=Path.cwd(); OUT=ROOT/'build/region_bible_v2/region-context-guard-independent-first'
sys.path.insert(0,str(ROOT/'tools'))
from level_region_context import build_region_context
spec=importlib.util.spec_from_file_location('context_original_tests',ROOT/'tests/test_level_region_context.py'); module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
case=module.RegionContextTests(); rows=[]
def check(name,condition,actual=None):
 rows.append({'name':name,'passed':bool(condition),'actual':actual}); assert condition,name
base=build_region_context('thorn_forest')
check('actual_current_consumer_present',base['implementation']['formal_region']=='consumer_present_in_source')
check('runtime_not_inferred',base['implementation']['runtime_available'] is None)
check('validation_not_claimed',base['implementation']['validation_status']=='unverified')
check('formal_grants_not_inferred',all(v['formal_grant']=='not_inferred' for v in base['implementation']['abilities'].values()))
check('candidate_gate_stays_proposed',base['design']['gate']['status'].startswith('PROPOSED'))
check('static_context_kind',base['kind']=='extracted_design_input_not_runtime_configuration')
check('old_expectation_actually_fails',base['implementation']['formal_region']!='no_formal_consumer_observed')
# Real complete authority fixtures with one actual observed source token removed; no mocks.
for path,token in [('scripts/demo/demo_app.gd','func _select_next_region('),('scripts/demo/demo_app.gd','func start_debug_region('),('scripts/demo/demo_app.gd','ThornForestRegionGenerator.new().generate('),('scripts/demo/demo_app.gd','ThornForestRegionStage.new()'),('scripts/demo/thorn_forest_region_stage.gd','ThornForestRegionAssembler')]:
 root=case.fixture(); target=root/path; original=target.read_text(); assert token in original
 target.write_text(original.replace(token,'REMOVED_IN_INDEPENDENT_TEMP_FIXTURE'))
 current=build_region_context('thorn_forest',root)
 check('missing_consumer_token_rejected:'+token,current['implementation']['formal_region']=='no_formal_consumer_observed')
 check('missing_consumer_still_no_runtime_admission:'+token,current['implementation']['runtime_available'] is None and current['implementation']['validation_status']=='unverified')
 # Any replacement with a constant presence result would now fail the above actual negative.
case.doCleanups()
old=subprocess.check_output(['git','show','7be8c34:tests/test_level_region_context.py'],text=True)
new=(ROOT/'tests/test_level_region_context.py').read_text()
old_tree=ast.parse(old);new_tree=ast.parse(new)
def funcs(tree): return {n.name:ast.dump(n,include_attributes=False) for n in ast.walk(tree) if isinstance(n,ast.FunctionDef)}
a,b=funcs(old_tree),funcs(new_tree)
check('all_original_test_names_retained',set(a)==set(b),sorted(a))
expected_old='self.assertEqual(context["implementation"]["formal_region"], "no_formal_consumer_observed")'
expected_new='self.assertEqual(context["implementation"]["formal_region"], "consumer_present_in_source")'
normalized=new.replace(expected_new,expected_old,1)
normalized=normalized.replace("        style_path = json.loads((ROOT/'docs/creative_direction/bibles/registry.json').read_bytes())['shared_style_authority']['path']\n        supplement = json.loads((ROOT/style_path).read_bytes())\n        for name in [style_path, *[row['path'] for row in supplement['runtime_reference']['references']]]:\n            target = root/name; target.parent.mkdir(parents=True,exist_ok=True); shutil.copyfile(ROOT/name,target)\n",'')
check('only_one_assertion_and_actual_style_fixture_closure_delta_vs_R',normalized==old)
for name in sorted(set(a)-{'fixture','test_forest_has_only_hook_gate_and_separate_runtime_scope'}):
 check('original_method_AST_unchanged:'+name,a[name]==b[name])
files=['tools/level_region_context.py','tests/test_level_region_context.py','scripts/demo/demo_app.gd','scripts/demo/thorn_forest_region_stage.gd','scripts/generation/thorn_forest_region_generator.gd','scripts/generation/thorn_forest_region_assembler.gd']
report={'verdict':'ACCEPT_SCOPED','scope':'Source-observation expectation and existing fixture closure only; no formal admission or art approval.','reviewer':'/root/bible_test_workflow_independent_review','baseline':'7be8c34','head':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'unit_suite':{'tests':10,'passed':True,'log':'unit.log'},'checks':rows,'reviewed_files':{p:{'sha256':hashlib.sha256((ROOT/p).read_bytes()).hexdigest(),'bytes':(ROOT/p).stat().st_size} for p in files},'limitations':['No engine or runtime execution.','Substring source inventory is not reachability/admission proof.','No technical_sample, whole art, device, player, or formal-grant approval.','Region source consumers may exist while whole region remains unverified.']}
(OUT/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'verdict':report['verdict'],'checks':len(rows),'all_passed':all(r['passed'] for r in rows)},ensure_ascii=False))
