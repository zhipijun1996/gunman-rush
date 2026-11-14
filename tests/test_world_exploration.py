"""New order, optional weapon branches, and local-knowledge exploration checks."""
import copy,json,sys,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools/world'))
from spatial_adjustments import world_for_draft,replay_review_journey
from simulate_world import Model,State
from explore_world import explore

class WorldExploration(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.world=world_for_draft(ROOT,json.loads((ROOT/'config/world/world.json').read_text()))
  cls.manifest=json.loads((ROOT/'config/world/spatial_layout.json').read_text())
 def test_awards_and_environment_access_agree(self):
  m=Model(self.world)
  self.assertEqual(m.actions['get_W']['room_id'],'P-R14')
  self.assertEqual(m.actions['get_H']['room_id'],'F-R10')
  self.assertFalse(m.available(m.actions['get_W'],State('P-R14')))
  self.assertIsNone(m.search(State('F-R01'),targets=[('F-R10','main')],allow_teleport=False))
  for target in ['F-R10','M-R09']:
   self.assertIsNotNone(m.search(State('F-R01',tokens={'gun','W'}),targets=[(target,'main')],allow_teleport=False))
 def test_both_orders_are_executable_in_stated_room_sequence(self):
  for rid in ['branch-hook-first','branch-double-first']:
   journey=next(r for r in self.manifest['world_routes'] if r['id']==rid)
   result=replay_review_journey(self.world,journey)
   self.assertTrue({'W','H','D'}<=set(result['tokens']))
   self.assertNotIn('shuriken',result['tokens'])
 def test_rope_requires_blade_and_permanent_cut_then_cache_is_optional(self):
  m=Model(self.world);state=State('P-R29')
  action=m.actions['cut_rope_P29']
  self.assertFalse(m.available(action,state))
  self.assertIsNone(m.search(state,targets=[('P-R29','rope_cache')],allow_teleport=False))
  state.tokens.add('shuriken');m.perform(action,state)
  self.assertIsNotNone(m.search(state,targets=[('P-R29','rope_cache')],allow_teleport=False))
  self.assertFalse(m.available(action,state))
  # Reconstructed permanent receipt, no temporary falling animation state.
  restored=State('P-R29',tokens={'gun','rope_P29_cut'})
  self.assertIsNotNone(m.search(restored,targets=[('P-R29','rope_cache')],allow_teleport=False))
  retreat=State('P-R29','rope_cache')
  self.assertIsNotNone(m.search(retreat,targets=[('P-R29','main')],allow_teleport=False))
 def test_no_shuriken_explorer_can_finish_main_progression(self):
  result=explore(self.world,'no_shuriken',0,forbidden=('shuriken',))
  self.assertTrue(result['exhausted'])
  self.assertNotIn('shuriken',result['tokens'])
  self.assertTrue({'W','H','D','Q','boss_Z_KING_defeated'}<=set(result['tokens']))
  self.assertFalse(any(a.startswith('cut_rope_') for a in result['actions']))
  self.assertGreater(result['unlocked_remembered'],0)
 def test_local_explorer_does_not_grant_unreachable_awards(self):
  world=copy.deepcopy(self.world)
  for a in world['actions']:
   if a['id']=='get_W':a['requires']=[['impossible_token']]
  result=explore(world,'curious',0)
  self.assertTrue(result['exhausted'])
  self.assertNotIn('W',result['tokens']);self.assertNotIn('H',result['tokens']);self.assertNotIn('D',result['tokens'])
 def test_skill_core_cannot_be_replaced_by_rescuing_smith(self):
  m=Model(self.world);s=State('P-R10',tokens={'gun','smith'});s.inventory['skill_core']=1
  self.assertFalse(m.available(m.actions['install_skill_core_1'],s))
  s.tokens.add('found_skill_core_root');self.assertTrue(m.available(m.actions['install_skill_core_1'],s))

if __name__=='__main__':unittest.main()
