"""Read-only S2 portable skeleton; no CI/network/test/publisher actions."""
from pathlib import Path
import hashlib,json,subprocess,re
R=Path.cwd();B=R/'build/forest_grapple02/ci_s2';O=B/'release02_skeleton';S=lambda b:hashlib.sha256(b).hexdigest();S1='7ba2e92d2c3cb5449ac6648b820f79679548ee89';S2='6adc5ff30515d7adaf598d5bbba0268d42af44f4';assert subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()==S2
rows=[]
def copy(src,dst):
 raw=src.read_bytes();assert not src.is_symlink()
 if re.search(rb'[?&](?:sig|X-Amz-Signature)=|gh[pousr]_[A-Za-z0-9]{20}|(?i:authorization)["\s:]+(?i:bearer)\s+[A-Za-z0-9]',raw):raise ValueError('Signed/token content: '+str(src))
 p=O/dst;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(raw);rows.append({'source':str(src),'destination':dst,'sha256':S(raw),'bytes':len(raw),'kind':'exact original copy'})
for n in ['commit_s2_review.json','commit_s2_review.md','commit_s2_probe.py']:copy(R/'build/verification/verifier_migration_review'/n,'originals/'+n)
for n in ['duplicate_cancel01.json','duplicate_cancel02.json']:copy(B/n,'originals/'+n)
a=json.loads((O/'originals/commit_s2_review.json').read_text());assert a['reviewed_commit']==S2 and a['verdict']=='ACCEPT' and len(a['affected_tests_tools_sha256'])==43 and a['rootbell_native_source_binding']['independently_git_bound_input_count']==1231 and not a['rootbell_native_source_binding']['mismatches']
paths=a['production_paths_compared'];argv=['git','diff','--name-only',S1,S2,'--',*paths];diff=subprocess.check_output(argv);assert diff==b'';(O/'production-S1-S2-diff.txt').write_bytes(diff)
identity={'scope':'Actual read-only production diff plus exact independent commit-bound report attribution; not new native execution','S1':S1,'S2':S2,'git_argv':argv,'production_diff_paths':[],'diff_stdout_sha256':S(diff),'independent_review43_count':43,'independent_RootBell_commit_binding_count':1231,'new_RootBell_actual_execution_identity':'Original S1HEAD+dirtytest snapshot, no S2-native rerun claimed','original_forest2127_identity':'S1 binding retained; three existing test/tool inputs differ in S2 and new fixture was absent. Not same2127.','selected_run':39200142616,'attempt':1,'full_CI89_forest80_release':'not certified by this skeleton'};(O/'source-identity.json').write_text(json.dumps(identity,indent=2)+'\n')
old=[]
for p in sorted((R/'docs/evidence/forest_grapple02/release01').glob('*.zip')):old.append({'committed_path':str(p.relative_to(R)),'sha256':S(p.read_bytes()),'bytes':p.stat().st_size,'duplicated_here':False})
(O/'prior-release01-reference.json').write_text(json.dumps({'scope':'References only; do not duplicate immutable committed preflight/failure/repair ZIPs','archives':old},indent=2)+'\n')
assert json.loads((O/'originals/duplicate_cancel01.json').read_text())==[]
cancels=json.loads((O/'originals/duplicate_cancel02.json').read_text());assert len(cancels)==2 and all(x['cancel_exit']==0 and x['run']['databaseId']!=39200142616 and x['run']['headSha']==S2 for x in cancels)
(O/'original-copy-custody.json').write_text(json.dumps({'scope':'exact originals source-to-copy map; no live publisher checkpoint','files':rows},indent=2)+'\n')
print(json.dumps({'originals':len(rows),'review_tests_tools':43,'rootbell_inputs_bound':1231,'production_diff':0,'old_ZIPs_referenced_not_copied':len(old)}))
