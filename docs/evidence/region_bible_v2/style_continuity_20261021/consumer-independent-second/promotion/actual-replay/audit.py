from pathlib import Path
import copy,hashlib,json,sys,math
ROOT=Path.cwd();sys.path[:0]=[str(ROOT/'tools')]
import run_forest_depth_versions as v
import run_forest_depth_region as r
import run_forest_depth_enemies as en
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
d=ROOT/'build/forest_depth/versions/v15-public-first';out=ROOT/'build/region_bible_v2/public-default-promotion-independent-review-first/actual-replay'
c=json.loads((d/'capture.json').read_text());receipt=json.loads((d/'receipt.json').read_text())
reports={p:json.loads((d/(p+'.json')).read_text()) for p in v.PHASES};receipts={p:json.loads((d/(p+'-receipt.json')).read_text()) for p in v.PHASES}
checks=[]
def check(ok,label,detail=None):
 checks.append(dict(label=label,passed=bool(ok),detail=detail))
 if not ok:raise AssertionError(label)
rebuilt=v.aggregate(reports,receipts,c['run_id'],c['verifier_sources'],d)
check(rebuilt==c,'actual_full_aggregate_rebuilt_from_original_two_native_files')
check(receipt['passed'] is True and receipt['source_guard'] is True,'original_success_and_stable_native_receipt')
check(c['assertions']==327 and c['capture_schema']==6 and len(c['cases'])==24 and c['failures']==0,'original327_schema6_24_preserved')
mutants=[]
for mapno in (1,2):
 def row(data):return next(x for x in data['cases'] if x['id']=='fruit_candidate_and_public_layout' and x['map']==mapno)
 base=row(c);check(base['default_manifest']==base['expected_public_manifest'],'actual_v15_whole_expected_map'+str(mapno))
 changes={
 'missing_expected':lambda x:x.pop('expected_public_manifest'),
 'default_geometry':lambda x:x['default_manifest']['platforms'][0]['rect'].__setitem__(0,x['default_manifest']['platforms'][0]['rect'][0]+.001),
 'expected_geometry':lambda x:x['expected_public_manifest']['platforms'][0]['rect'].__setitem__(0,x['expected_public_manifest']['platforms'][0]['rect'][0]+.001),
 'expected_false_to_zero':lambda x:x['expected_public_manifest'].__setitem__('production_pool',0),
 'default_false_to_zero':lambda x:x['default_manifest'].__setitem__('production_pool',0),
 'expected_map_float':lambda x:x['expected_public_manifest'].__setitem__('map_index',float(mapno)),
 'default_map_float':lambda x:x['default_manifest'].__setitem__('map_index',float(mapno)),
 'expected_map_bool':lambda x:x['expected_public_manifest'].__setitem__('map_index',True),
 'default_map_bool':lambda x:x['default_manifest'].__setitem__('map_index',True),
 'default_version':lambda x:x['default_manifest'].__setitem__('version','thorn-forest-region-v999'),
 'expected_layout14':lambda x:x['expected_public_manifest'].__setitem__('layout_version','forest-fruit-routes-v14'),
 'expected_seed':lambda x:x['expected_public_manifest'].__setitem__('seed','forged'),
 'default_region':lambda x:x['default_manifest'].__setitem__('region','windchime_plains'),
 'default_ungranted_capability':lambda x:x['default_manifest'].__setitem__('requires',['grapple','double_jump']),
 'default_geometry_nan':lambda x:x['default_manifest']['platforms'][0]['rect'].__setitem__(0,float('nan')),
 'expected_geometry_nan':lambda x:x['expected_public_manifest']['platforms'][0]['rect'].__setitem__(0,float('nan')),
 }
 for label,change in changes.items():
  data=copy.deepcopy(c);change(row(data))
  try:v.validate_fruit_version(data)
  except (ValueError,TypeError) as e:mutants.append(dict(map=mapno,label=label,rejected=True,reason=str(e)))
  else:raise AssertionError('accepted '+str(mapno)+'/'+label)
result=dict(verdict='ACCEPT_SCOPED_SOURCE_AND_FRESH_ACTUAL_VERSION_CONSUMER',checks=checks,actual_negative_controls=mutants,original_native_dir=str(d.relative_to(ROOT)),original_files={p.name:sha(p) for p in d.iterdir() if p.is_file()},source_sha256={'tools/run_forest_depth_versions.py':sha(ROOT/'tools/run_forest_depth_versions.py')},limitations=['Pure offline replay; reviewer ran no native engine','Runtime registry/version compatibility only; no claim for entire80 route corpus or art acceptance'])
(out/'report.json').write_text(json.dumps(result,indent=2)+'\n')
# Full actual ecology gate, no mocks or fabricated positive evidence.
ed=ROOT/'build/forest_depth/ecology/v15-consumer-entry-fourth/00-entry_wait/capture.json';ec=json.loads(ed.read_text());eo=ROOT/'build/region_bible_v2/entry-shot-roundoff-independent-review-first'
en.validate_formal_choice(ec)
shot=next(e for e in ec['events'] if e.get('kind')=='shot_fired' and e['tick']==1331)
req=next(x for x in ec['requests'] if x.get('kind')=='shoot_release' and x.get('tick')==1331 and x.get('queued')is True)
negative=[]
def change_data(label,fn):
 data=copy.deepcopy(ec);fn(data)
 reasons=r.validate(data)
 if 'shot_not_actual_router_request' not in reasons:raise AssertionError(label+str(reasons))
 negative.append(dict(label=label,rejected=True,expected_label_present=True))
def request(data):return next(x for x in data['requests'] if x.get('kind')=='shoot_release' and x.get('tick')==1331 and x.get('queued')is True)
def event(data):return next(x for x in data['events'] if x.get('kind')=='shot_fired' and x['tick']==1331)
change_data('request_direction_rotated_001',lambda d:request(d).__setitem__('aim',[math.cos(3*math.pi/4+.001),math.sin(3*math.pi/4+.001)]))
change_data('shot_direction_opposite',lambda d:event(d).__setitem__('aim',[-a for a in shot['aim']]))
change_data('actual_tick_mismatch',lambda d:request(d).__setitem__('tick',1330))
change_data('unqueued_request',lambda d:request(d).__setitem__('queued',False))
change_data('missing_actual_request',lambda d:d['requests'].remove(request(d)))
for value,label in [(None,'missing'),([], 'empty'),([0,0],'zero'),([2,0],'nonunit'),([True,0],'bool'),([float('nan'),0],'nan'),([float('inf'),0],'inf'),([1,0,0],'3d')]:
 for side in ('request','shot'):
  change_data(side+'_'+label,lambda d,value=value,side=side:(request(d) if side=='request' else event(d)).__setitem__('aim',value))
jsonout=dict(verdict='ACCEPT_SCOPED_NUMERIC_CONTRACT_AND_OFFLINE_ACTUAL_ENTRY',source_sha256={'tools/run_forest_depth_region.py':sha(ROOT/'tools/run_forest_depth_region.py')},actual_capture=str(ed.relative_to(ROOT)),actual_capture_sha256=sha(ed),full_unmocked_formal_choice_passed=True,route=dict(completed_legs=len(ec['completed_legs']),frames=len(ec['frames']),min_hp=min(f['snapshot']['health'] if 'snapshot' in f and 'health'in f['snapshot'] else f.get('health',999) for f in ec['frames'])),actual_roundoff=dict(tick=1331,queued=req['aim'],fired=shot['aim'],distance=math.dist(req['aim'],shot['aim'])),actual_negative_controls=negative,limitations=['Native source receipt from before reader repair stays original wrapper failure; offline replay does not rewrite it','Fresh native source-bound wrapper still pending','No runtime or production writes by reviewer'])
(eo/'report.json').write_text(json.dumps(jsonout,indent=2)+'\n')
print(json.dumps({'version_checks':len(checks),'version_negatives':len(mutants),'shot_negatives':len(negative),'actual_direction_distance':jsonout['actual_roundoff']['distance']}))
