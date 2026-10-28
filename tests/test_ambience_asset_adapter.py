"""Finite loader asset identities only; synthetic media do not certify audio."""
import copy
import hashlib
import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from check_quality_diff import (AMBIENCE_LOADER, AMBIENCE_ROOT,
                                ambience_asset_consumers, known_asset_consumers)

REPOSITORY = Path(__file__).resolve().parents[1]
MANIFEST = AMBIENCE_ROOT + 'manifest.json'


class AmbienceAssetAdapterTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for name in (AMBIENCE_LOADER, 'tools/audio_ambience_design.py',
                     'config/audio_director/ambience/recipes.json',
                     'config/audio_director/ambience/sources.json'):
            target = self.root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(REPOSITORY / name, target)
        self.manifest = json.loads((REPOSITORY / MANIFEST).read_text())
        self.expected = {MANIFEST}
        for index, take in enumerate(self.manifest['renders']):
            name = take['path'].removeprefix('res://')
            self.expected.add(name)
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b'synthetic asset fingerprint test only ' + bytes([index]))
            take['sha256'] = hashlib.sha256(path.read_bytes()).hexdigest()
            take['bytes'] = path.stat().st_size
        indexed = {take['id']: take for take in self.manifest['renders']}
        for event in self.manifest['events']:
            for candidate in event['candidates']:
                candidate['renders'] = [copy.deepcopy(indexed[candidate['id']])]
        for index, point in enumerate(self.manifest['point_events']):
            self.manifest['point_events'][index] = {**indexed[point['id']], 'event': point['event'], 'title': point['title']}
        self.save()

    def save(self):
        (self.root / MANIFEST).write_text(json.dumps(self.manifest))

    def rejected(self):
        with self.assertRaises(ValueError):
            ambience_asset_consumers(self.root)

    def test_positive_exact_family_excludes_siblings(self):
        (self.root / AMBIENCE_ROOT / 'unused.ogg').write_bytes(b'unregistered sibling')
        self.assertEqual(ambience_asset_consumers(self.root), self.expected)
        self.assertEqual(known_asset_consumers(self.root), self.expected)

    def test_absent_loader_does_not_consume_family(self):
        (self.root / AMBIENCE_LOADER).unlink()
        self.assertEqual(ambience_asset_consumers(self.root), set())

    def test_loader_drift_rejected(self):
        with (self.root / AMBIENCE_LOADER).open('ab') as stream:
            stream.write(b'\n# Requires fresh finite-adapter review\n')
        self.rejected()

    def test_other_caller_same_directory_or_dynamic_literal_rejected(self):
        caller = self.root / 'scripts/unknown.gd'
        for code in ('const ROOT = "res://assets/audio/ambience_v1/"',
                     'const FILE = "res://assets/audio/ambience_v1/%s.ogg"'):
            with self.subTest(code=code):
                caller.write_text(code)
                with self.assertRaises(ValueError):
                    known_asset_consumers(self.root)

    def test_manifest_wrong_schema_version_or_default_rejected(self):
        for key, value in [('schema_version', True), ('schema_version', 2),
                           ('version', 'audio-ambience-v2'), ('runtime_default', 'A'),
                           ('task', 'OTHER'), ('channels', True), ('sample_rate', 44100)]:
            with self.subTest(key=key, value=value):
                original = self.manifest[key]
                self.manifest[key] = value
                self.save()
                self.rejected()
                self.manifest[key] = original

    def test_missing_manifest_and_all_media_rejected(self):
        for name in self.expected:
            with self.subTest(name=name):
                path = self.root / name
                data = path.read_bytes()
                path.unlink()
                self.rejected()
                path.write_bytes(data)

    def test_input_fingerprint_drift_rejected(self):
        for name in ('config/audio_director/ambience/recipes.json',
                     'config/audio_director/ambience/sources.json',
                     'tools/audio_ambience_design.py'):
            with self.subTest(name=name):
                path = self.root / name
                data = path.read_bytes()
                path.write_bytes(data + b'\n')
                self.rejected()
                path.write_bytes(data)

    def test_runtime_unknown_and_noncanonical_paths_rejected(self):
        row = self.manifest['regions']['plains']['profiles']['A']
        for path in ('res://assets/audio/ambience_v1/unknown.ogg',
                     'res://assets/audio/ambience_v1/../plains_a.ogg',
                     'res://assets/audio/ambience_v1//plains_a.ogg',
                     'res://assets/elsewhere.ogg'):
            with self.subTest(path=path):
                row['bed'] = path
                self.save()
                self.rejected()

    def test_render_sha_size_bool_and_corruption_rejected(self):
        row = self.manifest['renders'][0]
        for key, value in [('sha256', '0' * 64), ('sha256', 'bad'),
                           ('bytes', True), ('bytes', 0), ('bytes', row['bytes'] + 1)]:
            with self.subTest(key=key, value=value):
                old = row[key]
                row[key] = value
                self.save()
                self.rejected()
                row[key] = old
        self.save()
        path = self.root / row['path'].removeprefix('res://')
        path.write_bytes(b'changed')
        self.rejected()

    def test_every_render_file_symlink_rejected_even_inside_root(self):
        for index, name in enumerate(sorted(self.expected)):
            with self.subTest(name=name):
                path = self.root / name
                data = path.read_bytes()
                real = self.root / ('ordinary-%d' % index)
                real.write_bytes(data)
                path.unlink()
                path.symlink_to(real)
                self.rejected()
                path.unlink()
                path.write_bytes(data)

    def test_each_ancestor_symlink_rejected_even_inside_root(self):
        for name in ('assets/audio/ambience_v1', 'assets/audio', 'assets', 'scripts/audio', 'scripts'):
            with self.subTest(name=name):
                path = self.root / name
                moved = self.root / 'relocated'
                path.rename(moved)
                path.symlink_to(moved, target_is_directory=True)
                self.rejected()
                path.unlink()
                moved.rename(path)

    def test_missing_bed_detail_or_render_rejected(self):
        original = copy.deepcopy(self.manifest)
        mutations = [lambda m: m['regions']['plains']['profiles'].pop('A'),
                     lambda m: m['regions']['forest']['profiles']['B']['details'].pop(),
                     lambda m: m['renders'].pop(),
                     lambda m: m['point_events'].pop(),
                     lambda m: m['events'][0]['candidates'].pop()]
        for mutate in mutations:
            self.manifest = copy.deepcopy(original)
            mutate(self.manifest)
            self.save()
            self.rejected()

    def test_extra_rows_and_duplicate_rows_rejected(self):
        original = copy.deepcopy(self.manifest)
        mutations = [lambda m: m['events'].append(copy.deepcopy(m['events'][0])),
                     lambda m: m['renders'].append(copy.deepcopy(m['renders'][0])),
                     lambda m: m['point_events'].append(copy.deepcopy(m['point_events'][0])),
                     lambda m: m['regions'].update({'unknown': copy.deepcopy(m['regions']['plains'])}),
                     lambda m: m['regions']['plains']['profiles'].update({'C': copy.deepcopy(m['regions']['plains']['profiles']['A'])}),
                     lambda m: m['regions']['plains']['profiles']['A']['details'].append(copy.deepcopy(m['regions']['plains']['profiles']['A']['details'][0]))]
        for mutate in mutations:
            self.manifest = copy.deepcopy(original)
            mutate(self.manifest)
            self.save()
            self.rejected()

    def test_catalog_candidate_and_detail_identity_must_match(self):
        original = copy.deepcopy(self.manifest)
        mutations = [lambda m: m['events'][0]['candidates'][0].update({'id': 'forest_a'}),
                     lambda m: m['events'][0]['candidates'][0].update({'path': m['events'][0]['candidates'][1]['path']}),
                     lambda m: m['events'][0]['candidates'][0].update({'loop': 1}),
                     lambda m: m['regions']['plains']['profiles']['A'].update({'gain_db': False}),
                     lambda m: m['regions']['plains']['profiles']['A'].update({'candidate_id': 'plains_b'}),
                     lambda m: m['regions']['forest']['profiles']['A']['details'][0].update({'id': 'other'}),
                     lambda m: m['regions']['forest']['profiles']['A']['details'][0].update({'max_distance': 2000}),
                     lambda m: m['point_events'][0].update({'sha256': '0' * 64})]
        for mutate in mutations:
            self.manifest = copy.deepcopy(original)
            mutate(self.manifest)
            self.save()
            self.rejected()

    def test_recipe_expansion_is_not_admitted_by_refreshing_input_hash(self):
        recipe_path = self.root / 'config/audio_director/ambience/recipes.json'
        original = json.loads(recipe_path.read_text())
        for field in ('beds', 'details'):
            recipe = copy.deepcopy(original)
            added = copy.deepcopy(recipe[field][0])
            added['id'] = 'unknown'
            recipe[field].append(added)
            recipe_path.write_text(json.dumps(recipe))
            self.manifest['recipe_sha256'] = hashlib.sha256(recipe_path.read_bytes()).hexdigest()
            self.save()
            self.rejected()

    def test_render_unknown_noncanonical_path_is_not_admitted(self):
        row = self.manifest['renders'][0]
        for field, value in [('id', 'unknown'), ('path', 'res://assets/audio/ambience_v1/../plains_a.ogg'),
                             ('path', 'res://assets/audio/ambience_v1/unknown.ogg')]:
            old = row[field]
            row[field] = value
            self.save()
            self.rejected()
            row[field] = old

    def test_duplicate_json_keys_and_nonfinite_rejected(self):
        for content in ('{"version":"audio-ambience-v1","version":"audio-ambience-v1"}',
                        '{"schema_version":NaN}'):
            (self.root / MANIFEST).write_text(content)
            self.rejected()


if __name__ == '__main__':
    unittest.main()
