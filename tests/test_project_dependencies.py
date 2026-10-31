import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from project_dependencies import inspect


class ProjectDependenciesTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def source(self, path, text):
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text)

    def test_shared_implementation_and_application_composition_are_allowed(self):
        self.source("game/combat/health.gd", "class_name Health\nextends RefCounted\n")
        self.source("game/enemies/enemy.gd", "class_name Enemy\nvar health: Health\n")
        self.source("game/application/app.gd", "class_name DemoApp\nvar enemy := Enemy.new()\n")
        result = inspect(self.root)
        self.assertFalse(result["errors"])
        self.assertIn({"source": "game/enemies/enemy.gd", "target": "game/combat/health.gd", "kind": "class"}, result["edges"])

    def test_duplicate_class_cannot_silently_select_a_second_implementation(self):
        self.source("scripts/old.gd", "class_name Health\n")
        self.source("game/combat/health.gd", "class_name Health\n")
        self.assertIn("Duplicate runtime class Health", "\n".join(inspect(self.root)["errors"]))

    def test_implicit_class_and_scene_dependencies_respect_boundary(self):
        self.source("game/application/demo_app.gd", "class_name DemoApp\n")
        self.source("game/world/level.gd", "var app: DemoApp\n")
        self.source("game/enemies/enemy.tscn", '[ext_resource path="res://experiments/fixture.gd" type="Script" id="1"]\n')
        errors = inspect(self.root)["errors"]
        self.assertEqual(2, len(errors), errors)

    def test_comments_strings_and_hash_inputs_are_not_calls(self):
        self.source("game/world/catalog.gd", '# load("res://tests/bad.gd")\nvar label = "DemoApp"\nvar hash_input = "res://tests/driver.gd"\n')
        self.source("game/application/app.gd", "class_name DemoApp\n")
        self.assertFalse(inspect(self.root)["errors"])

    def test_real_test_loads_are_rejected_and_computed_paths_remain_visible(self):
        self.source("scripts/preview.gd", 'const T = preload("res://tests/helper.gd")\nfunc get_scene(path):\n return load(path)\n')
        result = inspect(self.root)
        self.assertIn("Runtime loads test implementation", result["errors"][0])
        self.assertEqual([{"source": "scripts/preview.gd", "expression": "path"}], result["dynamic_loads"])

    def test_call_spellings_inside_all_string_forms_never_become_edges(self):
        self.source("game/world/catalog.gd", "\n".join([
            "var note = 'load(\"res://tests/bad.gd\")'",
            'var escaped = "preload(\\\"res://tests/bad.gd\\\")"',
            "var multiline = \"\"\"\nload('res://tests/bad.gd')\nclass_name DemoApp\n\"\"\"",
            "# ResourceLoader.load('res://tests/bad.gd')",
            'var tag = "# not a comment"']))
        self.source("game/application/app.gd", "class_name DemoApp\n")
        result = inspect(self.root)
        self.assertEqual(result["edges"], [])
        self.assertEqual(result["dynamic_loads"], [])
        self.assertEqual(result["errors"], [])

    def test_multiline_and_parentheses_in_literal_path_keep_real_loads(self):
        self.source("scripts/preview.gd", 'var a = preload(\n # retained comment\n "res://tests/(fixture).gd"\n)\n'
                    'var b = ResourceLoader.load("res://tests/second.gd")\n')
        result = inspect(self.root)
        self.assertEqual({edge['target'] for edge in result['edges']},
                         {'tests/(fixture).gd', 'tests/second.gd'})
        self.assertEqual(len(result['errors']), 2)
        self.assertEqual(result['dynamic_loads'], [])

    def test_resource_loader_type_and_cache_arguments_do_not_hide_literal_dependency(self):
        self.source("scripts/preview.gd", 'var a = ResourceLoader.load("res://tests/a,b.gd", "Script", ResourceLoader.CACHE_MODE_REUSE)\n')
        result = inspect(self.root)
        self.assertEqual(result['edges'], [{'source':'scripts/preview.gd', 'target':'tests/a,b.gd', 'kind':'resource'}])
        self.assertEqual(len(result['errors']), 1)
        self.assertEqual(result['dynamic_loads'], [])

    def test_nested_computed_load_is_visible_but_arbitrary_load_methods_are_not(self):
        self.source("scripts/preview.gd", 'var a = load(path_join("res://", family.get_name()))\n'
                    'func load_cache(path):\n return store.load(path)\n'
                    'func load(path):\n return path\n')
        result = inspect(self.root)
        self.assertEqual(result['edges'], [])
        self.assertEqual(result['dynamic_loads'], [{'source':'scripts/preview.gd',
                          'expression':'path_join("res://", family.get_name())'}])

    def test_real_ext_resource_headers_exclude_scene_strings_properties_and_comments(self):
        self.source("game/world/scene.tscn", '; [ext_resource path="res://tests/comment.gd"]\n'
                    '[node name="Example"]\npath="res://tests/property.gd"\n'
                    'text="[ext_resource path=\\\"res://tests/note.gd\\\"]"\n'
                    '[ext_resource\n type="Script" path="res://tests/real.gd" id="1"]\n')
        result = inspect(self.root)
        self.assertEqual(result['edges'], [{'source':'game/world/scene.tscn', 'target':'tests/real.gd', 'kind':'resource'}])
        self.assertEqual(len(result['errors']), 1)

    def test_real_implicit_class_forms_and_literal_extends_are_dependencies(self):
        self.source("game/application/app.gd", "class_name DemoApp\n")
        self.source("game/world/map.gd", 'extends "res://experiments/base.gd"\n'
                    'var typed: Array[DemoApp]\nvar app = DemoApp.new()\n'
                    'func is_app(value):\n return value is DemoApp\n')
        result = inspect(self.root)
        self.assertEqual({edge['target'] for edge in result['edges']},
                         {'game/application/app.gd', 'experiments/base.gd'})
        self.assertEqual(len(result['errors']), 2)

    def test_member_and_declaration_names_are_not_global_class_references(self):
        self.source("game/application/app.gd", "class_name DemoApp\n")
        self.source("game/world/map.gd", 'var DemoApp = 0\nfunc DemoApp():\n return other.DemoApp\n')
        self.assertEqual(inspect(self.root)['edges'], [])


if __name__ == "__main__":
    unittest.main()
