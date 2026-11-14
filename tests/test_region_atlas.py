"""Check the region-only spatial proposal before room subdivision."""
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools/world'))
from region_atlas import validate, region_bounds
from atlas_geometry import boundary, shared_port


class RegionAtlasTests(unittest.TestCase):
    def setUp(self):
        self.data = json.loads((ROOT / 'config/world/region_atlas.json').read_text())

    def test_world_is_connected_without_overlap_and_both_hubs_have_five_neighbors(self):
        result = validate(self.data)
        self.assertEqual(result['regions'], 16)
        self.assertEqual(result['interfaces'], 29)
        self.assertEqual(result['overlaps'], 0)
        self.assertEqual(result['city_neighbors'], ['A', 'E', 'K', 'N', 'P'])
        self.assertEqual(result['mine_neighbors'], ['E', 'G', 'P', 'R', 'S'])
        self.assertGreater(result['area_ratio_city_to_plains'], 1)
        self.assertLess(result['area_ratio_mine_to_city'], .3)
        self.assertNotIn('rooms', self.data)

    def test_interface_cannot_float_inside_one_region(self):
        self.data['interfaces'][0]['point'][0] += 64
        with self.assertRaisesRegex(AssertionError, 'A01'):
            validate(self.data)

    def test_touching_at_a_corner_is_not_an_interface(self):
        edge = self.data['interfaces'][0]
        regions = {r['id']: r for r in self.data['regions']}
        first, second = [regions[edge[side]]['outline'] for side in ('a', 'b')]
        edge['point'] = next(p for p in first if boundary(second, p) and not shared_port(first, second, p))
        with self.assertRaisesRegex(AssertionError, 'Corner-only port A01'):
            validate(self.data)

    def test_overlapping_regions_are_rejected(self):
        target = next(r for r in self.data['regions'] if r['id'] == 'I')
        target['outline'] = [[x, y + 64] for x, y in target['outline']]
        target['label'][1] += 64
        with self.assertRaisesRegex(AssertionError, 'Overlap'):
            validate(self.data)

    def test_stage_route_cannot_jump_between_non_adjacent_regions(self):
        self.data['routes'][0]['regions'] = ['P', 'I']
        with self.assertRaisesRegex(AssertionError, 'early'):
            validate(self.data)

    def test_coordinate_budget_and_table_use_same_geometry(self):
        self.assertEqual(self.data['coordinate_system']['planning_grid_world_units'], 1024)
        self.assertEqual(self.data['coordinate_system']['x_direction'], 'right')
        self.assertEqual(self.data['coordinate_system']['y_direction'], 'down')
        regions = {r['id']: r for r in self.data['regions']}
        self.assertEqual([v/1024 for v in region_bounds(regions['G'])], [41,23,22,14])
        self.assertEqual([v/1024 for v in region_bounds(regions['N'])], [35,32,13,6])
        for r in regions.values():
            for p in r['outline']:
                self.assertTrue(all(v % 1024 == 0 for v in p))

    def test_spine_cannot_cross_unassigned_space(self):
        r = next(r for r in self.data['regions'] if r['id']=='I')
        r['spines'][0]['path'].insert(1, [0,0])
        with self.assertRaisesRegex(AssertionError, 'Spine outside I'):
            validate(self.data)


if __name__ == '__main__':
    unittest.main()
