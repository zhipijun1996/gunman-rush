"""World proposal integrity, without installing its geometry into the runtime."""
import json,sys,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools/world'))
from export_editor_project import export
from forest_review import overlap
class WorldSpatialLayout(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.base=export();cls.p=export(spatial_draft=True);cls.d=json.loads((ROOT/'config/world/spatial_layout.json').read_text())
 def test_complete_identity_and_gameplay_preservation(self):
  self.assertEqual(len(self.p['rooms']),309);self.assertEqual(len(self.p['connections']),409)
  self.assertEqual(self.base['rewards'],self.p['rewards']);self.assertEqual(self.base['npcs'],self.p['npcs'])
  for rid,r in self.p['rooms'].items():
   for key in ['entities','routes','implemented','authored','root']:self.assertEqual(r[key],self.base['rooms'][rid][key],(rid,key))
  for cid,c in self.p['connections'].items():self.assertEqual({k:v for k,v in c.items() if k!='spatial_draft'},self.base['connections'][cid])
 def test_all_room_spaces_nonoverlap_in_same_layer(self):
  rooms=list(self.p['rooms'].values())
  for i,a in enumerate(rooms):
   for b in rooms[i+1:]:
    if a['layer']!=b['layer']:continue
    for x,y,w,h in a['spaces']:
     for u,v,ww,hh in b['spaces']:
      self.assertFalse(overlap([x+a['origin'][0],y+a['origin'][1],w,h],[u+b['origin'][0],v+b['origin'][1],ww,hh]),(a['id'],b['id']))
 def test_proposed_passages_end_at_their_ports_and_avoid_third_rooms(self):
  for cid,c in self.p['connections'].items():
   design=c['spatial_draft'];self.assertNotEqual(design['kind'],'interface_needs_review')
   for ep,at in [(c['a'],design['path'][0]),(c['b'],design['path'][-1])]:
    r=self.p['rooms'][ep['room']];self.assertEqual(at,[r['origin'][i]+r['ports'][ep['port']]['position'][i] for i in (0,1)])
   if design['kind']!='passage_draft':continue
   ids=[c['a']['room'],c['b']['room']];layer=self.p['rooms'][ids[0]]['layer']
   for a,b in zip(design['path'],design['path'][1:]):
    self.assertTrue(a[0]==b[0] or a[1]==b[1],cid)
    for rid,r in self.p['rooms'].items():
     if rid in ids or r['layer']!=layer:continue
     for x,y,w,h in r['spaces']:
      self.assertFalse(overlap([min(a[0],b[0])-48,min(a[1],b[1])-48,abs(a[0]-b[0])+96,abs(a[1]-b[1])+96],[x+r['origin'][0],y+r['origin'][1],w,h]),(cid,rid))
 def test_existing_geometry_remains_default_and_adaptations_are_explicit(self):
  for rid,r in self.p['rooms'].items():
   if self.d['rooms'][rid]['status']=='authored_anchor':
    for k in ['origin','spaces','bounds','ports']:self.assertEqual(r[k],self.base['rooms'][rid][k])
   else:self.assertEqual(r['spatial_source']['kind'],'spatial_draft');self.assertEqual(r['layout_status'],'draft')
  self.assertEqual(self.base['rooms']['G-R02']['origin'],[18496,768])
  self.assertEqual(self.p['rooms']['G-R02']['origin'],[26048,768])
if __name__=='__main__':unittest.main()
