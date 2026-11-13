"""Candidate geometry, interface migration and player progression regressions."""
import copy,json,sys,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools/world'))
from export_editor_project import export
from spatial_adjustments import world_for_draft,review_route_plans
from world_review import build,validate_assembly,validate_shared_door,validate_review_path
from simulate_world import Model,State

class WorldSpatialLayout(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.base=export();cls.p=export(spatial_draft=True);cls.plan,_=build(cls.p)
  cls.world=world_for_draft(ROOT,json.loads((ROOT/'config/world/world.json').read_text()))
  cls.manifest=json.loads((ROOT/'config/world/spatial_layout.json').read_text())
 def test_complete_world_with_eight_purposeful_new_rooms(self):
  self.assertEqual((len(self.base['rooms']),len(self.base['connections'])),(309,409))
  self.assertEqual((len(self.p['rooms']),len(self.p['connections'])),(317,415))
  self.assertEqual(self.plan['checks'],{'rooms':317,'cross_region_seams':30,'overlaps':0,'unresolved_connections':0})
  self.assertEqual(len(self.plan['transitions']),20)
  for rid,r in self.p['rooms'].items():
   self.assertNotEqual(r['spatial_source']['kind'],'unplaced')
   if rid not in self.base['rooms']:
    self.assertEqual(r['entities'],{});self.assertFalse(r['implemented'])
    self.assertEqual(self.p['management'][rid]['development'],'unbuilt')
 def test_runtime_entities_rewards_npcs_and_approval_are_preserved(self):
  self.assertEqual(self.p['rewards'],self.base['rewards']);self.assertEqual(self.p['npcs'],self.base['npcs'])
  for rid,r in self.base['rooms'].items():
   for key in ['entities','implemented','authored']:self.assertEqual(self.p['rooms'][rid][key],r[key],(rid,key))
   self.assertEqual(self.p['management'][rid],self.base['management'][rid])
   if rid[0]=='P':
    for key in ['origin','bounds','spaces']:self.assertEqual(self.p['rooms'][rid][key],r[key],(rid,key))
 def test_all_candidate_ports_are_reciprocal_and_bound_to_sections(self):
  for e in self.p['connections'].values():
   for side,other in [('a','b'),('b','a')]:
    ep=e[side];r=self.p['rooms'][ep['room']];p=r['ports'][ep['port']]
    self.assertIn(p['section'],r['sections'],e['id'])
    self.assertEqual((p['target_room'],p['target_port']),(e[other]['room'],e[other]['port']))
 def test_region_programs_have_real_landmarks_and_review_routes(self):
  programs=self.plan['region_programs'];routes={r['id'] for r in self.plan['routes']}
  self.assertEqual(set(programs),{r['code'] for r in self.plan['regions']})
  self.assertEqual(self.p['planning']['region_programs'],programs)
  for code,program in programs.items():
   for key in ('geography','first_visit','return_visit','repair_effect','branch_tradeoff'):
    self.assertTrue(program[key].strip(),(code,key))
   for rid in program['landmark_rooms']:
    self.assertIn(rid,self.p['rooms']);self.assertEqual(rid[0],code)
   self.assertTrue(set(program['route_ids'])<=routes,code)
 def test_outer_observation_route_stays_before_final_seal(self):
  edges={e['id']:e for e in self.world['connections']}
  self.assertEqual((edges['room-link-154']['a'],edges['room-link-154']['b']),('Z-R10','Z-R17'))
  self.assertEqual(edges['C25']['a'],'Z-R18')
  self.assertEqual(edges['L19']['a_section'],'main')
  self.assertEqual(edges['L19']['requires'],next(e['requires'] for e in json.loads((ROOT/'config/world/world.json').read_text())['connections'] if e['id']=='L19'))
 def test_scanline_partition_preserves_concave_room_without_tiny_grid_cells(self):
  from forest_review import rectangles
  from spatial import room_space
  poly=[[0,0],[1200,0],[1200,400],[800,400],[800,1000],[400,1000],[400,400],[0,400]]
  rs=rectangles(poly)
  self.assertEqual(sum(w*h for x,y,w,h in rs),720000)
  self.assertEqual(len(rs),2)
  result=room_space(rs,[1200,1000])
  self.assertEqual({tuple(p) for p in result['outline']},{tuple(p) for p in poly})
 def test_review_path_cannot_draw_through_a_void(self):
  polygons={'a':[[0,0],[100,0],[100,100],[0,100]],'b':[[200,0],[300,0],[300,100],[200,100]]}
  with self.assertRaisesRegex(AssertionError,'Review path leaves rooms'):
   validate_review_path({'id':'bad','a':'a','b':'b','path':[[50,50],[250,50]]},polygons)
 def test_room_outline_is_complete_geometry_not_reconstructed_from_routes(self):
  from regional_review import compile_plan
  from forest_review import rectangles
  cache={}
  for source in self.manifest['cluster_sources']:
   plan=compile_plan(ROOT,cluster=Path(source).stem,_cache=cache)
   raw=json.loads((ROOT/source).read_text())
   for r in raw['rooms']:
    compiled=next(a for a in plan['rooms'] if a['room_id']==r['room_id'])
    self.assertEqual(sum(w*h for x,y,w,h in rectangles(r['outline'])),sum(w*h for x,y,w,h in rectangles(compiled['outline'])))
 def test_misplaced_seam_fails_even_if_room_outlines_touch(self):
  changed=copy.deepcopy(self.p);e=changed['connections']['C08'];ep=e['b']
  changed['rooms'][ep['room']]['ports'][ep['port']]['position'][0]+=32
  with self.assertRaisesRegex(AssertionError,'Seam drift C08'):validate_assembly(self.plan,changed)
 def test_point_contact_and_backwards_normals_are_not_usable_doors(self):
  def room(rid,origin,pos,direction,height=256):
   return {'id':rid,'origin':origin,'bounds':[0,0,256,height],'spaces':[[0,0,256,height]],'ports':{'p':{'position':pos,'direction':direction}}}
  rooms={'a':room('a',[0,0],[256,128],'right'),'b':room('b',[256,0],[0,128],'left')}
  edge={'id':'test','a':{'room':'a','port':'p'},'b':{'room':'b','port':'p'},'spatial_draft':{'width':192}}
  validate_shared_door(rooms,edge)
  rooms['b']=room('b',[256,96],[0,32],'left',height=64)
  with self.assertRaisesRegex(AssertionError,'Mouth clearance'):validate_shared_door(rooms,edge)
  rooms['b']=room('b',[256,0],[0,128],'right')
  with self.assertRaisesRegex(AssertionError,'Normals'):validate_shared_door(rooms,edge)
 def test_p07_and_explicit_transport_keep_identity_without_fake_corridor(self):
  e=self.p['connections']['CITY-P-G-WEST']
  self.assertEqual(e['a']['room'],'P-R07');self.assertEqual(e['b']['room'],'G-R02')
  self.assertEqual(e['spatial_draft']['kind'],'field_freight_tram');self.assertTrue(e['front_door'])
  self.assertNotIn('path',e['spatial_draft'])
  for cid,kind in [('L22','well_lift'),('G-P18-L25','freight_lift')]:
   e=self.p['connections'][cid];self.assertEqual(e['spatial_draft']['kind'],kind)
   self.assertEqual(e['requires'],self.base['connections'][cid]['requires'])
 def test_removed_connections_leave_no_orphan_ports_or_candidate_edges(self):
  for cid in ['C17','room-link-065']:
   self.assertNotIn(cid,self.p['connections'])
   self.assertFalse(any(p['connection']==cid for r in self.p['rooms'].values() for p in r['ports'].values()))
 def test_new_entrances_do_not_bypass_ability_sections(self):
  model=Model(self.world);self.assertEqual(model.warnings,[])
  for origin,target,without,grant in [
   (('E-R15','entry:C22'),('E-R15','main'),{'gun','H','D','smith'},'Q'),
   (('N-R05','entry:L12'),('N-R05','main'),{'gun','H'},'D')]:
   self.assertIsNone(model.search(State(*origin,tokens=without),targets=[target],allow_teleport=False))
   self.assertIsNotNone(model.search(State(*origin,tokens=without|{grant}),targets=[target],allow_teleport=False))
  self.assertNotIn('entry:C22',self.p['rooms']['E-R12']['sections'])
  self.assertIn('entry:C22',self.p['rooms']['E-R15']['sections'])
 def test_repaired_furnace_opens_reward_return_not_before(self):
  m=Model(self.world);tokens={'gun','H','W','D','Q','smith'}
  self.assertIsNone(m.search(State('E-R15',tokens=tokens),targets=[('E-R10','main')],allow_teleport=False))
  self.assertIsNotNone(m.search(State('E-R15',tokens=tokens|{'clock_E'}),targets=[('E-R10','main')],allow_teleport=False))
 def test_four_current_journeys_complete_in_section_state_model(self):
  plans=review_route_plans(ROOT);self.assertEqual(len(plans),4)
  for plan in plans:
   result=Model(self.world).replay(plan)
   self.assertTrue(result['success'],(plan['id'],result['failure']))
 def test_source_migration_does_not_duplicate_sections_actions_or_rooms(self):
  self.assertEqual(len({r['id'] for r in self.world['rooms']}),len(self.world['rooms']))
  for r in self.world['rooms']:
   self.assertEqual(len({s['id'] for s in r['sections']}),len(r['sections']),r['id'])
   self.assertEqual(len({s['id'] for s in r['internal_routes']}),len(r['internal_routes']),r['id'])
  original=json.loads((ROOT/'config/world/world.json').read_text())
  self.assertEqual({a['id'] for a in self.world['actions']},{a['id'] for a in original['actions']})

if __name__=='__main__':unittest.main()
