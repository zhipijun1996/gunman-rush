"""Continuous regional geometry must survive export; layout alone is not quality."""
import json,sys,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools/world'))
from export_editor_project import export
from forest_review import overlap,build
from preview_catalog import preview_catalog
class WorldSpatialLayout(unittest.TestCase):
 @classmethod
 def setUpClass(cls):cls.base=export();cls.p=export(spatial_draft=True);cls.plan=build(ROOT,preview=preview_catalog(ROOT))
 def test_only_authored_draft_regions_change_and_others_remain_unplaced(self):
  self.assertEqual(len(self.p['rooms']),309);self.assertEqual(len(self.p['connections']),409)
  for rid,r in self.p['rooms'].items():
   if rid=='P-R18':
    self.assertEqual(r['layout_status'],self.base['rooms'][rid]['layout_status']);continue
   if rid[0] not in 'FMSTYICKN' and rid not in ['P-R07','P-R18','G-R02']:self.assertEqual(r,self.base['rooms'][rid])
   else:self.assertEqual(r['layout_status'],'draft')
  self.assertEqual(self.p['rooms']['G-R16']['spatial_source']['kind'],'unplaced')
 def test_complete_chamber_area_including_passages_survives(self):
  from forest_review import rectangles
  for design in self.plan['rooms']:
   r=self.p['rooms'][design['room_id']]
   self.assertEqual(sum(s[2]*s[3] for s in r['spaces']),sum(s[2]*s[3] for s in rectangles(design['outline'])))
 def test_all_thirty_internal_ports_are_shared_seams(self):
  for c in self.plan['connections']:
   edge=self.p['connections'][c['id']]
   for side in ['a','b']:
    ep=edge[side];r=self.p['rooms'][ep['room']];pos=r['ports'][ep['port']]['position'];self.assertEqual([pos[i]+r['origin'][i] for i in (0,1)],c['seam'])
   self.assertEqual(edge['spatial_draft']['length'],0)
 def test_rewards_abilities_and_runtime_entities_preserved(self):
  self.assertEqual(self.p['rewards'],self.base['rewards']);self.assertEqual(self.p['npcs'],self.base['npcs'])
  for rid,r in self.p['rooms'].items():
   for k in ['routes','entities','implemented']:self.assertEqual(r[k],self.base['rooms'][rid][k])
 def test_underground_geometry_anchors_and_explicit_lift(self):
  from regional_review import compile_plan
  plan=compile_plan(ROOT)
  self.assertEqual(len(plan['rooms']),50)
  self.assertEqual(len(plan['connections']),59)
  self.assertFalse(plan['issues'])
  for c in plan['connections']:
   edge=self.p['connections'][c['id']]
   for side in ['a','b']:
    ep=edge[side];r=self.p['rooms'][ep['room']];pos=r['ports'][ep['port']]['position']
    self.assertEqual([pos[i]+r['origin'][i] for i in (0,1)],c['seam'])
  for cid in ['C03','C04','C13','C14']:
   e=self.p['connections'][cid];points=[]
   for side in ['a','b']:
    r=self.p['rooms'][e[side]['room']];port=r['ports'][e[side]['port']]
    points.append([r['origin'][i]+port['position'][i] for i in (0,1)])
   self.assertEqual(*points,cid)
  lift=self.p['connections']['L22']
  self.assertEqual(lift['spatial_draft']['kind'],'well_lift')
  self.assertEqual(lift['requires'],self.base['connections']['L22']['requires'])
  self.assertTrue(lift['front_door'])
  self.assertNotIn('path',lift['spatial_draft'])
 def test_northwest_and_all_existing_regions_share_world_geometry(self):
  from world_review import build,validate_assembly
  plan,_=build(self.p)
  self.assertEqual(plan['checks'],{'rooms':197,'cross_region_seams':17,'overlaps':0})
  self.assertEqual({s['id'] for s in plan['seams']},{'C01','C02','C03','C04','C08','C09','C10','C11','C12','C13','C14','C26','C28','C05','C06','C17','C31'})
  self.assertEqual(len([r for r in plan['rooms'] if r['room_id'][0] in 'YIC']),46)
  self.assertFalse(any(e['target'][0] in 'PFMSTYICKN' for e in plan['external_ports']))
  # Catch an editor/export regression that leaves matching-looking geometry but
  # a misplaced or reversed actual port.
  import copy
  changed=copy.deepcopy(self.p);edge=changed['connections']['C08'];ep=edge['b']
  changed['rooms'][ep['room']]['ports'][ep['port']]['position'][0]+=32
  with self.assertRaisesRegex(AssertionError,'Seam drift C08'):validate_assembly(plan,changed)
 def test_eastern_rooms_and_existing_named_shortcuts(self):
  from regional_review import compile_plan
  plan=compile_plan(ROOT,cluster='eastern')
  self.assertEqual(len(plan['rooms']),42)
  self.assertEqual(len(plan['connections']),47)
  identities={e['id']:e for e in json.loads((ROOT/'config/world/world.json').read_text())['connections']}
  for cid in ['SC-K01','SC-N01']:
   self.assertTrue(identities[cid]['passage_profile'].startswith('paired named passage/lift stops'))
   self.assertEqual(self.p['connections'][cid]['spatial_draft']['kind'],'named_shortcut')
   self.assertNotIn('path',self.p['connections'][cid]['spatial_draft'])
  self.assertFalse(self.p['connections']['CITY-P-G-WEST']['front_door'])
 def test_city_entrance_moves_to_p07_without_moving_plains_rooms(self):
  from spatial_adjustments import designs
  from world_review import on_boundary,build
  from spatial import room_space
  for rid in ['P-R07','P-R18']:
   for field in ['origin','bounds','spaces','entities']:
    self.assertEqual(self.p['rooms'][rid][field],self.base['rooms'][rid][field],(rid,field))
  edge=self.p['connections']['CITY-P-G-WEST']
  self.assertEqual(edge['a'],{'room':'P-R07','port':'CITY-P-G-WEST:P-R07'})
  self.assertEqual(edge['b']['room'],'G-R02')
  self.assertNotIn('CITY-P-G-WEST:P-R18',self.p['rooms']['P-R18']['ports'])
  self.assertEqual(self.base['connections']['CITY-P-G-WEST']['a']['room'],'P-R18')
  for cid in ['room-link-133','room-link-134','CITY-P-G-WEST']:
   e=self.p['connections'][cid];points=[]
   for side in ['a','b']:
    ep=e[side];r=self.p['rooms'][ep['room']];port=r['ports'][ep['port']]
    points.append([port['position'][i]+r['origin'][i] for i in (0,1)])
    shape=room_space(r['spaces'],r['bounds'][2:])
    self.assertTrue(on_boundary(shape['outline'],port['position']),cid)
    other=e['b' if side=='a' else 'a']
    self.assertEqual((port['target_room'],port['target_port']),(other['room'],other['port']))
   self.assertEqual(*points,cid)
  plan,_=build(self.p);p07=next(r for r in plan['rooms'] if r['room_id']=='P-R07');p18=next(r for r in plan['rooms'] if r['room_id']=='P-R18')
  self.assertTrue(any(n['room']=='G-R02' for n in p07['neighbors']))
  self.assertFalse(any(n['room']=='G-R02' for n in p18['neighbors']))
  self.assertEqual(self.p['connections']['G-P18-L25'],self.base['connections']['G-P18-L25'])
 def test_draft_does_not_change_gate_or_reward_progression(self):
  for cid,e in self.p['connections'].items():
   for key in ['requires','direction','a','b']:
    if cid=='CITY-P-G-WEST' and key=='a':continue
    self.assertEqual(e[key],self.base['connections'][cid][key])
  for rid in self.p['rooms']:
   self.assertEqual(self.p['management'][rid],self.base['management'][rid])
if __name__=='__main__':unittest.main()
