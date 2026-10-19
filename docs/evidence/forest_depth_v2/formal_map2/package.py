from pathlib import Path
import hashlib,json,io,tarfile,importlib.util,copy
R=Path.cwd();O=R/'build/forest_depth/region/map2-eight-selected';sha=lambda b:hashlib.sha256(b).hexdigest();members={};rows=[]
plan=[('map2_formal02','map2_formal02'),('map2_formal02','map2_formal03'),('map2_formal04','map2_formal04'),('map2_formal05','map2_formal06'),('map2_formal05','map2_formal07')]
def add(name,path):
 assert name not in members and not name.startswith('/') and '..' not in Path(name).parts
 members[name]=path.read_bytes()
for snapshot,output in plan:
 S=R/'build/forest_depth/snapshots'/snapshot;P=S/'build/forest_depth/region'/output;receipt=json.loads((P/'receipt.json').read_text());assert receipt['status']=='passed' and receipt['source_stable']
 spec=importlib.util.spec_from_file_location('validator_'+output,S/'tools/run_forest_depth_region.py');v=importlib.util.module_from_spec(spec);spec.loader.exec_module(v)
 for run in receipt['runs']:
  assert run['status']=='passed' and run['exit_code']==0 and run['errors']==[]
  C=next(P.glob('*-'+run['route']+'/capture.json'));d=json.loads(C.read_text());assert not v.validate(d)
  row={'snapshot':snapshot,'output':output,'seed':d['seed'],'map':d['actual_stage_map'],'route':d['route'],'choices':d['manifest']['choices'],'frames':len(d['frames']),'legs':len(d['completed_legs']),'health':[d['initial_snapshot']['health'],d['final_snapshot']['health']],'cache_claimed':d['cache_claimed'],'duplicate_checked':d['duplicate_checked'],'gate_open':d['gate_saved_open'],'capture_sha256':sha(C.read_bytes()),'native_exit_code':run['exit_code'],'strict_errors':run['errors'],'policy_player_damage':[e for e in d['events'] if e['kind']=='committed_damage' and e['target']=='player'],'change_mind_events':[e for e in d['events'] if e['kind']=='actual_route_goal_changed'],'relay_methods':[e for e in d['events'] if e['kind']=='candidate_relay_method']}
  rows.append(row)
 for f in P.rglob('*'):
  if f.is_file() and f.suffix in ['.json','.log'] and not any(part.startswith('import-') for part in f.relative_to(P).parts):add('actual/'+output+'/'+str(f.relative_to(P)),f)
 add('contexts/'+snapshot+'/snapshot-receipt.json',S/'build/snapshot-receipt.json') if 'contexts/'+snapshot+'/snapshot-receipt.json' not in members else None
 selected=['project.godot','scripts/generation/thorn_forest_region_v2.gd','scripts/generation/forest_boss_arena_factory.gd','scripts/generation/forest_hollow_trunk_geometry.gd','scripts/demo/demo_app.gd','scripts/demo/thorn_forest_region_stage.gd','tests/forest_depth_region_trace.gd','tests/forest_depth_region_runner.gd','tools/run_forest_depth_region.py','config/player_tuning.json','resources/player/traversal.tres','scripts/player/traversal_definition.gd','scripts/input/input_router.gd']
 for relative in selected:
  name='producer/'+snapshot+'/'+relative
  if name not in members:add(name,S/relative)
for n in ['01','02','03','04','05','06','07']:
 P=R/f'build/forest_depth/region/map2-formal{n}-outer'
 for f in P.glob('*'):
  if f.is_file() and f.suffix in ['.py','.json','.log']:add('outer/'+P.name+'/'+f.name,f)
# Preserve original two native/validator failures, without relabeling either.
for snapshot,output in [('map2_formal01','map2_formal01'),('map2_formal04','map2_formal05')]:
 S=R/'build/forest_depth/snapshots'/snapshot;P=S/'build/forest_depth/region'/output
 for f in P.rglob('*'):
  if f.is_file() and f.suffix in ['.json','.log'] and not any(part.startswith('import-') for part in f.relative_to(P).parts):add('retained-failures/'+output+'/'+str(f.relative_to(P)),f)
 add('retained-failures/'+output+'/snapshot-receipt.json',S/'build/snapshot-receipt.json')
 for relative in ['tests/forest_depth_region_trace.gd','tools/run_forest_depth_region.py']:
  add('retained-failures/'+output+'/producer/'+relative,S/relative)
for f in (R/'build/forest_depth/region/map2-copy-disk-failure').glob('*'):
 if f.is_file() and f.suffix in ['.json','.py']:add('copy-failure/'+f.name,f)
assert len(rows)==8 and len({(x['seed'],x['route']) for x in rows})==8
summary={'status':'eight_actual_routes_strict_passed','scope':'Author implementation evidence only: actual normal DemoApp explicit experimental v2 debug spawn, both map2 families four routes each. No Boss fight, independent acceptance, fun/device or fullrelease claims. Two original failed attempts remain rejected; coldcopy disk failure remains rejected.','base_commit':'0dd1fba0bffba707d873155fc506f874d3651565','source_scope':'Each case is a genuine source snapshot plus dirty overlay, not clean HEAD. Its original receipt inventories bind exact producer; do not collapse multiple source overlays.','budgets':{'CLI_editor_import':90,'each_native_case':240,'each_route_ticks':18000,'each_edge_ticks':1800},'rows':rows,'limitations':['Growth routes arrive with HP1 and HP2 under this noncombat route policy; passing does not approve difficulty or claim forced damage.','Both samples use enemy_mix1; these traces do not cover mix0 in map2 or ten seeds.','Shared-node north_reward is normal descent with no extra H/R, not proof of H necessity.','Change-mind is an authored branch at real E support, not spontaneous player decision or discovery.','Current default remains v1; no Queen wholefight/content promotion.']}
(O/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');members['summary.json']=(O/'summary.json').read_bytes()
index={n:sha(b) for n,b in sorted(members.items())};members['members.json']=(json.dumps(index,indent=2)+'\n').encode();archive=O/'map2-eight-selected.tar.gz'
with tarfile.open(archive,'w:gz') as t:
 for n,b in sorted(members.items()):
  info=tarfile.TarInfo(n);info.size=len(b);info.mode=0o644;t.addfile(info,io.BytesIO(b))
with tarfile.open(archive,'r:gz') as t:
 actual={m.name:t.extractfile(m).read() for m in t.getmembers() if m.isfile()};assert len(actual)==len(members)
 assert all(sha(actual[n])==h for n,h in index.items())
receipt={'status':'author_selected_package_integrity_verified','archive':str(archive),'sha256':sha(archive.read_bytes()),'bytes':archive.stat().st_size,'regular_members':len(members),'indexed_members':len(index),'offline_actual_original_validators_accepted':8,'scope':summary['scope'],'safe_member_paths':True,'independent_review':'not performed by this implementation author'};(O/'archive-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(receipt))
