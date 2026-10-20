from pathlib import Path
import sys,ast,subprocess,json,hashlib,re
sys.path.insert(0,'tools');import harness as h
D=Path('build/harness_hash_cache');O=D/'independent_review';B='3affbc89011bce1ef206ce377f9ebdfc724880d4'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def load(p):return json.loads(Path(p).read_text())
hand=load(D/'handoff-summary.json');bench=load(D/'benchmark.json');inv=load(D/'inventory.json')
for p,s in hand['source_sha256'].items():assert sha(p)==s==bench['source_files'][p]
for name,r in hand['evidence'].items():assert (D/name).stat().st_size==r['bytes'] and sha(D/name)==r['sha256']
old=ast.parse(subprocess.check_output(['git','show',B+':tests/test_harness.py'],text=True));new=ast.parse(Path('tests/test_harness.py').read_text())
oldnodes={x.name:ast.dump(x,include_attributes=False) for x in old.body if isinstance(x,(ast.ClassDef,ast.FunctionDef))};newnodes={x.name:ast.dump(x,include_attributes=False) for x in new.body if isinstance(x,(ast.ClassDef,ast.FunctionDef))};assert all(newnodes[k]==v for k,v in oldnodes.items());assert set(newnodes)-set(oldnodes)=={'SourceHashCacheTests'}
orig=ast.parse(subprocess.check_output(['git','show',B+':tools/harness.py'],text=True));now=ast.parse(Path('tools/harness.py').read_text());a={x.name:ast.dump(x,include_attributes=False) for x in orig.body if isinstance(x,(ast.ClassDef,ast.FunctionDef))};b={x.name:ast.dump(x,include_attributes=False) for x in now.body if isinstance(x,(ast.ClassDef,ast.FunctionDef))};changed=[k for k in a if a[k]!=b[k]];assert set(changed)=={'input_digest','execute_checks','source_inventory','main'} and set(b)-set(a)=={'SourceHashCache'}
assert bench['status']=='PASS' and bench['native_commands']==[] and len(inv)==21176 and bench['differences']=={'fresh':[],'hot':[]}
canon=hashlib.sha256(json.dumps(inv,sort_keys=True).encode()).hexdigest();digest=h.input_digest({'argv':[]},sorted(inv),{'benchmark':'source-only; no toolchain probe'},snapshot=inv)
for p in bench['passes']:assert p['inventory_sha256']==canon and p['persistent_input_digest']==digest and p['files']==21176
assert [p['read_bytes'] for p in bench['passes']]==[8467029779,0,8467029779] and [p['read_calls'] for p in bench['passes']]==[21176,0,21176]
log=(D/'tests-77.log').read_text();assert re.search(r'Ran 77 tests in 10\.452s\s+OK',log) and 'FAILED' not in log
own=load(O/'independent-cache-tests-receipt.json');assert own['exit_code']==0 and re.search(r'Ran 12 tests .*\s+OK',(O/'independent-cache-tests.log').read_text())
# Source-final guards remain uncached at both execute and lane/verify approval boundaries.
functions={x.name:x for x in now.body if isinstance(x,ast.FunctionDef)}
execute=ast.get_source_segment(Path('tools/harness.py').read_text(),functions['execute_checks']);assert 'if input_digest({"argv": []}, source_files(), identity) != source_before:' in execute
main=ast.get_source_segment(Path('tools/harness.py').read_text(),functions['main']);assert 'source_files_after=source_inventory()' in main
r={'decision':'SCOPED_ACCEPT__EXACT_TWO_SOURCE_BLOBS','baseline_commit':B,'tested_and_reviewed_source_sha256':hand['source_sha256'],'original_test_classes_functions_AST_exact':True,'original_unchanged_harness_helpers_AST_count':len(a)-len(changed),'only_modified_harness_functions':changed,'independent_new12_tests_actual_exit':0,'independent_test_seconds':own['seconds'],'author_original77_actual_exit':0,'source_guard_policy':hand['policy'],'benchmark':{'source_only_no_native':True,'actual_inventory_entries':len(inv),'recorded_byte_volume_per_fresh_pass':8467029779,'three_inventory_and_persistent_digests_independently_recomputed_equal':True,'passes':bench['passes'],'cold_means_execution_cache_empty_not_OS_cache_flushed':True,'reviewer_did_not_rehash_8GB_or_repeat_benchmark':True},'unchanged_scope':['proof/artifact source hashing uses unchanged original functions','original report schema/check IDs/profiles/caps/argv/test coverage unchanged','persistent input digest still contains only original source hashes/check/toolchain payload, no stat metadata'],'native_by_reviewer':False,'not_accepted':['whole CI runtime benefit or fresh CI budget pass','current full regression suite','source mutation impossibility against a hostile filesystem; intermediate reuse trusts Linux ctime, terminal byte guard remains authoritative'],'source_proof_files':[{'path':str(D/n),'sha256':sha(D/n)} for n in ['handoff-summary.json','benchmark.json','benchmark.log','inventory.json','tests-77.log','benchmark.py','harness-source-cache.patch']]}
(O/'harness_cache_review.json').write_text(json.dumps(r,indent=2)+'\n');print('PASS harness scope; original77 evidence and independent12, no8GB rerun')
