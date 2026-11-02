"""Real filesystem checks for the narrow Bible runtime source inventory."""
import hashlib
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from forest_bible_world_sources import inventory


class RuntimeInventoryTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / 'project.godot').write_bytes(b'config_version=5\n')

    def write(self, relative, data=b'one'):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        return path

    def test_real_consumers_and_asset_bytes_are_included(self):
        names = ['scripts/demo/app.gd', 'scenes/forest.tscn', 'resources/enemy.tres',
                 'config/player.json', 'shaders/forest.gdshader', 'assets/forest.png',
                 'tests/driver.gd', 'tools/godot.sh']
        for name in names:
            self.write(name, b'\x00\xffbinary')
        snapshot = inventory(self.root)
        self.assertEqual(set(snapshot), set(names) | {'project.godot'})
        self.assertTrue(all(snapshot[name] == hashlib.sha256(b'\x00\xffbinary').hexdigest() for name in names))

    def test_build_git_and_python_cache_are_excluded(self):
        for name in ['build/trace.json', '.git/index', 'tools/__pycache__/driver.pyc', 'tools/cache.pyc']:
            self.write(name)
        self.assertEqual(set(inventory(self.root)), {'project.godot'})

    def test_actor_or_resource_mutation_changes_closure(self):
        for name in ['scripts/enemies/actor.gd', 'resources/forest.tres']:
            path = self.write(name)
            before = inventory(self.root)
            path.write_bytes(b'two')
            self.assertNotEqual(before, inventory(self.root))

    def test_added_or_removed_consumer_changes_closure(self):
        before = inventory(self.root)
        path = self.write('scripts/new_consumer.gd')
        after = inventory(self.root)
        self.assertNotEqual(before, after)
        path.unlink()
        self.assertEqual(before, inventory(self.root))

    def test_uid_and_import_configuration_are_not_hidden(self):
        self.write('scripts/actor.gd.uid', b'uid://example')
        path = self.write('assets/forest.png.import', b'filter=false')
        before = inventory(self.root)
        path.write_bytes(b'filter=true')
        self.assertIn('scripts/actor.gd.uid', before)
        self.assertNotEqual(before, inventory(self.root))

    def test_game_source_add_edit_remove_and_uid_changes_invalidate_inventory(self):
        original = inventory(self.root)
        actor = self.write('game/actors/actor.gd', b'extends Node\n')
        uid = self.write('game/actors/actor.gd.uid', b'uid://original')
        before = inventory(self.root)
        self.assertEqual(before['game/actors/actor.gd'], hashlib.sha256(actor.read_bytes()).hexdigest())
        self.assertEqual(before['game/actors/actor.gd.uid'], hashlib.sha256(uid.read_bytes()).hexdigest())
        actor.write_bytes(b'extends Node2D\n')
        after = inventory(self.root)
        self.assertNotEqual(before, after)
        uid.write_bytes(b'uid://changed')
        self.assertNotEqual(after, inventory(self.root))
        actor.unlink()
        self.assertNotIn('game/actors/actor.gd', inventory(self.root))
        uid.unlink()
        self.assertEqual(original, inventory(self.root))

    def test_actual_forest_and_capture_inventories_track_game_changes(self):
        import run_forest_depth_region as depth
        import run_forest_directional_golden as golden
        import run_forest_ecology_tests as ecology
        import run_forest_campaign_combat_tests as campaign
        import capture_run_gear as capture
        for name in ('export_presets.cfg', 'game/enemies/enemy_actor.gd',
                     'scripts/enemies/enemy_definition.gd', 'tests/forest_ecology_runner.gd',
                     'tests/forest_campaign_combat_runner.gd', 'tests/forest_region_trace.gd',
                     'tools/run_forest_campaign_combat_tests.py'):
            self.write(name)
        for module in (depth, golden, ecology, campaign, capture):
            with self.subTest(consumer=module.__name__), patch.object(module, 'ROOT', self.root), \
                    patch.object(campaign, '__file__', str(self.root/'tools/run_forest_campaign_combat_tests.py')):
                before = module.inventory()
                self.assertIn('game/enemies/enemy_actor.gd', before)
                actor = self.write('game/actors/current.gd', b'extends Node\n')
                uid = self.write('game/actors/current.gd.uid', b'uid://original')
                added = module.inventory()
                self.assertEqual(added['game/actors/current.gd'], hashlib.sha256(actor.read_bytes()).hexdigest())
                self.assertIn('game/actors/current.gd.uid', added)
                actor.write_bytes(b'extends Node2D\n')
                self.assertNotEqual(added, module.inventory())
                actor.unlink()
                uid.unlink()
                self.assertEqual(before, module.inventory())



    def test_actual_forest_and_capture_inventories_track_experiment_changes(self):
        import run_forest_depth_region as depth
        import run_forest_directional_golden as golden
        import run_forest_ecology_tests as ecology
        import run_forest_campaign_combat_tests as campaign
        import capture_run_gear as capture
        for name in ('export_presets.cfg', 'game/enemies/enemy_actor.gd',
                     'scripts/enemies/enemy_definition.gd', 'tests/forest_ecology_runner.gd',
                     'tests/forest_campaign_combat_runner.gd', 'tests/forest_region_trace.gd',
                     'tools/run_forest_campaign_combat_tests.py'):
            self.write(name)
        for module in (depth, golden, ecology, campaign, capture):
            with self.subTest(consumer=module.__name__), patch.object(module, 'ROOT', self.root), \
                    patch.object(campaign, '__file__', str(self.root/'tools/run_forest_campaign_combat_tests.py')):
                before = module.inventory()
                self.assertIn('game/enemies/enemy_actor.gd', before)
                actor = self.write('experiments/actors/current.gd', b'extends Node\n')
                uid = self.write('experiments/actors/current.gd.uid', b'uid://original')
                added = module.inventory()
                self.assertEqual(added['experiments/actors/current.gd'], hashlib.sha256(actor.read_bytes()).hexdigest())
                self.assertIn('experiments/actors/current.gd.uid', added)
                actor.write_bytes(b'extends Node2D\n')
                self.assertNotEqual(added, module.inventory())
                actor.unlink()
                uid.unlink()
                self.assertEqual(before, module.inventory())


if __name__ == '__main__':
    unittest.main()
