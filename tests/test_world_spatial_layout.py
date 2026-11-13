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
 def test_only_forest_calibration_changes_and_others_remain_unplaced(self):
  self.assertEqual(len(self.p['rooms']),309);self.assertEqual(len(self.p['connections']),409)
  for rid,r in self.p['rooms'].items():
   if not rid.startswith('F-'):self.assertEqual(r,self.base['rooms'][rid])
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
if __name__=='__main__':unittest.main()
