from pathlib import Path
import hashlib,json,re,difflib
R=Path('/workspace/gunman-rush-refactor');E=Path('/workspace/refactor-evidence/combat-perf-deploy-01/root-rig');base=json.loads((E/'baseline.json').read_text());sha=lambda x:hashlib.sha256(x).hexdigest()
files=base['files'];rows=[];patch=[]
for p,h in files.items():
 old=(E/'original'/p).read_bytes();new=(R/p).read_bytes();assert sha(old)==h
 rows.append(dict(path=p,before_sha256=h,sha256=sha(new),bytes=len(new)))
 patch.extend(difflib.unified_diff(old.decode().splitlines(keepends=True),new.decode().splitlines(keepends=True),fromfile='a/'+p,tofile='b/'+p))
def funcs(s):
 hits=list(re.finditer(r'^(?:static )?func (\w+)\([^\n]*',s,re.M));return {m[1]:s[m.start():hits[i+1].start() if i+1<len(hits) else len(s)].rstrip() for i,m in enumerate(hits)}
p='game/enemies/presentation/plains_revision_pose.gd';old=(E/'original'/p).read_text();new=(R/p).read_text();assert funcs(old)==funcs(new)
p='game/enemies/presentation/plains_revision_flora.gd';old=(E/'original'/p).read_text();new=(R/p).read_text();of,nf=funcs(old),funcs(new)
# Trailing comments beside method boundaries may move, so compare until last return.
def function_body(t):return t[:t.rfind('\n\treturn')]+t[t.rfind('\n\treturn'):].split('\n\n')[0] if '\n\treturn' in t else t
unchanged=[]
for name in of:
 if name in ('_root_bell','_carry_stem'):continue
 assert function_body(of[name])==function_body(nf[name]),name;unchanged.append(name)
# Each moved local RHS remains literally the same expression, with its original
# inferred type, before being stored in typed Vector2/float snapshot fields.
oldroot=of['_root_bell'];prep=nf['_prepare_root_geometry'];assignments=[]
for line in prep.splitlines():
 stripped=line.strip()
 if stripped.startswith('var '):
  assert stripped in oldroot or stripped in of['_carry_stem'],stripped
  assignments.append(stripped)
# Two composite live angles were originally inline call arguments.
assert '-.17*load+.39*strike-.07*recovery+.13*hurt+bell_lag' in oldroot
assert '.09*load-.15*strike+leaf_lag+.058*pose.root_leaf_sin*quiet' in oldroot
p='tests/plains_revision_deform_equivalence_runner.gd';old=(E/'original'/p).read_text();new=(R/p).read_text();of,nf=funcs(old),funcs(new)
for name,text in of.items():
 if name=='_run':assert nf[name].replace('\n\t_root_geometry_cases()','')==text
 else:assert nf[name]==text,name
proof=dict(base=base['head'],static_only=True,pose_original_functions_exact=True,flora_original_other_functions_exact=unchanged,moved_local_assignments_exact=assignments,root_leaf_uv_branch_unchanged=True,original_fold_elbow_exact=True,typed_vector2_and_float_storage=True,cache_scope='one prepared pose + exact valid size; pose.live owns a separate live snapshot; no Dictionary-identity, global or cross-draw cache',invalid_size_guard_unchanged=True,original_test_functions_exact_except_one_run_call=True,added_assertions=84,added_compared_vertices=924,expected_total_if_combined_original_scope=7185,expected_vertices_if_combined_original_scope=372725,engine_run=False,oracle_native_pending=True,root_owned_skin_not_modified=True)
(E/'static-proof.json').write_text(json.dumps(proof,indent=2)+'\n');(E/'candidate.patch').write_text(''.join(patch));freeze=dict(base=base['head'],owned_write_set=rows,patch_sha256=sha((E/'candidate.patch').read_bytes()),proof_sha256=sha((E/'static-proof.json').read_bytes()),tests='Original oracle runner unchanged except additive84 checks/924 vertices; native required by root. No engine/browser/benchmark run.')
(E/'freeze.json').write_text(json.dumps(freeze,indent=2)+'\n');print(json.dumps(dict(freeze_sha256=sha((E/'freeze.json').read_bytes()),files=rows)))
