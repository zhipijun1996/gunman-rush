"""Narrow Bible source/lease counterexamples; no Godot or full source snapshots."""
import copy
import hashlib
import json
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tempfile
import unittest
import zlib
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import region_creative_direction as creative
import region_style_history as history
import level_design
import production_loop as loop
import visual_director




BOSS_PARENT_MANIFESTS = {'bellstrider': 'c6e8c5ccc283900a84d3d5f8078ce599e9e9ef35acc9a1cdf8ae38cfacb43159', 'windkeeper': 'bebfb3cd755699bd66deda0ed3d7a9969bb461c177aad4da89c9fd509129132b'}

MERGED_BOSSES_ARCHIVE = 'docs/creative_direction/archive/merge-20261031-style25/'
MERGED_BOSSES_STYLE = 'docs/creative_direction/bibles/style-continuity-20261031-v25-merged-bosses.json'


def boss_parent_source(parent, path):
    """Keep each parent leaf first, then the finite pre-layout shared source."""
    raw = history.archived_source(creative.ROOT, MERGED_BOSSES_ARCHIVE.rstrip('/') + '/' + parent, path)
    return history.style25_source(creative.ROOT, path) if raw is None else raw


def boss_parent_registry(parent):
    return json.loads((creative.ROOT/MERGED_BOSSES_ARCHIVE/parent/creative.BIBLE_REGISTRY).read_bytes())

WINDKEEPER24_ARCHIVE = 'docs/creative_direction/archive/windkeeper-pressure-before-style24/'
WINDKEEPER24_STYLE = 'docs/creative_direction/bibles/style-continuity-20261030-v24-windkeeper-pressure.json'
WINDKEEPER22_APP_SHA = 'f8e974d9ee22e0c36e33a638d2943213711fa01fbc61c2cf84ba2a0487903c8a'
WINDKEEPER22_STYLE_SHA = '4749a82126bbd84a1a826b2d1fb6406a1267050bd2624f5ed05911b238889188'


def windkeeper22_source(path):
    # Only the genuinely changed registered leaf is replaced by exact old
    # bytes. No arbitrary file-based fallback may hide another changed input.
    if path == 'scripts/demo/demo_app.gd':
        content = (ROOT/(WINDKEEPER24_ARCHIVE+'sources/'+path+'.txt')).read_bytes()
        if hashlib.sha256(content).hexdigest() != WINDKEEPER22_APP_SHA:
            raise AssertionError('Frozen pre-pressure App source changed')
        return content
    return before_bellstrider_source(path)


MERGE21_MANIFESTS = {'program': '74dce20a314ba573c15f24bbe17b6faee7cdf0a65728f403663057a7b49e9742', 'audio': 'f31f059792aea55b3a973cd9803e7c5b9d91497da593466b12a84bcc536fbe49'}
MERGE21_ARCHIVE = 'docs/creative_direction/archive/merge-20261030-style21/'

BELLSTRIDER_ARCHIVE = 'docs/creative_direction/archive/creative-v25-before-bellstrider-rework/'
BELLSTRIDER_STYLE23 = 'docs/creative_direction/bibles/style-continuity-20261030-v23-bellstrider-rework.json'
BELLSTRIDER_OLD_LEAVES = {'scripts/demo/plains_region_stage.gd','scripts/demo/demo_app.gd','scripts/combat/weapon_action_runtime.gd'}

def before_bellstrider_source(path):
    if path in BELLSTRIDER_OLD_LEAVES:
        return (ROOT/(BELLSTRIDER_ARCHIVE+'sources/'+path+'.txt')).read_bytes()
    return history.style25_source(ROOT, path)


def merge21_parent_source(parent, path):
    snapshot = ROOT/(MERGE21_ARCHIVE+parent+'/sources/'+Path(path).name+'.txt')
    return snapshot.read_bytes() if snapshot.is_file() else before_bellstrider_source(path)

STYLE19_PATH = 'docs/creative_direction/bibles/style-continuity-20261029-v19-mobile-ui-clarity.json'
STYLE20_PATH = 'docs/creative_direction/bibles/style-continuity-20261030-v20-audio-feedback.json'
STYLE22_ARCHIVE = 'docs/creative_direction/archive/creative-v22/'
STYLE23_ARCHIVE = 'docs/creative_direction/archive/creative-v23/'
STYLE19_FROZEN_PATHS = {
    'scripts/demo/demo_app.gd',
    'scripts/ui/demo_menu.gd',
    'scripts/items/v5/item_v5_shop_presenter.gd',
}


def style19_source(path):
    # Only the three genuinely changed leaves need frozen historical bytes.
    if path in STYLE19_FROZEN_PATHS:
        return (ROOT/(STYLE22_ARCHIVE+'runtime_inputs/'+Path(path).name+'.txt')).read_bytes()
    return merge21_parent_source('audio',path)


def style20_source(path):
    if path == 'scripts/ui/demo_menu.gd':
        return (ROOT/(STYLE23_ARCHIVE+'runtime_inputs/demo_menu.gd.txt')).read_bytes()
    return merge21_parent_source('audio',path)


# Actual visual consumer additions; original36 stay in their original order.
ITEM_V5_STYLE_REFERENCES = [
    ('item_feedback_view', 'scripts/items/v5/item_effect_view.gd'),
    ('item_feedback_config', 'config/item_v5_feedback.json'),
    ('item_entity_view', 'scripts/items/v5/item_v5_entity.gd'),
    ('item_entity_config', 'config/item_v5_entities.json'),
    ('item_defense_glyphs', 'scripts/items/v5/item_defense_effects.gd'),
    ('item_defense_visual_config', 'config/item_v5_defense.json'),
    ('item_resource_hud', 'scripts/ui/actor_resources_hud.gd'),
    ('item_pause_menu', 'scripts/ui/demo_menu.gd'),
    ('item_description', 'scripts/ui/item_presentation.gd'),
    ('item_card', 'scripts/ui/item_card.gd'),
    ('item_toast', 'scripts/ui/item_acquired_toast.gd'),
    ('item_shop_modal', 'scripts/ui/item_shop_modal.gd'),
    ('item_reward_modal', 'scripts/ui/stage_reward_modal.gd'),
    ('item_touch_control', 'scripts/ui/touch_overlay.gd'),
    ('item_shop_presenter', 'scripts/items/v5/item_v5_shop_presenter.gd'),
    ('item_weapon_runtime', 'scripts/combat/weapon_action_runtime.gd'),
    ('item_weapon_feel', 'scripts/dev/player_presentation_01/weapon_feel.gd'),
    ('item_weapon_vfx', 'scripts/dev/player_presentation_01/weapon_vfx_v2.gd'),
]

ITEM_ART_GOLDEN_REFERENCES = [
    ('item_art_library', 'scripts/items/v5/item_art_library.gd'),
    ('item_art_config', 'config/item_v5_art.json'),
    ('item_icon_metadata', 'config/item_v5_authoring.json'),
    ('item_icon_atlas_first8', 'assets/items/v5/icons/golden-02.source.png'),
    ('item_vfx_p24_source', 'assets/items/v5/vfx/p24-01.source.png'),
    ('item_vfx_p14_source', 'assets/items/v5/vfx/p14-01.source.png'),
    ('item_vfx_g16_source', 'assets/items/v5/vfx/g16-01.source.png'),
]

ITEM_ART_EXPANSION_REFERENCES = [
    ('item_icon_atlas_catalog01', 'assets/items/v5/icons/catalog-01.source.png'),
    ('item_icon_atlas_catalog02', 'assets/items/v5/icons/catalog-02.source.png'),
    ('item_icon_atlas_catalog03', 'assets/items/v5/icons/catalog-03.source.png'),
    ('item_icon_atlas_catalog04', 'assets/items/v5/icons/catalog-04.source.png'),
    ('item_vfx_static_entities_source', 'assets/items/v5/vfx/static-entities.source.png'),
    ('item_vfx_static_procs_source', 'assets/items/v5/vfx/static-procs.source.png'),
    ('item_world_sampler_shader', 'shaders/item_v5_world_sprite.gdshader'),
]


HOME_CODEX_REFERENCES = [
    ('home_codex_ui', 'scripts/ui/home_item_codex.gd'),
    ('home_codex_world', 'scripts/underworld_plains/underworld_home_world.gd'),
    ('home_item_catalog_policy', 'scripts/meta/home_item_catalog.gd'),
    ('home_item_policy_config', 'config/home_items.json'),
    ('home_item_profile_presenter', 'scripts/meta/meta_progression.gd'),
]


CHEST_ART_REFERENCES = [
    ('chest_art_library', 'scripts/art/chest_art_library.gd'),
    ('chest_art_layer', 'scripts/art/chest_art_layer.gd'),
    ('chest_formal_dispatch', 'scripts/underworld_plains/underworld_objects.gd'),
    ('chest_forest_presentation', 'scripts/presentation/forest_bible_presentation.gd'),
    ('chest_forest_stage', 'scripts/demo/thorn_forest_region_stage.gd'),
    ('chest_cosmetic_boundary', 'scripts/art/p1_unity_props.gd'),
    ('chest_art_config', 'config/chest_art.json'),
    ('chest_source04_atlas', 'assets/objects/chests/chest-tiers-v1.source.png'),
]



MERGE_PARENT_ARCHIVE = 'docs/creative_direction/archive/merge-20261030-style19/'
PARENT_MANIFESTS = {'program': '8a7599713c3335b8db484608d6aef75efb44c5685e59f8f57e9fa7f30e1db4fc', 'mobile': '9b655c34c32ec6921932f2e5312a06560aa82d44da42fa13dd03c564fe19eff5'}
MERGE_UI_LEAVES = {'scripts/demo/home_scene.gd','scripts/ui/demo_menu.gd',
                   'scripts/ui/stage_reward_modal.gd','scripts/ui/home_item_codex.gd'}

def merge_parent_source(parent, path):
    # Exact seven source snapshots keep both historical contracts meaningful
    # after the other branch changes their live filesystem consumers.
    snapshot = ROOT/(MERGE_PARENT_ARCHIVE+parent+'/sources/'+Path(path).name+'.txt')
    return snapshot.read_bytes() if snapshot.is_file() else merge21_parent_source('program',path)



MOTION_LOOT_ARCHIVE = 'docs/creative_direction/archive/creative-v23-before-plains-motion-loot/'
MOTION_LOOT_ARCHIVE_SHA = '9f93b5c60a5c56845484314df8800b06a8a4faadc8092c1ab94b0acb3bc33ab5'

def initial20_source(path):
    if path in {'scripts/demo/demo_app.gd','scripts/demo/plains_region_stage.gd','scripts/demo/thorn_forest_region_stage.gd'}:
        return (ROOT/(MOTION_LOOT_ARCHIVE+'sources/'+Path(path).name+'.txt')).read_bytes()
    return merge21_parent_source('program',path)


class BibleTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        for name in ['docs/world_regions.json', creative.BIBLE_REGISTRY,
                     'docs/creative_direction/bibles/user-request.json',
                     'docs/creative_direction/bibles/1-windchime_plains_region_bible_v2.md',
                     'docs/creative_direction/bibles/2-thorn_forest_region_bible_v2.md']:
            target = self.root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / name, target)
        reg = json.loads((ROOT/creative.BIBLE_REGISTRY).read_bytes())
        ref = reg['shared_style_authority']
        supplement = json.loads((ROOT/ref['path']).read_bytes())
        for name in [ref['path'], *[row['path'] for row in supplement['runtime_reference']['references']]]:
            target = self.root/name; target.parent.mkdir(parents=True,exist_ok=True)
            shutil.copyfile(ROOT/name,target)
        self.bible, self.ref = creative.bind_region_bible('thorn_forest', self.root)

    def registry(self, mutate):
        path = self.root / creative.BIBLE_REGISTRY
        data = json.loads(path.read_bytes())
        row = next(r for r in data['regions'] if r['region_id'] == 'thorn_forest')
        mutate(data, row)
        path.write_text(json.dumps(data))

    def task(self):
        return {'id':'BIBLE', 'goal':'Inspect selected forest Bible', 'region_id':'thorn_forest',
                'region_bible':self.ref, 'skills':['gameplay-reviewer'], 'checks':['docs'], 'read_only':True}

    def test_cli_and_original_selected_bytes(self):
        result = subprocess.run([sys.executable, str(ROOT/'tools/region_creative_direction.py'), '--check-bibles'],
                                cwd=ROOT, capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('PASS:', result.stdout)
        self.assertEqual(len(creative.load_bible_registry(self.root)['regions']), 16)
        self.assertEqual(self.ref['sha256'], hashlib.sha256((self.root/self.ref['path']).read_bytes()).hexdigest())
        self.assertEqual(self.bible['music_status'], 'deferred_user_supplied')

    def test_missing_bible_is_distinct_from_invalid_bible(self):
        with self.assertRaises(creative.MissingBible):
            creative.bind_region_bible('firefly_marsh', self.root)
        self.registry(lambda data,row:row['current_bible'].update(status='proposed'))
        with self.assertRaisesRegex(ValueError, 'selected direction'):
            creative.bind_region_bible('thorn_forest', self.root)

    def test_wrong_region_partial_binding_and_wrong_version_fail(self):
        for ref in ({}, {**self.ref,'region_id':'windchime_plains'}, {**self.ref,'version':'3.0'}):
            with self.subTest(ref=ref), self.assertRaises(ValueError):
                creative.validate_bible_binding(ref, 'thorn_forest', self.root)
        for version in ('3.0', '2.1'):
            self.registry(lambda data,row:row['current_bible'].update(version=version))
            with self.subTest(version=version), self.assertRaisesRegex(ValueError, 'version/region'):
                creative.bind_region_bible('thorn_forest', self.root)

    def test_unannounced_original_drift_never_refreshes_binding(self):
        path = self.root / self.ref['path']
        path.write_bytes(path.read_bytes() + b'\nchanged original\n')
        with self.assertRaisesRegex(ValueError, 'impact analysis'):
            creative.validate_bible_binding(self.ref, root=self.root)

    def test_registry_drift_invalidates_existing_binding_even_if_bible_unchanged(self):
        path = self.root / creative.BIBLE_REGISTRY
        path.write_bytes(path.read_bytes() + b'\n')
        with self.assertRaisesRegex(ValueError, 'independent review/rebind'):
            creative.validate_bible_binding(self.ref, root=self.root)

    def test_duplicate_json_and_duplicate_regions_rejected(self):
        path = self.root / creative.BIBLE_REGISTRY
        raw = path.read_text()
        path.write_text(raw[:-2] + ', "schema_version":1}\n')
        with self.assertRaisesRegex(ValueError, 'Duplicate JSON key'):
            creative.load_bible_registry(self.root)
        path.write_text(raw)
        self.registry(lambda data,row:data['regions'].append(copy.deepcopy(row)))
        with self.assertRaisesRegex(ValueError, 'exactly once'):
            creative.load_bible_registry(self.root)

    def test_path_escape_absolute_and_symlink_ancestors_rejected(self):
        for name in ('../outside.md', '/tmp/outside.md'):
            with self.subTest(name=name), self.assertRaises(ValueError):
                creative.repository_file(name, self.root)
        directory = self.root/'docs/creative_direction/bibles'
        actual = self.root/'originals'
        directory.rename(actual)
        directory.symlink_to(actual, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, 'symlinks'):
            creative.bind_region_bible('thorn_forest', self.root)

    def test_selection_needs_raw_original_user_evidence(self):
        self.registry(lambda data,row:row['current_bible'].pop('selection_evidence'))
        with self.assertRaisesRegex(ValueError, 'original user instruction'):
            creative.bind_region_bible('thorn_forest', self.root)

    def test_hash_refresh_cannot_turn_another_attachment_into_forest(self):
        self.registry(lambda data,row:row['current_bible'].update(
            path='docs/creative_direction/bibles/1-windchime_plains_region_bible_v2.md'))
        with self.assertRaisesRegex(ValueError, 'version/region'):
            creative.bind_region_bible('thorn_forest', self.root)

    def test_selected_direction_cannot_forge_raw_quote_or_player_approval(self):
        data = json.loads((ROOT/'docs/creative_direction/thorn_forest.json').read_bytes())
        data['user_acceptance'] = 'player_approved'
        self.assertTrue(creative.validate_direction(data))
        data['user_acceptance'] = 'direction_only_not_art_gameplay_or_device'
        for name in [ref['path'] for ref in data['authority_sources']]:
            target = self.root/name
            if not target.exists():
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT/name,target)
        data['user_evidence']['quote'] = 'Fabricated approval'
        path = self.root/'forged-direction.json'; path.write_text(json.dumps(data))
        with self.assertRaisesRegex(ValueError, 'actual original instruction'):
            creative.load_direction('forged-direction.json','thorn_forest',self.root)

    def test_cross_attachment_bytes_cannot_be_relabelled_with_refreshed_registry(self):
        # Exact reproduction of independent-review/cross-attachment-probe-first:
        # leave both original evidence attachment rows and their SHA untouched.
        plains = self.root/'docs/creative_direction/bibles/1-windchime_plains_region_bible_v2.md'
        forest = self.root/self.ref['path']
        forest.write_bytes(plains.read_bytes())
        sha = hashlib.sha256(forest.read_bytes()).hexdigest()
        self.registry(lambda data,row:row['current_bible'].update(sha256=sha))
        with self.assertRaisesRegex(ValueError, 'original/staged attachment identity'):
            creative.bind_region_bible('thorn_forest', self.root)

    def test_original_staged_basename_mismatch_and_duplicate_identity_refused(self):
        evidence_path = self.root/self.ref['selection_evidence_path']
        original = json.loads(evidence_path.read_bytes())
        for failure in ('staged_wrong_region', 'original_wrong_region', 'duplicate_original'):
            data = copy.deepcopy(original)
            forest = next(a for a in data['attachments'] if 'thorn_forest' in a['staged_path'])
            if failure == 'staged_wrong_region': forest['staged_path'] = data['attachments'][0]['staged_path']
            elif failure == 'original_wrong_region': forest['original_attachment_path'] = data['attachments'][0]['original_attachment_path']
            else: data['attachments'].append(copy.deepcopy(forest))
            evidence_path.write_text(json.dumps(data))
            sha = hashlib.sha256(evidence_path.read_bytes()).hexdigest()
            self.registry(lambda data,row:row['current_bible']['selection_evidence'].update(sha256=sha))
            with self.subTest(failure=failure), self.assertRaisesRegex(ValueError, 'attachment'):
                creative.bind_region_bible('thorn_forest', self.root)

    def test_latest_shared_style_quotes_and_actual_family_bind_all_region_production(self):
        style = creative.supplemental_authority(self.bible,'thorn_forest',self.root)
        data = style['content']
        self.assertEqual(data['source']['quote'],'森林的tile set得和风铃平原的整体风格一致，只是体现不同的区域特色。你这个都直接扔掉了')
        self.assertEqual(data['source']['additional_quote'],'同时后续区域不要出类似的问题')
        self.assertEqual(data['applies_to'],'all_region_create_optimize_and_proposed_bibles')
        self.assertEqual([data['runtime_reference'][k] for k in ('tile_px','world_tile_wu')],[32,32])
        refs = data['runtime_reference']['references']
        self.assertTrue(any(row['path']=='scripts/underworld_plains/underworld_terrain.gd' for row in refs))
        for row in refs:
            self.assertEqual(hashlib.sha256((self.root/row['path']).read_bytes()).hexdigest(),row['sha256'])
        for region, expected in [('windchime_plains','02c9dd3299d12c91a426cf40b2a5885e526b51f467b955539b4b5ff99e1aca35'),('thorn_forest','a7bad8323af64a7be0577132e5d988a6e1b781d9e1ac1639d37f9d65935194e3')]:
            _,ref = creative.bind_region_bible(region,self.root)
            self.assertEqual(ref['sha256'],expected)
            self.assertEqual(ref['supplemental_authority_sha256'],style['sha256'])

    def test_future_proposed_worker_gets_shared_style_without_visual_gate(self):
        mission = level_design.route_request('制作萤雾沼泽')
        task = mission['tasks'][0]
        self.assertEqual(task['required_gates'],['G0'])
        registry=creative.load_bible_registry()
        missing=[row['region_id'] for row in registry['regions'] if row['current_bible'] is None]
        self.assertEqual(len(missing),14)
        for region in missing:
            proposed=level_design.route_request('create '+region)['tasks'][0]
            self.assertEqual(proposed['shared_style_authority'],task['shared_style_authority'])
            self.assertEqual(proposed['required_gates'],['G0'])
        folder=self.root/'future-prompt';folder.mkdir()
        prompt,*_ = loop.prepare_call(task,mission,'implement',folder,'{}',check_contracts={'checks':[]})
        self.assertIn('同时后续区域不要出类似的问题',prompt)
        self.assertIn('scripts/underworld_plains/underworld_terrain.gd',prompt)
        sources=loop.bound_source_inputs(task)
        self.assertIn(task['shared_style_authority'],sources)
        self.assertGreater(len(sources),10)
        task.pop('shared_style_authority')
        with self.assertRaisesRegex(ValueError,'Shared style authority binding'):
            loop.region_bible_input(task)

    def test_shared_reference_or_quote_drift_blocks_calls_and_restore(self):
        style=creative.supplemental_authority(self.bible,'thorn_forest',self.root)
        paths=[style['path'],'shaders/formal_fine_boundary.gdshader','assets/underworld_plains/terrain/fine_32/terrain.png','assets/underworld_plains/terrain/fine_32/source.png','assets/underworld_plains/terrain/fine_32/terrain.tres',
               'scripts/art/player_presentation_runtime.gd','assets/player_presentation_01/motion_v1/motion_source.png','resources/art/avatars.json','scripts/demo/demo_app.gd','scripts/underworld_plains/underworld_presentation.gd']
        paths.extend(path for _,path in ITEM_V5_STYLE_REFERENCES)
        paths.extend(path for _,path in ITEM_ART_GOLDEN_REFERENCES)
        paths.extend(path for _,path in ITEM_ART_EXPANSION_REFERENCES)
        paths.extend(path for _,path in HOME_CODEX_REFERENCES)
        paths.extend(path for _,path in CHEST_ART_REFERENCES)
        skill=self.root/'.agents/skills/gameplay-reviewer/SKILL.md';skill.parent.mkdir(parents=True,exist_ok=True);skill.write_text('Synthetic reviewer')
        stripped=self.task();stripped['region_bible']={k:v for k,v in self.ref.items() if not k.startswith('supplemental_authority_')}
        with patch.object(loop,'ROOT',self.root),self.assertRaisesRegex(ValueError,'binding changed'):
            loop.region_bible_input(stripped)
        for name in paths:
            path=self.root/name;raw=path.read_bytes();path.write_bytes(raw+b'changed')
            with self.subTest(path=name),patch.object(loop,'ROOT',self.root):
                with self.assertRaisesRegex(ValueError,'SHA changed'):
                    creative.validate_bible_binding(self.ref,root=self.root)
                self.assertIn('BIBLE',loop.mission_bible_preflight({'objective':'Update the regional generator','tasks':[self.task()]}))
                mission={'schema_version':1,'objective':'Update the regional generator','tasks':[self.task()], 'max_calls':2,'max_rounds':1,'call_timeout_seconds':10,'native_import_preflight':True}
                with patch.object(loop,'snapshot',side_effect=AssertionError('must not snapshot')),patch.object(loop,'native_import_preflight',side_effect=AssertionError('must not import')):
                    state=loop.run(mission,self.root/('style-drift-'+hashlib.sha256(name.encode()).hexdigest()[:12]),lambda *a:self.fail('must not invoke'))
                self.assertEqual(state['calls'],0)
                self.assertEqual(state['status'],'blocked')
                with self.assertRaisesRegex(ValueError,'SHA changed'):
                    loop.validate_restored_completion({'tasks':[self.task()]},{'tasks':{'BIBLE':{'status':'complete'}}},self.root/'no-resume')
            path.write_bytes(raw)
            self.assertEqual(creative.validate_bible_binding(self.ref,root=self.root)[1],self.ref)

    def test_global_physics_actions_and_plain_docs_have_no_shared_art_gate(self):
        for path in ('scripts/player/player_motor.gd','scripts/player/traversal_ability.gd','docs/controls_contract.md'):
            task={'goal':'Fix global physics or action contract','allowed_paths':[path]}
            with self.subTest(path=path),patch.object(creative,'supplemental_authority',side_effect=AssertionError('unrelated task must not load shared art')):
                self.assertIsNone(loop.region_bible_input(task))
                self.assertIsNone(loop.shared_style_input(task))

    def test_actual_player_body_closure_is_required_and_superseded_binding_refused(self):
        style = creative.supplemental_authority(self.bible,'thorn_forest',self.root)
        self.assertEqual(style['content']['version'],'25')
        self.assertEqual(json.loads((ROOT/(BELLSTRIDER_ARCHIVE+'style22.json')).read_bytes())['version'],'22')
        style = {**style,'content':json.loads((ROOT/(MERGE21_ARCHIVE+'program/style21.json')).read_bytes())}
        self.assertEqual(style['content']['version'],'21')
        # Preserve the entire original19/18 history against immutable parent19.
        style = {**style,'content':json.loads((ROOT/(MERGE_PARENT_ARCHIVE+'program/style19.json')).read_bytes())}
        self.assertEqual(style['content']['version'],'19')
        new_refs = style['content']['runtime_reference']['references']
        self.assertEqual(len(new_refs),81)
        old_style_path = 'docs/creative_direction/bibles/style-continuity-20261028-v18-chest-art.json'
        old_style_raw = (ROOT/old_style_path).read_bytes()
        self.assertEqual(hashlib.sha256(old_style_raw).hexdigest(),'22c2afbb1a298bfbb5f72315b4f60aefc9ae377a6c93bc47780ef6ae4f0a7510')
        old_style = json.loads(old_style_raw)
        self.assertEqual(old_style['version'],'18')
        actual_refs = old_style['runtime_reference']['references']
        self.assertEqual(len(actual_refs),81)
        history_root = 'docs/creative_direction/archive/creative-v21/'
        history_manifest_raw = (ROOT/(history_root+'manifest.json')).read_bytes()
        self.assertEqual(hashlib.sha256(history_manifest_raw).hexdigest(),'1748d7171770ba8bfdaaa415a5a1fd11e6b04d5353fa4bd0076b18debae49a62')
        for row in json.loads(history_manifest_raw)['files']:
            raw = (ROOT/(history_root+row['path'])).read_bytes()
            self.assertEqual(hashlib.sha256(raw).hexdigest(),row['sha256'])
            self.assertEqual(len(raw),row['bytes'])
        changed = {'scripts/demo/demo_app.gd','scripts/demo/plains_region_stage.gd',
                   'scripts/demo/thorn_forest_region_stage.gd'}
        def chest18_source(path):
            if path in MERGE_UI_LEAVES:
                return (ROOT/('docs/evidence/mobile_ui_clarity_01/source-bindings/before-style19/'+Path(path).name+'.txt')).read_bytes()
            if path in changed:
                return (ROOT/(history_root+'sources/'+Path(path).name+'.txt')).read_bytes()
            return merge21_parent_source('program',path)
        changed_actual = set()
        for before,after in zip(actual_refs,new_refs):
            self.assertEqual({k:v for k,v in before.items() if k!='sha256'},
                             {k:v for k,v in after.items() if k!='sha256'})
            self.assertEqual(before['sha256'],hashlib.sha256(chest18_source(before['path'])).hexdigest())
            self.assertEqual(after['sha256'],hashlib.sha256(merge_parent_source('program',after['path'])).hexdigest())
            if before != after:
                changed_actual.add(before['path'])
            else:
                self.assertNotIn(before['path'],changed)
        self.assertEqual(changed_actual,changed)
        self.assertEqual(style['content']['supersedes']['path'],old_style_path)
        self.assertEqual(style['content']['supersedes']['sha256'],hashlib.sha256(old_style_raw).hexdigest())
        for key in old_style.keys()-{'version','runtime_reference','supersedes','revision_impact'}:
            self.assertEqual(style['content'][key],old_style[key])
        self.assertEqual({k:v for k,v in style['content']['runtime_reference'].items() if k!='references'},
                         {k:v for k,v in old_style['runtime_reference'].items() if k!='references'})
        stale18 = copy.deepcopy(self.ref)
        stale18['supplemental_authority_path'] = old_style_path
        stale18['supplemental_authority_sha256'] = hashlib.sha256(old_style_raw).hexdigest()
        with self.assertRaisesRegex(ValueError,'binding changed'):
            creative.validate_bible_binding(stale18,root=self.root)
        # Bind01 remains exact. The same unpublished candidate now changes
        # only App's explicit post-restore notification; other80 rows remain.
        bind01_root = 'docs/creative_direction/archive/creative-v22/before-boss-restore-notification/'
        bind01_manifest_raw = (ROOT/(bind01_root+'manifest.json')).read_bytes()
        self.assertEqual(hashlib.sha256(bind01_manifest_raw).hexdigest(),'15338e2ffc77252855f40e6ba83b8a44fa96035a4f7942539000dc859e5d7262')
        for row in json.loads(bind01_manifest_raw)['files']:
            raw = (ROOT/(bind01_root+row['path'])).read_bytes()
            self.assertEqual(hashlib.sha256(raw).hexdigest(),row['sha256'])
            self.assertEqual(len(raw),row['bytes'])
        bind01_raw = (ROOT/(bind01_root+'style19.json')).read_bytes()
        self.assertEqual(hashlib.sha256(bind01_raw).hexdigest(),'411db2a5b5d59f447f20465559cb7869cc96c0bcf49a0ef3244abd7ec47906aa')
        bind01 = json.loads(bind01_raw)
        self.assertEqual(bind01['version'],'19')
        self.assertEqual(len(bind01['runtime_reference']['references']),81)
        bind01_changed = set()
        for before,after in zip(bind01['runtime_reference']['references'],new_refs):
            self.assertEqual({k:v for k,v in before.items() if k!='sha256'},
                             {k:v for k,v in after.items() if k!='sha256'})
            if before != after:
                bind01_changed.add(before['path'])
                prior = (ROOT/(bind01_root+'demo_app.gd.txt')).read_bytes()
                self.assertEqual(before['sha256'],hashlib.sha256(prior).hexdigest())
            else:
                self.assertEqual(before,after)
        self.assertEqual(bind01_changed,{'scripts/demo/demo_app.gd'})
        stale19 = copy.deepcopy(self.ref)
        stale19['supplemental_authority_path'] = bind01_root+'style19.json'
        stale19['supplemental_authority_sha256'] = hashlib.sha256(bind01_raw).hexdigest()
        with self.assertRaisesRegex(ValueError,'binding changed'):
            creative.validate_bible_binding(stale19,root=self.root)
        home_path = 'docs/creative_direction/bibles/style-continuity-20261028-v17-home-codex.json'
        home_raw = (ROOT/home_path).read_bytes()
        self.assertEqual(hashlib.sha256(home_raw).hexdigest(),'ab5f9289fccc909596abf05e9dbb9a4b6c297824d2efc9d69440dfe88c7c16fa')
        home_style = json.loads(home_raw)
        self.assertEqual(home_style['version'],'17')
        live_refs = home_style['runtime_reference']['references']
        self.assertEqual(len(live_refs),73)
        input_archive = 'docs/evidence/chest_art_01/source-bindings/before-reward-input-rebind/'
        pre_input_raw = (ROOT/(input_archive+'style-continuity-20261028-v18-chest-art.json')).read_bytes()
        self.assertEqual(hashlib.sha256(pre_input_raw).hexdigest(),'44206cc99ddddf587b4052a98503ee6c9b2017ef6a6d6f1dd15dd57fe0504624')
        pre_input = json.loads(pre_input_raw)
        self.assertEqual(pre_input['version'],'18')
        chest_refs = pre_input['runtime_reference']['references']
        self.assertEqual(len(chest_refs),81)
        input_manifest_raw = (ROOT/(input_archive+'manifest.json')).read_bytes()
        self.assertEqual(hashlib.sha256(input_manifest_raw).hexdigest(),'d2ca9013df23b0d6488dc9c8638a5b09f6b27dcd64c0e4cbe78d5b4e8ae57efb')
        for row in json.loads(input_manifest_raw)['files']:
            raw = (ROOT/(input_archive+row['path'])).read_bytes()
            self.assertEqual(hashlib.sha256(raw).hexdigest(),row['sha256'])
            self.assertEqual(len(raw),row['bytes'])
        for before,after in zip(chest_refs,actual_refs):
            self.assertEqual({k:v for k,v in before.items() if k!='sha256'},
                             {k:v for k,v in after.items() if k!='sha256'})
            self.assertEqual(after['sha256'],hashlib.sha256(chest18_source(after['path'])).hexdigest())
            if before['path']=='scripts/demo/demo_app.gd':
                old_app = (ROOT/(input_archive+'demo_app.gd.txt')).read_bytes()
                self.assertEqual(before['sha256'],hashlib.sha256(old_app).hexdigest())
                self.assertNotEqual(before['sha256'],after['sha256'])
            else:
                self.assertEqual(before,after)
        stale_pre_input = copy.deepcopy(self.ref)
        stale_pre_input['supplemental_authority_path'] = input_archive+'style-continuity-20261028-v18-chest-art.json'
        stale_pre_input['supplemental_authority_sha256'] = hashlib.sha256(pre_input_raw).hexdigest()
        with self.assertRaisesRegex(ValueError,'binding changed'):
            creative.validate_bible_binding(stale_pre_input,root=self.root)
        chest_archive = 'docs/evidence/chest_art_01/source-bindings/before-style18/'
        chest_manifest_raw = (ROOT/(chest_archive+'manifest.json')).read_bytes()
        self.assertEqual(hashlib.sha256(chest_manifest_raw).hexdigest(),'7693e9159827ca55aeb61bf068b58675e31926abfdf85bd25300a085db7c6615')
        for row in json.loads(chest_manifest_raw)['files']:
            raw = (ROOT/(chest_archive+row['path'])).read_bytes()
            self.assertEqual(hashlib.sha256(raw).hexdigest(),row['sha256'])
            self.assertEqual(len(raw),row['bytes'])
        def first_chest_source(path):
            if path == 'scripts/demo/demo_app.gd':
                return (ROOT/(input_archive+'demo_app.gd.txt')).read_bytes()
            return chest18_source(path)
        def pre_chest_source(path):
            if path == 'scripts/demo/plains_region_stage.gd':
                return (ROOT/(chest_archive+'plains_region_stage.gd.txt')).read_bytes()
            return first_chest_source(path)
        for before,after in zip(live_refs,chest_refs[:73]):
            self.assertEqual({k:v for k,v in before.items() if k!='sha256'},
                             {k:v for k,v in after.items() if k!='sha256'})
            self.assertEqual(before['sha256'],hashlib.sha256(pre_chest_source(before['path'])).hexdigest())
            self.assertEqual(after['sha256'],hashlib.sha256(first_chest_source(after['path'])).hexdigest())
            if before['path']=='scripts/demo/plains_region_stage.gd':
                self.assertNotEqual(before['sha256'],after['sha256'])
            else:
                self.assertEqual(before,after)
        self.assertEqual([(row['role'],row['path']) for row in actual_refs[73:]],CHEST_ART_REFERENCES)
        for row in actual_refs[73:]:
            self.assertEqual(row['sha256'],hashlib.sha256(chest18_source(row['path'])).hexdigest())
        self.assertEqual(old_style['supersedes']['path'],home_path)
        self.assertEqual(old_style['supersedes']['sha256'],hashlib.sha256(home_raw).hexdigest())
        for key in home_style.keys()-{'version','runtime_reference','supersedes','revision_impact'}:
            self.assertEqual(old_style[key],home_style[key])
        published_path = 'docs/creative_direction/bibles/style-continuity-20261028-v16-item-authoring.json'
        published_raw = (ROOT/published_path).read_bytes()
        self.assertEqual(hashlib.sha256(published_raw).hexdigest(),'62befdd0e89ea7b17b649b93dce977b1a35eb2164bad1b9500c108b33309b6da')
        published_style = json.loads(published_raw)
        self.assertEqual(published_style['version'],'16')
        current_refs = published_style['runtime_reference']['references']
        self.assertEqual(len(current_refs),68)
        archive_root = 'docs/evidence/home_codex_01/source-bindings/before-style17/'
        manifest_raw = (ROOT/(archive_root+'manifest.json')).read_bytes()
        self.assertEqual(hashlib.sha256(manifest_raw).hexdigest(),'9b0f3e344a95cab2320894659b6a76828fdbbf2b2a947df0d71f05b67d1e54dc')
        manifest = json.loads(manifest_raw)
        for row in manifest['files']:
            raw = (ROOT/(archive_root+row['path'])).read_bytes()
            self.assertEqual(hashlib.sha256(raw).hexdigest(),row['sha256'])
            self.assertEqual(len(raw),row['bytes'])
        changed_home = {'scripts/demo/demo_app.gd','scripts/demo/home_scene.gd'}
        def historical_source(path):
            if path in changed_home:
                return (ROOT/(archive_root+Path(path).name+'.txt')).read_bytes()
            return pre_chest_source(path)
        for before,after in zip(current_refs,live_refs[:68]):
            self.assertEqual({k:v for k,v in before.items() if k!='sha256'},
                             {k:v for k,v in after.items() if k!='sha256'})
            self.assertEqual(before['sha256'],hashlib.sha256(historical_source(before['path'])).hexdigest())
            self.assertEqual(after['sha256'],hashlib.sha256(pre_chest_source(after['path'])).hexdigest())
            if before['path'] in changed_home:
                self.assertNotEqual(before['sha256'],after['sha256'])
            else:
                self.assertEqual(before,after)
        self.assertEqual([(row['role'],row['path']) for row in live_refs[68:]],HOME_CODEX_REFERENCES)
        for row in live_refs[68:]:
            self.assertEqual(row['sha256'],hashlib.sha256(merge_parent_source('program',row['path'])).hexdigest())
        self.assertEqual(home_style['supersedes']['path'],published_path)
        self.assertEqual(home_style['supersedes']['sha256'],hashlib.sha256(published_raw).hexdigest())
        for key in published_style.keys()-{'version','runtime_reference','supersedes','revision_impact'}:
            self.assertEqual(home_style[key],published_style[key])
        r12_root = 'docs/evidence/item_art_01/source-bindings/pre-main-audio-r13/'
        r12_path = r12_root+'style-continuity-20261028-v16-item-authoring.json'
        r12_raw = (ROOT/r12_path).read_bytes()
        self.assertEqual(hashlib.sha256(r12_raw).hexdigest(),'079de07b65d33c4e12364a22fa2f8408b0cd63b6044570bb6c7b5800799cf403')
        r12 = json.loads(r12_raw)
        self.assertEqual(r12['version'],'16')
        self.assertEqual(len(r12['runtime_reference']['references']),68)
        pre_audio_refs = r12['runtime_reference']['references']
        for before,after in zip(pre_audio_refs,current_refs):
            if before['path']=='scripts/dev/player_presentation_01/weapon_feel.gd':
                self.assertEqual({k:v for k,v in before.items() if k!='sha256'},{k:v for k,v in after.items() if k!='sha256'})
                self.assertNotEqual(before['sha256'],after['sha256'])
                old_leaf = (ROOT/(r12_root+'weapon_feel.gd.txt')).read_bytes()
                self.assertEqual(before['sha256'],hashlib.sha256(old_leaf).hexdigest())
                new_leaf = (ROOT/after['path']).read_text()
                sound_call = 'audio.weapon_cue(cue,_owner,key,profile.shot_attenuation if attenuation<0 else attenuation,sustained,controller.shoot_ability.weapon.id)'
                self.assertEqual(new_leaf.count(sound_call),1)
                self.assertEqual(new_leaf.replace(sound_call,'audio.weapon_cue(cue,_owner,key,profile.shot_attenuation if attenuation<0 else attenuation,sustained)'),old_leaf.decode())
            else:
                self.assertEqual(before,after)
        stale_r12 = copy.deepcopy(self.ref)
        stale_r12['supplemental_authority_path'] = r12_path
        stale_r12['supplemental_authority_sha256'] = hashlib.sha256(r12_raw).hexdigest()
        with self.assertRaisesRegex(ValueError,'binding changed'):
            creative.validate_bible_binding(stale_r12,root=self.root)
        # Frozen Markdown keeps exact bytes as .md.txt: its original relative
        # links cannot be resolved from a different archive directory. Live .md
        # files are explicit navigation wrappers, not rewritten originals.
        markdown_archives = {
            'docs/evidence/item_authoring_01/source-bindings/before-v16':
                '2e0bd3e6c34bfe331ea71e368f0f59486595aa0fa5107d5e6a75fe7390138858',
            'docs/evidence/item_art_01/source-bindings/pre-golden-r08':
                'cee721987fdd001db0815bf55fa0cad97e9441c4bd0fab815c559a5664fc0592',
            'docs/evidence/item_art_01/source-bindings/pre-expansion-r09':
                '9eaa2d11a9569c25a8bf858b5104e649a6595fa51e8c563bd56a4a0d85d65725',
        }
        relocated_markdown = 0
        for archive_path,original_digest in markdown_archives.items():
            folder = ROOT/archive_path
            original_raw = (folder/'manifest.before-markdown-relocation.json.txt').read_bytes()
            self.assertEqual(hashlib.sha256(original_raw).hexdigest(),original_digest)
            original_manifest = json.loads(original_raw)
            manifest = json.loads((folder/'manifest.json').read_bytes())
            self.assertEqual({k:v for k,v in manifest.items() if k not in {'files','original_manifest_before_markdown_relocation'}},
                             {k:v for k,v in original_manifest.items() if k!='files'})
            self.assertEqual(len(manifest['files']),len(original_manifest['files']))
            for before,after in zip(original_manifest['files'],manifest['files']):
                self.assertEqual({k:v for k,v in after.items() if k!='relocation'},before)
                if before['path'].endswith('.md'):
                    relocated_markdown += 1
                    self.assertEqual(after['relocation']['path'],before['path']+'.txt')
                    self.assertEqual(after['relocation']['wrapper_path'],before['path'])
                    original_bytes = (folder/after['relocation']['path']).read_bytes()
                    self.assertEqual(hashlib.sha256(original_bytes).hexdigest(),before['sha256'])
                    self.assertEqual(len(original_bytes),before['bytes'])
                else:
                    self.assertNotIn('relocation',after)
        self.assertEqual(relocated_markdown,4)
        r11_root = 'docs/evidence/item_art_01/source-bindings/pre-spend-proof-r12/'
        r11_path = r11_root+'style-continuity-20261028-v16-item-authoring.json'
        r11_raw = (ROOT/r11_path).read_bytes()
        self.assertEqual(hashlib.sha256(r11_raw).hexdigest(),'9dcfa6c4aa17c84f7d54492df8aefa78718adf17c2346c91823d14bea4b25e42')
        r11 = json.loads(r11_raw)
        self.assertEqual(r11['version'],'16')
        self.assertEqual(len(r11['runtime_reference']['references']),68)
        for before,after in zip(r11['runtime_reference']['references'],pre_audio_refs):
            if before['path']=='scripts/items/v5/item_defense_effects.gd':
                self.assertEqual({k:v for k,v in before.items() if k!='sha256'},{k:v for k,v in after.items() if k!='sha256'})
                self.assertNotEqual(before['sha256'],after['sha256'])
                old_leaf = (ROOT/(r11_root+'item_defense_effects.gd.txt')).read_bytes()
                self.assertEqual(before['sha256'],hashlib.sha256(old_leaf).hexdigest())
            else:
                self.assertEqual(before,after)
        stale_r11 = copy.deepcopy(self.ref)
        stale_r11['supplemental_authority_path'] = r11_path
        stale_r11['supplemental_authority_sha256'] = hashlib.sha256(r11_raw).hexdigest()
        with self.assertRaisesRegex(ValueError,'binding changed'):
            creative.validate_bible_binding(stale_r11,root=self.root)
        r10_root = 'docs/evidence/item_art_01/source-bindings/pre-legacy-cues-r11/'
        r10_path = r10_root+'style-continuity-20261028-v16-item-authoring.json'
        r10_raw = (ROOT/r10_path).read_bytes()
        self.assertEqual(hashlib.sha256(r10_raw).hexdigest(),'aa06d0dc339247cbc5ba1068887c19d39b2b8cbfccc94c8647c6e99ae1fe0867')
        r10 = json.loads(r10_raw)
        self.assertEqual(r10['version'],'16')
        self.assertEqual(len(r10['runtime_reference']['references']),68)
        changed_r11 = {'scripts/items/v5/item_effect_view.gd',
                       'scripts/items/v5/item_defense_effects.gd'}
        # R11's two-leaf correction stays an exact frozen-stage proof, while
        # the final dedicated-spend fix above changes only Defense once more.
        for before,after in zip(r10['runtime_reference']['references'],r11['runtime_reference']['references']):
            if before['path'] in changed_r11:
                self.assertEqual({k:v for k,v in before.items() if k!='sha256'},{k:v for k,v in after.items() if k!='sha256'})
                self.assertNotEqual(before['sha256'],after['sha256'])
                original_leaf = (ROOT/(r10_root+Path(before['path']).name+'.txt')).read_bytes()
                self.assertEqual(before['sha256'],hashlib.sha256(original_leaf).hexdigest())
            else:
                self.assertEqual(before,after)
        stale_r10 = copy.deepcopy(self.ref)
        stale_r10['supplemental_authority_path'] = r10_path
        stale_r10['supplemental_authority_sha256'] = hashlib.sha256(r10_raw).hexdigest()
        with self.assertRaisesRegex(ValueError,'binding changed'):
            creative.validate_bible_binding(stale_r10,root=self.root)
        r09_path = 'docs/evidence/item_art_01/source-bindings/pre-envelope-r10/style-continuity-20261028-v16-item-authoring.json'
        r09_raw = (ROOT/r09_path).read_bytes()
        self.assertEqual(hashlib.sha256(r09_raw).hexdigest(),'bc3c97d31789281fdfa0679cb821243d5f4a1c796398530e0f83a9a59fdfd96a')
        r09 = json.loads(r09_raw)
        self.assertEqual(r09['version'],'16')
        self.assertEqual(len(r09['runtime_reference']['references']),68)
        # Preserve R10's one-config-change proof against its exact frozen source.
        for before,after in zip(r09['runtime_reference']['references'],r10['runtime_reference']['references']):
            if before['path']=='config/item_v5_art.json':
                self.assertEqual({k:v for k,v in before.items() if k!='sha256'},{k:v for k,v in after.items() if k!='sha256'})
                self.assertNotEqual(before['sha256'],after['sha256'])
                historical = subprocess.check_output(['git','show','f9fefe6e14e9a3bf7858d4f57f5fc5ea2293d5cb:'+before['path']],cwd=ROOT)
                self.assertEqual(before['sha256'],hashlib.sha256(historical).hexdigest())
            else:
                self.assertEqual(before,after)
        old_art_raw = (ROOT/'docs/evidence/item_art_01/source-bindings/pre-envelope-r10/item_v5_art.json').read_bytes()
        self.assertEqual(hashlib.sha256(old_art_raw).hexdigest(),'3d54e59b0e176eefb623a57347265c80215c6b2368ba92d7c44fa69343e4b96a')
        old_art = json.loads(old_art_raw)
        current_art = json.loads((ROOT/'config/item_v5_art.json').read_bytes())
        self.assertEqual({k:v for k,v in old_art.items() if k!='clips'},
                         {k:v for k,v in current_art.items() if k!='clips'})
        self.assertEqual(set(old_art['clips']),set(current_art['clips']))
        refined = {'g05.large_guard','p25.needle_trap','p20.crystal'}
        self.assertEqual({key for key in old_art['clips'] if old_art['clips'][key]!=current_art['clips'][key]},refined)
        for key in refined:
            self.assertEqual({k:v for k,v in old_art['clips'][key].items() if k not in {'regions','world_size','pivot'}},
                             {k:v for k,v in current_art['clips'][key].items() if k not in {'regions','world_size','pivot'}})
        stale_r09 = copy.deepcopy(self.ref)
        stale_r09['supplemental_authority_path'] = r09_path
        stale_r09['supplemental_authority_sha256'] = hashlib.sha256(r09_raw).hexdigest()
        with self.assertRaisesRegex(ValueError,'binding changed'):
            creative.validate_bible_binding(stale_r09,root=self.root)
        changed_golden = {'scripts/ui/item_presentation.gd',
                          'scripts/items/v5/item_effect_view.gd',
                          'scripts/items/v5/item_v5_entity.gd'}
        changed_current54 = changed_golden | {'scripts/items/v5/item_defense_effects.gd'}
        r08_path = 'docs/evidence/item_art_01/source-bindings/pre-expansion-r09/docs/creative_direction/bibles/style-continuity-20261028-v16-item-authoring.json'
        r08_raw = (ROOT/r08_path).read_bytes()
        self.assertEqual(hashlib.sha256(r08_raw).hexdigest(),'473a8efc6ccba6a98696a0a29dfbf980f30c65b217685fc7b885f3a319e20149')
        r08 = json.loads(r08_raw)
        self.assertEqual(r08['version'],'16')
        self.assertEqual(len(r08['runtime_reference']['references']),61)
        changed_r09 = {'scripts/items/v5/item_effect_view.gd',
                       'scripts/items/v5/item_v5_entity.gd',
                       'scripts/items/v5/item_defense_effects.gd',
                       'scripts/items/v5/item_art_library.gd',
                       'config/item_v5_art.json','config/item_v5_authoring.json'}
        for before,after in zip(r08['runtime_reference']['references'],pre_audio_refs[:61]):
            self.assertEqual({k:v for k,v in before.items() if k!='sha256'},{k:v for k,v in after.items() if k!='sha256'})
            if before['path'] in changed_r09:
                self.assertNotEqual(before['sha256'],after['sha256'])
                historical = subprocess.check_output(['git','show','cd163e2ddbb9e1041067279eb2f554d09af0582a:'+before['path']],cwd=ROOT)
                self.assertEqual(before['sha256'],hashlib.sha256(historical).hexdigest())
            else:
                self.assertEqual(before,after)
        stale_r08 = copy.deepcopy(self.ref)
        stale_r08['supplemental_authority_path'] = r08_path
        stale_r08['supplemental_authority_sha256'] = hashlib.sha256(r08_raw).hexdigest()
        with self.assertRaisesRegex(ValueError,'binding changed'):
            creative.validate_bible_binding(stale_r08,root=self.root)
        pre_art_path = 'docs/evidence/item_art_01/source-bindings/pre-golden-r08/style-continuity-20261028-v16-item-authoring.json'
        pre_art_raw = (ROOT/pre_art_path).read_bytes()
        self.assertEqual(hashlib.sha256(pre_art_raw).hexdigest(),'fe89f171ad210b0ddc16c355c94c48b34d1a66891fd6ca25c0810c6f32aa336f')
        pre_art = json.loads(pre_art_raw)
        self.assertEqual(pre_art['version'],'16')
        self.assertEqual(len(pre_art['runtime_reference']['references']),54)
        for before,after in zip(pre_art['runtime_reference']['references'],pre_audio_refs[:54]):
            self.assertEqual({k:v for k,v in before.items() if k!='sha256'},{k:v for k,v in after.items() if k!='sha256'})
            if before['path'] in changed_current54:
                self.assertNotEqual(before['sha256'],after['sha256'])
                historical = subprocess.check_output(['git','show','df5b075799e36624597b780a17d88850f0b4ff21:'+before['path']],cwd=ROOT)
                self.assertEqual(before['sha256'],hashlib.sha256(historical).hexdigest())
            else:
                self.assertEqual(before,after)
        stale_pre_art = copy.deepcopy(self.ref)
        stale_pre_art['supplemental_authority_path'] = pre_art_path
        stale_pre_art['supplemental_authority_sha256'] = hashlib.sha256(pre_art_raw).hexdigest()
        with self.assertRaisesRegex(ValueError,'binding changed'):
            creative.validate_bible_binding(stale_pre_art,root=self.root)
        # Keep the original R08 exact three-leaf guard as a frozen-history check.
        for before,after in zip(pre_art['runtime_reference']['references'],r08['runtime_reference']['references'][:54]):
            self.assertEqual({k:v for k,v in before.items() if k!='sha256'},{k:v for k,v in after.items() if k!='sha256'})
            if before['path'] in changed_golden:
                self.assertNotEqual(before['sha256'],after['sha256'])
            else:
                self.assertEqual(before,after)
        old_v15_path = 'docs/creative_direction/bibles/style-continuity-20261027-v15-item-v5.json'
        old_v15_raw = (ROOT/old_v15_path).read_bytes()
        self.assertEqual(hashlib.sha256(old_v15_raw).hexdigest(), '6d0303e867592d72723973f29060902226b1f25e31aff24fcd065fff427cbfd0')
        old_v15 = json.loads(old_v15_raw)
        self.assertEqual(old_v15['version'],'15')
        self.assertEqual(len(old_v15['runtime_reference']['references']),54)
        self.assertEqual(published_style['supersedes']['path'],old_v15_path)
        self.assertEqual(published_style['supersedes']['sha256'],hashlib.sha256(old_v15_raw).hexdigest())
        for key in old_v15.keys()-{'version','runtime_reference','supersedes','revision_impact'}:
            self.assertEqual(published_style[key],old_v15[key])
        for before,after in zip(old_v15['runtime_reference']['references'],pre_audio_refs):
            if before['path'] in changed_current54:
                self.assertEqual({k:v for k,v in before.items() if k!='sha256'},{k:v for k,v in after.items() if k!='sha256'})
                self.assertNotEqual(before['sha256'],after['sha256'])
                historical = subprocess.check_output(['git','show','d9445c0e5d6516d4eb93ebbfbc5639efddf7fc04:'+before['path']],cwd=ROOT)
                self.assertEqual(before['sha256'],hashlib.sha256(historical).hexdigest())
                self.assertEqual(after['sha256'],hashlib.sha256(historical_source(after['path'])).hexdigest())
            else:
                self.assertEqual(before,after)
        old_v14_path = 'docs/creative_direction/bibles/style-continuity-20261026-v14-run-gear.json'
        old_v14_raw = (ROOT/old_v14_path).read_bytes()
        self.assertEqual(hashlib.sha256(old_v14_raw).hexdigest(), 'a9fba5dd2cadbc1d36abda4928f4d473bd8849d882346abd70870a68900dc366')
        old_v14 = json.loads(old_v14_raw)
        self.assertEqual(len(old_v14['runtime_reference']['references']),36)
        self.assertEqual(old_v15['supersedes']['path'],old_v14_path)
        self.assertEqual(old_v15['supersedes']['sha256'],hashlib.sha256(old_v14_raw).hexdigest())
        for key in old_v14.keys()-{'version','runtime_reference','supersedes','revision_impact'}:
            self.assertEqual(published_style[key],old_v14[key])
        for before,after in zip(old_v14['runtime_reference']['references'],current_refs[:36]):
            if before['path']=='scripts/demo/demo_app.gd':
                self.assertEqual({k:v for k,v in before.items() if k!='sha256'},{k:v for k,v in after.items() if k!='sha256'})
                self.assertNotEqual(before['sha256'],after['sha256'])
                historical = subprocess.check_output(['git','show','879b39eaa869be70cb799dedd1bb6ffc35e0b92f:'+before['path']],cwd=ROOT)
                self.assertEqual(before['sha256'],hashlib.sha256(historical).hexdigest())
                self.assertEqual(after['sha256'],hashlib.sha256(historical_source(after['path'])).hexdigest())
            else:
                self.assertEqual(before,after)
        # Preserve the pre-art author's exact one-leaf change against V15 too.
        for before,after in zip(old_v15['runtime_reference']['references'],pre_art['runtime_reference']['references']):
            if before['path']=='scripts/ui/item_presentation.gd':
                self.assertEqual({k:v for k,v in before.items() if k!='sha256'},{k:v for k,v in after.items() if k!='sha256'})
                self.assertNotEqual(before['sha256'],after['sha256'])
            else:
                self.assertEqual(before,after)
        self.assertEqual([(row['role'],row['path']) for row in current_refs[36:54]],ITEM_V5_STYLE_REFERENCES)
        self.assertEqual([(row['role'],row['path']) for row in current_refs[54:61]],ITEM_ART_GOLDEN_REFERENCES)
        self.assertEqual([(row['role'],row['path']) for row in current_refs[61:]],ITEM_ART_EXPANSION_REFERENCES)
        for row in current_refs[36:]:
            self.assertEqual(row['sha256'],hashlib.sha256(merge_parent_source('program',row['path'])).hexdigest())
        old_v12 = json.loads((ROOT/'docs/creative_direction/bibles/style-continuity-20261024-v12-fixed-status.json').read_bytes())
        for key in old_v12.keys()-{'version','runtime_reference','supersedes','revision_impact'}:
            self.assertEqual(published_style[key], old_v12[key])
        for before, after in zip(old_v12['runtime_reference']['references'], current_refs):
            if before['path']=='scripts/demo/demo_app.gd':
                self.assertEqual({k:v for k,v in before.items() if k!='sha256'}, {k:v for k,v in after.items() if k!='sha256'})
                self.assertNotEqual(before['sha256'], after['sha256'])
                actual = subprocess.check_output(['git','show','4fc1e7a55c191dbe56cd7bc385539fc42b8f7898:'+before['path']], cwd=ROOT)
                self.assertEqual(before['sha256'], hashlib.sha256(actual).hexdigest())
                self.assertEqual(after['sha256'], hashlib.sha256(historical_source(after['path'])).hexdigest())
            else:
                self.assertEqual(before, after)
        old_v11 = json.loads((ROOT/'docs/creative_direction/bibles/style-continuity-20261024-v11-playtest-feedback.json').read_bytes())
        for key in old_v11.keys()-{'version','runtime_reference','supersedes','revision_impact'}:
            self.assertEqual(published_style[key], old_v11[key])
        for before, after in zip(old_v11['runtime_reference']['references'], current_refs):
            if before['path']=='scripts/demo/demo_app.gd':
                self.assertEqual({k:v for k,v in before.items() if k!='sha256'}, {k:v for k,v in after.items() if k!='sha256'})
                self.assertNotEqual(before['sha256'], after['sha256'])
                self.assertEqual(after['sha256'], hashlib.sha256(historical_source(after['path'])).hexdigest())
            else:
                self.assertEqual(before, after)
        old_v10 = json.loads((ROOT/'docs/creative_direction/bibles/style-continuity-20261023-v10-foreground-cpu.json').read_bytes())
        for key in old_v10.keys()-{'version','runtime_reference','supersedes','revision_impact'}:
            self.assertEqual(old_v11[key], old_v10[key])
        for before, after in zip(old_v10['runtime_reference']['references'], old_v11['runtime_reference']['references']):
            if before['path'] in ('scripts/demo/demo_app.gd','scripts/demo/home_scene.gd'):
                self.assertEqual({k:v for k,v in before.items() if k!='sha256'}, {k:v for k,v in after.items() if k!='sha256'})
                self.assertNotEqual(before['sha256'], after['sha256'])
                actual = subprocess.check_output(['git','show','e5254559b38f9593f03fa2fd7847b107d5d04402:'+after['path']], cwd=ROOT)
                self.assertEqual(after['sha256'], hashlib.sha256(actual).hexdigest())
            else:
                self.assertEqual(before, after)
        old_v9 = json.loads((ROOT/'docs/creative_direction/bibles/style-continuity-20261023-v9-hud-layout.json').read_bytes())
        for before, after in zip(old_v9['runtime_reference']['references'], old_v10['runtime_reference']['references']):
            if before['path']=='scripts/underworld_plains/underworld_presentation.gd':
                self.assertEqual({k:v for k,v in before.items() if k!='sha256'}, {k:v for k,v in after.items() if k!='sha256'})
                self.assertNotEqual(before['sha256'], after['sha256'])
                self.assertEqual(after['sha256'], hashlib.sha256(historical_source(after['path'])).hexdigest())
            else:
                self.assertEqual(before, after)
        for key in old_v9.keys()-{'version','runtime_reference','supersedes','revision_impact'}:
            self.assertEqual(old_v10[key], old_v9[key])
        self.assertEqual({k:v for k,v in published_style['runtime_reference'].items() if k!='references'}, {k:v for k,v in old_v9['runtime_reference'].items() if k!='references'})
        refs = old_v9['runtime_reference']['references']
        old_v7 = json.loads((ROOT/'docs/creative_direction/bibles/style-continuity-20261023-v7.json').read_bytes())
        old_refs = old_v7['runtime_reference']['references']
        self.assertEqual(len(old_refs),36)
        for before, after in zip(old_refs,refs):
            if before['path']=='scripts/demo/demo_app.gd':
                self.assertEqual({k:v for k,v in before.items() if k!='sha256'}, {k:v for k,v in after.items() if k!='sha256'})
                self.assertNotEqual(before['sha256'],after['sha256'])
                # The v9 source is frozen in the actual pre-feedback main,
                # while the active DemoApp is independently verified above.
                actual = subprocess.check_output(['git','show','cd4989a68613e0b457cdfd5e252634dd57008505:'+after['path']], cwd=ROOT)
                self.assertEqual(after['sha256'],hashlib.sha256(actual).hexdigest())
            else:
                self.assertEqual(before,after)
        for key in old_v7.keys()-{'version','runtime_reference','supersedes','revision_impact'}:
            self.assertEqual(old_v9[key],old_v7[key])
        self.assertEqual({k:v for k,v in published_style['runtime_reference'].items() if k!='references'}, {k:v for k,v in old_v7['runtime_reference'].items() if k!='references'})
        # The selected fine style superseded V4; V7 adds the real default body.
        # All20 V6 references remain exact, and old bindings remain refused.
        previous_path = 'docs/creative_direction/bibles/style-continuity-20261021-v2.json'
        previous_bytes = (ROOT/previous_path).read_bytes()
        previous = json.loads((ROOT/'docs/creative_direction/bibles/style-continuity-20261023-v6.json').read_bytes())
        for row in previous['runtime_reference']['references']:
            self.assertIn(row, refs)
        superseded = copy.deepcopy(self.ref)
        superseded['supplemental_authority_path'] = previous_path
        superseded['supplemental_authority_sha256'] = hashlib.sha256(previous_bytes).hexdigest()
        with self.assertRaisesRegex(ValueError,'binding changed'):
            creative.validate_bible_binding(superseded,root=self.root)
        v3_path = 'docs/creative_direction/bibles/style-continuity-20261021-v3.json'
        stale_v3 = copy.deepcopy(self.ref)
        stale_v3['supplemental_authority_path'] = v3_path
        stale_v3['supplemental_authority_sha256'] = hashlib.sha256((ROOT/v3_path).read_bytes()).hexdigest()
        with self.assertRaisesRegex(ValueError, 'binding changed'):
            creative.validate_bible_binding(stale_v3,root=self.root)
        for old_style in ['style-continuity-20261022-v4.json','style-continuity-20261022-v5.json','style-continuity-20261023-v6.json','style-continuity-20261023-v7.json','style-continuity-20261023-v9-hud-layout.json','style-continuity-20261023-v10-foreground-cpu.json','style-continuity-20261024-v11-playtest-feedback.json','style-continuity-20261024-v12-fixed-status.json','style-continuity-20261024-v13-responsive-navigation.json','style-continuity-20261026-v14-run-gear.json','style-continuity-20261027-v15-item-v5.json','style-continuity-20261028-v16-item-authoring.json','style-continuity-20261028-v17-home-codex.json']:
            old_path = 'docs/creative_direction/bibles/'+old_style
            stale = copy.deepcopy(self.ref)
            stale['supplemental_authority_path'] = old_path
            stale['supplemental_authority_sha256'] = hashlib.sha256((ROOT/old_path).read_bytes()).hexdigest()
            with self.subTest(superseded=old_style),self.assertRaisesRegex(ValueError, 'binding changed'):
                creative.validate_bible_binding(stale,root=self.root)
        refs = actual_refs
        for role,path in creative.PLAYER_STYLE_DEPENDENCIES.items():
            self.assertIn({'role':role,'path':path,'sha256':hashlib.sha256((self.root/path).read_bytes()).hexdigest()},refs)
        old = json.loads((ROOT/'docs/creative_direction/archive/creative-v5/thorn_forest.json').read_bytes())['region_bible']
        with self.assertRaisesRegex(ValueError,'binding changed'):
            creative.validate_bible_binding(old,root=self.root)
        supplement_path = self.root/style['path']
        original = supplement_path.read_bytes()
        registry_path = self.root/creative.BIBLE_REGISTRY
        registry_raw = registry_path.read_bytes()
        for role in creative.PLAYER_STYLE_DEPENDENCIES:
            data = json.loads(original)
            data['runtime_reference']['references'] = [row for row in refs if row['role'] != role]
            supplement_path.write_text(json.dumps(data))
            registry = json.loads(registry_raw)
            registry['shared_style_authority']['sha256'] = hashlib.sha256(supplement_path.read_bytes()).hexdigest()
            registry_path.write_text(json.dumps(registry))
            with self.subTest(missing_role=role),self.assertRaisesRegex(ValueError,'Complete actual formal'):
                creative.bind_region_bible('thorn_forest',self.root)
        supplement_path.write_bytes(original);registry_path.write_bytes(registry_raw)

    def test_body_payload_drift_blocks_production_and_proposed_before_after_and_resume(self):
        # Regresses style-body-closure-probe/report-first: changing real body
        # payloads alone leaves the UnderworldPlayer script byte-identical.
        script = self.root/'scripts/underworld_plains/underworld_player.gd'
        script_raw = script.read_bytes()
        for skill_name in ('gameplay-reviewer','region-creative-director'):
            skill = self.root/('.agents/skills/'+skill_name+'/SKILL.md')
            skill.parent.mkdir(parents=True,exist_ok=True);skill.write_text('Synthetic isolated fixture')
        proposed = level_design.route_request('create firefly_marsh')['tasks'][0]

        def mutation(path):
            raw = path.read_bytes()
            if path.suffix == '.json':
                data = json.loads(raw);data['anchor'][0] += 1
                return json.dumps(data).encode()
            # The actual atlas is non-interlaced RGBA and starts with a zero
            # filter row. Change its first visible RGBA pixel data, recompress
            # IDAT and repair CRCs: a valid changed PNG, not trailing garbage.
            self.assertEqual(raw[:8],b'\x89PNG\r\n\x1a\n')
            chunks=[];offset=8
            while offset < len(raw):
                size=struct.unpack('>I',raw[offset:offset+4])[0]
                chunks.append((raw[offset+4:offset+8],raw[offset+8:offset+8+size]))
                offset += size+12
            pixels=bytearray(zlib.decompress(b''.join(body for kind,body in chunks if kind==b'IDAT')))
            self.assertEqual(pixels[0],0)
            pixels[1:5]=bytes([255,0,255,255])
            result=bytearray(raw[:8]);written=False
            for kind,body in chunks:
                if kind==b'IDAT':
                    if written: continue
                    body=zlib.compress(pixels);written=True
                result.extend(struct.pack('>I',len(body))+kind+body+struct.pack('>I',zlib.crc32(kind+body)))
            return bytes(result)

        for path_name in creative.PLAYER_STYLE_DEPENDENCIES.values():
            path=self.root/path_name;original=path.read_bytes();changed=mutation(path)
            self.assertNotEqual(changed,original)
            for kind,task in [('production',self.task()),('proposed',proposed)]:
                mission={'schema_version':1,'objective':'Inspect regional shared style','tasks':[copy.deepcopy(task)],
                         'max_calls':4,'max_rounds':1,'call_timeout_seconds':10}
                task=mission['tasks'][0]
                name=kind+'-'+path.stem
                with self.subTest(path=path_name,kind=kind),patch.object(loop,'ROOT',self.root):
                    expected={'path':path_name,'sha256':hashlib.sha256(original).hexdigest()}
                    self.assertIn(expected,loop.bound_source_inputs(task))
                    folder=self.root/(name+'-prompt');folder.mkdir()
                    prompt,*_=loop.prepare_call(task,mission,'implement',folder,'{}',check_contracts={'checks':[]})
                    self.assertIn(path_name,prompt)
                    self.assertIn(expected['sha256'],prompt)
                    path.write_bytes(changed)
                    with patch.object(loop,'snapshot',side_effect=AssertionError('must reject before snapshot')),patch.object(loop,'native_import_preflight',side_effect=AssertionError('must not import')):
                        blocked=loop.run({**mission,'native_import_preflight':True},self.root/(name+'-before'),lambda *a:self.fail('must not invoke'))
                    self.assertEqual(blocked['calls'],0);self.assertEqual(blocked['status'],'blocked')
                    path.write_bytes(original)

                    def drifting_worker(*args):
                        path.write_bytes(changed)
                        return {'status':'ready_for_review','summary':'SIMULATED body-only mutation','findings':[]}
                    with patch.object(loop,'snapshot',return_value={}),patch.object(loop,'required_input_preflight',return_value={'status':'passed'}):
                        after_dir=self.root/(name+'-after')
                        with self.assertRaisesRegex(ValueError,'SHA changed'):
                            loop.run(mission,after_dir,drifting_worker)
                    after=json.loads((after_dir/'state.json').read_bytes())
                    self.assertEqual(after['calls'],1);self.assertEqual(after['status'],'blocked')
                    self.assertFalse(after['content_complete'])
                    path.write_bytes(original)

                    calls=[]
                    def worker(*args):
                        calls.append('implement')
                        return {'status':'ready_for_review','summary':'SIMULATED saved phase','findings':[]}
                    resume_dir=self.root/(name+'-resume')
                    with patch.object(loop,'snapshot',return_value={}),patch.object(loop,'required_input_preflight',return_value={'status':'passed'}):
                        paused=loop.run(mission,resume_dir,worker,stop_after_phase='implement')
                    self.assertEqual(paused['status'],'paused');self.assertEqual(paused['calls'],1)
                    checkpoint=(resume_dir/'state.json').read_bytes()
                    path.write_bytes(changed)
                    with patch.object(loop,'snapshot',side_effect=AssertionError('must reject resume before snapshot')),self.assertRaisesRegex(ValueError,'Restored Bible source/binding changed'):
                        loop.run(mission,resume_dir,worker)
                    self.assertEqual((resume_dir/'state.json').read_bytes(),checkpoint)
                    self.assertEqual(calls,['implement'])
                    path.write_bytes(original)
                    self.assertEqual(script.read_bytes(),script_raw)

    def test_new_actual_consumer_cache_inputs_include_body_and_inventory_changes(self):
        # Exercise the real cache selector on synthetic hashes, without asking
        # either inventory or the full production snapshot to scan the tree.
        import harness
        checks=harness.load_manifest()['checks']
        body='assets/underworld_plains/player_animation/run_sheet.png'
        helper='tools/forest_bible_world_sources.py'
        added='assets/forest_bible_v2/new-runtime-body.png'
        original={body:'body-v1',helper:'inventory-v1'}
        for check_id in ('forest-bible-app-discoveries','forest-bible-integration-tests',
                         'forest-bible-world-contract','forest-bible-world-connection',
                         'forest-bible-world-backbranch','forest-practice-bell-restore'):
            check=checks[check_id]
            baseline=harness.input_digest(check,list(original),{},snapshot=original)
            variants=[{**original,body:'body-v2'}, {**original,helper:'inventory-v2'},
                      {**original,added:'added-asset'}, {helper:original[helper]}]
            for changed in variants:
                with self.subTest(check=check_id,changed=changed):
                    self.assertNotEqual(baseline,harness.input_digest(check,list(changed),{},snapshot=changed))

    def test_default_current_bibles_skip_election(self):
        for request, region in [('制作荆棘森林','thorn_forest'), ('优化风铃平原美术','windchime_plains')]:
            mission = level_design.route_request(request)
            self.assertEqual(mission['phase'], 'production')
            self.assertNotIn('visual_recipe', mission['preparation'])
            self.assertNotIn('continuation', mission)
            for task in mission['tasks']:
                self.assertEqual(task['region_bible'], mission['region_bible'])
                self.assertEqual(task['region_id'], region)
            data, _ = creative.load_direction('docs/creative_direction/'+region+'.json', region)
            self.assertEqual(data['selection_basis'], 'user_supplied_bible')
            self.assertEqual(data['candidates'], [])
            self.assertEqual(data['user_acceptance'], 'direction_only_not_art_gameplay_or_device')

    def test_no_bible_proposal_only_and_explicit_production_rejected(self):
        mission = level_design.route_request('制作萤雾沼泽')
        task = mission['tasks'][0]
        self.assertEqual(mission['creative_phase'], 'proposed_bible_only')
        self.assertEqual(task['required_gates'], ['G0'])
        self.assertTrue(all(name.startswith('docs/') for name in task['allowed_paths']))
        self.assertIsNone(loop.region_bible_input(task))
        task['allowed_paths'].append('scripts/generation/')
        with self.assertRaisesRegex(ValueError, 'document-only'):
            loop.region_bible_input(task)
        for phase in ('production','prototype'):
            with self.assertRaisesRegex(ValueError, 'requires a registered current Bible'):
                level_design.route_request('制作萤雾沼泽', phase=phase)

    def test_handwritten_mission_omitting_task_region_blocks_before_import_and_calls(self):
        m = {'schema_version':1,'objective':'制作荆棘森林','max_calls':2,'max_rounds':1,'call_timeout_seconds':10,
             'native_import_preflight':True,'tasks':[{'id':'READ','goal':'inspect','skills':['gameplay-reviewer'],
                 'checks':['docs'],'read_only':True}]}
        with (patch.object(loop,'snapshot', side_effect=AssertionError('must not snapshot')),
              patch.object(loop,'native_import_preflight', side_effect=AssertionError('must not import'))):
            state = loop.run(m, self.root/'run', lambda *args: self.fail('must not invoke'))
        self.assertEqual(state['calls'],0)
        self.assertEqual(state['status'],'blocked')
        self.assertEqual(state['tasks']['READ']['input_preflight']['uncertain_inputs'][0]['reason'],'region_bible_invalid')

    def test_anonymous_production_write_paths_block_all_original_adversarial_probes(self):
        for path in ('scripts/generation/thorn_forest_region_v2_v15.gd',
                     'scripts/generation/plains_region_generator.gd',
                     'scripts/generation/nonexistent_future_region.gd',
                     'scripts/generation/', 'scripts/', 'assets/',
                     'scripts/underworld_plains/underworld_terrain.gd',
                     'scripts/presentation/forest_bible_presentation.gd',
                     'resources/items/forest_old_badge.tres'):
            task = {'id':'ANONYMOUS','goal':'Implement the updated regional layout',
                    'skills':['region-generator'],'checks':['docs'],'read_only':False,
                    'allowed_paths':[path],'quality_record':'docs/quality/records/ANONYMOUS.json'}
            mission = {'schema_version':1,'objective':'Update the regional generator','max_calls':2,
                       'max_rounds':1,'call_timeout_seconds':10,'native_import_preflight':True,'tasks':[task]}
            with self.subTest(path=path), patch.object(loop,'snapshot',side_effect=AssertionError('must not snapshot')), patch.object(loop,'native_import_preflight',side_effect=AssertionError('must not import')):
                with self.assertRaises(ValueError): loop.region_bible_input(task)
                self.assertIn('ANONYMOUS',loop.mission_bible_preflight(mission))
                state = loop.run(mission,self.root/('anonymous-'+hashlib.sha256(path.encode()).hexdigest()[:12]),lambda *args:self.fail('must not invoke'))
                self.assertEqual(state['calls'],0)
                self.assertEqual(state['status'],'blocked')

    def test_exact_known_catalog_paths_require_matching_single_region_binding(self):
        task = {**self.task(), 'goal':'Implement the updated regional layout',
                'allowed_paths':['scripts/generation/thorn_forest_region_v2_v15.gd']}
        self.assertEqual(loop.region_bible_input(task)['binding']['region_id'],'thorn_forest')
        for paths in (['scripts/generation/plains_region_generator.gd'],
                      ['scripts/generation/thorn_forest_region_v2_v15.gd','scripts/generation/plains_region_generator.gd'],
                      ['scripts/generation/firefly_marsh_generator.gd']):
            with self.subTest(paths=paths), self.assertRaisesRegex(ValueError,'cross-region'):
                loop.region_bible_input({**task,'allowed_paths':paths})
        for key in ('creative_direction','region_proof'):
            with self.subTest(key=key), self.assertRaisesRegex(ValueError,'cross-region'):
                loop.region_bible_input({**task,key:{'region_id':'windchime_plains'}})

    def test_all_runtime_domains_detect_registered_region_families_before_prefix_filter(self):
        domains = ('scripts/unregistered_consumer_family', 'resources/items', 'scenes/new_family',
                   'assets/new_family', 'shaders/new_family', 'config/new_family')
        for domain in domains:
            path = domain + '/forest_new_consumer.gd'
            with self.subTest(path=path), self.assertRaises(ValueError):
                loop.region_bible_input({'goal':'Update consumer','allowed_paths':[path]})
            with self.subTest(cross_region=path), self.assertRaisesRegex(ValueError,'cross-region'):
                loop.region_bible_input({**self.task(),'allowed_paths':[path,'scripts/underworld_plains/']})
        # Neither shared physical code nor process-only regional test/docs names
        # become creative-region work just because their path contains a word.
        for path in ('scripts/player/player_motor.gd','scripts/run/demo_lifetime.gd',
                     'config/player_tuning.json','tools/run_forest_bible_weaver.py',
                     'tests/forest_bible_weaver_runner.gd','docs/design/forest_notes.md'):
            with self.subTest(shared=path):
                self.assertIsNone(loop.region_bible_input({'goal':'Fix global physics or process validation','allowed_paths':[path]}))

    def test_anonymous_multi_region_task_and_ambiguous_mission_return_blocked(self):
        task = {'id':'MIXED','goal':'Update the consumer','allowed_paths':[
            'scripts/generation/thorn_forest_region_v2_v15.gd','scripts/generation/plains_region_generator.gd']}
        mission = {'objective':'Update the generator','tasks':[task]}
        self.assertIn('MIXED',loop.mission_bible_preflight(mission))
        mission['objective'] = 'Update thorn_forest and windchime_plains'
        self.assertIn('MIXED',loop.mission_bible_preflight(mission))

    def test_broad_bound_scope_cannot_write_another_actual_region_consumer(self):
        task = {**self.task(), 'goal':'Implement the updated regional layout','read_only':False,
                'allowed_paths':['scripts/generation/'],'quality_record':'docs/quality/records/BIBLE.json'}
        # Simulate source snapshots of one real temporary file only; this never
        # calls the full repository snapshot or any engine/worker process.
        target = self.root/'scripts/generation/plains_region_generator.gd'
        skill = self.root/'.agents/skills/gameplay-reviewer/SKILL.md'
        skill.parent.mkdir(parents=True); skill.write_text('Synthetic read-only reviewer')
        def snapshot():
            return {target.relative_to(self.root).as_posix():hashlib.sha256(target.read_bytes()).hexdigest()} if target.exists() else {}
        def worker(*args):
            target.parent.mkdir(parents=True,exist_ok=True); target.write_text('cross-region temporary probe')
            return {'status':'ready_for_review','summary':'synthetic','findings':[]}
        mission = {'schema_version':1,'objective':'Update the regional generator','max_calls':2,
                   'max_rounds':1,'call_timeout_seconds':10,'tasks':[task]}
        with patch.object(loop,'ROOT',self.root), patch.object(loop,'snapshot',side_effect=snapshot), patch.object(loop,'required_input_preflight',return_value={'status':'passed'}):
            self.assertEqual(loop.region_bible_input(task)['binding']['region_id'],'thorn_forest')
            with self.assertRaisesRegex(ValueError,'cross-region'):
                loop.run(mission,self.root/'cross-region-worker',worker)
        state = json.loads((self.root/'cross-region-worker/state.json').read_bytes())
        self.assertEqual(state['status'],'blocked')
        self.assertEqual(state['calls'],1)
        self.assertTrue(target.exists())  # Original failed edit is preserved.

    def test_handwritten_partial_binding_and_source_inputs(self):
        with patch.object(loop, 'ROOT', self.root):
            task = self.task()
            sources = loop.bound_source_inputs(task)
            self.assertEqual({r['path'] for r in sources},
                             {self.ref['registry_path'],self.ref['path'],self.ref['selection_evidence_path'],self.ref['supplemental_authority_path'], *[row['path'] for row in creative.supplemental_authority(self.bible,'thorn_forest',self.root)['content']['runtime_reference']['references']]})
            task['region_bible'] = {'path':self.ref['path']}
            with self.assertRaisesRegex(ValueError,'Complete region_bible'):
                loop.region_bible_input(task)

    def test_worker_prompt_contains_full_original_and_audio_scope(self):
        mission = level_design.route_request('制作荆棘森林')
        task = mission['tasks'][0]
        folder = self.root/'prompt'; folder.mkdir()
        prompt, *_ = loop.prepare_call(task, mission, 'implement', folder, '{}', check_contracts={'checks':[]})
        self.assertIn((ROOT/task['region_bible']['path']).read_text(), prompt)
        self.assertIn('BGM deferred_user_supplied', prompt)
        self.assertIn('actual consumer/source/version', prompt)

    def test_source_drift_during_worker_blocks_after_call(self):
        task = self.task()
        attempt = self.root/'run/BIBLE/1'; attempt.mkdir(parents=True)
        state = {'calls':0}
        mission = {'max_calls':2}
        path = self.root/self.ref['path']
        def worker(*args):
            path.write_bytes(path.read_bytes()+b'changed')
            return {'status':'ready_for_review','summary':'fixture','findings':[]}
        with patch.object(loop,'ROOT',self.root), patch.object(loop,'snapshot',return_value={}):
            with self.assertRaisesRegex(ValueError,'impact analysis'):
                loop._call_with_retries(task,mission,'implement',attempt,'{}',state,self.root/'run/state.json',worker)
        self.assertEqual(state['calls'],1)

    def test_source_drift_before_worker_and_restored_completion_block(self):
        task = self.task()
        path = self.root/self.ref['path']; path.write_bytes(path.read_bytes()+b'changed')
        attempt = self.root/'run/BIBLE/1'; attempt.mkdir(parents=True)
        state = {'calls':0}
        with patch.object(loop,'ROOT',self.root), patch.object(loop,'snapshot',side_effect=AssertionError('must not snapshot')):
            with self.assertRaisesRegex(ValueError,'impact analysis'):
                loop._call_with_retries(task,{'max_calls':2},'implement',attempt,'{}',state,self.root/'run/state.json',lambda *a:self.fail('must not invoke'))
            with self.assertRaisesRegex(ValueError,'impact analysis'):
                loop.validate_restored_completion({'tasks':[task]}, {'tasks':{'BIBLE':{'status':'complete'}}},self.root/'run')
        self.assertEqual(state['calls'],0)

    def test_visual_director_uses_current_bible_and_exact_caller_scope(self):
        m = visual_director.route('优化风铃平原美术','current-art','docs/quality/records/current-art.json',['scripts/art/'],phase='golden')
        self.assertNotIn('visual_recipe',m['preparation'])
        self.assertEqual(m['tasks'][0]['allowed_paths'],['scripts/art/'])
        self.assertEqual(m['tasks'][0]['required_gates'],['G0','G1','G2'])
        self.assertEqual(m['tasks'][0]['region_bible']['bible_id'],'windchime_plains_v2')



    def test_mobile_ui_v19_is_finite_preserves_originals_and_rejects_stale_v18(self):
        archive = 'docs/evidence/mobile_ui_clarity_01/source-bindings/before-style19/'
        manifest_raw = (ROOT/(archive+'manifest.json')).read_bytes()
        self.assertEqual(hashlib.sha256(manifest_raw).hexdigest(),'f440dee12a1bbcc1eb77ab897a079f52b8465ee00018068f0d4e1b73e8e8272a')
        for row in json.loads(manifest_raw)['files']:
            raw = (ROOT/row['path']).read_bytes()
            self.assertEqual(hashlib.sha256(raw).hexdigest(),row['sha256'])
            self.assertEqual(len(raw),row['bytes'])
        old_path = archive+'style-continuity-20261028-v18-chest-art.json'
        old_raw = (ROOT/old_path).read_bytes()
        old = json.loads(old_raw)
        current = json.loads((ROOT/(MERGE_PARENT_ARCHIVE+'mobile/style19.json')).read_bytes())
        self.assertEqual(current['version'],'19')
        self.assertEqual(len(current['runtime_reference']['references']),81)
        changed = {'default_player_5','item_pause_menu','item_reward_modal','home_codex_ui'}
        for before,after in zip(old['runtime_reference']['references'],current['runtime_reference']['references']):
            self.assertEqual({k:v for k,v in before.items() if k!='sha256'},
                             {k:v for k,v in after.items() if k!='sha256'})
            self.assertEqual(after['sha256'],hashlib.sha256(merge_parent_source('mobile',after['path'])).hexdigest())
            if after['role'] in changed:
                self.assertNotEqual(before['sha256'],after['sha256'])
                self.assertEqual(before['sha256'],hashlib.sha256((ROOT/(archive+Path(before['path']).name+'.txt')).read_bytes()).hexdigest())
            else:
                self.assertEqual(before,after)
        for key in old.keys()-{'version','runtime_reference','supersedes','revision_impact'}:
            self.assertEqual(current[key],old[key])
        self.assertEqual(current['supersedes'],{'path':'docs/creative_direction/bibles/style-continuity-20261028-v18-chest-art.json','sha256':hashlib.sha256(old_raw).hexdigest()})
        self.assertEqual(current['revision_impact']['task_id'],'MOBILE-UI-CLARITY-01')
        self.assertEqual(len(current['revision_impact']['changed_references']),4)
        self.assertEqual(current['revision_impact']['added_references'],[])
        stale = copy.deepcopy(self.ref)
        stale.update(supplemental_authority_path=old_path,supplemental_authority_sha256=hashlib.sha256(old_raw).hexdigest())
        with self.assertRaisesRegex(ValueError,'binding changed'):
            creative.validate_bible_binding(stale,root=self.root)


    def test_merged20_preserves_both_parent19_contracts_and_refuses_both_pointers(self):
        current = json.loads((ROOT/(MOTION_LOOT_ARCHIVE+'style20.json')).read_bytes())
        self.assertEqual(current['version'],'20')
        actual = current['runtime_reference']['references']
        self.assertEqual(len(actual),81)
        parents = {}
        for parent in ('program','mobile'):
            base = ROOT/(MERGE_PARENT_ARCHIVE+parent)
            manifest_raw = (base/'manifest.json').read_bytes()
            self.assertEqual(hashlib.sha256(manifest_raw).hexdigest(),PARENT_MANIFESTS[parent])
            for row in json.loads(manifest_raw)['files']:
                raw = (base/row['path']).read_bytes()
                self.assertEqual((len(raw),hashlib.sha256(raw).hexdigest()),(row['bytes'],row['sha256']))
            raw = (base/'style19.json').read_bytes()
            parents[parent] = json.loads(raw)['runtime_reference']['references']
            stale = copy.deepcopy(self.ref)
            stale.update(supplemental_authority_path=MERGE_PARENT_ARCHIVE+parent+'/style19.json',supplemental_authority_sha256=hashlib.sha256(raw).hexdigest())
            with self.assertRaisesRegex(ValueError,'binding changed'):
                creative.validate_bible_binding(stale,root=self.root)
        changed = set()
        preserved = 0
        for before,other,after in zip(parents['program'],parents['mobile'],actual):
            self.assertEqual({k:v for k,v in before.items() if k!='sha256'},{k:v for k,v in other.items() if k!='sha256'})
            self.assertEqual({k:v for k,v in before.items() if k!='sha256'},{k:v for k,v in after.items() if k!='sha256'})
            self.assertEqual(after['sha256'],hashlib.sha256(initial20_source(after['path'])).hexdigest())
            if before==other:
                self.assertEqual(after,before)
                preserved += 1
            else:
                changed.add(after['path'])
                self.assertIn(after['sha256'],(before['sha256'],other['sha256']))
        self.assertEqual(changed,MERGE_UI_LEAVES|{'scripts/demo/demo_app.gd','scripts/demo/plains_region_stage.gd','scripts/demo/thorn_forest_region_stage.gd'})
        self.assertEqual(preserved,74)
        self.assertEqual(current['shared_dimensions'],json.loads((ROOT/(MERGE_PARENT_ARCHIVE+'mobile/style19.json')).read_bytes())['shared_dimensions'])


    def test_plains_motion_loot21_keeps81_prefix_rebinds_three_and_adds_two_real_references(self):
        root = ROOT/MOTION_LOOT_ARCHIVE
        raw = (root/'manifest.json').read_bytes()
        self.assertEqual(hashlib.sha256(raw).hexdigest(),MOTION_LOOT_ARCHIVE_SHA)
        for row in json.loads(raw)['files']:
            content = (root/row['path']).read_bytes()
            self.assertEqual((len(content),hashlib.sha256(content).hexdigest()),(row['bytes'],row['sha256']))
        prior_raw = (root/'style20.json').read_bytes()
        prior = json.loads(prior_raw)
        self.assertEqual(prior['version'],'20')
        current = json.loads((ROOT/(MERGE21_ARCHIVE+'program/style21.json')).read_bytes())
        self.assertEqual(current['version'],'21')
        before = prior['runtime_reference']['references']
        actual = current['runtime_reference']['references']
        self.assertEqual((len(before),len(actual)),(81,83))
        changed = set()
        for old,new in zip(before,actual[:81]):
            self.assertEqual({k:v for k,v in old.items() if k!='sha256'},{k:v for k,v in new.items() if k!='sha256'})
            self.assertEqual(old['sha256'],hashlib.sha256(initial20_source(old['path'])).hexdigest())
            self.assertEqual(new['sha256'],hashlib.sha256(merge21_parent_source('program',new['path'])).hexdigest())
            if old!=new:changed.add(new['path'])
        self.assertEqual(changed,{'scripts/demo/demo_app.gd','scripts/demo/plains_region_stage.gd','scripts/demo/thorn_forest_region_stage.gd'})
        self.assertEqual(sum(a==b for a,b in zip(before,actual[:81])),78)
        self.assertEqual([(x['role'],x['path']) for x in actual[81:]],[('plains_loot_life_orb','assets/plains_loot_02/life_orb.png'),('plains_loot_world_sampler','shaders/plains_loot_02.gdshader')])
        consumer = (ROOT/'scripts/art/plains_stage_visual.gd').read_text()
        for row in actual[81:]:
            self.assertIn('res://'+row['path'],consumer)
            self.assertEqual(row['sha256'],hashlib.sha256((ROOT/row['path']).read_bytes()).hexdigest())
        self.assertEqual(current['shared_dimensions'],prior['shared_dimensions'])
        original_inputs = json.loads((root/'region-bible-inputs.json').read_bytes())
        self.assertEqual(len(original_inputs),368)
        live_inputs = json.loads((ROOT/'tools/harness/profiles.json').read_bytes())['checks']['region-bible-tests']['inputs']
        self.assertEqual(live_inputs[:368],original_inputs)
        stale = copy.deepcopy(self.ref)
        stale.update(supplemental_authority_path=MOTION_LOOT_ARCHIVE+'style20.json',supplemental_authority_sha256=hashlib.sha256(prior_raw).hexdigest())
        with self.assertRaisesRegex(ValueError,'binding changed'):
            creative.validate_bible_binding(stale,root=self.root)




    def test_actual_player_body_closure_is_required_and_superseded_binding_refused_audio_history(self):
        style = creative.supplemental_authority(self.bible,'thorn_forest',self.root)
        self.assertEqual(style['content']['version'],'25')
        self.assertEqual(json.loads((ROOT/(BELLSTRIDER_ARCHIVE+'style22.json')).read_bytes())['version'],'22')
        style = {**style,'content':json.loads((ROOT/(MERGE21_ARCHIVE+'audio/style21.json')).read_bytes())}
        self.assertEqual(style['content']['version'],'21')
        # Preserve the full old18 historical chain against exact frozen leaves.
        current_style = style
        archive19 = 'docs/evidence/mobile_ui_clarity_01/source-bindings/before-style19/'
        old18_raw = (ROOT/(archive19+'style-continuity-20261028-v18-chest-art.json')).read_bytes()
        self.assertEqual(hashlib.sha256(old18_raw).hexdigest(),'22c2afbb1a298bfbb5f72315b4f60aefc9ae377a6c93bc47780ef6ae4f0a7510')
        style = {**style, 'content': json.loads(old18_raw)}
        def style18_source(path):
            if path in {'scripts/demo/home_scene.gd','scripts/ui/demo_menu.gd','scripts/ui/stage_reward_modal.gd','scripts/ui/home_item_codex.gd'}:
                return (ROOT/(archive19+Path(path).name+'.txt')).read_bytes()
            return style19_source(path)
        actual_refs = style['content']['runtime_reference']['references']
        self.assertEqual(len(actual_refs),81)
        home_path = 'docs/creative_direction/bibles/style-continuity-20261028-v17-home-codex.json'
        home_raw = (ROOT/home_path).read_bytes()
        self.assertEqual(hashlib.sha256(home_raw).hexdigest(),'ab5f9289fccc909596abf05e9dbb9a4b6c297824d2efc9d69440dfe88c7c16fa')
        home_style = json.loads(home_raw)
        self.assertEqual(home_style['version'],'17')
        live_refs = home_style['runtime_reference']['references']
        self.assertEqual(len(live_refs),73)
        input_archive = 'docs/evidence/chest_art_01/source-bindings/before-reward-input-rebind/'
        pre_input_raw = (ROOT/(input_archive+'style-continuity-20261028-v18-chest-art.json')).read_bytes()
        self.assertEqual(hashlib.sha256(pre_input_raw).hexdigest(),'44206cc99ddddf587b4052a98503ee6c9b2017ef6a6d6f1dd15dd57fe0504624')
        pre_input = json.loads(pre_input_raw)
        self.assertEqual(pre_input['version'],'18')
        chest_refs = pre_input['runtime_reference']['references']
        self.assertEqual(len(chest_refs),81)
        input_manifest_raw = (ROOT/(input_archive+'manifest.json')).read_bytes()
        self.assertEqual(hashlib.sha256(input_manifest_raw).hexdigest(),'d2ca9013df23b0d6488dc9c8638a5b09f6b27dcd64c0e4cbe78d5b4e8ae57efb')
        for row in json.loads(input_manifest_raw)['files']:
            raw = (ROOT/(input_archive+row['path'])).read_bytes()
            self.assertEqual(hashlib.sha256(raw).hexdigest(),row['sha256'])
            self.assertEqual(len(raw),row['bytes'])
        for before,after in zip(chest_refs,actual_refs):
            self.assertEqual({k:v for k,v in before.items() if k!='sha256'},
                             {k:v for k,v in after.items() if k!='sha256'})
            self.assertEqual(after['sha256'],hashlib.sha256(style18_source(after['path'])).hexdigest())
            if before['path']=='scripts/demo/demo_app.gd':
                old_app = (ROOT/(input_archive+'demo_app.gd.txt')).read_bytes()
                self.assertEqual(before['sha256'],hashlib.sha256(old_app).hexdigest())
                self.assertNotEqual(before['sha256'],after['sha256'])
            else:
                self.assertEqual(before,after)
        stale_pre_input = copy.deepcopy(self.ref)
        stale_pre_input['supplemental_authority_path'] = input_archive+'style-continuity-20261028-v18-chest-art.json'
        stale_pre_input['supplemental_authority_sha256'] = hashlib.sha256(pre_input_raw).hexdigest()
        with self.assertRaisesRegex(ValueError,'binding changed'):
            creative.validate_bible_binding(stale_pre_input,root=self.root)
        chest_archive = 'docs/evidence/chest_art_01/source-bindings/before-style18/'
        chest_manifest_raw = (ROOT/(chest_archive+'manifest.json')).read_bytes()
        self.assertEqual(hashlib.sha256(chest_manifest_raw).hexdigest(),'7693e9159827ca55aeb61bf068b58675e31926abfdf85bd25300a085db7c6615')
        for row in json.loads(chest_manifest_raw)['files']:
            raw = (ROOT/(chest_archive+row['path'])).read_bytes()
            self.assertEqual(hashlib.sha256(raw).hexdigest(),row['sha256'])
            self.assertEqual(len(raw),row['bytes'])
        def first_chest_source(path):
            if path == 'scripts/demo/demo_app.gd':
                return (ROOT/(input_archive+'demo_app.gd.txt')).read_bytes()
            return style18_source(path)
        def pre_chest_source(path):
            if path == 'scripts/demo/plains_region_stage.gd':
                return (ROOT/(chest_archive+'plains_region_stage.gd.txt')).read_bytes()
            return first_chest_source(path)
        for before,after in zip(live_refs,chest_refs[:73]):
            self.assertEqual({k:v for k,v in before.items() if k!='sha256'},
                             {k:v for k,v in after.items() if k!='sha256'})
            self.assertEqual(before['sha256'],hashlib.sha256(pre_chest_source(before['path'])).hexdigest())
            self.assertEqual(after['sha256'],hashlib.sha256(first_chest_source(after['path'])).hexdigest())
            if before['path']=='scripts/demo/plains_region_stage.gd':
                self.assertNotEqual(before['sha256'],after['sha256'])
            else:
                self.assertEqual(before,after)
        self.assertEqual([(row['role'],row['path']) for row in actual_refs[73:]],CHEST_ART_REFERENCES)
        for row in actual_refs[73:]:
            self.assertEqual(row['sha256'],hashlib.sha256(style18_source(row['path'])).hexdigest())
        self.assertEqual(style['content']['supersedes']['path'],home_path)
        self.assertEqual(style['content']['supersedes']['sha256'],hashlib.sha256(home_raw).hexdigest())
        for key in home_style.keys()-{'version','runtime_reference','supersedes','revision_impact'}:
            self.assertEqual(style['content'][key],home_style[key])
        published_path = 'docs/creative_direction/bibles/style-continuity-20261028-v16-item-authoring.json'
        published_raw = (ROOT/published_path).read_bytes()
        self.assertEqual(hashlib.sha256(published_raw).hexdigest(),'62befdd0e89ea7b17b649b93dce977b1a35eb2164bad1b9500c108b33309b6da')
        published_style = json.loads(published_raw)
        self.assertEqual(published_style['version'],'16')
        current_refs = published_style['runtime_reference']['references']
        self.assertEqual(len(current_refs),68)
        archive_root = 'docs/evidence/home_codex_01/source-bindings/before-style17/'
        manifest_raw = (ROOT/(archive_root+'manifest.json')).read_bytes()
        self.assertEqual(hashlib.sha256(manifest_raw).hexdigest(),'9b0f3e344a95cab2320894659b6a76828fdbbf2b2a947df0d71f05b67d1e54dc')
        manifest = json.loads(manifest_raw)
        for row in manifest['files']:
            raw = (ROOT/(archive_root+row['path'])).read_bytes()
            self.assertEqual(hashlib.sha256(raw).hexdigest(),row['sha256'])
            self.assertEqual(len(raw),row['bytes'])
        changed_home = {'scripts/demo/demo_app.gd','scripts/demo/home_scene.gd'}
        def historical_source(path):
            if path in changed_home:
                return (ROOT/(archive_root+Path(path).name+'.txt')).read_bytes()
            return pre_chest_source(path)
        for before,after in zip(current_refs,live_refs[:68]):
            self.assertEqual({k:v for k,v in before.items() if k!='sha256'},
                             {k:v for k,v in after.items() if k!='sha256'})
            self.assertEqual(before['sha256'],hashlib.sha256(historical_source(before['path'])).hexdigest())
            self.assertEqual(after['sha256'],hashlib.sha256(pre_chest_source(after['path'])).hexdigest())
            if before['path'] in changed_home:
                self.assertNotEqual(before['sha256'],after['sha256'])
            else:
                self.assertEqual(before,after)
        self.assertEqual([(row['role'],row['path']) for row in live_refs[68:]],HOME_CODEX_REFERENCES)
        for row in live_refs[68:]:
            self.assertEqual(row['sha256'],hashlib.sha256(style18_source(row['path'])).hexdigest())
        self.assertEqual(home_style['supersedes']['path'],published_path)
        self.assertEqual(home_style['supersedes']['sha256'],hashlib.sha256(published_raw).hexdigest())
        for key in published_style.keys()-{'version','runtime_reference','supersedes','revision_impact'}:
            self.assertEqual(home_style[key],published_style[key])
        r12_root = 'docs/evidence/item_art_01/source-bindings/pre-main-audio-r13/'
        r12_path = r12_root+'style-continuity-20261028-v16-item-authoring.json'
        r12_raw = (ROOT/r12_path).read_bytes()
        self.assertEqual(hashlib.sha256(r12_raw).hexdigest(),'079de07b65d33c4e12364a22fa2f8408b0cd63b6044570bb6c7b5800799cf403')
        r12 = json.loads(r12_raw)
        self.assertEqual(r12['version'],'16')
        self.assertEqual(len(r12['runtime_reference']['references']),68)
        pre_audio_refs = r12['runtime_reference']['references']
        for before,after in zip(pre_audio_refs,current_refs):
            if before['path']=='scripts/dev/player_presentation_01/weapon_feel.gd':
                self.assertEqual({k:v for k,v in before.items() if k!='sha256'},{k:v for k,v in after.items() if k!='sha256'})
                self.assertNotEqual(before['sha256'],after['sha256'])
                old_leaf = (ROOT/(r12_root+'weapon_feel.gd.txt')).read_bytes()
                self.assertEqual(before['sha256'],hashlib.sha256(old_leaf).hexdigest())
                new_leaf = (ROOT/after['path']).read_text()
                sound_call = 'audio.weapon_cue(cue,_owner,key,profile.shot_attenuation if attenuation<0 else attenuation,sustained,controller.shoot_ability.weapon.id)'
                self.assertEqual(new_leaf.count(sound_call),1)
                self.assertEqual(new_leaf.replace(sound_call,'audio.weapon_cue(cue,_owner,key,profile.shot_attenuation if attenuation<0 else attenuation,sustained)'),old_leaf.decode())
            else:
                self.assertEqual(before,after)
        stale_r12 = copy.deepcopy(self.ref)
        stale_r12['supplemental_authority_path'] = r12_path
        stale_r12['supplemental_authority_sha256'] = hashlib.sha256(r12_raw).hexdigest()
        with self.assertRaisesRegex(ValueError,'binding changed'):
            creative.validate_bible_binding(stale_r12,root=self.root)
        # Frozen Markdown keeps exact bytes as .md.txt: its original relative
        # links cannot be resolved from a different archive directory. Live .md
        # files are explicit navigation wrappers, not rewritten originals.
        markdown_archives = {
            'docs/evidence/item_authoring_01/source-bindings/before-v16':
                '2e0bd3e6c34bfe331ea71e368f0f59486595aa0fa5107d5e6a75fe7390138858',
            'docs/evidence/item_art_01/source-bindings/pre-golden-r08':
                'cee721987fdd001db0815bf55fa0cad97e9441c4bd0fab815c559a5664fc0592',
            'docs/evidence/item_art_01/source-bindings/pre-expansion-r09':
                '9eaa2d11a9569c25a8bf858b5104e649a6595fa51e8c563bd56a4a0d85d65725',
        }
        relocated_markdown = 0
        for archive_path,original_digest in markdown_archives.items():
            folder = ROOT/archive_path
            original_raw = (folder/'manifest.before-markdown-relocation.json.txt').read_bytes()
            self.assertEqual(hashlib.sha256(original_raw).hexdigest(),original_digest)
            original_manifest = json.loads(original_raw)
            manifest = json.loads((folder/'manifest.json').read_bytes())
            self.assertEqual({k:v for k,v in manifest.items() if k not in {'files','original_manifest_before_markdown_relocation'}},
                             {k:v for k,v in original_manifest.items() if k!='files'})
            self.assertEqual(len(manifest['files']),len(original_manifest['files']))
            for before,after in zip(original_manifest['files'],manifest['files']):
                self.assertEqual({k:v for k,v in after.items() if k!='relocation'},before)
                if before['path'].endswith('.md'):
                    relocated_markdown += 1
                    self.assertEqual(after['relocation']['path'],before['path']+'.txt')
                    self.assertEqual(after['relocation']['wrapper_path'],before['path'])
                    original_bytes = (folder/after['relocation']['path']).read_bytes()
                    self.assertEqual(hashlib.sha256(original_bytes).hexdigest(),before['sha256'])
                    self.assertEqual(len(original_bytes),before['bytes'])
                else:
                    self.assertNotIn('relocation',after)
        self.assertEqual(relocated_markdown,4)
        r11_root = 'docs/evidence/item_art_01/source-bindings/pre-spend-proof-r12/'
        r11_path = r11_root+'style-continuity-20261028-v16-item-authoring.json'
        r11_raw = (ROOT/r11_path).read_bytes()
        self.assertEqual(hashlib.sha256(r11_raw).hexdigest(),'9dcfa6c4aa17c84f7d54492df8aefa78718adf17c2346c91823d14bea4b25e42')
        r11 = json.loads(r11_raw)
        self.assertEqual(r11['version'],'16')
        self.assertEqual(len(r11['runtime_reference']['references']),68)
        for before,after in zip(r11['runtime_reference']['references'],pre_audio_refs):
            if before['path']=='scripts/items/v5/item_defense_effects.gd':
                self.assertEqual({k:v for k,v in before.items() if k!='sha256'},{k:v for k,v in after.items() if k!='sha256'})
                self.assertNotEqual(before['sha256'],after['sha256'])
                old_leaf = (ROOT/(r11_root+'item_defense_effects.gd.txt')).read_bytes()
                self.assertEqual(before['sha256'],hashlib.sha256(old_leaf).hexdigest())
            else:
                self.assertEqual(before,after)
        stale_r11 = copy.deepcopy(self.ref)
        stale_r11['supplemental_authority_path'] = r11_path
        stale_r11['supplemental_authority_sha256'] = hashlib.sha256(r11_raw).hexdigest()
        with self.assertRaisesRegex(ValueError,'binding changed'):
            creative.validate_bible_binding(stale_r11,root=self.root)
        r10_root = 'docs/evidence/item_art_01/source-bindings/pre-legacy-cues-r11/'
        r10_path = r10_root+'style-continuity-20261028-v16-item-authoring.json'
        r10_raw = (ROOT/r10_path).read_bytes()
        self.assertEqual(hashlib.sha256(r10_raw).hexdigest(),'aa06d0dc339247cbc5ba1068887c19d39b2b8cbfccc94c8647c6e99ae1fe0867')
        r10 = json.loads(r10_raw)
        self.assertEqual(r10['version'],'16')
        self.assertEqual(len(r10['runtime_reference']['references']),68)
        changed_r11 = {'scripts/items/v5/item_effect_view.gd',
                       'scripts/items/v5/item_defense_effects.gd'}
        # R11's two-leaf correction stays an exact frozen-stage proof, while
        # the final dedicated-spend fix above changes only Defense once more.
        for before,after in zip(r10['runtime_reference']['references'],r11['runtime_reference']['references']):
            if before['path'] in changed_r11:
                self.assertEqual({k:v for k,v in before.items() if k!='sha256'},{k:v for k,v in after.items() if k!='sha256'})
                self.assertNotEqual(before['sha256'],after['sha256'])
                original_leaf = (ROOT/(r10_root+Path(before['path']).name+'.txt')).read_bytes()
                self.assertEqual(before['sha256'],hashlib.sha256(original_leaf).hexdigest())
            else:
                self.assertEqual(before,after)
        stale_r10 = copy.deepcopy(self.ref)
        stale_r10['supplemental_authority_path'] = r10_path
        stale_r10['supplemental_authority_sha256'] = hashlib.sha256(r10_raw).hexdigest()
        with self.assertRaisesRegex(ValueError,'binding changed'):
            creative.validate_bible_binding(stale_r10,root=self.root)
        r09_path = 'docs/evidence/item_art_01/source-bindings/pre-envelope-r10/style-continuity-20261028-v16-item-authoring.json'
        r09_raw = (ROOT/r09_path).read_bytes()
        self.assertEqual(hashlib.sha256(r09_raw).hexdigest(),'bc3c97d31789281fdfa0679cb821243d5f4a1c796398530e0f83a9a59fdfd96a')
        r09 = json.loads(r09_raw)
        self.assertEqual(r09['version'],'16')
        self.assertEqual(len(r09['runtime_reference']['references']),68)
        # Preserve R10's one-config-change proof against its exact frozen source.
        for before,after in zip(r09['runtime_reference']['references'],r10['runtime_reference']['references']):
            if before['path']=='config/item_v5_art.json':
                self.assertEqual({k:v for k,v in before.items() if k!='sha256'},{k:v for k,v in after.items() if k!='sha256'})
                self.assertNotEqual(before['sha256'],after['sha256'])
                historical = subprocess.check_output(['git','show','f9fefe6e14e9a3bf7858d4f57f5fc5ea2293d5cb:'+before['path']],cwd=ROOT)
                self.assertEqual(before['sha256'],hashlib.sha256(historical).hexdigest())
            else:
                self.assertEqual(before,after)
        old_art_raw = (ROOT/'docs/evidence/item_art_01/source-bindings/pre-envelope-r10/item_v5_art.json').read_bytes()
        self.assertEqual(hashlib.sha256(old_art_raw).hexdigest(),'3d54e59b0e176eefb623a57347265c80215c6b2368ba92d7c44fa69343e4b96a')
        old_art = json.loads(old_art_raw)
        current_art = json.loads((ROOT/'config/item_v5_art.json').read_bytes())
        self.assertEqual({k:v for k,v in old_art.items() if k!='clips'},
                         {k:v for k,v in current_art.items() if k!='clips'})
        self.assertEqual(set(old_art['clips']),set(current_art['clips']))
        refined = {'g05.large_guard','p25.needle_trap','p20.crystal'}
        self.assertEqual({key for key in old_art['clips'] if old_art['clips'][key]!=current_art['clips'][key]},refined)
        for key in refined:
            self.assertEqual({k:v for k,v in old_art['clips'][key].items() if k not in {'regions','world_size','pivot'}},
                             {k:v for k,v in current_art['clips'][key].items() if k not in {'regions','world_size','pivot'}})
        stale_r09 = copy.deepcopy(self.ref)
        stale_r09['supplemental_authority_path'] = r09_path
        stale_r09['supplemental_authority_sha256'] = hashlib.sha256(r09_raw).hexdigest()
        with self.assertRaisesRegex(ValueError,'binding changed'):
            creative.validate_bible_binding(stale_r09,root=self.root)
        changed_golden = {'scripts/ui/item_presentation.gd',
                          'scripts/items/v5/item_effect_view.gd',
                          'scripts/items/v5/item_v5_entity.gd'}
        changed_current54 = changed_golden | {'scripts/items/v5/item_defense_effects.gd'}
        r08_path = 'docs/evidence/item_art_01/source-bindings/pre-expansion-r09/docs/creative_direction/bibles/style-continuity-20261028-v16-item-authoring.json'
        r08_raw = (ROOT/r08_path).read_bytes()
        self.assertEqual(hashlib.sha256(r08_raw).hexdigest(),'473a8efc6ccba6a98696a0a29dfbf980f30c65b217685fc7b885f3a319e20149')
        r08 = json.loads(r08_raw)
        self.assertEqual(r08['version'],'16')
        self.assertEqual(len(r08['runtime_reference']['references']),61)
        changed_r09 = {'scripts/items/v5/item_effect_view.gd',
                       'scripts/items/v5/item_v5_entity.gd',
                       'scripts/items/v5/item_defense_effects.gd',
                       'scripts/items/v5/item_art_library.gd',
                       'config/item_v5_art.json','config/item_v5_authoring.json'}
        for before,after in zip(r08['runtime_reference']['references'],pre_audio_refs[:61]):
            self.assertEqual({k:v for k,v in before.items() if k!='sha256'},{k:v for k,v in after.items() if k!='sha256'})
            if before['path'] in changed_r09:
                self.assertNotEqual(before['sha256'],after['sha256'])
                historical = subprocess.check_output(['git','show','cd163e2ddbb9e1041067279eb2f554d09af0582a:'+before['path']],cwd=ROOT)
                self.assertEqual(before['sha256'],hashlib.sha256(historical).hexdigest())
            else:
                self.assertEqual(before,after)
        stale_r08 = copy.deepcopy(self.ref)
        stale_r08['supplemental_authority_path'] = r08_path
        stale_r08['supplemental_authority_sha256'] = hashlib.sha256(r08_raw).hexdigest()
        with self.assertRaisesRegex(ValueError,'binding changed'):
            creative.validate_bible_binding(stale_r08,root=self.root)
        pre_art_path = 'docs/evidence/item_art_01/source-bindings/pre-golden-r08/style-continuity-20261028-v16-item-authoring.json'
        pre_art_raw = (ROOT/pre_art_path).read_bytes()
        self.assertEqual(hashlib.sha256(pre_art_raw).hexdigest(),'fe89f171ad210b0ddc16c355c94c48b34d1a66891fd6ca25c0810c6f32aa336f')
        pre_art = json.loads(pre_art_raw)
        self.assertEqual(pre_art['version'],'16')
        self.assertEqual(len(pre_art['runtime_reference']['references']),54)
        for before,after in zip(pre_art['runtime_reference']['references'],pre_audio_refs[:54]):
            self.assertEqual({k:v for k,v in before.items() if k!='sha256'},{k:v for k,v in after.items() if k!='sha256'})
            if before['path'] in changed_current54:
                self.assertNotEqual(before['sha256'],after['sha256'])
                historical = subprocess.check_output(['git','show','df5b075799e36624597b780a17d88850f0b4ff21:'+before['path']],cwd=ROOT)
                self.assertEqual(before['sha256'],hashlib.sha256(historical).hexdigest())
            else:
                self.assertEqual(before,after)
        stale_pre_art = copy.deepcopy(self.ref)
        stale_pre_art['supplemental_authority_path'] = pre_art_path
        stale_pre_art['supplemental_authority_sha256'] = hashlib.sha256(pre_art_raw).hexdigest()
        with self.assertRaisesRegex(ValueError,'binding changed'):
            creative.validate_bible_binding(stale_pre_art,root=self.root)
        # Keep the original R08 exact three-leaf guard as a frozen-history check.
        for before,after in zip(pre_art['runtime_reference']['references'],r08['runtime_reference']['references'][:54]):
            self.assertEqual({k:v for k,v in before.items() if k!='sha256'},{k:v for k,v in after.items() if k!='sha256'})
            if before['path'] in changed_golden:
                self.assertNotEqual(before['sha256'],after['sha256'])
            else:
                self.assertEqual(before,after)
        old_v15_path = 'docs/creative_direction/bibles/style-continuity-20261027-v15-item-v5.json'
        old_v15_raw = (ROOT/old_v15_path).read_bytes()
        self.assertEqual(hashlib.sha256(old_v15_raw).hexdigest(), '6d0303e867592d72723973f29060902226b1f25e31aff24fcd065fff427cbfd0')
        old_v15 = json.loads(old_v15_raw)
        self.assertEqual(old_v15['version'],'15')
        self.assertEqual(len(old_v15['runtime_reference']['references']),54)
        self.assertEqual(published_style['supersedes']['path'],old_v15_path)
        self.assertEqual(published_style['supersedes']['sha256'],hashlib.sha256(old_v15_raw).hexdigest())
        for key in old_v15.keys()-{'version','runtime_reference','supersedes','revision_impact'}:
            self.assertEqual(published_style[key],old_v15[key])
        for before,after in zip(old_v15['runtime_reference']['references'],pre_audio_refs):
            if before['path'] in changed_current54:
                self.assertEqual({k:v for k,v in before.items() if k!='sha256'},{k:v for k,v in after.items() if k!='sha256'})
                self.assertNotEqual(before['sha256'],after['sha256'])
                historical = subprocess.check_output(['git','show','d9445c0e5d6516d4eb93ebbfbc5639efddf7fc04:'+before['path']],cwd=ROOT)
                self.assertEqual(before['sha256'],hashlib.sha256(historical).hexdigest())
                self.assertEqual(after['sha256'],hashlib.sha256(historical_source(after['path'])).hexdigest())
            else:
                self.assertEqual(before,after)
        old_v14_path = 'docs/creative_direction/bibles/style-continuity-20261026-v14-run-gear.json'
        old_v14_raw = (ROOT/old_v14_path).read_bytes()
        self.assertEqual(hashlib.sha256(old_v14_raw).hexdigest(), 'a9fba5dd2cadbc1d36abda4928f4d473bd8849d882346abd70870a68900dc366')
        old_v14 = json.loads(old_v14_raw)
        self.assertEqual(len(old_v14['runtime_reference']['references']),36)
        self.assertEqual(old_v15['supersedes']['path'],old_v14_path)
        self.assertEqual(old_v15['supersedes']['sha256'],hashlib.sha256(old_v14_raw).hexdigest())
        for key in old_v14.keys()-{'version','runtime_reference','supersedes','revision_impact'}:
            self.assertEqual(published_style[key],old_v14[key])
        for before,after in zip(old_v14['runtime_reference']['references'],current_refs[:36]):
            if before['path']=='scripts/demo/demo_app.gd':
                self.assertEqual({k:v for k,v in before.items() if k!='sha256'},{k:v for k,v in after.items() if k!='sha256'})
                self.assertNotEqual(before['sha256'],after['sha256'])
                historical = subprocess.check_output(['git','show','879b39eaa869be70cb799dedd1bb6ffc35e0b92f:'+before['path']],cwd=ROOT)
                self.assertEqual(before['sha256'],hashlib.sha256(historical).hexdigest())
                self.assertEqual(after['sha256'],hashlib.sha256(historical_source(after['path'])).hexdigest())
            else:
                self.assertEqual(before,after)
        # Preserve the pre-art author's exact one-leaf change against V15 too.
        for before,after in zip(old_v15['runtime_reference']['references'],pre_art['runtime_reference']['references']):
            if before['path']=='scripts/ui/item_presentation.gd':
                self.assertEqual({k:v for k,v in before.items() if k!='sha256'},{k:v for k,v in after.items() if k!='sha256'})
                self.assertNotEqual(before['sha256'],after['sha256'])
            else:
                self.assertEqual(before,after)
        self.assertEqual([(row['role'],row['path']) for row in current_refs[36:54]],ITEM_V5_STYLE_REFERENCES)
        self.assertEqual([(row['role'],row['path']) for row in current_refs[54:61]],ITEM_ART_GOLDEN_REFERENCES)
        self.assertEqual([(row['role'],row['path']) for row in current_refs[61:]],ITEM_ART_EXPANSION_REFERENCES)
        for row in current_refs[36:]:
            self.assertEqual(row['sha256'],hashlib.sha256(style18_source(row['path'])).hexdigest())
        old_v12 = json.loads((ROOT/'docs/creative_direction/bibles/style-continuity-20261024-v12-fixed-status.json').read_bytes())
        for key in old_v12.keys()-{'version','runtime_reference','supersedes','revision_impact'}:
            self.assertEqual(published_style[key], old_v12[key])
        for before, after in zip(old_v12['runtime_reference']['references'], current_refs):
            if before['path']=='scripts/demo/demo_app.gd':
                self.assertEqual({k:v for k,v in before.items() if k!='sha256'}, {k:v for k,v in after.items() if k!='sha256'})
                self.assertNotEqual(before['sha256'], after['sha256'])
                actual = subprocess.check_output(['git','show','4fc1e7a55c191dbe56cd7bc385539fc42b8f7898:'+before['path']], cwd=ROOT)
                self.assertEqual(before['sha256'], hashlib.sha256(actual).hexdigest())
                self.assertEqual(after['sha256'], hashlib.sha256(historical_source(after['path'])).hexdigest())
            else:
                self.assertEqual(before, after)
        old_v11 = json.loads((ROOT/'docs/creative_direction/bibles/style-continuity-20261024-v11-playtest-feedback.json').read_bytes())
        for key in old_v11.keys()-{'version','runtime_reference','supersedes','revision_impact'}:
            self.assertEqual(published_style[key], old_v11[key])
        for before, after in zip(old_v11['runtime_reference']['references'], current_refs):
            if before['path']=='scripts/demo/demo_app.gd':
                self.assertEqual({k:v for k,v in before.items() if k!='sha256'}, {k:v for k,v in after.items() if k!='sha256'})
                self.assertNotEqual(before['sha256'], after['sha256'])
                self.assertEqual(after['sha256'], hashlib.sha256(historical_source(after['path'])).hexdigest())
            else:
                self.assertEqual(before, after)
        old_v10 = json.loads((ROOT/'docs/creative_direction/bibles/style-continuity-20261023-v10-foreground-cpu.json').read_bytes())
        for key in old_v10.keys()-{'version','runtime_reference','supersedes','revision_impact'}:
            self.assertEqual(old_v11[key], old_v10[key])
        for before, after in zip(old_v10['runtime_reference']['references'], old_v11['runtime_reference']['references']):
            if before['path'] in ('scripts/demo/demo_app.gd','scripts/demo/home_scene.gd'):
                self.assertEqual({k:v for k,v in before.items() if k!='sha256'}, {k:v for k,v in after.items() if k!='sha256'})
                self.assertNotEqual(before['sha256'], after['sha256'])
                actual = subprocess.check_output(['git','show','e5254559b38f9593f03fa2fd7847b107d5d04402:'+after['path']], cwd=ROOT)
                self.assertEqual(after['sha256'], hashlib.sha256(actual).hexdigest())
            else:
                self.assertEqual(before, after)
        old_v9 = json.loads((ROOT/'docs/creative_direction/bibles/style-continuity-20261023-v9-hud-layout.json').read_bytes())
        for before, after in zip(old_v9['runtime_reference']['references'], old_v10['runtime_reference']['references']):
            if before['path']=='scripts/underworld_plains/underworld_presentation.gd':
                self.assertEqual({k:v for k,v in before.items() if k!='sha256'}, {k:v for k,v in after.items() if k!='sha256'})
                self.assertNotEqual(before['sha256'], after['sha256'])
                self.assertEqual(after['sha256'], hashlib.sha256(historical_source(after['path'])).hexdigest())
            else:
                self.assertEqual(before, after)
        for key in old_v9.keys()-{'version','runtime_reference','supersedes','revision_impact'}:
            self.assertEqual(old_v10[key], old_v9[key])
        self.assertEqual({k:v for k,v in published_style['runtime_reference'].items() if k!='references'}, {k:v for k,v in old_v9['runtime_reference'].items() if k!='references'})
        refs = old_v9['runtime_reference']['references']
        old_v7 = json.loads((ROOT/'docs/creative_direction/bibles/style-continuity-20261023-v7.json').read_bytes())
        old_refs = old_v7['runtime_reference']['references']
        self.assertEqual(len(old_refs),36)
        for before, after in zip(old_refs,refs):
            if before['path']=='scripts/demo/demo_app.gd':
                self.assertEqual({k:v for k,v in before.items() if k!='sha256'}, {k:v for k,v in after.items() if k!='sha256'})
                self.assertNotEqual(before['sha256'],after['sha256'])
                # The v9 source is frozen in the actual pre-feedback main,
                # while the active DemoApp is independently verified above.
                actual = subprocess.check_output(['git','show','cd4989a68613e0b457cdfd5e252634dd57008505:'+after['path']], cwd=ROOT)
                self.assertEqual(after['sha256'],hashlib.sha256(actual).hexdigest())
            else:
                self.assertEqual(before,after)
        for key in old_v7.keys()-{'version','runtime_reference','supersedes','revision_impact'}:
            self.assertEqual(old_v9[key],old_v7[key])
        self.assertEqual({k:v for k,v in published_style['runtime_reference'].items() if k!='references'}, {k:v for k,v in old_v7['runtime_reference'].items() if k!='references'})
        # The selected fine style superseded V4; V7 adds the real default body.
        # All20 V6 references remain exact, and old bindings remain refused.
        previous_path = 'docs/creative_direction/bibles/style-continuity-20261021-v2.json'
        previous_bytes = (ROOT/previous_path).read_bytes()
        previous = json.loads((ROOT/'docs/creative_direction/bibles/style-continuity-20261023-v6.json').read_bytes())
        for row in previous['runtime_reference']['references']:
            self.assertIn(row, refs)
        superseded = copy.deepcopy(self.ref)
        superseded['supplemental_authority_path'] = previous_path
        superseded['supplemental_authority_sha256'] = hashlib.sha256(previous_bytes).hexdigest()
        with self.assertRaisesRegex(ValueError,'binding changed'):
            creative.validate_bible_binding(superseded,root=self.root)
        v3_path = 'docs/creative_direction/bibles/style-continuity-20261021-v3.json'
        stale_v3 = copy.deepcopy(self.ref)
        stale_v3['supplemental_authority_path'] = v3_path
        stale_v3['supplemental_authority_sha256'] = hashlib.sha256((ROOT/v3_path).read_bytes()).hexdigest()
        with self.assertRaisesRegex(ValueError, 'binding changed'):
            creative.validate_bible_binding(stale_v3,root=self.root)
        for old_style in ['style-continuity-20261022-v4.json','style-continuity-20261022-v5.json','style-continuity-20261023-v6.json','style-continuity-20261023-v7.json','style-continuity-20261023-v9-hud-layout.json','style-continuity-20261023-v10-foreground-cpu.json','style-continuity-20261024-v11-playtest-feedback.json','style-continuity-20261024-v12-fixed-status.json','style-continuity-20261024-v13-responsive-navigation.json','style-continuity-20261026-v14-run-gear.json','style-continuity-20261027-v15-item-v5.json','style-continuity-20261028-v16-item-authoring.json','style-continuity-20261028-v17-home-codex.json']:
            old_path = 'docs/creative_direction/bibles/'+old_style
            stale = copy.deepcopy(self.ref)
            stale['supplemental_authority_path'] = old_path
            stale['supplemental_authority_sha256'] = hashlib.sha256((ROOT/old_path).read_bytes()).hexdigest()
            with self.subTest(superseded=old_style),self.assertRaisesRegex(ValueError, 'binding changed'):
                creative.validate_bible_binding(stale,root=self.root)
        style = current_style
        refs = style['content']['runtime_reference']['references']
        for role,path in creative.PLAYER_STYLE_DEPENDENCIES.items():
            self.assertIn({'role':role,'path':path,'sha256':hashlib.sha256((self.root/path).read_bytes()).hexdigest()},refs)
        old = json.loads((ROOT/'docs/creative_direction/archive/creative-v5/thorn_forest.json').read_bytes())['region_bible']
        with self.assertRaisesRegex(ValueError,'binding changed'):
            creative.validate_bible_binding(old,root=self.root)
        supplement_path = self.root/style['path']
        original = supplement_path.read_bytes()
        registry_path = self.root/creative.BIBLE_REGISTRY
        registry_raw = registry_path.read_bytes()
        for role in creative.PLAYER_STYLE_DEPENDENCIES:
            data = json.loads(original)
            data['runtime_reference']['references'] = [row for row in refs if row['role'] != role]
            supplement_path.write_text(json.dumps(data))
            registry = json.loads(registry_raw)
            registry['shared_style_authority']['sha256'] = hashlib.sha256(supplement_path.read_bytes()).hexdigest()
            registry_path.write_text(json.dumps(registry))
            with self.subTest(missing_role=role),self.assertRaisesRegex(ValueError,'Complete actual formal'):
                creative.bind_region_bible('thorn_forest',self.root)
        supplement_path.write_bytes(original);registry_path.write_bytes(registry_raw)

    def test_mobile_ui_v19_is_finite_preserves_originals_and_rejects_stale_v18_audio_history(self):
        archive = 'docs/evidence/mobile_ui_clarity_01/source-bindings/before-style19/'
        manifest_raw = (ROOT/(archive+'manifest.json')).read_bytes()
        self.assertEqual(hashlib.sha256(manifest_raw).hexdigest(),'f440dee12a1bbcc1eb77ab897a079f52b8465ee00018068f0d4e1b73e8e8272a')
        for row in json.loads(manifest_raw)['files']:
            raw = (ROOT/row['path']).read_bytes()
            self.assertEqual(hashlib.sha256(raw).hexdigest(),row['sha256'])
            self.assertEqual(len(raw),row['bytes'])
        old_path = archive+'style-continuity-20261028-v18-chest-art.json'
        old_raw = (ROOT/old_path).read_bytes()
        old = json.loads(old_raw)
        current = json.loads((ROOT/STYLE19_PATH).read_bytes())
        self.assertEqual(current['version'],'19')
        self.assertEqual(len(current['runtime_reference']['references']),81)
        changed = {'default_player_5','item_pause_menu','item_reward_modal','home_codex_ui'}
        for before,after in zip(old['runtime_reference']['references'],current['runtime_reference']['references']):
            self.assertEqual({k:v for k,v in before.items() if k!='sha256'},
                             {k:v for k,v in after.items() if k!='sha256'})
            self.assertEqual(after['sha256'],hashlib.sha256(style19_source(after['path'])).hexdigest())
            if after['role'] in changed:
                self.assertNotEqual(before['sha256'],after['sha256'])
                self.assertEqual(before['sha256'],hashlib.sha256((ROOT/(archive+Path(before['path']).name+'.txt')).read_bytes()).hexdigest())
            else:
                self.assertEqual(before,after)
        for key in old.keys()-{'version','runtime_reference','supersedes','revision_impact'}:
            self.assertEqual(current[key],old[key])
        self.assertEqual(current['supersedes'],{'path':'docs/creative_direction/bibles/style-continuity-20261028-v18-chest-art.json','sha256':hashlib.sha256(old_raw).hexdigest()})
        self.assertEqual(current['revision_impact']['task_id'],'MOBILE-UI-CLARITY-01')
        self.assertEqual(len(current['revision_impact']['changed_references']),4)
        self.assertEqual(current['revision_impact']['added_references'],[])
        stale = copy.deepcopy(self.ref)
        stale.update(supplemental_authority_path=old_path,supplemental_authority_sha256=hashlib.sha256(old_raw).hexdigest())
        with self.assertRaisesRegex(ValueError,'binding changed'):
            creative.validate_bible_binding(stale,root=self.root)

    def test_audio_feedback_v20_preserves81_and_refuses_stale19(self):
        old_raw = (ROOT/STYLE19_PATH).read_bytes()
        self.assertEqual(hashlib.sha256(old_raw).hexdigest(),'7e1a7710028253ce9d6bde253227eb745aef32cd133c9aa3959f5a081219537e')
        old = json.loads(old_raw)
        current = json.loads((ROOT/STYLE20_PATH).read_bytes())
        self.assertEqual(current['version'],'20')
        self.assertEqual(len(current['runtime_reference']['references']),81)
        expected = {
            'scripts/demo/demo_app.gd': ('default_player_4','3e9e9baf24da3e08cc53890d41d1f995f78c280d90666f514e47b4cda6555c5f'),
            'scripts/ui/demo_menu.gd': ('item_pause_menu','af2f5a92ca800bcbe4340c23d3007e9d37b93dff96e9720df102cb17040c930d'),
            'scripts/items/v5/item_v5_shop_presenter.gd': ('item_shop_presenter','2b803f8f23154de50f1471033d030eb1329196d0505a4119706742879cfa7a7b'),
        }
        deltas = []
        for before,after in zip(old['runtime_reference']['references'],current['runtime_reference']['references']):
            self.assertEqual({k:v for k,v in before.items() if k!='sha256'},
                             {k:v for k,v in after.items() if k!='sha256'})
            self.assertEqual(before['sha256'],hashlib.sha256(style19_source(before['path'])).hexdigest())
            self.assertEqual(after['sha256'],hashlib.sha256(style20_source(after['path'])).hexdigest())
            if after['path'] in expected:
                self.assertEqual((after['role'],after['sha256']),expected[after['path']])
                self.assertNotEqual(before['sha256'],after['sha256'])
                deltas.append({'role':after['role'],'path':after['path'],'old_sha256':before['sha256'],'new_sha256':after['sha256']})
            else:
                self.assertEqual(before,after)
        self.assertEqual(len(deltas),3)
        self.assertEqual(current['revision_impact']['changed_references'],deltas)
        self.assertEqual(current['revision_impact']['added_references'],[])
        self.assertEqual(current['revision_impact']['task_id'],'AUDIO-FEEDBACK-05')
        self.assertEqual(current['supersedes'],{'path':STYLE19_PATH,'sha256':hashlib.sha256(old_raw).hexdigest()})
        for key in old.keys()-{'version','runtime_reference','supersedes','revision_impact'}:
            self.assertEqual(current[key],old[key])
        self.assertEqual({k:v for k,v in current['runtime_reference'].items() if k!='references'},
                         {k:v for k,v in old['runtime_reference'].items() if k!='references'})
        manifest_raw = (ROOT/(STYLE22_ARCHIVE+'manifest.json')).read_bytes()
        self.assertEqual(hashlib.sha256(manifest_raw).hexdigest(),'edb99db3c34ff269c21ccf2f20b049edb530d306b56e06612895ecd2e06ff4e7')
        self.assertEqual(current['revision_impact']['previous_binding_manifest'],{'path':STYLE22_ARCHIVE+'manifest.json','sha256':hashlib.sha256(manifest_raw).hexdigest()})
        manifest = json.loads(manifest_raw)
        self.assertEqual(len(manifest['files']),7)
        self.assertEqual({row['source_path'] for row in manifest['files'] if '/runtime_inputs/' in row['path']},set(expected))
        for row in manifest['files']:
            raw = (ROOT/row['path']).read_bytes()
            self.assertEqual(hashlib.sha256(raw).hexdigest(),row['sha256'])
            self.assertEqual(len(raw),row['bytes'])
        stale = copy.deepcopy(self.ref)
        stale.update(supplemental_authority_path=STYLE19_PATH,supplemental_authority_sha256=hashlib.sha256(old_raw).hexdigest())
        with self.assertRaisesRegex(ValueError,'binding changed'):
            creative.validate_bible_binding(stale,root=self.root)

    def test_audio_feedback06_v21_rebinds_only_original_title_and_refuses_stale20(self):
        old_raw = (ROOT/STYLE20_PATH).read_bytes()
        self.assertEqual(hashlib.sha256(old_raw).hexdigest(),'66d75a2ea49cf0126cfbe5585daf2099ec3b1e883e8b5cd01e5ff78b77ac92f8')
        old = json.loads(old_raw)
        current = json.loads((ROOT/(MERGE21_ARCHIVE+'audio/style21.json')).read_bytes())
        self.assertEqual((old['version'],current['version']),('20','21'))
        self.assertEqual(len(current['runtime_reference']['references']),81)
        self.assertEqual({k:v for k,v in current.items() if k not in {'version','runtime_reference','supersedes','revision_impact'}},
                         {k:v for k,v in old.items() if k not in {'version','runtime_reference','supersedes','revision_impact'}})
        self.assertEqual({k:v for k,v in current['runtime_reference'].items() if k!='references'},
                         {k:v for k,v in old['runtime_reference'].items() if k!='references'})
        deltas = []
        for before,after in zip(old['runtime_reference']['references'],current['runtime_reference']['references']):
            self.assertEqual({k:v for k,v in before.items() if k!='sha256'},
                             {k:v for k,v in after.items() if k!='sha256'})
            self.assertEqual(before['sha256'],hashlib.sha256(style20_source(before['path'])).hexdigest())
            self.assertEqual(after['sha256'],hashlib.sha256(merge21_parent_source('audio',after['path'])).hexdigest())
            if after['path']=='scripts/ui/demo_menu.gd':
                self.assertEqual(after['role'],'item_pause_menu')
                self.assertEqual((before['sha256'],after['sha256']),('af2f5a92ca800bcbe4340c23d3007e9d37b93dff96e9720df102cb17040c930d','1552093205becf49569ae581747e4f8d71fc6f5b1552d021bb0aa7490f95471f'))
                deltas.append({'role':after['role'],'path':after['path'],'old_sha256':before['sha256'],'new_sha256':after['sha256']})
                self.assertEqual(merge21_parent_source('audio',after['path']),(ROOT/(STYLE22_ARCHIVE+'runtime_inputs/demo_menu.gd.txt')).read_bytes())
            else:
                self.assertEqual(before,after)
        self.assertEqual(len(deltas),1)
        self.assertEqual(current['revision_impact']['changed_references'],deltas)
        self.assertEqual(current['revision_impact']['added_references'],[])
        self.assertEqual(current['revision_impact']['task_id'],'AUDIO-FEEDBACK-06')
        self.assertEqual(current['supersedes'],{'path':STYLE20_PATH,'sha256':hashlib.sha256(old_raw).hexdigest()})
        manifest_raw = (ROOT/(STYLE23_ARCHIVE+'manifest.json')).read_bytes()
        self.assertEqual(hashlib.sha256(manifest_raw).hexdigest(),'d4d6c6026932c114c0f24e54b7008069b74f11b43065e03e3d1343134e450e96')
        self.assertEqual(current['revision_impact']['previous_binding_manifest'],{'path':STYLE23_ARCHIVE+'manifest.json','sha256':hashlib.sha256(manifest_raw).hexdigest()})
        manifest = json.loads(manifest_raw)
        self.assertEqual(len(manifest['files']),5)
        self.assertEqual([row['source_path'] for row in manifest['files'] if '/runtime_inputs/' in row['path']],['scripts/ui/demo_menu.gd'])
        for row in manifest['files']:
            raw = (ROOT/row['path']).read_bytes()
            self.assertEqual(hashlib.sha256(raw).hexdigest(),row['sha256'])
            self.assertEqual(len(raw),row['bytes'])
        stale = copy.deepcopy(self.ref)
        stale.update(supplemental_authority_path=STYLE20_PATH,supplemental_authority_sha256=hashlib.sha256(old_raw).hexdigest())
        with self.assertRaisesRegex(ValueError,'binding changed'):
            creative.validate_bible_binding(stale,root=self.root)
        menu = self.root/'scripts/ui/demo_menu.gd'
        original = menu.read_bytes()
        menu.write_bytes(original+b'\n# isolated title source drift\n')
        with self.assertRaisesRegex(ValueError,'Shared Plains style reference SHA changed'):
            creative.bind_region_bible('thorn_forest',self.root)
        menu.write_bytes(original)
        self.assertEqual(creative.bind_region_bible('thorn_forest',self.root)[1],self.ref)

    def test_merged22_keeps83_roles_and_both_parent21_histories_and_rejects_stale(self):
        live = creative.supplemental_authority(self.bible,'thorn_forest',self.root)['content']
        self.assertEqual(live['version'],'25')
        current = json.loads((ROOT/(BELLSTRIDER_ARCHIVE+'style22.json')).read_bytes())
        self.assertEqual(current['version'],'22')
        actual = current['runtime_reference']['references']
        self.assertEqual(len(actual),83)
        parents = {}
        for parent, digest in MERGE21_MANIFESTS.items():
            base = ROOT/(MERGE21_ARCHIVE+parent)
            raw = (base/'manifest.json').read_bytes()
            self.assertEqual(hashlib.sha256(raw).hexdigest(),digest)
            for row in json.loads(raw)['files']:
                content = (base/row['path']).read_bytes()
                self.assertEqual((len(content),hashlib.sha256(content).hexdigest()),(row['bytes'],row['sha256']))
            parents[parent] = json.loads((base/'style21.json').read_bytes())
            prior = parents[parent]
            self.assertEqual(prior['version'],'21')
            self.assertEqual({k:v for k,v in current.items() if k not in {'version','runtime_reference','supersedes','revision_impact'}},
                             {k:v for k,v in prior.items() if k not in {'version','runtime_reference','supersedes','revision_impact'}})
            oldrefs = prior['runtime_reference']['references']
            self.assertEqual([(x['role'],x['path']) for x in actual[:len(oldrefs)]],[(x['role'],x['path']) for x in oldrefs])
            for row in oldrefs:
                self.assertEqual(row['sha256'],hashlib.sha256(merge21_parent_source(parent,row['path'])).hexdigest())
            stale = copy.deepcopy(self.ref)
            registry = json.loads((base/'registry.json').read_bytes())
            stale.update(supplemental_authority_path=registry['shared_style_authority']['path'],supplemental_authority_sha256=registry['shared_style_authority']['sha256'])
            with self.assertRaisesRegex(ValueError,'binding changed'):
                creative.validate_bible_binding(stale,root=self.root)
        self.assertEqual(len(parents['program']['runtime_reference']['references']),83)
        self.assertEqual(len(parents['audio']['runtime_reference']['references']),81)
        changed = []
        for before,after in zip(parents['program']['runtime_reference']['references'],actual):
            self.assertEqual({k:v for k,v in before.items() if k!='sha256'},{k:v for k,v in after.items() if k!='sha256'})
            self.assertEqual(after['sha256'],hashlib.sha256(before_bellstrider_source(after['path'])).hexdigest())
            if before != after: changed.append({'role':after['role'],'path':after['path'],'old_sha256':before['sha256'],'new_sha256':after['sha256']})
        self.assertEqual({row['path'] for row in changed},{'scripts/demo/demo_app.gd','scripts/items/v5/item_v5_shop_presenter.gd'})
        self.assertEqual(current['revision_impact']['changed_references'],changed)
        self.assertEqual(current['revision_impact']['added_references'],[])
        self.assertEqual(current['supersedes'],json.loads((ROOT/(MERGE21_ARCHIVE+'program/registry.json')).read_bytes())['shared_style_authority'])
        source = self.root/'scripts/demo/demo_app.gd'
        original = source.read_bytes()
        source.write_bytes(original+b'\n# merged source drift counterexample\n')
        with self.assertRaisesRegex(ValueError,'Shared Plains style reference SHA changed'):
            creative.bind_region_bible('thorn_forest',self.root)
        source.write_bytes(original)
        self.assertEqual(creative.bind_region_bible('thorn_forest',self.root)[1],self.ref)

    def test_bellstrider23_has_exact83_prefix_and_finite_real_body_audio_closure(self):
        current = json.loads((ROOT/BELLSTRIDER_STYLE23).read_bytes())
        self.assertEqual(current['version'],'23')
        prior = json.loads((ROOT/(BELLSTRIDER_ARCHIVE+'style22.json')).read_bytes())
        before = prior['runtime_reference']['references']
        actual = current['runtime_reference']['references']
        self.assertEqual((len(before),len(actual)),(83,96))
        self.assertEqual([(r['role'],r['path']) for r in actual[:83]],[(r['role'],r['path']) for r in before])
        changed = []
        for old,new in zip(before,actual[:83]):
            self.assertEqual({k:v for k,v in old.items() if k!='sha256'},{k:v for k,v in new.items() if k!='sha256'})
            self.assertEqual(old['sha256'],hashlib.sha256(before_bellstrider_source(old['path'])).hexdigest())
            self.assertEqual(new['sha256'],hashlib.sha256(boss_parent_source('bellstrider',new['path'])).hexdigest())
            if old != new:changed.append({'role':new['role'],'path':new['path'],'old_sha256':old['sha256'],'new_sha256':new['sha256']})
        self.assertEqual({r['path'] for r in changed},BELLSTRIDER_OLD_LEAVES)
        self.assertEqual(current['revision_impact']['changed_references'],changed)
        expected = [
            ('bellstrider_presentation','scripts/bosses/bellstrider_presentation.gd'),
            ('bellstrider_shared_rig','scripts/bosses/bellstrider_rig_pose.gd'),
            ('bellstrider_accepted_pose_owner','scripts/bosses/bellstrider_encounter.gd'),
            ('bellstrider_definition','scripts/bosses/bellstrider_definition.gd'),
            ('bellstrider_config','resources/bosses/bellstrider.tres'),
            ('bellstrider_source_body','assets/underworld_plains/actors/bellstrider.png'),
            ('bellstrider_source_bell','assets/underworld_plains/actors/bell.png'),
            ('bellstrider_audio_consumer','scripts/audio/bellstrider_audio.gd'),
            ('bellstrider_audio_manifest','assets/audio/bellstrider_01/manifest.json'),
            ('bellstrider_audio_sources','assets/audio/bellstrider_01/sources.json'),
            ('bellstrider_audio_recipes','assets/audio/bellstrider_01/recipes.json'),
            ('bellstrider_local_ring_vfx','scripts/bosses/bellstrider_ring_projectile.gd'),
            ('bellstrider_lob_bell_vfx','scripts/bosses/bellstrider_bell_projectile.gd')]
        self.assertEqual([(r['role'],r['path']) for r in actual[83:]],expected)
        self.assertEqual(current['revision_impact']['added_references'],actual[83:])
        self.assertEqual({k:v for k,v in current.items() if k not in {'version','runtime_reference','supersedes','revision_impact'}},
                         {k:v for k,v in prior.items() if k not in {'version','runtime_reference','supersedes','revision_impact'}})
        archive_manifest = json.loads((ROOT/(BELLSTRIDER_ARCHIVE+'manifest.json')).read_bytes())
        for row in archive_manifest['files']:
            raw = (ROOT/BELLSTRIDER_ARCHIVE/row['path']).read_bytes()
            self.assertEqual((len(raw),hashlib.sha256(raw).hexdigest()),(row['bytes'],row['sha256']))
        reviewed94 = current['revision_impact']['previous_candidate_manifest']
        reviewed94_raw = (ROOT/reviewed94['path']).read_bytes()
        self.assertEqual(hashlib.sha256(reviewed94_raw).hexdigest(),reviewed94['sha256'])
        archive94 = (ROOT/reviewed94['path']).parent
        for row in json.loads(reviewed94_raw)['files']:
            raw = (archive94/row['path']).read_bytes()
            self.assertEqual((len(raw),hashlib.sha256(raw).hexdigest()),(row['bytes'],row['sha256']))
        old94 = json.loads((archive94/BELLSTRIDER_STYLE23).read_bytes())
        self.assertEqual(len(old94['runtime_reference']['references']),94)
        self.assertEqual([(r['role'],r['path']) for r in actual[:94]],[(r['role'],r['path']) for r in old94['runtime_reference']['references']])
        stale = copy.deepcopy(self.ref)
        frozen_registry = json.loads((ROOT/(BELLSTRIDER_ARCHIVE+'registry.json')).read_bytes())
        stale.update(supplemental_authority_path=frozen_registry['shared_style_authority']['path'],supplemental_authority_sha256=frozen_registry['shared_style_authority']['sha256'])
        with self.assertRaisesRegex(ValueError,'binding changed'):creative.validate_bible_binding(stale,root=self.root)
        for relative in ['scripts/bosses/bellstrider_rig_pose.gd','scripts/bosses/bellstrider_presentation.gd','assets/audio/bellstrider_01/manifest.json','assets/underworld_plains/actors/bellstrider.png','scripts/bosses/bellstrider_ring_projectile.gd','scripts/bosses/bellstrider_bell_projectile.gd']:
            path = self.root/relative;raw = path.read_bytes();path.write_bytes(raw+b'\nsource-drift')
            with self.subTest(path=relative),self.assertRaisesRegex(ValueError,'Shared Plains style reference SHA changed'):
                creative.bind_region_bible('thorn_forest',self.root)
            path.write_bytes(raw)

    def test_bellstrider_audio_assets_are_literal17_real_wavs_with_strict_byte_custody(self):
        import re
        import wave
        from quality import validate_asset
        record_path = 'docs/quality/asset_records/bellstrider-rework-01-material-audio.json'
        record = json.loads((ROOT/record_path).read_bytes())
        self.assertEqual(record['disposition'],'runtime_candidate')
        self.assertEqual(record['visual_status'],'unverified')
        self.assertEqual(record['audio_status'],'unverified')
        self.assertEqual(record['user_acceptance_evidence'],[])
        expected_ids = {'armour_hit','weak_hit','roll_warn','roll_warn_double','roll_start','brake','turn','ring_strike','lob_aim','lob_lock','lob_release','lob_impact','phase','death','death_jam','death_impact','death_final'}
        consumer = (ROOT/'scripts/audio/bellstrider_audio.gd').read_text()
        literal = re.findall(r'preload\("res://(assets/audio/bellstrider_01/[^\"]+\.wav)"\)',consumer)
        self.assertEqual(len(literal),17)
        self.assertEqual({Path(p).stem for p in literal},expected_ids)
        self.assertEqual(set(record['runtime_paths']),set(literal))
        manifest = json.loads((ROOT/record['source_path']).read_bytes())
        self.assertEqual({r['path'] for r in manifest['assets']},set(literal))
        for row in manifest['assets']:
            self.assertEqual(hashlib.sha256((ROOT/row['path']).read_bytes()).hexdigest(),row['sha256'])
            with wave.open(str(ROOT/row['path']),'rb') as wav:
                self.assertEqual((wav.getnchannels(),wav.getsampwidth(),wav.getframerate(),wav.getnframes()),(1,2,48000,row['frames']))
        paths = [record['source_path'],*record['runtime_paths'],*(r['path'] for r in record['associated_files'])]
        for relative in set(paths):
            target = self.root/relative;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ROOT/relative,target)
        self.assertEqual(validate_asset(record,self.root),[])
        corrupted = self.root/literal[0];raw = corrupted.read_bytes();corrupted.write_bytes(raw+b'\x00\x00')
        self.assertIn('Associated file hash mismatch',validate_asset(record,self.root))
        corrupted.write_bytes(raw)

    def test_bellstrider_binding_migration_preserves57_original_methods_hashes_and_input_prefixes(self):
        import ast
        import re
        modified = {
            'test_region_bible.py':{'test_actual_player_body_closure_is_required_and_superseded_binding_refused','test_actual_player_body_closure_is_required_and_superseded_binding_refused_audio_history','test_merged22_keeps83_roles_and_both_parent21_histories_and_rejects_stale'},
            'test_region_creative_direction.py':{'test_selected_direction_binds_every_specialist_and_retains_stage_gates','test_merged25_preserves_both_parent24_directions_and_authority_union'}}
        for filename,allowed in modified.items():
            original = (ROOT/BELLSTRIDER_ARCHIVE/(filename+'.txt')).read_text();live = (ROOT/MERGED_BOSSES_ARCHIVE/'bellstrider'/'tests'/filename).read_text()
            def methods(text):return {n.name:ast.get_source_segment(text,n) for n in ast.walk(ast.parse(text)) if isinstance(n,ast.FunctionDef) and n.name.startswith('test_')}
            before,after = methods(original),methods(live)
            self.assertEqual(len(before),40 if filename=='test_region_bible.py' else 17)
            self.assertTrue(before.keys()<=after.keys())
            self.assertEqual({name for name in before if before[name]!=after[name]},allowed)
            self.assertTrue(set(re.findall(r'[a-f0-9]{64}',original))<=set(re.findall(r'[a-f0-9]{64}',live)))
        frozen = json.loads((ROOT/BELLSTRIDER_ARCHIVE/'harness-region-checks.json').read_bytes())['checks']
        live = json.loads((ROOT/MERGED_BOSSES_ARCHIVE/'bellstrider'/'tools/harness/profiles.json').read_bytes())['checks']
        for name,prior in frozen.items():
            for field in ('argv','timeout_seconds','success_pattern'):self.assertEqual(live[name][field],prior[field])
            if 'inputs' in prior:self.assertEqual(live[name]['inputs'][:len(prior['inputs'])],prior['inputs'])
            else:self.assertNotIn('inputs',live[name])
        self.assertEqual((len(frozen['region-bible-tests']['inputs']),len(frozen['region-bible-contract']['inputs'])),(422,24))

    def test_windkeeper24_keeps83_prefix_and_binds_actual_pressure_consumers(self):
        current = json.loads((ROOT/WINDKEEPER24_STYLE).read_bytes())
        self.assertEqual(current['version'],'24')
        before_raw = (ROOT/(WINDKEEPER24_ARCHIVE+'style22.json')).read_bytes()
        self.assertEqual(hashlib.sha256(before_raw).hexdigest(),WINDKEEPER22_STYLE_SHA)
        before = json.loads(before_raw)
        old_refs = before['runtime_reference']['references']
        actual = current['runtime_reference']['references']
        self.assertEqual(len(old_refs),83)
        self.assertGreater(len(actual),83)
        self.assertEqual([(r['role'],r['path']) for r in actual[:83]],
                         [(r['role'],r['path']) for r in old_refs])
        changed = []
        for old,new in zip(old_refs,actual[:83]):
            self.assertEqual({k:v for k,v in old.items() if k!='sha256'},
                             {k:v for k,v in new.items() if k!='sha256'})
            self.assertEqual(old['sha256'],hashlib.sha256(windkeeper22_source(old['path'])).hexdigest())
            self.assertEqual(new['sha256'],hashlib.sha256(boss_parent_source('windkeeper',new['path'])).hexdigest())
            if old != new:
                changed.append(dict(role=new['role'],path=new['path'],old_sha256=old['sha256'],new_sha256=new['sha256']))
        self.assertEqual({row['path'] for row in changed},{'scripts/demo/demo_app.gd'})
        self.assertEqual(sum(old==new for old,new in zip(old_refs,actual[:83])),82)
        self.assertEqual(current['revision_impact']['changed_references'],changed)
        self.assertEqual(current['revision_impact']['added_references'],actual[83:])
        self.assertEqual(current['supersedes'],json.loads((ROOT/(WINDKEEPER24_ARCHIVE+'registry.json')).read_bytes())['shared_style_authority'])
        self.assertEqual(current['revision_impact']['task_id'],'WINDKEEPER-PRESSURE-01')
        for key in before.keys()-{'version','runtime_reference','supersedes','revision_impact'}:
            self.assertEqual(current[key],before[key])
        expected = [
            ('windkeeper_pressure_factory','scripts/bosses/boss_factory.gd'),
            ('windkeeper_pressure_scene','scenes/bosses/windkeeper_pressure.tscn'),
            ('windkeeper_pressure_definition','scripts/bosses/windkeeper_pressure_definition.gd'),
            ('windkeeper_pressure_config','resources/bosses/windkeeper_storm.tres'),
            ('windkeeper_pressure_health','resources/bosses/windkeeper_pressure_health.tres'),
            ('windkeeper_pressure_pose_owner','scripts/bosses/windkeeper_pressure_encounter.gd'),
            ('windkeeper_pressure_rig','scripts/bosses/windkeeper_pressure_rig.gd'),
            ('windkeeper_pressure_presentation','scripts/bosses/windkeeper_pressure_presentation.gd'),
            ('windkeeper_pressure_projectile','scripts/bosses/windkeeper_pressure_projectile.gd'),
            ('windkeeper_pressure_strike','scripts/bosses/windkeeper_pressure_strike.gd'),
            ('windkeeper_pressure_audio','scripts/audio/windkeeper_pressure_audio.gd'),
            ('windkeeper_pressure_rewards','scripts/rewards/windkeeper_pressure_rewards.gd'),
            ('windkeeper_pressure_hud','scripts/ui/windkeeper_hud.gd'),
            ('windkeeper_pressure_contact','scripts/damage/demo_contact_emitter.gd'),
            ('windkeeper_pressure_style_installer','scripts/art_foundation/pixel_formal_style_installer.gd'),
            ('windkeeper_pressure_actor_installer','scripts/underworld_plains/underworld_actor_installer.gd'),
            ('windkeeper_pressure_lab','scripts/demo/module_lab.gd'),
            ('windkeeper_pressure_manifest','scripts/run/run_manifest.gd'),
            ('windkeeper_pressure_stage_visual','scripts/art/plains_stage_visual.gd'),
            ('windkeeper_pressure_wind','scripts/bosses/windkeeper_pressure_wind.gd'),
            ('windkeeper_pressure_foreground_shader','shaders/windkeeper_pressure_foreground.gdshader'),
        ]
        self.assertEqual([(r['role'],r['path']) for r in actual[83:104]],expected)
        audio_manifest = json.loads((ROOT/'assets/audio/windkeeper_pressure_01/manifest.json').read_bytes())
        audio_paths = {row['path'].removeprefix('res://') for row in audio_manifest['cues'].values()}
        self.assertEqual(len(audio_paths),32)
        audio_source = (ROOT/'scripts/audio/windkeeper_pressure_audio.gd').read_text()
        for path in audio_paths:
            self.assertIn('preload("res://'+path+'")',audio_source)
        audio_paths |= {'assets/audio/windkeeper_pressure_01/'+name for name in ('CC0-1.0.txt','README.md','manifest.json','sources.json')}
        self.assertEqual([r['path'] for r in actual[104:]],sorted(audio_paths))
        self.assertEqual(len(actual),140)
        for row in actual[83:]:
            self.assertEqual(row['sha256'],hashlib.sha256(boss_parent_source('windkeeper',row['path'])).hexdigest())
        scene = (ROOT/'scenes/bosses/windkeeper_pressure.tscn').read_text()
        for path in ['scripts/bosses/windkeeper_pressure_encounter.gd',
                     'scripts/bosses/windkeeper_pressure_presentation.gd',
                     'scripts/audio/windkeeper_pressure_audio.gd']:
            self.assertIn('res://'+path,scene)
        self.assertIn('res://scripts/bosses/windkeeper_pressure_definition.gd',
                      (ROOT/'resources/bosses/windkeeper_storm.tres').read_text())
        self.assertIn('res://resources/bosses/windkeeper_pressure_health.tres',
                      (ROOT/'resources/bosses/windkeeper_storm.tres').read_text())
        self.assertIn('max_health = 60.0',(ROOT/'resources/bosses/windkeeper_pressure_health.tres').read_text())
        self.assertIn('res://scripts/bosses/windkeeper_pressure_wind.gd',scene)
        wind_source = (ROOT/'scripts/bosses/windkeeper_pressure_wind.gd').read_text()
        self.assertIn('res://shaders/windkeeper_pressure_foreground.gdshader',wind_source)
        live_inputs = json.loads((ROOT/'tools/harness/profiles.json').read_bytes())['checks']['region-bible-tests']['inputs']
        self.assertLessEqual({r['path'] for r in actual},set(live_inputs))


    def test_windkeeper24_rejects_prior22_and_new_consumer_drift(self):
        prior_registry = json.loads((ROOT/(WINDKEEPER24_ARCHIVE+'registry.json')).read_bytes())
        stale = copy.deepcopy(self.ref)
        stale.update(supplemental_authority_path=prior_registry['shared_style_authority']['path'],
                     supplemental_authority_sha256=prior_registry['shared_style_authority']['sha256'])
        with self.assertRaisesRegex(ValueError,'binding changed'):
            creative.validate_bible_binding(stale,root=self.root)
        # Every new actual source/asset is independently protected, not just
        # the old App leaf. Mutate temp copies; never the production checkout.
        current = creative.supplemental_authority(self.bible,'thorn_forest',self.root)['content']
        for row in current['runtime_reference']['references'][83:]:
            path = self.root/row['path'];original = path.read_bytes()
            path.write_bytes(original+b'\npressure source drift\n')
            with self.subTest(path=row['path']):
                with self.assertRaisesRegex(ValueError,'Shared Plains style reference SHA changed'):
                    creative.bind_region_bible('thorn_forest',self.root)
            path.write_bytes(original)
        self.assertEqual(creative.bind_region_bible('thorn_forest',self.root)[1],self.ref)


    def test_windkeeper24_archive_and_original_harness_guards_remain(self):
        base = ROOT/WINDKEEPER24_ARCHIVE
        manifest = json.loads((base/'manifest.json').read_bytes())
        self.assertEqual(manifest['baseline_commit'],'840108da9ae91e412dc9f1d8a38ccdad0229bb11')
        for row in manifest['files']:
            content = (base/row['path']).read_bytes()
            self.assertEqual((len(content),hashlib.sha256(content).hexdigest()),(row['bytes'],row['sha256']))
        archived = json.loads((base/'harness-profiles.json').read_bytes())
        live = json.loads((ROOT/MERGED_BOSSES_ARCHIVE/'windkeeper'/'tools/harness/profiles.json').read_bytes())
        self.assertEqual(len(archived['profiles']['full']),168)
        self.assertEqual(live['profiles']['full'][:168],archived['profiles']['full'])
        self.assertEqual(live['profiles']['full'][168:],['windkeeper-pressure-01'])
        original_inputs = json.loads((base/'region-bible-inputs.json').read_bytes())
        self.assertEqual(len(original_inputs),422)
        self.assertEqual(live['checks']['region-bible-tests']['inputs'][:422],original_inputs)
        for name, budget in [('region-bible-tests',30),('region-bible-contract',30),
                             ('creative-direction',30),('creative-direction-tests',60)]:
            self.assertEqual(live['checks'][name]['timeout_seconds'],budget)
            self.assertEqual({k:v for k,v in live['checks'][name].items() if k!='inputs'},
                             {k:v for k,v in archived['checks'][name].items() if k!='inputs'})
        original22 = json.loads((base/'style22.json').read_bytes())
        self.assertEqual(hashlib.sha256((ROOT/'docs/creative_direction/bibles/style-continuity-20261030-v22-merged-motion-audio.json').read_bytes()).hexdigest(),WINDKEEPER22_STYLE_SHA)
        self.assertEqual(len(original22['runtime_reference']['references']),83)
        # All preexisting named scenarios remain, even when their current
        # identity checks or historical source selectors are migrated.
        import ast
        for filename in ('test_region_bible.py','test_region_creative_direction.py'):
            before = ast.parse((base/(filename+'.txt')).read_text())
            after = ast.parse((ROOT/'tests'/filename).read_text())
            methods = lambda tree: {n.name for n in ast.walk(tree) if isinstance(n,ast.FunctionDef) and n.name.startswith('test_')}
            self.assertLessEqual(methods(before),methods(after))


    def test_merged25_preserves_both_frozen_parents_and_real153_union(self):
        import ast
        current = creative.supplemental_authority(self.bible,'thorn_forest',self.root)['content']
        self.assertEqual(current['version'],'25')
        self.assertEqual(current['revision_impact']['task_id'],'MAIN-INTEGRATION-122-124-125')
        parents = {}
        expected_changes = []
        for parent, digest in BOSS_PARENT_MANIFESTS.items():
            base = ROOT/MERGED_BOSSES_ARCHIVE/parent
            raw = (base/'manifest.json').read_bytes()
            self.assertEqual(hashlib.sha256(raw).hexdigest(),digest)
            manifest = json.loads(raw)
            for row in manifest['files']:
                content = (base/row['path']).read_bytes()
                self.assertEqual((len(content),hashlib.sha256(content).hexdigest()),(row['bytes'],row['sha256']))
            registry = boss_parent_registry(parent)
            ref = registry['shared_style_authority']
            parents[parent] = json.loads((base/ref['path']).read_bytes())
            self.assertEqual((base/ref['path']).read_bytes(),(ROOT/ref['path']).read_bytes())
            self.assertEqual(hashlib.sha256((ROOT/ref['path']).read_bytes()).hexdigest(),ref['sha256'])
            self.assertIn(ref,current['supersedes'])
            for filename in ('test_region_bible.py','test_region_creative_direction.py'):
                before = ast.parse((base/'tests'/filename).read_text())
                after = ast.parse((ROOT/'tests'/filename).read_text())
                names = lambda tree:{n.name for n in ast.walk(tree) if isinstance(n,ast.FunctionDef) and n.name.startswith('test_')}
                self.assertLessEqual(names(before),names(after))
            prior = json.loads((base/'docs/creative_direction/thorn_forest.json').read_bytes())
            with self.assertRaisesRegex(ValueError,'binding changed'):
                creative.validate_bible_binding(prior['region_bible'],root=self.root)
        refs = current['runtime_reference']['references']
        left,right = [parents[p]['runtime_reference']['references'] for p in ('bellstrider','windkeeper')]
        self.assertEqual((len(left),len(right),len(refs)),(96,140,153))
        expected = [(r['role'],r['path']) for r in left]
        expected.extend((r['role'],r['path']) for r in right if r['role'] not in {x['role'] for x in left})
        self.assertEqual([(r['role'],r['path']) for r in refs],expected)
        self.assertEqual(len({r['path'] for r in refs}),153)
        for row in refs:
            digest=hashlib.sha256((ROOT/row['path']).read_bytes()).hexdigest()
            self.assertEqual(row['sha256'],digest)
            parent_hashes=[dict(parent=p,sha256=r['sha256']) for p,s in parents.items() for r in s['runtime_reference']['references'] if r['role']==row['role']]
            if any(r['sha256']!=digest for r in parent_hashes):
                expected_changes.append(dict(role=row['role'],path=row['path'],parent_hashes=parent_hashes,merged_sha256=digest))
        self.assertEqual(current['revision_impact']['changed_references'],expected_changes)
        self.assertEqual({r['path'] for r in expected_changes},{'scripts/demo/demo_app.gd','scripts/demo/plains_region_stage.gd','scripts/combat/weapon_action_runtime.gd','scripts/ui/windkeeper_hud.gd','scripts/art/plains_stage_visual.gd'})


class Style25ArchiveTests(unittest.TestCase):
    """The bounded old-source archive never substitutes for current validation."""
    def manifest(self):
        raw = (ROOT/history.STYLE25_ARCHIVE/'manifest.json').read_bytes()
        self.assertEqual(hashlib.sha256(raw).hexdigest(), history.STYLE25_MANIFEST_SHA)
        return json.loads(raw)

    def test_exact_finite_source_selection_and_original_documents(self):
        manifest = self.manifest()
        base = ROOT/history.STYLE25_ARCHIVE
        self.assertEqual(manifest['source_commit'], '4bb7aa962cb9477b6fc931b221b3a38132cad1f2')
        style = json.loads((base/MERGED_BOSSES_STYLE).read_bytes())
        held = {'resources/bosses/bellstrider.tres', 'resources/bosses/windkeeper_pressure_health.tres',
                'resources/bosses/windkeeper_storm.tres', 'scenes/bosses/windkeeper_pressure.tscn'}
        expected = {row['path'] for row in style['runtime_reference']['references']
                    if row['path'].startswith(('scripts/', 'scenes/', 'resources/')) and row['path'] not in held}
        self.assertEqual(len(expected), 72)
        expected.add('scripts/underworld_plains/underworld_terrain.gdshader')
        self.assertEqual({row['path'] for row in manifest['sources']}, expected)
        self.assertEqual(len(manifest['sources']), 73)
        self.assertEqual(len(manifest['files']), 80)
        self.assertFalse(manifest['selection']['media_copied'])
        self.assertFalse(manifest['selection']['runtime_uid_copied'])
        for row in manifest['files']:
            raw = (base/row['path']).read_bytes()
            self.assertEqual((len(raw), hashlib.sha256(raw).hexdigest()), (row['bytes'], row['sha256']))
        for row in manifest['sources']:
            self.assertTrue(row['archive_path'].endswith('.txt'))
            self.assertEqual(hashlib.sha256(history.style25_source(ROOT, row['path'])).hexdigest(), row['sha256'])
        for row in style['runtime_reference']['references']:
            self.assertEqual(hashlib.sha256(history.style25_source(ROOT, row['path'])).hexdigest(), row['sha256'])
        for region in ('windchime_plains', 'thorn_forest'):
            direction = json.loads((base/'docs/creative_direction'/(region+'.json')).read_bytes())
            self.assertEqual(direction['version'], 'creative-v28')
            self.assertEqual(direction['user_acceptance'], 'direction_only_not_art_gameplay_or_device')
        self.assertIn('no_inherited', style['runtime_reference']['status'])

    def test_scene_reference_supplement_preserves_original_archive_and_rejects_missing_leaf(self):
        self.manifest()  # The original e7d7 manifest is still byte-for-byte pinned.
        base = ROOT/history.STYLE25_SCENE_ARCHIVE
        raw = (base/'manifest.json').read_bytes()
        self.assertEqual(hashlib.sha256(raw).hexdigest(), history.STYLE25_SCENE_MANIFEST_SHA)
        manifest = json.loads(raw)
        self.assertEqual(manifest['original_archive_manifest_sha256'], history.STYLE25_MANIFEST_SHA)
        self.assertEqual(manifest['source_commit'], '4bb7aa962cb9477b6fc931b221b3a38132cad1f2')
        self.assertEqual(len(manifest['sources']), 3)
        self.assertEqual({r['path'] for r in manifest['sources']}, {'scenes/bosses/windkeeper_pressure.tscn', 'assets/underworld_plains/terrain/fine_32/terrain_build.json', 'assets/underworld_plains/terrain/terrain_build.json'})
        for original_file in manifest['files']:
            original_bytes = (base/original_file['path']).read_bytes()
            self.assertEqual((len(original_bytes), hashlib.sha256(original_bytes).hexdigest()), (original_file['bytes'], original_file['sha256']))
        row = manifest['sources'][0]
        self.assertEqual(row['path'], 'scenes/bosses/windkeeper_pressure.tscn')
        self.assertEqual(row['sha256'], 'd751a5a3eae2faa1c507f93fe565bd04601fe88185951690055d136824e54033')
        self.assertEqual(hashlib.sha256(history.style25_source(ROOT, row['path'])).hexdigest(), row['sha256'])
        root = self.fixture()
        live = root/row['path']
        live.parent.mkdir(parents=True, exist_ok=True)
        live.write_bytes((ROOT/row['path']).read_bytes())
        (root/history.STYLE25_SCENE_ARCHIVE/row['archive_path']).unlink()
        with self.assertRaisesRegex(ValueError, 'Missing/unsafe Bible source'):
            history.style25_source(root, row['path'])

    def test_preserved_original_test_methods_are_unchanged(self):
        import ast
        base = ROOT/history.STYLE25_ARCHIVE
        for name in ('test_region_bible.py', 'test_region_creative_direction.py'):
            methods = lambda tree: {node.name: ast.dump(node, include_attributes=False)
                                   for node in ast.walk(tree)
                                   if isinstance(node, ast.FunctionDef) and node.name.startswith('test_')}
            old = methods(ast.parse((base/'tests'/name).read_text()))
            current = methods(ast.parse((ROOT/'tests'/name).read_text()))
            self.assertTrue(old)
            self.assertLessEqual(old.keys(), current.keys())
            for key, body in old.items():
                self.assertEqual(current[key], body, key)

    def fixture(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        shutil.copytree(ROOT/history.STYLE25_ARCHIVE, root/history.STYLE25_ARCHIVE)
        return root

    def test_missing_frozen_source_rejects_even_when_live_path_exists(self):
        root = self.fixture()
        path = 'scripts/ui/item_card.gd'
        (root/path).parent.mkdir(parents=True, exist_ok=True)
        (root/path).write_bytes(history.style25_source(ROOT, path))
        (root/history.STYLE25_ARCHIVE/('sources/'+path+'.txt')).unlink()
        with self.assertRaisesRegex(ValueError, 'Missing/unsafe Bible source'):
            history.style25_source(root, path)

    def test_corrupt_frozen_source_rejects_even_when_live_path_exists(self):
        root = self.fixture()
        path = 'scripts/ui/item_card.gd'
        (root/path).parent.mkdir(parents=True, exist_ok=True)
        (root/path).write_bytes(history.style25_source(ROOT, path))
        leaf = root/history.STYLE25_ARCHIVE/('sources/'+path+'.txt')
        leaf.write_bytes(leaf.read_bytes()+b'\nsource-drift')
        with self.assertRaisesRegex(AssertionError, 'Frozen combination parent source changed'):
            history.style25_source(root, path)

    def test_rehashing_mutated_archive_manifest_does_not_re_sign_history(self):
        root = self.fixture()
        path = root/history.STYLE25_ARCHIVE/'manifest.json'
        data = json.loads(path.read_bytes())
        data['sources'][0]['sha256'] = '0'*64
        path.write_text(json.dumps(data))
        with self.assertRaisesRegex(AssertionError, 'Frozen source manifest changed'):
            history.style25_source(root, data['sources'][0]['path'])

    def test_existing_boss_parent_override_precedes_shared_style25_snapshot(self):
        path = 'scripts/demo/demo_app.gd'
        prior = boss_parent_source('bellstrider', path)
        self.assertEqual(hashlib.sha256(prior).hexdigest(), 'fee196963d244f6d1fe9ca32ec69cd54bf08ec5c4a62949f41c1a72e94a168bf')
        self.assertNotEqual(prior, history.style25_source(ROOT, path))
        self.assertEqual(boss_parent_source('bellstrider', 'scripts/ui/item_card.gd'),
                         history.style25_source(ROOT, 'scripts/ui/item_card.gd'))
        untouched = 'config/player_tuning.json'
        self.assertEqual(history.style25_source(ROOT, untouched), (ROOT/untouched).read_bytes())

    def test_live_validator_still_rejects_changed_source_despite_available_archive(self):
        root = self.fixture()
        base = root/history.STYLE25_ARCHIVE
        registry = json.loads((base/creative.BIBLE_REGISTRY).read_bytes())
        style = json.loads((base/MERGED_BOSSES_STYLE).read_bytes())
        paths = {'docs/world_regions.json', 'docs/creative_direction/bibles/user-request.json',
                 'docs/creative_direction/bibles/1-windchime_plains_region_bible_v2.md',
                 'docs/creative_direction/bibles/2-thorn_forest_region_bible_v2.md',
                 *[row['path'] for row in style['runtime_reference']['references']]}
        for path in paths:
            target = root/path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(history.style25_source(ROOT, path))
        for path in (creative.BIBLE_REGISTRY, MERGED_BOSSES_STYLE):
            target = root/path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes((base/path).read_bytes())
        original = creative.bind_region_bible('thorn_forest', root)[1]
        self.assertEqual(original['supplemental_authority_sha256'], registry['shared_style_authority']['sha256'])
        live = root/'scripts/demo/demo_app.gd'
        live.write_bytes(live.read_bytes()+b'\ncurrent-source-drift')
        self.assertNotEqual(live.read_bytes(), history.style25_source(root, 'scripts/demo/demo_app.gd'))
        with self.assertRaisesRegex(ValueError, 'Shared Plains style reference SHA changed'):
            creative.bind_region_bible('thorn_forest', root)

if __name__ == '__main__':
    unittest.main()
