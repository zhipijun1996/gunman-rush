"""Synthetic current-GOLD reader counterexamples; not native combat evidence."""
from copy import deepcopy
import json
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from run_forest_depth_campaign_boss import validate_canopy_gold


def fixture(hp_bonus=0):
    params = {'idle_delay_s': 6.0, 'resonance_per_s': 2.0, 'max_recovery_per_map': 20.0}
    raw_mods = [['max_health', 1, hp_bonus, 0]] if hp_bonus else []
    declaration = ['G07', 5, 2, 2, 0, 1, 1, ['item_v5'], [], [], [], '', 1.0,
                   [['G07', 0, [], params]], raw_mods, 5, 1, 68, params, {}]
    fingerprint = json.dumps(declaration)
    identity = {'instance_id': 'run/reward:boss', 'definition_id': 'G07',
                'definition_version': 5, 'source_id': 'reward:boss', 'level': 1,
                'fingerprint': fingerprint}
    before = {'hp': 4, 'capacity': 5, 'wallet': 1, 'count': 0, 'instances': [], 'equipped': []}
    after = {**before, 'count': 1, 'instances': [identity]}
    equipped = {**after, 'capacity': 5+hp_bonus, 'equipped': ['G07']}
    start = {'clock': 0.0, 'last_combat': 0.0, 'physics_frame': 10, 'motor_steps': 20,
             'actor_instance': 1, 'session': 2, 'actor_epoch': 3, 'resonance': 95.0,
             'capacity': 100.0, 'hp': 4, 'hp_capacity': 5+hp_bonus, 'map': 'map2',
             'recovered': 0.0, 'serial': 0, 'instance': identity['instance_id'],
             'parameters': params, 'core_modal_open': True, 'paused': True,
             'campaign_phase': 1, 'abilities': ['grapple']}
    frames, grants, previous_gain = [], [], 0.0
    for index in range(1, 433):
        clock = index/60
        gain = max(0, clock-6)*2
        if gain-previous_gain > 1e-6:
            grants.append({'receipt': 'item/G07/run/reward:boss/map2/recovery/'+str(len(grants)+1),
                           'amount': gain-previous_gain})
        frames.append({**start, 'clock': clock, 'physics_frame': 10+index,
                       'motor_steps': 20+index, 'resonance': 95+gain,
                       'recovered': gain, 'serial': len(grants), 'paused': False})
        previous_gain = gain
    debit = {'event_id': 'explicit_probe_debit', 'amount': 0.0, 'before': 95.0,
             'after': 95.0, 'accepted': True,
             'method': 'CombatEnergyState.consume; no direct assignment or grant'}
    return {'gold_definition': {'id': 'G07', 'rarity': 2, 'catalog_version': 5,
                               'level': 1, 'fingerprint': fingerprint, 'parameters': params,
                               'modifiers': [{'stat': m[0], 'operation': m[1], 'value': m[2], 'priority': m[3]} for m in raw_mods]},
            'before_gold': before, 'after_gold': after,
            'gold_equipment_fixture': {'scope': 'Explicit paused EquipmentService fixture while real core-choice modal remains open; not natural menu operation',
                                      'accepted': True, 'source_id': 'reward:boss', 'before': after,
                                      'after': equipped, 'expected_hp_capacity': 5+hp_bonus,
                                      'progression_open': True, 'core_before': ['grapple'], 'core_after': ['grapple']},
            'position_health_phase_resource_injection_scope': 'Original route/combat/reload only; postcombat debit fixture separately disclosed',
            'postcombat_resource_debit_fixture': debit,
            'gold_effect_probe': {'scope': 'Explicit real-frame passive probe with core-choice modal retained; optional CombatEnergyState debit is disclosed fixture, not a natural skill or resource grant',
                                  'kind': 'G07_idle_recovery', 'supported': True, 'parameters': params,
                                  'start': start, 'after': {**frames[-1], 'paused': True},
                                  'debit_fixture': debit, 'frames': frames, 'grants': grants},
            'before_boundary': {'item_effect': params,
                                'item_sources': [{'definition_id': 'G07', 'instance_id': identity['instance_id'], 'source_id': identity['instance_id']+'/G07', 'level': 1, 'parameters': params}],
                                'manifest': {'stages': [{'outputs': {'reward_claim': {'item': 'G07'}, 'core_ability_reward': {'ability': 'double_jump'}}}]}}}


class CanopyGoldContractTests(unittest.TestCase):
    def rejects(self, mutate):
        value = deepcopy(fixture())
        mutate(value)
        with self.assertRaises((ValueError, KeyError, TypeError)):
            validate_canopy_gold(value)

    def test_synthetic_g07_reader_positive_does_not_mutate_payload(self):
        value = fixture()
        before = deepcopy(value)
        validate_canopy_gold(value)
        self.assertEqual(value, before)

    def test_declared_plus_two_hp_modifier_still_requires_its_actual_delta(self):
        # Explicit reader-only modifier component. This retains the original
        # +2 requirement whenever the selected definition actually declares it.
        value = fixture(hp_bonus=2)
        validate_canopy_gold(value)
        value['gold_equipment_fixture']['after']['capacity'] = 5
        with self.assertRaises(ValueError): validate_canopy_gold(value)

    def test_old_identity_wrong_rarity_and_owned_snapshot_refuse(self):
        for key, value in [('id', 'forest_heart_gold'), ('rarity', 0), ('catalog_version', 0), ('level', 2)]:
            with self.subTest(key=key):
                self.rejects(lambda d: d['gold_definition'].update({key: value}))
        for key, value in [('definition_id', 'foreign'), ('definition_version', 6), ('source_id', 'wrong'), ('level', 2), ('fingerprint', 'wrong')]:
            with self.subTest(key=key):
                self.rejects(lambda d: d['after_gold']['instances'][0].update({key: value}))

    def test_automatic_equip_heal_cost_or_absent_effect_refuse(self):
        for key, value in [('capacity', 7), ('hp', 5), ('wallet', 9), ('count', 0), ('equipped', ['G07'])]:
            with self.subTest(key=key):
                self.rejects(lambda d: d['after_gold'].update({key: value}))
        self.rejects(lambda d: d['gold_equipment_fixture'].update(accepted=False))
        self.rejects(lambda d: d['gold_equipment_fixture']['core_after'].append('double_jump'))
        self.rejects(lambda d: d['gold_effect_probe'].update(grants=[]))

    def test_passive_frames_gate_rate_budget_hp_and_ownership_refuse(self):
        for key, value in [('resonance', 99), ('recovered', 99), ('hp', 5), ('hp_capacity', 7),
                           ('physics_frame', 999), ('motor_steps', 999), ('instance', 'foreign'),
                           ('session', 99), ('map', 'foreign'), ('paused', True), ('core_modal_open', False),
                           ('last_combat', -1), ('campaign_phase', 3)]:
            with self.subTest(key=key):
                self.rejects(lambda d: d['gold_effect_probe']['frames'][0].update({key: value}))
        self.rejects(lambda d: d['gold_effect_probe']['parameters'].update(resonance_per_s=3))

    def test_forged_or_duplicated_grants_and_hidden_debit_refuse(self):
        self.rejects(lambda d: d['gold_effect_probe']['grants'][0].update(receipt='forged'))
        self.rejects(lambda d: d['gold_effect_probe']['grants'][0].update(amount=20))
        self.rejects(lambda d: d['gold_effect_probe']['grants'].append(d['gold_effect_probe']['grants'][0]))
        self.rejects(lambda d: d['postcombat_resource_debit_fixture'].update(amount=20))
        self.rejects(lambda d: d.pop('postcombat_resource_debit_fixture'))
        self.rejects(lambda d: d.update(position_health_phase_resource_injection_scope='natural skill'))

    def test_final_summary_cannot_invent_gain_after_the_last_real_frame(self):
        # Independent review's confirmed counterexample: the real frame series
        # remains2.4 recovery, but an inflated summary adds1 plus a valid-looking
        # next grant receipt. The final sample must be the same observed state.
        value = fixture()
        end = value['gold_effect_probe']['after']
        end['resonance'] += 1
        end['recovered'] += 1
        end['serial'] += 1
        value['gold_effect_probe']['grants'].append({'receipt': 'item/G07/run/reward:boss/map2/recovery/'+str(end['serial']), 'amount': 1.0})
        with self.assertRaises(ValueError): validate_canopy_gold(value)
        for key, changed in [('hp', 5), ('hp_capacity', 7), ('actor_instance', 9),
                             ('session', 9), ('map', 'foreign'), ('core_modal_open', False)]:
            with self.subTest(key=key):
                self.rejects(lambda d: d['gold_effect_probe']['after'].update({key: changed}))

    def test_boundary_sources_and_manifest_cannot_substitute_an_item(self):
        self.rejects(lambda d: d['before_boundary']['item_sources'][0].update(source_id=''))
        self.rejects(lambda d: d['before_boundary']['item_sources'][0].update(instance_id='different'))
        self.rejects(lambda d: d['before_boundary']['manifest']['stages'][0]['outputs']['reward_claim'].update(item='forest_heart_gold'))


if __name__ == '__main__':
    unittest.main()
