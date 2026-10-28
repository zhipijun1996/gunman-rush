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
import level_design
import production_loop as loop
import visual_director


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
        self.assertEqual(style['content']['version'],'16')
        refs = style['content']['runtime_reference']['references']
        self.assertEqual(len(refs),68)
        current_refs = refs
        r09_path = 'docs/evidence/item_art_01/source-bindings/pre-envelope-r10/style-continuity-20261028-v16-item-authoring.json'
        r09_raw = (ROOT/r09_path).read_bytes()
        self.assertEqual(hashlib.sha256(r09_raw).hexdigest(),'bc3c97d31789281fdfa0679cb821243d5f4a1c796398530e0f83a9a59fdfd96a')
        r09 = json.loads(r09_raw)
        self.assertEqual(r09['version'],'16')
        self.assertEqual(len(r09['runtime_reference']['references']),68)
        for before,after in zip(r09['runtime_reference']['references'],current_refs):
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
        for before,after in zip(r08['runtime_reference']['references'],current_refs[:61]):
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
        for before,after in zip(pre_art['runtime_reference']['references'],current_refs[:54]):
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
        self.assertEqual(style['content']['supersedes']['path'],old_v15_path)
        self.assertEqual(style['content']['supersedes']['sha256'],hashlib.sha256(old_v15_raw).hexdigest())
        for key in old_v15.keys()-{'version','runtime_reference','supersedes','revision_impact'}:
            self.assertEqual(style['content'][key],old_v15[key])
        for before,after in zip(old_v15['runtime_reference']['references'],current_refs):
            if before['path'] in changed_current54:
                self.assertEqual({k:v for k,v in before.items() if k!='sha256'},{k:v for k,v in after.items() if k!='sha256'})
                self.assertNotEqual(before['sha256'],after['sha256'])
                historical = subprocess.check_output(['git','show','d9445c0e5d6516d4eb93ebbfbc5639efddf7fc04:'+before['path']],cwd=ROOT)
                self.assertEqual(before['sha256'],hashlib.sha256(historical).hexdigest())
                self.assertEqual(after['sha256'],hashlib.sha256((ROOT/after['path']).read_bytes()).hexdigest())
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
            self.assertEqual(style['content'][key],old_v14[key])
        for before,after in zip(old_v14['runtime_reference']['references'],current_refs[:36]):
            if before['path']=='scripts/demo/demo_app.gd':
                self.assertEqual({k:v for k,v in before.items() if k!='sha256'},{k:v for k,v in after.items() if k!='sha256'})
                self.assertNotEqual(before['sha256'],after['sha256'])
                historical = subprocess.check_output(['git','show','879b39eaa869be70cb799dedd1bb6ffc35e0b92f:'+before['path']],cwd=ROOT)
                self.assertEqual(before['sha256'],hashlib.sha256(historical).hexdigest())
                self.assertEqual(after['sha256'],hashlib.sha256((ROOT/after['path']).read_bytes()).hexdigest())
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
            self.assertEqual(row['sha256'],hashlib.sha256((ROOT/row['path']).read_bytes()).hexdigest())
        old_v12 = json.loads((ROOT/'docs/creative_direction/bibles/style-continuity-20261024-v12-fixed-status.json').read_bytes())
        for key in old_v12.keys()-{'version','runtime_reference','supersedes','revision_impact'}:
            self.assertEqual(style['content'][key], old_v12[key])
        for before, after in zip(old_v12['runtime_reference']['references'], current_refs):
            if before['path']=='scripts/demo/demo_app.gd':
                self.assertEqual({k:v for k,v in before.items() if k!='sha256'}, {k:v for k,v in after.items() if k!='sha256'})
                self.assertNotEqual(before['sha256'], after['sha256'])
                actual = subprocess.check_output(['git','show','4fc1e7a55c191dbe56cd7bc385539fc42b8f7898:'+before['path']], cwd=ROOT)
                self.assertEqual(before['sha256'], hashlib.sha256(actual).hexdigest())
                self.assertEqual(after['sha256'], hashlib.sha256((ROOT/after['path']).read_bytes()).hexdigest())
            else:
                self.assertEqual(before, after)
        old_v11 = json.loads((ROOT/'docs/creative_direction/bibles/style-continuity-20261024-v11-playtest-feedback.json').read_bytes())
        for key in old_v11.keys()-{'version','runtime_reference','supersedes','revision_impact'}:
            self.assertEqual(style['content'][key], old_v11[key])
        for before, after in zip(old_v11['runtime_reference']['references'], current_refs):
            if before['path']=='scripts/demo/demo_app.gd':
                self.assertEqual({k:v for k,v in before.items() if k!='sha256'}, {k:v for k,v in after.items() if k!='sha256'})
                self.assertNotEqual(before['sha256'], after['sha256'])
                self.assertEqual(after['sha256'], hashlib.sha256((ROOT/after['path']).read_bytes()).hexdigest())
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
                self.assertEqual(after['sha256'], hashlib.sha256((ROOT/after['path']).read_bytes()).hexdigest())
            else:
                self.assertEqual(before, after)
        for key in old_v9.keys()-{'version','runtime_reference','supersedes','revision_impact'}:
            self.assertEqual(old_v10[key], old_v9[key])
        self.assertEqual({k:v for k,v in style['content']['runtime_reference'].items() if k!='references'}, {k:v for k,v in old_v9['runtime_reference'].items() if k!='references'})
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
        self.assertEqual({k:v for k,v in style['content']['runtime_reference'].items() if k!='references'}, {k:v for k,v in old_v7['runtime_reference'].items() if k!='references'})
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
        for old_style in ['style-continuity-20261022-v4.json','style-continuity-20261022-v5.json','style-continuity-20261023-v6.json','style-continuity-20261023-v7.json','style-continuity-20261023-v9-hud-layout.json','style-continuity-20261023-v10-foreground-cpu.json','style-continuity-20261024-v11-playtest-feedback.json','style-continuity-20261024-v12-fixed-status.json','style-continuity-20261024-v13-responsive-navigation.json','style-continuity-20261026-v14-run-gear.json','style-continuity-20261027-v15-item-v5.json']:
            old_path = 'docs/creative_direction/bibles/'+old_style
            stale = copy.deepcopy(self.ref)
            stale['supplemental_authority_path'] = old_path
            stale['supplemental_authority_sha256'] = hashlib.sha256((ROOT/old_path).read_bytes()).hexdigest()
            with self.subTest(superseded=old_style),self.assertRaisesRegex(ValueError, 'binding changed'):
                creative.validate_bible_binding(stale,root=self.root)
        refs = current_refs
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


if __name__ == '__main__':
    unittest.main()
