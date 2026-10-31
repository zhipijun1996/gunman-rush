"""Real small format-4 PCK byte fixtures; no engine/export/rendering claim."""
import base64
import configparser
import contextlib
import gzip
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import struct
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location('bundle', Path(__file__).resolve().parents[1] / 'tools/check_web_bundle.py')
bundle = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(bundle)
PNG = base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a2ioAAAAASUVORK5CYII=')
FAMILIES = ['windmill_repair_workshop_complete_v1', 'bank_shoulder_wide_v1', 'clock_regulator_court_v1', 'woodland_two_depth_ridges_v1']


def write_pack(path, entries):
    """Independent fixture writer for actual PCK header/directory/payload bytes."""
    body = bytearray()
    rows = []
    for name, data in entries:
        rows.append((name, len(body), len(data), hashlib.md5(data).digest()))
        body.extend(data)
    header = struct.pack('<4s5IQQ', b'GDPC', 4, 4, 7, 2, 2, 112, 112 + len(body))
    directory = bytearray(struct.pack('<I', len(rows)))
    for name, offset, length, digest in rows:
        encoded = name.encode() + b'\0'
        encoded += b'\0' * (-len(encoded) % 4)
        directory.extend(struct.pack('<I', len(encoded)) + encoded + struct.pack('<QQ', offset, length) + digest + struct.pack('<I', 0))
    path.write_bytes(header.ljust(112, b'\0') + body + directory)


class BundleTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name) / 'repo'
        self.repo.mkdir()
        self.pack = Path(self.temp.name) / 'test.pck'
        self.entries = {}
        self.raw = []
        self.texture_targets = {}
        landscape = 'const PILOT_FAMILIES := ' + json.dumps(FAMILIES[:3]) + '\nconst FAMILY_ID := "' + FAMILIES[3] + '"\n'
        self.local(bundle.LANDSCAPE, landscape.encode())
        for family in FAMILIES:
            folder = bundle.SPACES + family
            self.manifest(folder + '/family.json', {'path': folder + '/source.png', 'sha256': hashlib.sha256(PNG).hexdigest()})
            self.texture(folder + '/source.png', raw=True)
        presentation = []
        for family in ('root_bell', 'root_bell_burst'):
            folder = 'assets/region_production_v3/enemies/' + family
            name = folder + '/manifest.json'
            presentation.append('var manifest := "res://' + name + '"')
            self.manifest(name, {'texture': 'source/master.png', 'sha256': hashlib.sha256(PNG).hexdigest()})
            self.texture(folder + '/source/master.png')
        self.local(bundle.ROOT_BELL, '\n'.join(presentation).encode())
        contract = 'assets/region_production_v3/terrain_sampling_v1/contract_v2.json'
        self.manifest(contract, {'version': 2})
        sampler = ['const CONTRACT_PATH := "res://' + contract + '"', 'const CONTRACT_SHA := "' + hashlib.sha256(self.entries[contract]).hexdigest() + '"']
        for kind, family in [('CLIFF', 'limestone_bank_section_v1'), ('PANEL', 'suspended_mechanical_baffle_v1')]:
            name = bundle.SPACES + family + '/source.png'
            self.texture(name, raw=True)
            sampler += ['const ' + kind + ' := preload("res://' + name + '")', 'const ' + kind + '_SHA := "' + hashlib.sha256(PNG).hexdigest() + '"']
        self.local(bundle.TERRAIN, '\n'.join(sampler).encode())

    def local(self, name, data):
        path = self.repo / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)

    def manifest(self, name, data):
        body = json.dumps(data).encode()
        self.local(name, body)
        self.entries[name] = body

    def texture(self, name, raw=False):
        self.local(name, PNG)
        if raw:
            self.raw.append(name)
            self.entries[name] = PNG
        target = '.godot/imported/' + hashlib.sha256(name.encode()).hexdigest() + '.ctex'
        self.texture_targets[name] = target
        # The closure checker tests imported-file presence/integrity, not a texture decoder.
        self.entries[target] = b'CTEX structural fixture, not rendered'
        self.entries[name + '.import'] = ('[remap]\nimporter="texture"\ntype="CompressedTexture2D"\npath="res://' + target + '"\n').encode()
        self.local(name + '.import', self.entries[name + '.import'])
        self.local(target, self.entries[target])

    def check(self, entries=None):
        write_pack(self.pack, list((entries if entries is not None else self.entries).items()))
        return bundle.check_runtime_closure(self.pack, self.repo)


    def connected(self):
        self.local(bundle.CONNECTED, ('const ROOT := "res://' + bundle.CONNECTED_ROOT + '"\nvar candidate := read_family("rooted_plants_v1")\n').encode())
        folder = bundle.CONNECTED_ROOT + 'rooted_plants_v1/'
        self.manifest(folder+'family.json', {'path':'res://'+folder+'raw.png','sha256':hashlib.sha256(PNG).hexdigest()})
        self.texture(folder+'raw.png', raw=True)
        return folder

    def test_connected_actual_consumer_requires_json_raw_and_normal_import(self):
        folder = self.connected()
        result = self.check()
        self.assertIn(folder+'raw.png', result['raw_png'])
        self.assertIn(folder+'family.json', result['json'])
        for absent in (folder+'family.json',folder+'raw.png',folder+'raw.png.import',self.texture_targets[folder+'raw.png']):
            with self.subTest(absent=absent):
                broken=self.entries.copy();del broken[absent]
                with self.assertRaisesRegex(ValueError,'missing runtime resource'):
                    self.check(broken)

    def background(self):
        name = bundle.SPACES + 'distant_limestone_ridge_v1/source.png'
        self.texture(name)
        self.local(bundle.BACKGROUND, ('const RIDGE := preload("res://' + name + '")\n').encode())
        return name

    def test_background_preload_uses_import_without_raw_png_or_family_json(self):
        name = self.background()
        result = self.check()
        self.assertIn(name, result['textures'])
        self.assertNotIn(name, result['raw_png'])
        self.assertNotIn(bundle.SPACES + 'distant_limestone_ridge_v1/family.json', result['json'])
        self.assertNotIn(name, self.entries)

    def test_background_missing_import_or_target_is_rejected(self):
        name = self.background()
        for removed in (name + '.import', self.texture_targets[name]):
            with self.subTest(path=removed):
                broken = self.entries.copy(); del broken[removed]
                with self.assertRaisesRegex(ValueError, 'missing runtime resource'):
                    self.check(broken)

    def test_background_wrong_existing_texture_target_is_rejected(self):
        name = self.background()
        other = self.texture_targets[self.raw[0]]
        broken = self.entries.copy()
        broken[name + '.import'] = ('[remap]\nimporter="texture"\npath="res://' + other + '"\n').encode()
        with self.assertRaisesRegex(ValueError, 'target differs from source mapping'):
            self.check(broken)

    def test_background_wrong_imported_bytes_with_valid_pack_md5_is_rejected(self):
        name = self.background()
        broken = self.entries.copy(); broken[self.texture_targets[name]] += b'coherent wrong image'
        with self.assertRaisesRegex(ValueError, 'imported texture bytes differ'):
            self.check(broken)

    def test_background_changed_declaration_is_not_silently_skipped(self):
        self.background()
        self.local(bundle.BACKGROUND, b'const RIDGE := load("res://assets/region_production_v3/spaces/distant_limestone_ridge_v1/source.png")')
        with self.assertRaisesRegex(ValueError, 'ridge declaration changed'):
            self.check()

    def backend_imports(self):
        name = self.background()
        first = self.texture_targets[name]
        second = '.godot/imported/second-supported-format.ctex'
        self.local(second, b'CTEX second supported format fixture')
        self.entries[second] = b'CTEX second supported format fixture'
        def mapping(rows):
            return ('[remap]\nimporter="texture"\n' + ''.join(
                key + '="res://' + target + '"\n' for key, target in rows)).encode()
        rows = [('path.s3tc', first), ('path.etc2', second)]
        self.local(name + '.import', mapping(rows))
        self.entries[name + '.import'] = mapping(rows)
        return name, rows, mapping

    def test_backend_texture_mapping_preserves_exact_keys_and_allows_subset(self):
        name, rows, mapping = self.backend_imports()
        self.assertIn(name, self.check()['textures'])
        subset = self.entries.copy(); subset[name + '.import'] = mapping(rows[1:])
        self.assertIn(name, self.check(subset)['textures'])

    def test_swapped_backend_texture_keys_are_rejected_with_correct_target_bytes(self):
        name, rows, mapping = self.backend_imports()
        broken = self.entries.copy()
        broken[name + '.import'] = mapping([(rows[0][0], rows[1][1]), (rows[1][0], rows[0][1])])
        with self.assertRaisesRegex(ValueError, 'target differs from source mapping'):
            self.check(broken)

    def test_duplicate_texture_target_keys_are_rejected_in_pack_and_local_mapping(self):
        name, rows, mapping = self.backend_imports()
        duplicate = mapping(rows + [rows[0]])
        broken = self.entries.copy(); broken[name + '.import'] = duplicate
        with self.assertRaisesRegex(ValueError, 'Duplicate texture import target key'):
            self.check(broken)
        self.local(name + '.import', duplicate)
        with self.assertRaisesRegex(ValueError, 'Duplicate texture import target key'):
            self.check()

    def test_multiple_remap_sections_and_spaced_duplicate_targets_are_rejected(self):
        name = self.background()
        other = self.texture_targets[self.raw[0]]
        for suffix in ('\n[remap]\nimporter="texture"\npath="res://' + other + '"\n',
                       'path = "res://' + other + '"\n'):
            with self.subTest(suffix=suffix):
                broken = self.entries.copy(); broken[name + '.import'] += suffix.encode()
                with self.assertRaisesRegex(ValueError, 'Duplicate texture'):
                    self.check(broken)

    def test_whitespace_import_target_is_valid_but_malformed_target_is_rejected(self):
        name = self.background()
        target = self.texture_targets[name]
        valid = self.entries.copy()
        valid[name + '.import'] = ('[remap]\nimporter="texture"\n path = "res://' + target + '" \n').encode()
        self.assertIn(name, self.check(valid)['textures'])
        invalid = self.entries.copy()
        invalid[name + '.import'] = b'[remap]\nimporter="texture"\npath = "uid://unresolved"\n'
        with self.assertRaisesRegex(ValueError, 'Malformed texture import target'):
            self.check(invalid)

    def test_complete_current_and_pending_integrations_have_finite_closure(self):
        result = self.check()
        self.assertEqual((len(result['json']), len(result['raw_png']), len(result['textures'])), (7, 6, 8))
        self.assertEqual(result['pending_consumers'], [])
        self.assertIn(bundle.SPACES + 'limestone_bank_section_v1/source.png', result['textures'])
        self.assertIn(bundle.SPACES + 'suspended_mechanical_baffle_v1/source.png', result['raw_png'])

    def test_unintegrated_child_consumers_are_explicitly_pending(self):
        (self.repo / bundle.TERRAIN).unlink()
        self.local(bundle.ROOT_BELL, b'var path := "res://assets/region_production_v3/enemies/root_bell/manifest.json"')
        result = self.check()
        self.assertEqual((len(result['json']), len(result['raw_png']), len(result['textures'])), (5, 4, 5))
        self.assertEqual(len(result['pending_consumers']), 2)
        self.assertNotIn('assets/region_production_v3/enemies/root_bell_burst/manifest.json', result['json'])

    def test_archived_boss_sources_are_allowed_on_disk_but_not_in_pack(self):
        for family in bundle.EVIDENCE_ONLY_FAMILIES:
            self.local(family + 'source.png', PNG)
        self.assertEqual(self.check()['excluded_evidence_families'], list(bundle.EVIDENCE_ONLY_FAMILIES))
        for family in bundle.EVIDENCE_ONLY_FAMILIES:
            for name, payload in [('source.png', PNG), ('family.json', b'{}')]:
                with self.subTest(family=family, path=name):
                    broken = self.entries.copy(); broken[family + name] = payload
                    with self.assertRaisesRegex(ValueError, 'PCK contains excluded evidence-only family'):
                        self.check(broken)

    def test_archived_boss_imported_derivative_alone_is_rejected(self):
        family = bundle.EVIDENCE_ONLY_FAMILIES[0]
        target = '.godot/imported/rejected-boss.ctex'
        self.local(family + 'source.png.import', ('path="res://' + target + '"\n').encode())
        broken = self.entries.copy(); broken[target] = b'old imported source'
        with self.assertRaisesRegex(ValueError, 'excluded evidence-only imported texture'):
            self.check(broken)

    def test_new_boss_reference_requires_exclusion_removal_in_every_preset(self):
        family = bundle.EVIDENCE_ONLY_FAMILIES[0]
        self.local('config/new_visual.json', json.dumps({'family': Path(family).name}).encode())
        with self.assertRaisesRegex(ValueError, 'remove its export exclusion first'):
            self.check()
        self.local('export_presets.cfg', ('[preset.0]\nexclude_filter=""\n'
                   '[preset.1]\nexclude_filter="'+family+'*"\n'
                   '[preset.2]\nexclude_filter=""\n').encode())
        with self.assertRaisesRegex(ValueError, 'remove its export exclusion first'):
            self.check()
        # An explicit policy change removes this unused-family guard. A real
        # future consumer must additionally join the runtime closure contract.
        self.local('export_presets.cfg', b'[preset.0]\nexclude_filter=""\n[preset.1]\nexclude_filter=""\n[preset.2]\nexclude_filter=""\n')
        self.assertEqual(self.check()['excluded_evidence_families'], [])

    def test_new_shader_reference_to_excluded_family_is_rejected(self):
        self.local('scripts/new.gdshader', ('// '+bundle.EVIDENCE_ONLY_FAMILIES[1]+'source.png').encode())
        with self.assertRaisesRegex(ValueError, 'Runtime consumer references excluded'):
            self.check()

    def test_game_consumers_cannot_reference_excluded_evidence_families(self):
        for suffix in ('.gd', '.tscn', '.tres', '.json', '.gdshader'):
            name = 'game/presentation/consumer' + suffix
            with self.subTest(path=name):
                self.local(name, ('res://' + bundle.EVIDENCE_ONLY_FAMILIES[0] + 'source.png').encode())
                with self.assertRaisesRegex(ValueError, 'Runtime consumer references excluded'):
                    self.check()
                (self.repo / name).unlink()
        self.assertEqual(self.check()['excluded_evidence_families'], list(bundle.EVIDENCE_ONLY_FAMILIES))


    def test_experiment_consumers_cannot_reference_excluded_evidence_families(self):
        for suffix in ('.gd', '.tscn', '.tres', '.json', '.gdshader'):
            name = 'experiments/presentation/consumer' + suffix
            with self.subTest(path=name):
                self.local(name, ('res://' + bundle.EVIDENCE_ONLY_FAMILIES[0] + 'source.png').encode())
                with self.assertRaisesRegex(ValueError, 'Runtime consumer references excluded'):
                    self.check()
                (self.repo / name).unlink()
        self.assertEqual(self.check()['excluded_evidence_families'], list(bundle.EVIDENCE_ONLY_FAMILIES))

    def test_missing_each_runtime_json_is_rejected(self):
        for name in [n for n in self.entries if n.endswith('.json')]:
            with self.subTest(path=name):
                broken = self.entries.copy(); del broken[name]
                with self.assertRaisesRegex(ValueError, 'missing runtime resource'):
                    self.check(broken)

    def test_json_changed_only_in_pack_is_rejected(self):
        broken = self.entries.copy()
        broken['assets/region_production_v3/enemies/root_bell/manifest.json'] = b'{}'
        with self.assertRaisesRegex(ValueError, 'JSON differs'):
            self.check(broken)

    def test_malformed_matching_source_json_is_rejected(self):
        name = 'assets/region_production_v3/enemies/root_bell/manifest.json'
        self.local(name, b'{broken'); self.entries[name] = b'{broken'
        with self.assertRaises(ValueError):
            self.check()

    def test_ctex_cannot_replace_any_FileAccess_source_png(self):
        for name in self.raw:
            with self.subTest(path=name):
                broken = self.entries.copy(); del broken[name]
                self.assertIn(name + '.import', broken)
                self.assertIn(self.texture_targets[name], broken)
                with self.assertRaisesRegex(ValueError, 'missing runtime resource'):
                    self.check(broken)

    def test_changed_raw_png_is_rejected_even_with_intact_import(self):
        broken = self.entries.copy(); broken[self.raw[0]] += b'changed'
        with self.assertRaisesRegex(ValueError, 'raw PNG differs'):
            self.check(broken)

    def test_source_and_pack_coherent_edit_cannot_override_declared_png_sha(self):
        self.entries[self.raw[0]] += b'changed'; self.local(self.raw[0], self.entries[self.raw[0]])
        with self.assertRaisesRegex(ValueError, 'differs from its contract'):
            self.check()

    def test_enemy_atlas_and_import_target_must_remain(self):
        name = 'assets/region_production_v3/enemies/root_bell_burst/source/master.png'
        for removed in [name + '.import', self.texture_targets[name]]:
            with self.subTest(path=removed):
                broken = self.entries.copy(); del broken[removed]
                with self.assertRaisesRegex(ValueError, 'missing runtime resource'):
                    self.check(broken)

    def test_empty_or_wrong_import_mapping_is_rejected(self):
        name = self.raw[0] + '.import'
        for data, reason in [(b'[remap]\nimporter="audio"\n', 'no texture import'), (b'[remap]\nimporter="texture"\n', 'no import target')]:
            with self.subTest(data=data):
                broken = self.entries.copy(); broken[name] = data
                with self.assertRaisesRegex(ValueError, reason):
                    self.check(broken)

    def test_unintegrated_source_referenced_by_consumer_fails(self):
        (self.repo / self.raw[0]).unlink()
        with self.assertRaisesRegex(ValueError, 'lacks source resource'):
            self.check()

    def test_terrain_contract_sha_is_not_just_presence(self):
        name = 'assets/region_production_v3/terrain_sampling_v1/contract_v2.json'
        self.manifest(name, {'version': 'changed'})
        with self.assertRaisesRegex(ValueError, 'sampling JSON differs'):
            self.check()

    def test_changed_landscape_declaration_requires_contract_adapter_update(self):
        self.local(bundle.LANDSCAPE, b'const PILOT_FAMILIES := compute_families()')
        with self.assertRaisesRegex(ValueError, 'declaration changed'):
            self.check()

    def recorded_enemy_fixture(self):
        name = 'resources/enemies/legacy/plains_charger_v2.tres'
        raw = b'[gd_resource type="Resource" format=3]\n[resource]\ncollision_damage = 32.0\n'
        digest = hashlib.sha256(raw).hexdigest()
        self.local(name, raw)
        self.local('game/enemies/enemy_behavior_registry.gd',
                   ('const OLD_REVISION := "' + digest + '"\nconst BEHAVIORS := {\n'
                    '\t&"charger": {"revisions":{OLD_REVISION:"res://' + name + '"}},\n'
                    '}\nconst CANDIDATES := {}\n').encode())
        target = '.godot/exported/fixture/plains_charger_v2.res'
        self.entries[name] = raw
        self.entries[name + '.remap'] = ('[remap]\npath="res://' + target + '"\n').encode()
        self.entries[target] = b'Synthetic converted resource; actual ResourceLoader is tested in PCK runner'
        return name, target

    def test_recorded_enemy_requires_both_original_raw_bytes_and_normal_resource_remap(self):
        name, target = self.recorded_enemy_fixture()
        write_pack(self.pack, list(self.entries.items()))
        result = bundle.check_runtime_closure(self.pack, self.repo)
        self.assertEqual(result['recorded_enemy_definitions'], [name])
        for missing in (name, name + '.remap', target):
            with self.subTest(missing=missing):
                write_pack(self.pack, [(key, value) for key, value in self.entries.items() if key != missing])
                with self.assertRaises(ValueError):
                    bundle.check_runtime_closure(self.pack, self.repo)

    def test_single_quoted_revision_keys_and_paths_cannot_skip_pack_validation(self):
        name, target = self.recorded_enemy_fixture()
        registry = self.repo / 'game/enemies/enemy_behavior_registry.gd'
        registry.write_text(registry.read_text().replace('"', "'"))
        self.assertEqual(bundle.recorded_enemy_contract(self.repo),
                         {name: hashlib.sha256(self.entries[name]).hexdigest()})
        write_pack(self.pack, list(self.entries.items()))
        self.assertEqual(bundle.check_runtime_closure(self.pack, self.repo)['recorded_enemy_definitions'], [name])
        for missing in (name, name + '.remap', target):
            write_pack(self.pack, [(key, value) for key, value in self.entries.items() if key != missing])
            with self.subTest(missing=missing), self.assertRaises(ValueError):
                bundle.check_runtime_closure(self.pack, self.repo)

    def test_recorded_enemy_changed_source_or_pack_and_unsafe_registry_are_rejected(self):
        name, target = self.recorded_enemy_fixture()
        original = self.entries[name]
        self.entries[name] = original + b'changed raw'
        write_pack(self.pack, list(self.entries.items()))
        with self.assertRaisesRegex(ValueError, 'PCK raw enemy Definition differs'):
            bundle.check_runtime_closure(self.pack, self.repo)
        self.entries[name] = original
        self.local(name, original + b'changed source')
        with self.assertRaisesRegex(ValueError, 'Recorded enemy source SHA changed'):
            bundle.recorded_enemy_contract(self.repo)
        self.local(name, original)
        registry = self.repo / 'game/enemies/enemy_behavior_registry.gd'
        source = registry.read_text()
        for invalid in ('res://resources/../escaped.tres', 'res://resources/missing.tres'):
            registry.write_text(source.replace('res://' + name, invalid))
            with self.assertRaises(ValueError):
                bundle.recorded_enemy_contract(self.repo)
        registry.write_text(source.replace('OLD_REVISION:"res://', 'UNKNOWN_REVISION:"res://'))
        with self.assertRaisesRegex(ValueError, 'Unknown/duplicate'):
            bundle.recorded_enemy_contract(self.repo)
        registry.write_text(source.replace('{OLD_REVISION:', 'build_revisions({OLD_REVISION:'))
        with self.assertRaisesRegex(ValueError, 'finite literal'):
            bundle.recorded_enemy_contract(self.repo)

    def test_pack_rejects_duplicate_paths(self):
        rows = list(self.entries.items()); rows.append(rows[0]); write_pack(self.pack, rows)
        with self.assertRaisesRegex(ValueError, 'duplicate'):
            bundle.Pack(self.pack)

    def test_pack_rejects_unsafe_path(self):
        write_pack(self.pack, [('../outside.json', b'{}')])
        with self.assertRaisesRegex(ValueError, 'Invalid runtime resource path'):
            bundle.Pack(self.pack)

    def test_unknown_format_and_flags_fail_closed(self):
        write_pack(self.pack, list(self.entries.items())); original = self.pack.read_bytes()
        for offset, number in [(4, 3), (20, 3), (20, 6)]:
            with self.subTest(offset=offset, value=number):
                changed = bytearray(original); struct.pack_into('<I', changed, offset, number); self.pack.write_bytes(changed)
                with self.assertRaises(ValueError):
                    bundle.Pack(self.pack)

    def test_truncation_and_payload_corruption_are_rejected(self):
        write_pack(self.pack, list(self.entries.items())); original = self.pack.read_bytes()
        self.pack.write_bytes(original[:-1])
        with self.assertRaises(ValueError):
            bundle.Pack(self.pack)
        changed = bytearray(original); changed[112] ^= 1; self.pack.write_bytes(changed)
        with self.assertRaisesRegex(ValueError, 'MD5 changed'):
            bundle.check_runtime_closure(self.pack, self.repo)

    def test_out_of_data_bounds_entry_is_rejected(self):
        write_pack(self.pack, [('valid.json', b'{}')]); changed = bytearray(self.pack.read_bytes())
        directory = struct.unpack_from('<Q', changed, 32)[0]
        name_length = struct.unpack_from('<I', changed, directory + 4)[0]
        struct.pack_into('<Q', changed, directory + 8 + name_length, len(changed) + 1)
        self.pack.write_bytes(changed)
        with self.assertRaisesRegex(ValueError, 'Invalid/duplicate/flagged'):
            bundle.Pack(self.pack)

    def web_fixture(self):
        folder = Path(self.temp.name) / 'web'; folder.mkdir()
        write_pack(folder / 'index.test.pck', list(self.entries.items()))
        data = (folder / 'index.test.pck').read_bytes()
        compressed = gzip.compress(data); (folder / 'chunk.gz').write_bytes(compressed)
        part = {'url': 'chunk.gz', 'gzip_bytes': len(compressed), 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}
        resources = {'index.test.pck': {'chunks': [part], 'sha256': part['sha256']}}
        (folder / 'index.cache-sw.js').write_text('const RESOURCE_MAP = ' + json.dumps(resources) + ';')
        metadata = {'download_bytes': len(compressed), 'cache_schema': 2, 'build_id': part['sha256'][:12], 'pack': 'index.test.pck'}
        (folder / 'build-info.json').write_text(json.dumps(metadata))
        return folder, resources

    def test_existing_bundle_entrypoint_checks_chunks_and_new_closure(self):
        folder, _ = self.web_fixture()
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            bundle.check(folder, self.repo)
        result = json.loads(output.getvalue())
        self.assertEqual(result['failed'], 0)
        self.assertEqual(result['checked_resources'], 1)
        self.assertEqual(len(result['pack_runtime_closure']['textures']), 8)

    def test_old_chunk_and_excluded_consumer_checks_remain(self):
        folder, resources = self.web_fixture()
        resources['index.test.pck']['chunks'][0]['gzip_bytes'] += 1
        (folder / 'index.cache-sw.js').write_text('const RESOURCE_MAP = ' + json.dumps(resources) + ';')
        with self.assertRaises(AssertionError):
            bundle.check(folder, self.repo)
        resources['index.test.pck']['chunks'][0]['gzip_bytes'] -= 1
        (folder / 'index.cache-sw.js').write_text('const RESOURCE_MAP = ' + json.dumps(resources) + ';')
        self.local('scripts/bad.gd', b'var bad := "res://assets/painterly_v2/retired.png"')
        with self.assertRaises(AssertionError):
            bundle.check(folder, self.repo)

    def test_bundle_entrypoint_rejects_retired_painterly_consumer_in_game(self):
        folder, _ = self.web_fixture()
        self.local('game/presentation/retired.gd', b'var bad := "res://assets/painterly_v2/retired.png"')
        with self.assertRaisesRegex(AssertionError, 'game/presentation/retired.gd'):
            bundle.check(folder, self.repo)


    def test_bundle_entrypoint_rejects_retired_painterly_consumer_in_experiment(self):
        folder, _ = self.web_fixture()
        self.local('experiments/presentation/retired.gd', b'var bad := "res://assets/painterly_v2/retired.png"')
        with self.assertRaisesRegex(AssertionError, 'experiments/presentation/retired.gd'):
            bundle.check(folder, self.repo)

    def test_all_shipping_presets_preserve_finite_runtime_closure(self):
        presets = configparser.ConfigParser(interpolation=None)
        presets.read(bundle.REPO / 'export_presets.cfg')
        required_json = [bundle.SPACES + f + '/family.json' for f in FAMILIES]
        required_json += ['assets/region_production_v3/enemies/' + f + '/manifest.json'
                          for f in ('root_bell', 'root_bell_burst')]
        required_json += ['assets/region_production_v3/terrain_sampling_v1/contract_v2.json']
        required_raw = [bundle.SPACES + f + '/source.png' for f in FAMILIES +
                        ['limestone_bank_section_v1', 'suspended_mechanical_baffle_v1']]
        import fnmatch
        for index in range(3):
            section = presets['preset.' + str(index)]
            included = section['include_filter'].strip('"').split(',')
            excluded = section['exclude_filter'].strip('"').split(',')
            for name in required_json + required_raw:
                with self.subTest(preset=index, path=name):
                    self.assertIn(name, included)
                    self.assertFalse(any(fnmatch.fnmatchcase(name, pattern) for pattern in excluded))
            for family in bundle.EVIDENCE_ONLY_FAMILIES:
                self.assertIn(family + '*', excluded)

    def dynamic_highland(self):
        family='windmill_highland_v1';folder=bundle.SPACES+family
        original=(self.repo/bundle.LANDSCAPE).read_text()
        self.local(bundle.LANDSCAPE,(original+'\nfunc _build_highland_pilot():\n'
            '\tvar family := read_family("'+family+'")\n').encode())
        self.manifest(folder+'/family.json',{'path':folder+'/source.png','sha256':hashlib.sha256(PNG).hexdigest()})
        self.texture(folder+'/source.png',raw=True)
        return folder

    def test_literal_highland_consumer_outside_static_pilot_list_has_finite_closure(self):
        folder=self.dynamic_highland();result=self.check()
        self.assertIn(folder+'/family.json',result['json'])
        self.assertIn(folder+'/source.png',result['raw_png'])
        self.assertIn(folder+'/source.png',result['textures'])
        self.assertEqual(len(result['json']),8)

    def test_dynamic_highland_requires_json_raw_png_import_and_imported_target(self):
        folder=self.dynamic_highland();png=folder+'/source.png'
        for path in [folder+'/family.json',png,png+'.import',self.texture_targets[png]]:
            with self.subTest(path=path):
                broken=self.entries.copy();del broken[path]
                with self.assertRaisesRegex(ValueError,'missing runtime resource'):
                    self.check(broken)

    def test_dynamic_highland_rejects_changed_json_png_and_remap(self):
        folder=self.dynamic_highland();png=folder+'/source.png'
        for path,data,error in [(folder+'/family.json',b'{}','JSON differs'),
            (png,PNG+b'changed','raw PNG differs'),
            (png+'.import',self.entries[self.raw[0]+'.import'],'target differs from source mapping')]:
            with self.subTest(path=path):
                broken=self.entries.copy();broken[path]=data
                with self.assertRaisesRegex(ValueError,error):self.check(broken)

    def test_non_consumer_comments_and_quoted_notes_do_not_add_fake_families(self):
        original=(self.repo/bundle.LANDSCAPE).read_text()
        self.local(bundle.LANDSCAPE,(original+'\n# read_family("missing_comment_family")\n'
            'var note = "notes read_family(\\\"missing_string_family\\\")"\n').encode())
        self.assertEqual(len(self.check()['json']),7)

    def test_unknown_dynamic_family_expression_requires_adapter_instead_of_silent_omission(self):
        original=(self.repo/bundle.LANDSCAPE).read_text()
        for argument in ['unknown_family','String("windmill_highland_v1")']:
            with self.subTest(argument=argument):
                self.local(bundle.LANDSCAPE,(original+'\nvar candidate = read_family('+argument+')\n').encode())
                with self.assertRaisesRegex(ValueError,'not a finite known family'):self.check()

    def test_failed_woodland_v2_whole_family_and_imported_derivative_remain_excluded(self):
        family=bundle.SPACES+'woodland_two_depth_ridges_v2/'
        self.assertIn(family,bundle.EVIDENCE_ONLY_FAMILIES)
        self.assertIn(family,self.check()['excluded_evidence_families'])
        for name in ['family.json','source.png','production/any.png']:
            with self.subTest(name=name):
                broken=self.entries.copy();broken[family+name]=PNG
                with self.assertRaisesRegex(ValueError,'PCK contains excluded evidence-only family'):self.check(broken)
        target='.godot/imported/failed-woodland-v2.ctex'
        self.local(family+'source.png.import',('path="res://'+target+'"\n').encode())
        broken=self.entries.copy();broken[target]=b'failed imported derivative'
        with self.assertRaisesRegex(ValueError,'excluded evidence-only imported texture'):self.check(broken)

    def test_shipping_presets_include_literal_highland_and_exclude_failed_woodland_v2(self):
        presets=configparser.ConfigParser(interpolation=None);presets.read(bundle.REPO/'export_presets.cfg')
        for index in range(3):
            section=presets['preset.'+str(index)]
            included=section['include_filter'].strip('"').split(',')
            excluded=section['exclude_filter'].strip('"').split(',')
            for tail in ['family.json','source.png']:
                self.assertIn(bundle.SPACES+'windmill_highland_v1/'+tail,included)
            self.assertIn(bundle.SPACES+'woodland_two_depth_ridges_v2/*',excluded)


    def test_rejected_overhang_family_is_quarantined_in_every_shipping_preset(self):
        family = bundle.SPACES + 'supported_overhang_limestone_bank_v1/'
        self.assertIn(family, bundle.EVIDENCE_ONLY_FAMILIES)
        self.assertIn(family, self.check()['excluded_evidence_families'])
        presets = configparser.ConfigParser(interpolation=None)
        presets.read(bundle.REPO / 'export_presets.cfg')
        for index in range(3):
            excluded = presets['preset.' + str(index)]['exclude_filter'].strip('"').split(',')
            self.assertIn(family + '*', excluded)
        broken = self.entries.copy()
        broken[family + 'source.png'] = PNG
        with self.assertRaisesRegex(ValueError, 'PCK contains excluded evidence-only family'):
            self.check(broken)


class DeliveryMetadataTests(unittest.TestCase):
    """Delivery identity only; complete runtime validation remains in check()."""
    def test_exact_commit_pack_hash_and_size_are_required_after_transport(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); pack = root / 'fixture.pck'
            write_pack(pack, [('res://fixture.txt', b'actual small pack bytes')])
            commit = 'a' * 40
            original = {'source_commit': commit, 'pack': pack.name, 'pack_bytes': pack.stat().st_size,
                        'build_id': hashlib.sha256(pack.read_bytes()).hexdigest()[:12]}
            info = root / 'build-info.json'; info.write_text(json.dumps(original))
            self.assertEqual(bundle.verify_delivery_metadata(root, commit), original)
            for key, value in [('source_commit', 'b' * 40), ('pack', '../fixture.pck'), ('pack', '/tmp/a.pck'),
                               ('pack', 'sub\\a.pck'), ('pack_bytes', True), ('pack_bytes', 1), ('build_id', '0' * 12)]:
                with self.subTest(key=key, value=value):
                    info.write_text(json.dumps({**original, key: value}))
                    with self.assertRaises(ValueError): bundle.verify_delivery_metadata(root, commit)
            info.write_text(json.dumps(original)); pack.write_bytes(b'corrupt')
            with self.assertRaises(ValueError): bundle.verify_delivery_metadata(root, commit)
            pack.unlink(); pack.symlink_to(info)
            with self.assertRaises(ValueError): bundle.verify_delivery_metadata(root, commit)


if __name__ == '__main__':
    unittest.main()
