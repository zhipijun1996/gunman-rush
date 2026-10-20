from pathlib import Path
import json,hashlib,subprocess,zipfile,copy,re
R=Path.cwd();D=R/'build/foundry_final_W11';O=R/'build/forest_revision04/rooted-fix-review'
C1='220fe7dec48e46ad52b8a83302f6c46e8352bac8';C2='3affbc89011bce1ef206ce377f9ebdfc724880d4';H='cea407025bb3a31be745c440efb85920307679a3';OLD='169ef171fee3f70911847fb2c2890351ee3468bb'
def sha(b):return hashlib.sha256(b).hexdigest()
def load(p):return json.loads(Path(p).read_text())
def git(ref,p):return subprocess.check_output(['git','show',ref+':'+p])
paths=subprocess.check_output(['git','diff',C1,C2,'--name-only'],text=True).splitlines();assert len(paths)==56 and all(p.startswith('resources/foundry/') for p in paths)
before={};after={}
for p in paths:
 b=git(H,p);n=git(C2,p);assert b==git(OLD,p)==(D/'baseline_H2'/Path(p).relative_to('resources/foundry')).read_bytes()
 before[p]=json.loads(b);after[p]=json.loads(n)
B='resources/foundry/batch.json';E='resources/foundry/export_basis.json';ob=before[B];nb=after[B];oldbasis=ob['basis'];newbasis=nb['basis'];assert oldbasis=='f3e060598385696137aa40910811fcbfed931853fe7f4c9992b11cf1af0263cb' and newbasis=='6323c953b6d79b79b401659338da5c37bc8cd49853554593b9323717fc8ca70e'
allowed={'/batch/basis','/export_basis/basis'}
for i in range(36):
 for k in ['basis','hash']:allowed.add(f'/batch/accepted/{i}/manifest/{k}')
for i in range(18):
 for k in ['basis','hash']:allowed.add(f'/batch/itineraries/{i}/{k}')
 assert len(ob['itineraries'][i]['phrases'])==len(nb['itineraries'][i]['phrases'])==3
 for j in range(3):
  for k in ['basis','hash']:allowed.add(f'/batch/itineraries/{i}/phrases/{j}/{k}')
replays=[p for p in paths if '/replays/' in p];assert len(replays)==54
for p in replays:
 for k in ['basis','manifest_hash']:allowed.add('/replays/'+Path(p).name+'/'+k)
assert len(allowed)==326 and allowed==set(load(D/'explicit_stamp_whitelist.json'))==set(load(D/'comparison.json')['allowed_stamp_paths'])
visited=set()
def compare(a,b,p):
 assert type(a) is type(b),p+':type'
 if p in allowed:
  assert isinstance(a,str) and re.fullmatch('[0-9a-f]{64}',a) and re.fullmatch('[0-9a-f]{64}',b),p
  if p.endswith('/basis'):assert a==oldbasis and b==newbasis
  visited.add(p);return
 if isinstance(a,dict):
  assert a.keys()==b.keys(),p+':keys'
  for k in a:compare(a[k],b[k],p+'/'+k)
 elif isinstance(a,list):
  assert len(a)==len(b),p+':length'
  for i,(x,y) in enumerate(zip(a,b)):compare(x,y,p+'/'+str(i))
 else:assert a==b,p+':value'
for p in paths:
 label='/batch' if p==B else '/export_basis' if p==E else '/replays/'+Path(p).name
 compare(before[p],after[p],label)
assert visited==allowed
# Recompute direct Godot canonical checksums, then verify all nested/replay links.
def canonical(v):
 if isinstance(v,dict):return {k:canonical(v[k]) for k in sorted(v)}
 if isinstance(v,list):return [canonical(x) for x in v]
 if isinstance(v,float) and v.is_integer():return int(v)
 return v
frames=0
for collection,basis in [(before,oldbasis),(after,newbasis)]:
 b=collection[B];assert len(b['accepted'])==36 and len(b['itineraries'])==18 and len(b['connection_proofs'])==18 and b['rejected']==[]
 manifests={x['manifest']['id']:x['manifest'] for x in b['accepted']};manifests.update({x['id']:x for x in b['itineraries']});assert len(manifests)==54
 count=0
 for mid,m in manifests.items():
  c=copy.deepcopy(m);expected=c.pop('hash');actual=sha(json.dumps(canonical(c),ensure_ascii=False,separators=(',',':')).encode());assert expected==actual and m['basis']==basis
  for phrase in m.get('phrases',[]):assert phrase==manifests[phrase['id']]
  p='resources/foundry/replays/'+mid+'.json';r=collection[p]
  assert set(r)=={'basis','capability_profile','frames','manifest_hash','schema'} and r['basis']==basis and r['manifest_hash']==actual and r['capability_profile']==m['capability_profile']
  assert all(set(f)=={'actions','axis','position','shots'} for f in r['frames']);count+=len(r['frames'])
 assert count==56113
 frames=count
# Actual independently authored nonprovenance mutants, including same-number type changes.
rp=sorted(replays)[0];r=after[rp];basepath='/replays/'+Path(rp).name
controls=[]
for label,mutate in [
 ('same_value_axis_float_to_int',lambda x:x['frames'][0].update(axis=int(x['frames'][0]['axis']))),
 ('same_value_position_float_to_int',lambda x:x['frames'][0]['position'].__setitem__(0,int(x['frames'][0]['position'][0]))),
 ('shot_count_changed',lambda x:x['frames'][0].update(shots=x['frames'][0]['shots']+1)),
 ('action_added',lambda x:x['frames'][0]['actions'].append('jump'))]:
 bad=copy.deepcopy(r);mutate(bad)
 # Compare at frames subtree so unchanged new provenance need not pretend to be old basis.
 try:compare(r['frames'],bad['frames'],basepath+'/frames')
 except AssertionError as e:controls.append({'name':label,'refused':str(e)})
 else:raise AssertionError('accepted '+label)
for label,mutate in [('repair_attempt_changed',lambda x:x['accepted'][0].update(repair_attempt=x['accepted'][0]['repair_attempt']+1)),('route_identity_changed',lambda x:x['accepted'][0]['manifest'].update(id=x['accepted'][0]['manifest']['id']+'x'))]:
 bad=copy.deepcopy(nb);mutate(bad)
 try:compare(ob['accepted'][0],bad['accepted'][0],'/batch/accepted/0')
 except AssertionError as e:controls.append({'name':label,'refused':str(e)})
 else:raise AssertionError('accepted '+label)
# All203 exact basis inputs: only accepted-hit Actor differs.
basis=load(D/'independent_basis_delta.json');assert len(basis['entries'])==203
oldrows=[];newrows=[];changed=[]
for row in basis['entries']:
 p=row['path'];a=sha(git(H,p));b=sha(git(C2,p));assert a==row['before_sha256'] and b==row['after_sha256'];oldrows.append((row['res_path'],a));newrows.append((row['res_path'],b))
 if a!=b:changed.append(p)
assert changed==['scripts/enemies/enemy_actor.gd']
engine=before[E]['engine'];assert engine==after[E]['engine']
for rows,want in [(oldrows,oldbasis),(newrows,newbasis)]:assert sha('\n'.join([engine]+[p+':'+h for p,h in rows]).encode())==want
s0=load(D/'source_before.json');s1=load(D/'source_after.json');assert s0.keys()==s1.keys() and len(s0)==1861 and sorted(p for p in s0 if s0[p]!=s1[p])==paths
for p in paths:assert sha(git(C1,p))==s0[p] and sha(git(C2,p))==s1[p]
# Source before/after matches the immutable C1/C2 trees via prior checked source + exact Git delta.
# Independently hash code/resources in the declared203 basis plus raw56 output; no engine started.
for row in basis['entries']:assert s0[row['path']]==s1[row['path']]==row['after_sha256']
assert sha(git(C2,'scripts/enemies/enemy_actor.gd'))==load(O/'C1_independent_audit.json')['actual_actor_dirty_before_after_sha']
# Exact successful commands, unchanged caps; original diagnostics scans.
commands=[]
for stem,cap in [('build36_18',1000),('export_stamp',90)]:
 c=load(D/(stem+'.json'));assert c['exit_code']==0 and not c['timed_out'] and c['timeout_seconds']==cap and c['elapsed_seconds']<cap
 log=(D/(stem+'.log')).read_text();assert not any(x in log for x in ['SCRIPT ERROR:','Parse Error:','SHADER ERROR:','Shader compilation failed','ObjectDB instances leaked','resources still in use','ERROR:'])
 commands.append(c)
assert 'Validated 36 development phrases; 18 continuous itineraries.' in (D/'build36_18.log').read_text();assert newbasis in (D/'export_stamp.log').read_text()
idx=load(D/'index.json');zp=D/'foundry-final-W11-proofs.zip';assert zp.stat().st_size==733481 and sha(zp.read_bytes())=='7137c210cf6c329e0f1a7eea29413ec7c0060bf0adf5d6e0398c0d7399d65f50'
with zipfile.ZipFile(zp) as z:
 assert z.testzip() is None
 for row in idx['members']:
  b=z.read(row['path']);assert len(b)==row['bytes'] and sha(b)==row['sha256']
 for p in paths:assert z.read('after_foundry/'+str(Path(p).relative_to('resources/foundry')))==git(C2,p)
 members=len(z.namelist())
# Textual c77f logger error preserved; executable comparator and actual56 baseline are H2.
raw=load(D/'handoff-summary.native_logger_raw.json');assert 'c77f' in raw['scope'] and 'baseline_H2' in (D/'compare.py').read_text() and load(D/'baseline_inventory.json')['baseline_commit']==H
result={'status':'PASS','reviewed_final_runtime_commit':C2,'actual_native_source_commit':C1,'baseline_resource_commit':H,'native_commands':commands,'phrases':36,'itineraries':18,'replays':54,'frames':frames,'all_fields_and_numeric_types_except_exact326_provenance_paths_equal':True,'independently_derived_exact_whitelist':sorted(allowed),'direct_old_new_manifest_hashes_recomputed':108,'same_value_types_and_action_shot_repair_identity_controls':controls,'basis_inputs':203,'basis_changed_paths':changed,'before_basis':oldbasis,'after_basis':newbasis,'guard_entries':1861,'guard_only56_resource_outputs_changed':True,'C1_to_C2_only56_resources':True,'baseline_H2_resources_all56_Git_and_R169_equal':True,'selected_zip':{'sha256':sha(zp.read_bytes()),'bytes':zp.stat().st_size,'members':members,'indexed_members_verified':len(idx['members']),'all56_output_bytes_equal_C2':True},'erratum':'Preserved raw outer logger says c77f in scope string. Actual compare.py baseline_H2, baseline inventory and all56 independently compared Git H2 blobs are correct. Authored handoff corrects text separately; original raw was not rewritten.','no_native_run_by_reviewer':True}
(O/'C2_W11_independent_audit.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'status':'PASS','frames':frames,'typed_fields':True,'hashes':108,'whitelist':len(allowed),'basis':203,'zip_members':members}))
