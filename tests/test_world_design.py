"""Mutation tests for fixed-world references and phase boundaries."""
import copy
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from check_world_design import validate, validate_data
from world.room_context import extract
from level_region_context import build_region_context, ContextError
from level_design import route_request, content_plan
from production_loop import validate as validate_mission

class WorldTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        p = ROOT / 'config/world'
        from world.build import build
        cls.contracts, _ = build()
        cls.world = json.loads((p/'world.json').read_text())
        cls.catalog = json.loads((p/'collections.json').read_text())

    def test_current_graph_with_cycles_passes(self):
        self.assertEqual(validate(), [])

    def test_broken_endpoints_and_duplicate_ids_fail(self):
        for mutate in [lambda w: w['rooms'].append(w['rooms'][0]),
                       lambda w: w['connections'][0].update(a='missing'),
                       lambda w: w['connections'][0].update(a_section='missing'),
                       lambda w: w['connections'][0].update(requires=[['H']]),
                       lambda w: w['actions'][0].update(section_id='missing'),
                       lambda w: w['shortcuts'][0].update(open_from_room='missing')]:
            w = copy.deepcopy(self.world); mutate(w)
            self.assertTrue(validate_data(w, self.contracts, self.catalog))

    def test_broken_door_pair_and_spawn_fail(self):
        for field in ['target_door_id', 'target_spawn']:
            c = copy.deepcopy(self.contracts)
            c['rooms'][0]['doors'][0][field] = 'missing'
            self.assertTrue(validate_data(self.world, c, self.catalog))

    def test_catalog_wrong_reference_fails(self):
        c = copy.deepcopy(self.catalog)
        c['equipment_sources'][0]['action_ref'] = 'missing'
        self.assertTrue(validate_data(self.world, self.contracts, c))

    def test_room_context_bounded_and_unknown_rejected(self):
        result = extract('P-R03')
        self.assertEqual(result['room']['id'], 'P-R03')
        self.assertTrue(all('P-R03' in (c['a'],c['b']) for c in result['connections']))
        self.assertEqual('implemented_graybox', result['runtime_status'])
        with self.assertRaises(ValueError): extract('../../missing')

    def test_region_mapping_does_not_grant_runtime_or_invent_stages(self):
        for r in self.world['regions']:
            c = build_region_context(r['code'])
            self.assertEqual(c['region_id'], r['id'])
            self.assertNotIn('stage', c['design'])
            self.assertFalse(c['implementation']['fixed_world_runtime'])
            self.assertTrue(c['room_ids'])
        with self.assertRaises(ContextError): build_region_context('reverse_clocktower')

    def test_region_bible_migration_evidence_is_bound(self):
        from unittest.mock import patch
        import region_creative_direction as creative
        for region in ('thorn_forest', 'windchime_plains'):
            creative.load_direction('docs/data/creative_direction/' + region + '.json', region)
        original = creative._ValidationFiles.read
        def changed(files, path):
            raw = original(files, path)
            return raw + b' ' if path == 'docs/data/world/migration-authority.json' else raw
        with patch.object(creative._ValidationFiles, 'read', changed):
            with self.assertRaisesRegex(ValueError, 'Migration authority hash'):
                creative.bind_region_bible('thorn_forest')

    def test_import_is_excluded_from_existing_raw_export_configuration(self):
        import re
        presets = (ROOT / 'export_presets.cfg').read_text()
        includes = re.findall(r'^include_filter="(.*)"$', presets, re.M)
        excludes = re.findall(r'^exclude_filter="(.*)"$', presets, re.M)
        self.assertTrue(includes and excludes)
        self.assertTrue(all('docs/*' in row.split(',') for row in excludes))
        self.assertTrue(all(not item.startswith('docs/') for row in includes for item in row.split(',')))
        plugin = (ROOT / 'addons/runtime_raw_export/raw_exporter.gd').read_text()
        self.assertNotIn('docs/data/world', plugin)

    def test_old_routes_and_frozen_missions_refuse(self):
        for call in (route_request, content_plan):
            with self.assertRaisesRegex(ValueError, 'retired'): call('制作固定世界平原')
        with self.assertRaisesRegex(ValueError, 'retired'):
            validate_mission({'tasks':[{'skills':['region-generator']}]})

if __name__ == '__main__': unittest.main()
