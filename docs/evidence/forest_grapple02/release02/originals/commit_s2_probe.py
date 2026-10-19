"""Read-only Git-object integration review; no engine/test execution."""
import hashlib,json,pathlib,subprocess
R=pathlib.Path.cwd(); O=R/'build/verification/verifier_migration_review'
B='6c61faadd511c48a267b975550da897e701fd09f'; S1='7ba2e92d2c3cb5449ac6648b820f79679548ee89'; S2='6adc5ff30515d7adaf598d5bbba0268d42af44f4'
def git(*a):return subprocess.check_output(['git',*a])
def read(p):return json.loads((R/p).read_text())
def sha(p):return hashlib.sha256((R/p).read_bytes()).hexdigest()
prefix='build/verification/verifier_migration_review/'
prior=read(prefix+'commit_s1_review.json'); historic=read(prefix+'rootbell_historical_review01.json'); native=read(prefix+'rootbell_native_review01.json')
inner_path=native['inner_original_report']; inner=read(inner_path); outer_path=native['outer_original_report'];outer=read(outer_path)
matrix_path='build/forest_grapple02/matrix16_final02/receipt.json';matrix=read(matrix_path)
changed=git('diff','--name-only',B,S2,'--','tests','tools').decode().splitlines(); delta=git('diff','--name-only',S1,S2,'--','tests','tools').decode().splitlines()
expected_delta=['tests/fixtures/root_bell/pre_focus_15_player_tuning.json','tests/root_bell_formal_tests.gd','tools/harness/profiles.json','tools/test_root_bell_formal_verifier.py']
card=read('docs/quality/records/FOREST-GRAPPLE-CONSUMERS-02.json')
paths=set(changed)|set(inner['source_before'])|set(matrix['source_after']); blobs={};proc=subprocess.Popen(['git','cat-file','--batch'],stdin=subprocess.PIPE,stdout=subprocess.PIPE)
for p in sorted(paths):
 proc.stdin.write((S2+':'+p+'\n').encode());proc.stdin.flush();header=proc.stdout.readline().decode().split();assert len(header)==3 and header[1]=='blob',(p,header)
 data=proc.stdout.read(int(header[2]));assert len(data)==int(header[2]) and proc.stdout.read(1)==b'\n'
 blobs[p]={'sha256':hashlib.sha256(data).hexdigest(),'git_blob':header[0],'bytes':len(data)}
proc.stdin.close();proc.stdout.close();assert proc.wait()==0
mismatches=[{'path':p,'actual_native_sha256':h,'S2_git_sha256':blobs[p]['sha256']} for p,h in inner['source_before'].items() if blobs[p]['sha256']!=h]
forest_diff=[{'path':p,'original_S1_native_sha256':h,'S2_git_sha256':blobs[p]['sha256']} for p,h in matrix['source_after'].items() if blobs[p]['sha256']!=h]
reviewed={};gaps=[]
for p in changed:
 h=blobs[p]['sha256']; expected=native['reviewed_sha256'].get(p) if p in expected_delta else prior['affected_tests_tools_sha256'].get(p,{}).get('sha256')
 if expected!=h:gaps.append(p)
 reviewed[p]={**blobs[p],'review_chain_reference':prefix+('rootbell_native_review01.json' if p in expected_delta else 'commit_s1_review.json'),'working_bytes_equal_commit':sha(p)==h}
prod_paths=['scripts','scenes','resources','config','assets','project.godot','export_presets.cfg','project','export']
production_diff=git('diff','--name-only',S1,S2,'--',*prod_paths).decode().splitlines()
p1=json.loads(git('show',S1+':tools/harness/profiles.json'));p2=json.loads(git('show',S2+':tools/harness/profiles.json'));p1['checks']['root-bell-tests']['artifact_paths']=['build/root_bell/formal_v2']
checks={
'exact_S2_HEAD':git('rev-parse','HEAD').decode().strip()==S2,
'exact43_final_tests_tools':len(changed)==43,
'exact_child_affected_paths':set(changed)=={p for p in card['affected_paths'] if p.startswith(('tests/','tools/'))},
'only_four_test_tool_delta_paths_since_S1':delta==expected_delta,
'all43_prior_independent_chain_final_SHA_covered':not gaps,
'all43_working_bytes_equal_S2':all(r['working_bytes_equal_commit'] for r in reviewed.values()),
'prior_S1_review_was_ACCEPT':prior['verdict']=='ACCEPT' and all(prior['checks'].values()),
'rootbell_contract_and_actual_review_ACCEPT':historic['verdict']=='ACCEPT_SCOPED_TEST_CONTRACT' and native['verdict']=='ACCEPT' and all(historic['checks'].values()) and all(native['checks'].values()),
'rootbell1231_before_after_identical':len(inner['source_before'])==1231 and inner['source_before']==inner['source_after'],
'rootbell1231_all_independently_git_bound_S2':not mismatches,
'rootbell_original_reports_unchanged':sha(inner_path)==native['inner_report_sha256'] and sha(outer_path)==native['outer_report_sha256'],
'rootbell_raw_outer_still_S1_dirty':outer['commit']==S1 and bool(outer['git_status']),
'production_S1_to_S2_zero_diff':not production_diff,
'profile_only_original_artifact_collection_addition':p1==p2,
'old_forest2127_not_falsely_same_S2':len(matrix['source_after'])==2127 and {r['path'] for r in forest_diff}==set(expected_delta)-{'tests/fixtures/root_bell/pre_focus_15_player_tuning.json'},
'new_fixture_absent_original_forest_inventory':'tests/fixtures/root_bell/pre_focus_15_player_tuning.json' not in matrix['source_after'],
'original_forest_receipt_identity_hash_preserved':matrix['source_head']==B and sha(matrix_path)==prior['matrix_receipt_sha256'],
'production_rootbell_reader_still_original':blobs['tools/run_root_bell_formal.py']['sha256']==native['reviewed_sha256']['tools/run_root_bell_formal.py'],
}
refs=[prefix+n for n in ['commit_s1_review.json','commit_s1_review.md','rootbell_historical_review01.json','rootbell_historical_review01.md','rootbell_native_review01.json','rootbell_native_review01.md']]
r={'task_id':'FOREST-GRAPPLE-CONSUMERS-02','reviewer':'/root/verifier_migration_review','review_type':'commit-bound consumer integration review','baseline_commit':B,'previous_reviewed_commit':S1,'reviewed_commit':S2,'selected_CI_run':39200142616,'scope':'Test/tool migration and exact committed-source evidence binding only. No engine/full-test/CI invocation; no whole-region or player/device acceptance.','verdict':'ACCEPT' if all(checks.values()) else 'REJECT','checks':checks,'affected_tests_tools_sha256':reviewed,'chain_gaps':gaps,'rootbell_native_source_binding':{'original_report':inner_path,'report_sha256':sha(inner_path),'original_outer_report':outer_path,'outer_report_sha256':sha(outer_path),'original_outer_commit':outer['commit'],'original_outer_git_status_sha256':hashlib.sha256(outer['git_status'].encode()).hexdigest(),'original_outer_dirty':bool(outer['git_status']),'independently_git_bound_input_count':len(inner['source_before']),'mismatches':mismatches,'source_table_sha256':hashlib.sha256(json.dumps(inner['source_before'],sort_keys=True,separators=(',',':')).encode()).hexdigest(),'all_input_git_bindings':{p:blobs[p] for p in sorted(inner['source_before'])},'interpretation':'Original actual fresh targeted run was captured at S1 with dirty test-only changes. All1231 observed inputs now match S2 Git objects exactly. This binding does not relabel the raw capture or claim a fresh S2 invocation.'},'original_forest_inventory_binding':{'original_receipt':matrix_path,'original_receipt_sha256':sha(matrix_path),'original_source_head':matrix['source_head'],'original_committed_binding':S1,'inventory_count':2127,'S2_changed_entries':forest_diff,'new_fixture_absent_old_inventory':True,'interpretation':'Retain original S1 binding. Production-source identity supports limited reuse of original movies/16 representative routes only; the old2127 source inventory does not fully match S2 and is not S2-native-fresh.'},'production_paths_compared':prod_paths,'production_S1_S2_diff_paths':production_diff,'evidence_chain':[{'path':p,'sha256':sha(p)} for p in refs],'prior_S1_evidence_chain':prior['evidence_chain'],'unverified':['Selected S2 CI full89 checks','Original full80-route current corpus/600-second consumer','S2 fresh full native invocation','New Web release and browser/device verification','Whole-region fun/design/visual/audio/commercial quality or human acceptance'],'raw_evidence_policy':'Old source_head6c61/S1 commit and dirty identities are not rewritten; previous failures and reviews remain unchanged.'}
(O/'commit_s2_review.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n')
md=f'''# S2 commit-bound consumer integration review\n\n**{r['verdict']}**, limited to test/tool contract migration and committed-source evidence binding. Reviewed `{S2}` against base `{B}` and prior S1 `{S1}`. No engine, test suite, or CI was started by this review.\n\nAll **43** affected tests/tools match the final independent review chain: the S1 original40 coverage plus three additional Root Bell paths, with the overlapping profile replaced by its final artifact-only reviewed bytes. The exact SHA256/Git blob map is in the accompanying JSON. Old cases, negative counterexamples and budgets retain the S1 review coverage; S1→S2 changes only the four listed test/tool paths.\n\nGit cat-file independently verified **1231/1231** original Root Bell before/after source entries against S2 objects, with zero mismatches. The original successful single targeted check remains recorded at S1 with dirty test changes: 121.717s under its original360-second budget, 165 native assertions, 41+9 refusals, 40 historical/current audit rows and original27+9 reader probes. This is a new commit binding of unchanged actual evidence, not a newly executed S2-native run. Original raw reports and identities are unchanged.\n\nS1→S2 has **zero production diff** in scripts/scenes/resources/config/assets/project/export paths. The old forest2127 inventory now differs at three existing test/tool entries; the new historical fixture was absent from that inventory. Therefore the original S1 inventory binding stays scoped to S1. Unchanged production permits limited reuse of the original two films and16 representative routes, without calling them fresh S2 evidence.\n\nThe selected S2 CI `{r['selected_CI_run']}`, full89 checks, original80/600-second corpus, Web/device verification and player/whole-region quality remain outside this ACCEPT. Parent region remains REVISE. Old failures and old6c61/S1 raw identities remain intact.\n\nEvidence: `commit_s1_review.{{json,md}}`, `rootbell_historical_review01.{{json,md}}`, and final `rootbell_native_review01.{{json,md}}` in this directory. Exact hashes and complete1231 input mapping appear in `commit_s2_review.json`.\n'''
(O/'commit_s2_review.md').write_text(md)
print(json.dumps({'verdict':r['verdict'],'checks':checks,'changed_count':len(changed),'gaps':gaps,'native_mismatches':mismatches,'forest_changed_entries':forest_diff},indent=2))
