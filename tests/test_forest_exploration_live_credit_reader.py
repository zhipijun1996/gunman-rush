"""Real H Policy receipts must never become fabricated projectile refunds."""
import copy
import importlib.util
from pathlib import Path
import sys
import unittest

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
spec=importlib.util.spec_from_file_location('v16_live_credit',ROOT/'tools/run_forest_exploration_motor.py')
reader=importlib.util.module_from_spec(spec)
spec.loader.exec_module(reader)


def actual_contact_sample():
    actor='exploration__district_1_main_b__forest_swing_pod'
    before={'shot_economy':{'owner_id':231743687639,'session_id':2,'combat_packets':{},'hits':{}},'enemies':[{'id':actor,'motor_instance':284340260823,'health':2.}]}
    after=copy.deepcopy(before);after.update(tick=2084);after['enemies'][0]['health']=1.;after['shot_economy']['combat_packets']={'2/hook/2':7.}
    events=[{'tick':2084,'kind':'hook_contact_kick','target_actor_id':actor,'target_instance':284340260823,'position':[4939.4697265625,903.119567871094],'hook_tip':[4915.45947265625,885.133178710938]},
            {'tick':2084,'kind':'committed_damage','event_id':'hook/231743687639/2/2','target':actor,'source':'player_projectile:231743687639','amount':1.,'damage_kind':0,'health_after':1.,'lethal':False}]
    data={'manifest':{'enemies':[{'id':actor,'behavior_id':'forest_swing_pod'}]}}
    return data,after,before,events


class LiveCreditAndClearance(unittest.TestCase):
    def test_actual_native12_H_has_independent_contact_policy_HP_and_ledger(self):
        self.assertEqual(reader.actual_hook_combat_packets(*actual_contact_sample(),7),({'2/hook/2'},[]))

    def test_missing_contact_wrong_actor_HP_or_receipt_are_rejected(self):
        for mutation in ('missing_contact','motor','hp','packet','owner'):
            data,after,before,events=actual_contact_sample()
            if mutation=='missing_contact':events=events[1:]
            elif mutation=='motor':events[0]['target_instance']+=1
            elif mutation=='hp':after['enemies'][0]['health']=2.
            elif mutation=='packet':after['shot_economy']['combat_packets']={'2/hook/99':7.}
            elif mutation=='owner':events[1]['source']='player_projectile:1'
            with self.subTest(mutation=mutation):
                self.assertIn('actual_living_hook_combat_evidence',reader.actual_hook_combat_packets(data,after,before,events,7)[1])

    def test_actual_float32_Vector2_foot_and_material_mutation(self):
        position=[1060.53173828125,1013.33514404297]
        self.assertTrue(reader.actual_player_foot(position,[1060.53173828125,1031.33520507812]))
        self.assertFalse(reader.actual_player_foot(position,[1060.53173828125,1031.33620507812]))
        self.assertFalse(reader.actual_player_foot(position,[True,1031.33520507812]))
        # Native14 is exactly a float32 midpoint after +18. Restore the
        # independently serialized source before applying ties-to-even.
        midpoint=[5299.99462890625,1019.63092041016]
        self.assertTrue(reader.actual_player_foot(midpoint,[5299.99462890625,1037.630859375]))
        self.assertFalse(reader.actual_player_foot(midpoint,[5299.99462890625,1037.6309814453125]))

    def test_same_long_root_requires_authored_receiver_not_early_whole_root(self):
        leg={'kind':'jump_gap','from_support_id':'long_root','support_id':'long_root','landing':[300.,82.]}
        self.assertFalse(reader.same_support_landing_clearance(leg,{'position':[100.,20.]}))
        self.assertTrue(reader.same_support_landing_clearance(leg,{'position':[290.,20.]}))


if __name__=='__main__':unittest.main()
