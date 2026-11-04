"""Current Bible source, media, region isolation and lease counterexamples."""
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


MERGED_BOSSES_STYLE = 'docs/creative_direction/bibles/style-continuity-20261031-v25-merged-bosses.json'

FEATURE_LAYOUT_STYLE = 'docs/creative_direction/bibles/style-continuity-20261031-v26-feature-layout.json'


def frozen33_root(testcase):
    return _frozen_style_root(testcase, history.STYLE33_ARCHIVE, history.style33_source)


def _frozen_style_root(testcase, archive, source_reader):
    """Replay the exact selected authority through its finite source reader."""
    folder = tempfile.TemporaryDirectory()
    testcase.addCleanup(folder.cleanup)
    root = Path(folder.name)
    base = ROOT/archive
    registry = json.loads((base/creative.BIBLE_REGISTRY).read_bytes())
    style_path = registry['shared_style_authority']['path']
    style = json.loads((ROOT/style_path).read_bytes())
    frozen_documents = {creative.BIBLE_REGISTRY,
                        'docs/creative_direction/windchime_plains.json',
                        'docs/creative_direction/thorn_forest.json'}
    paths = {'docs/world_regions.json', style_path, *frozen_documents,
             *[row['path'] for row in style['runtime_reference']['references']]}
    for row in registry['regions']:
        bible = row['current_bible']
        if bible:
            paths.update((bible['path'], bible['selection_evidence']['path']))
    for region in ('windchime_plains', 'thorn_forest'):
        direction = json.loads((base/('docs/creative_direction/'+region+'.json')).read_bytes())
        paths.update(ref['path'] for ref in direction['authority_sources'])
    for path in paths:
        raw = (base/path).read_bytes() if path in frozen_documents else source_reader(ROOT, path)
        target = root/path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(raw)
    return root


def layout_path(path):
    """Only migrate live test consumers listed by the current finite authority."""
    current = json.loads((ROOT/FEATURE_LAYOUT_STYLE).read_bytes())
    return next((row['path'] for row in current['revision_impact']['changed_references']
                 if row['previous_path'] == path), path)


WINDKEEPER24_ARCHIVE = 'docs/creative_direction/archive/windkeeper-pressure-before-style24/'


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


# Finite reviewed current-test migrations; old AST identities always remain pinned.
# Each full current method is fixed too: unreachable assertions or changed loops fail.
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
        self.assertTrue(any(row['path']=='game/presentation/world/underworld_plains/underworld_terrain.gd' for row in refs))
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
        self.assertIn('game/presentation/world/underworld_plains/underworld_terrain.gd',prompt)
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
            path=self.root/layout_path(name);raw=path.read_bytes();path.write_bytes(raw+b'changed')
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


    def test_body_payload_drift_blocks_production_and_proposed_before_after_and_resume(self):
        # Regresses style-body-closure-probe/report-first: changing real body
        # payloads alone leaves the UnderworldPlayer script byte-identical.
        script = self.root/layout_path('scripts/underworld_plains/underworld_player.gd')
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
        consumer = (ROOT/layout_path('scripts/audio/bellstrider_audio.gd')).read_text()
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
            target = self.root/relative;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(history.style25_source(ROOT,relative))
        self.assertEqual(validate_asset(record,self.root),[])
        corrupted = self.root/literal[0];raw = corrupted.read_bytes();corrupted.write_bytes(raw+b'\x00\x00')
        self.assertIn('Associated file hash mismatch',validate_asset(record,self.root))
        corrupted.write_bytes(raw)


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
            path = self.root/layout_path(row['path']);original = path.read_bytes()
            path.write_bytes(original+b'\npressure source drift\n')
            with self.subTest(path=row['path']):
                with self.assertRaisesRegex(ValueError,'Shared Plains style reference SHA changed'):
                    creative.bind_region_bible('thorn_forest',self.root)
            path.write_bytes(original)
        self.assertEqual(creative.bind_region_bible('thorn_forest',self.root)[1],self.ref)


class Style25ArchiveTests(unittest.TestCase):
    """The bounded old-source archive never substitutes for current validation."""
    def manifest(self):
        raw = (ROOT/history.STYLE25_ARCHIVE/'manifest.json').read_bytes()
        self.assertEqual(hashlib.sha256(raw).hexdigest(), history.STYLE25_MANIFEST_SHA)
        return json.loads(raw)


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


class FeatureLayoutBindingTests(unittest.TestCase):
    """Current206-source authority is validated separately from frozen25 replay."""
    setUp = BibleTests.setUp


    def test_new_delegates_drift_and_missing_current_source_cannot_fall_back_to_archive(self):
        shutil.copytree(ROOT/history.STYLE25_ARCHIVE,self.root/history.STYLE25_ARCHIVE)
        for name in ('game/application/run_session.gd','game/world/levels/level_runtime.gd',
                     'game/loadout/effects/item_active_cast.gd','game/loadout/effects/item_time_context.gd',
                     'game/bosses/encounter/boss_encounter.gd','game/bosses/thorn_forest/thorn_forest_encounter.gd',
                     'game/bosses/windkeeper/windkeeper_encounter.gd'):
            path=self.root/name;raw=path.read_bytes()
            path.write_bytes(raw+b'\n# current consumer drift\n')
            with self.subTest(path=name),self.assertRaisesRegex(ValueError,'Shared Plains style reference SHA changed'):
                creative.bind_region_bible('thorn_forest',self.root)
            path.unlink()
            with self.subTest(missing=name),self.assertRaisesRegex(ValueError,'Missing/unsafe Bible source'):
                creative.bind_region_bible('thorn_forest',self.root)
            path.write_bytes(raw)
        self.assertEqual(creative.bind_region_bible('thorn_forest',self.root)[1],self.ref)

    def test_current_player_identity_rejects_former_path_even_after_refreshing_hashes(self):
        registry_path=self.root/creative.BIBLE_REGISTRY
        registry=json.loads(registry_path.read_bytes());style_path=self.root/registry['shared_style_authority']['path']
        style=json.loads(style_path.read_bytes());player=next(row for row in style['runtime_reference']['references'] if row['role']=='player_style_reference')
        old_path='scripts/underworld_plains/underworld_player.gd';target=self.root/old_path
        target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes((self.root/player['path']).read_bytes())
        player['path']=old_path;style_path.write_text(json.dumps(style));registry['shared_style_authority']['sha256']=hashlib.sha256(style_path.read_bytes()).hexdigest();registry_path.write_text(json.dumps(registry))
        with self.assertRaisesRegex(ValueError,'Actual UnderworldPlayer body dependencies'):
            creative.bind_region_bible('thorn_forest',self.root)


class OwnershipBindingTests(unittest.TestCase):


    def test_indexed26_leaf_never_falls_back_and_live27_never_uses_archive(self):
        folder = tempfile.TemporaryDirectory()
        self.addCleanup(folder.cleanup)
        root = Path(folder.name)
        shutil.copytree(ROOT/history.STYLE26_ARCHIVE,root/history.STYLE26_ARCHIVE)
        rows = json.loads((root/history.STYLE26_ARCHIVE/'manifest.json').read_bytes())['sources']
        for row in rows:
            live = root/row['path']; live.parent.mkdir(parents=True,exist_ok=True)
            live.write_bytes((ROOT/row['path']).read_bytes())
            leaf = root/history.STYLE26_ARCHIVE/row['archive_path']; raw = leaf.read_bytes()
            leaf.unlink()
            with self.subTest(missing=row['path']), self.assertRaisesRegex(ValueError,'Missing/unsafe Bible source'):
                history.style26_source(root,row['path'])
            leaf.write_bytes(raw+b'\nsource drift')
            with self.subTest(corrupt=row['path']), self.assertRaisesRegex(AssertionError,'Frozen combination parent source changed'):
                history.style26_source(root,row['path'])
            leaf.write_bytes(raw)
        manifest_path = root/history.STYLE26_ARCHIVE/'manifest.json'; original = manifest_path.read_bytes()
        manifest = json.loads(original);manifest['sources'][0]['sha256']='0'*64;manifest_path.write_text(json.dumps(manifest))
        with self.assertRaisesRegex(AssertionError,'Frozen source manifest changed'):
            history.style26_source(root,rows[0]['path'])
        manifest_path.write_bytes(original)
        BibleTests.setUp(self)  # Real current27 fixture, not the frozen26 fixture.
        shutil.copytree(ROOT/history.STYLE26_ARCHIVE,self.root/history.STYLE26_ARCHIVE)
        for row in rows:
            live=self.root/row['path'];raw=live.read_bytes();live.write_bytes(history.style26_source(ROOT,row['path']))
            with self.subTest(old_live=row['path']), self.assertRaisesRegex(ValueError,'Shared Plains style reference SHA changed'):
                creative.bind_region_bible('thorn_forest',self.root)
            live.unlink()
            with self.subTest(missing_live=row['path']), self.assertRaisesRegex(ValueError,'Missing/unsafe Bible source'):
                creative.bind_region_bible('thorn_forest',self.root)
            live.write_bytes(raw)
        self.assertEqual(creative.bind_region_bible('thorn_forest',self.root)[1],self.ref)


CANVAS_PREPARATION_STYLE = 'docs/creative_direction/bibles/style-continuity-20261102-v33-canvas-preparation.json'

class RuntimeOwnershipBindingTests(unittest.TestCase):
    setUp = BibleTests.setUp


    def test_current34_exact206_sources_roles_media_and_five_technical_changes(self):
        previous = json.loads((ROOT/CANVAS_PREPARATION_STYLE).read_bytes())
        current = creative.supplemental_authority(self.bible, 'thorn_forest', self.root)['content']
        before, after = previous['runtime_reference']['references'], current['runtime_reference']['references']
        self.assertEqual(current['version'], '34')
        self.assertEqual(len(after), 206)
        self.assertEqual([(r['role'], r['path']) for r in after], [(r['role'], r['path']) for r in before])
        changes = []
        for old, new in zip(before, after):
            self.assertEqual(hashlib.sha256((self.root/new['path']).read_bytes()).hexdigest(), new['sha256'])
            self.assertEqual(hashlib.sha256(history.style33_source(ROOT, old['path'])).hexdigest(), old['sha256'])
            if old != new:
                self.assertEqual(Path(new['path']).suffix, '.gd')
                changes.append(dict(role=new['role'], path=new['path'], previous_sha256=old['sha256'], sha256=new['sha256']))
        self.assertEqual(len(changes), 5)
        self.assertEqual(current['revision_impact']['changed_references'], changes)
        self.assertEqual(current['revision_impact']['added_references'], [])
        self.assertEqual(current['supersedes'], {'path': CANVAS_PREPARATION_STYLE, 'sha256': hashlib.sha256((ROOT/CANVAS_PREPARATION_STYLE).read_bytes()).hexdigest()})
        self.assertEqual(current['revision_impact']['source_commit'], '5d3303b78d4db374300d4a0266bde8eb1a6de5b2')
        self.assertEqual({r['path']:r['sha256'] for r in current['revision_impact']['candidate_source']}, {r['path']:r['sha256'] for r in changes})
        self.assertIn('candidate not present in baseline Git', current['revision_impact']['source_identity'])
        self.assertIn('no_inherited', current['runtime_reference']['status'])


    def test_current34_rejects_old_missing_corrupt_sources_and_manifest_resigning(self):
        shutil.copytree(ROOT/history.STYLE33_ARCHIVE, self.root/history.STYLE33_ARCHIVE)
        style = creative.supplemental_authority(self.bible, 'thorn_forest', self.root)['content']
        manifest_path = self.root/history.STYLE33_ARCHIVE/'manifest.json'
        manifest_raw = manifest_path.read_bytes()
        manifest = json.loads(manifest_raw)
        self.assertEqual(len(manifest['sources']), 5)
        for row in style['revision_impact']['changed_references']:
            path = self.root/row['path']; raw = path.read_bytes()
            old = history.style33_source(ROOT, row['path'])
            for bad in (old, raw+b'\n# current source drift\n'):
                path.write_bytes(bad)
                with self.subTest(path=row['path']), self.assertRaisesRegex(ValueError, 'Shared Plains style reference SHA changed'):
                    creative.bind_region_bible('thorn_forest', self.root)
            path.unlink()
            with self.subTest(missing=row['path']), self.assertRaisesRegex(ValueError, 'Missing/unsafe Bible source'):
                creative.bind_region_bible('thorn_forest', self.root)
            path.write_bytes(raw)
            archived = next(r for r in manifest['sources'] if r['path']==row['path'])
            leaf = self.root/history.STYLE33_ARCHIVE/archived['archive_path']; saved = leaf.read_bytes()
            leaf.unlink()
            with self.assertRaisesRegex(ValueError, 'Missing/unsafe Bible source'):
                history.style33_source(self.root, row['path'])
            leaf.write_bytes(saved+b'changed')
            with self.assertRaisesRegex(AssertionError, 'Frozen combination parent source changed'):
                history.style33_source(self.root, row['path'])
            leaf.write_bytes(saved)
        manifest['sources'][0]['sha256']='0'*64
        manifest_path.write_text(json.dumps(manifest))
        with self.assertRaisesRegex(AssertionError, 'Frozen source manifest changed'):
            history.style33_source(self.root, manifest['sources'][0]['path'])
        manifest_path.write_bytes(manifest_raw)
        stale = creative.bind_region_bible('thorn_forest', frozen33_root(self))[1]
        with self.assertRaisesRegex(ValueError, 'binding changed'):
            creative.validate_bible_binding(stale, root=self.root)
        self.assertEqual(creative.bind_region_bible('thorn_forest', self.root)[1], self.ref)


if __name__ == '__main__':
    unittest.main()
