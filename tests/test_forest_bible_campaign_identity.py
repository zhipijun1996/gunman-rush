"""Finite synthetic Boss-identity controls, never native campaign evidence."""
import copy
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from run_forest_depth_campaign_boss import validate_map2_boss_identity


class BibleCampaignIdentityTests(unittest.TestCase):
    def manifest(self, layout='forest-bible-world-v15'):
        return {'version': 'thorn-forest-region-v2', 'region': 'thorn_forest', 'map_index': 2,
                'layout_version': layout,
                'boss_content': {'contract': 'forest-queen-canopy-v3',
                                 'scene': 'res://scenes/bosses/thorn_queen_canopy.tscn',
                                 'resource': 'res://resources/bosses/thorn_queen_canopy.tres'},
                'boss_contract': {'ok': True, 'version': 'forest-queen-canopy-v3',
                                  'boss_contract': 'forest-queen-canopy-v3',
                                  'admission': 'candidate_whole_boss_pending'}}

    def refuse(self, mutate):
        for allow_legacy in (False, True):
            data = self.manifest()
            mutate(data)
            with self.subTest(allow_legacy=allow_legacy):
                with self.assertRaises(ValueError):
                    validate_map2_boss_identity(data, allow_legacy=allow_legacy)

    def test_exact_v15_identity_and_pending_admission_accept_without_mutation(self):
        for allow_legacy in (False, True):
            data = self.manifest()
            before = copy.deepcopy(data)
            validate_map2_boss_identity(data, allow_legacy=allow_legacy)
            self.assertEqual(data, before)

    def test_unknown_future_and_malformed_layout_never_fall_back(self):
        for layout in ('forest-bible-world-v999', 'forest-bible-world-v15 ', '', None, 15, {}):
            with self.subTest(layout=layout):
                self.refuse(lambda m: m.update(layout_version=layout))

    def test_each_boss_asset_field_is_exact_and_extra_declarations_reject(self):
        for field in ('contract', 'scene', 'resource'):
            for value in ('foreign', '', None):
                with self.subTest(field=field, value=value):
                    self.refuse(lambda m: m['boss_content'].update({field: value}))
        self.refuse(lambda m: m['boss_content'].update(alternate_resource='res://legacy.tres'))
        self.refuse(lambda m: m.pop('boss_content'))

    def test_current_layout_cannot_masquerade_as_historical_queen(self):
        def old_queen(m):
            m.pop('boss_content')
            m['boss_contract'] = {'ok': True, 'version': 'forest-queen-weave-golden-v2',
                                  'boss_contract': 'queen-weave-region-experimental',
                                  'admission': 'experimental_whole_boss_pending'}
        self.refuse(old_queen)

    def test_typed_boss_contract_and_candidate_status_are_required(self):
        for key, value in (('ok', 1), ('ok', False), ('version', 'forest-queen-weave-golden-v2'),
                           ('boss_contract', 'queen-weave-region-experimental'),
                           ('admission', 'production'), ('admission', 'experimental_whole_boss_pending')):
            with self.subTest(key=key, value=value):
                self.refuse(lambda m: m['boss_contract'].update({key: value}))
        self.refuse(lambda m: m.update(boss_contract=[]))

    def test_region_version_and_exact_integer_map_cannot_be_relabelled(self):
        for key, value in (('version', 'thorn-forest-region-v1'), ('region', 'plains'),
                           ('map_index', 1), ('map_index', True), ('map_index', 2.0), ('map_index', '2')):
            with self.subTest(key=key, value=value):
                self.refuse(lambda m: m.update({key: value}))

    def test_existing_canopy_and_explicit_legacy_branches_stay_exact(self):
        for layout in ('shared-tree-canopy-hunt-v10', 'forest-expedition-airborne-v11',
                       'forest-woven-trunk-v12', 'forest-interwoven-canopy-v13', 'forest-fruit-routes-v14'):
            validate_map2_boss_identity(self.manifest(layout))
        legacy = self.manifest('shared-tree-directional-cavities-v7')
        legacy.pop('boss_content')
        legacy['boss_contract'] = {'ok': True, 'version': 'forest-queen-weave-golden-v2',
                                  'boss_contract': 'queen-weave-region-experimental',
                                  'admission': 'experimental_whole_boss_pending'}
        validate_map2_boss_identity(legacy, allow_legacy=True)
        with self.assertRaises(ValueError):
            validate_map2_boss_identity(legacy)


if __name__ == '__main__':
    unittest.main()
