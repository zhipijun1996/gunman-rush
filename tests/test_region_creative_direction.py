"""Selected direction binding and short-prompt production boundaries, not artistic scoring."""
import copy
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
import region_creative_direction as creative
import level_design
import production_loop


def candidate_direction():
    data = json.loads((creative.ROOT / 'docs/data/creative_direction/thorn_forest.json').read_text())
    data.update(selection_basis='test_candidates', acceptance='professional_recommendation', direction_id='a')
    fields = ('experience', 'space', 'ecology_boss', 'art_emotion', 'originality', 'feasibility', 'player_appeal', 'risk')
    data['candidates'] = [dict(id=key, **{field: 'SIMULATED ' + key + ' ' + field for field in fields}) for key in ('a', 'b')]
    return data


class CreativeTests(unittest.TestCase):
    def setUp(self):
        self.path = 'docs/data/creative_direction/thorn_forest.json'
        self.data = json.loads((creative.ROOT / self.path).read_text())

    def test_actual_recommendations_are_valid_but_never_player_or_runtime_acceptance(self):
        for path in ('windchime_plains', 'thorn_forest'):
            data, ref = creative.load_direction('docs/data/creative_direction/' + path + '.json', path)
            self.assertIn(data['acceptance'], {'professional_recommendation', 'user_confirmed'})
            if data['acceptance'] == 'professional_recommendation':
                self.assertEqual(data['user_acceptance'], 'unverified')
            else:
                self.assertEqual(data['user_acceptance'], 'direction_only_not_art_gameplay_or_device')
                self.assertIn('scope', data['user_evidence'])
            self.assertEqual(ref['sha256'], hashlib.sha256((creative.ROOT/ref['path']).read_bytes()).hexdigest())


    def test_current_authorities_are_canonical_and_old_bindings_are_refused(self):
        registry = creative.load_bible_registry()
        for region in ('windchime_plains', 'thorn_forest'):
            path = 'docs/data/creative_direction/' + region + '.json'
            data, binding = creative.load_direction(path, region)
            self.assertEqual(data['version'], 'creative-v39-mv')
            self.assertEqual(data['region_bible'], creative.bind_region_bible(region)[1])
            self.assertEqual(data['user_acceptance'], 'direction_only_not_art_gameplay_or_device')
            sources = {row['path'] for row in data['authority_sources']}
            self.assertIn('docs/bible/regions/' + region + '.md', sources)
            self.assertIn(registry['shared_style_authority']['path'], sources)
            self.assertFalse(any('/style-continuity-' in source and not source.startswith('docs/data/')
                                 for source in sources))
            stale = dict(data['region_bible'], sha256='0'*64)
            with self.assertRaisesRegex(ValueError, 'binding changed'):
                creative.validate_bible_binding(stale)

    def test_missing_theme_or_whole_screen_coverage_is_refused(self):
        for key in creative.COVERAGE:
            bad = copy.deepcopy(self.data); del bad[key]
            self.assertTrue(creative.validate_direction(bad), key)

    def test_candidate_comparison_cannot_be_empty_or_single_color_variant(self):
        self.data = candidate_direction()
        for mutate in ('single', 'duplicate', 'missing_comparison', 'unselected'):
            bad = copy.deepcopy(self.data)
            if mutate == 'single': bad['candidates'] = bad['candidates'][:1]
            if mutate == 'duplicate': bad['candidates'][1]['id'] = bad['candidates'][0]['id']
            if mutate == 'missing_comparison': del bad['candidates'][1]['ecology_boss']
            if mutate == 'unselected': bad['direction_id'] = 'uncompared'
            self.assertTrue(creative.validate_direction(bad), mutate)
        # Structural completeness does not prove real creative differences: independent review still required.

    def test_authority_changes_and_region_mismatch_fail_closed(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); (root/'authority.txt').write_text('old')
            data = candidate_direction()
            data['authority_sources'] = [{'path':'authority.txt','sha256':hashlib.sha256(b'old').hexdigest()}]
            (root/'direction.json').write_text(json.dumps(data))
            creative.load_direction('direction.json', 'thorn_forest', root)
            with self.assertRaisesRegex(ValueError, 'another region'):
                creative.load_direction('direction.json', 'windchime_plains', root)
            (root/'authority.txt').write_text('new')
            with self.assertRaisesRegex(ValueError, 'Authority changed'):
                creative.load_direction('direction.json', 'thorn_forest', root)

    def test_short_prompt_does_not_restart_retired_production(self):
        for request in ('制作荆棘森林', '制作萤雾沼泽'):
            with self.assertRaisesRegex(ValueError, 'retired'):
                level_design.route_request(request)

    def test_explicit_region_task_uses_current_binding_without_imposed_visual_gate(self):
        from mission_fixtures import selected_mission
        mission = selected_mission()
        production_loop.validate(mission)
        task = mission['tasks'][0]
        self.assertEqual(task['region_bible'], creative.bind_region_bible('thorn_forest')[1])
        self.assertFalse(production_loop.needs_independent_review(task))
        self.assertNotIn('G2', task.get('required_gates', []))

    def test_retired_route_cannot_be_revived_by_prototype_flag(self):
        for phase in ('auto', 'preproduction', 'production', 'prototype'):
            with self.assertRaisesRegex(ValueError, 'retired'):
                level_design.route_request('制作荆棘森林', phase=phase, direction=self.path)

    def test_shared_source_inventory_keeps_original_extra_dependencies_and_detects_changes(self):
        import level_formal
        extras = ['tools/run_plains_experience_golden_tests.py',
                  'tools/run_plains_redesign_spatial_tests.py', 'tools/harness/profiles.json']
        before = level_formal.source_files()
        expected = dict(before)
        expected.update({name: hashlib.sha256((creative.ROOT/name).read_bytes()).hexdigest() for name in extras})
        self.assertEqual(level_formal.source_files(extra_paths=extras), expected)
        for name in extras:
            self.assertIn(name, level_formal.source_files(extra_paths=extras))
        with self.assertRaises(ValueError):
            level_formal.source_files(extra_paths=['../outside'])
        with self.assertRaises(FileNotFoundError):
            level_formal.source_files(extra_paths=['missing_producer.py'])

    def test_direction_does_not_bypass_route_retirement(self):
        for request in ('优化风铃平原', '制作未知地下河'):
            with self.assertRaisesRegex(ValueError, 'retired'):
                level_design.route_request(request, direction=self.path)


class ValidationReadScopeTests(unittest.TestCase):
    def setUp(self):
        from test_region_bible import BibleTests
        BibleTests.setUp(self)

    def test_public_calls_reread_mutable_sources_and_reject_resigned_binding(self):
        style = creative.supplemental_authority(self.bible, 'thorn_forest', self.root)
        row = next(r for r in style['content']['runtime_reference']['references'] if r['role']=='architecture_enemy_actor')
        leaf = self.root/row['path']; raw = leaf.read_bytes()
        changed = bytes([raw[0]^1])+raw[1:]  # Same size must not evade fresh hashing.
        for call in (lambda: creative.bind_region_bible('thorn_forest',self.root),
                     lambda: creative.validate_bible_binding(self.ref,root=self.root),
                     lambda: creative.supplemental_authority(self.bible,'thorn_forest',self.root)):
            call()
            leaf.write_bytes(changed)
            with self.assertRaisesRegex(ValueError, 'Shared Plains style reference SHA changed'):
                call()
            leaf.write_bytes(raw); call()
            leaf.unlink()
            with self.assertRaisesRegex(ValueError, 'Missing/unsafe Bible source'):
                call()
            leaf.write_bytes(raw)
            parent=leaf.parent; moved=parent.with_name(parent.name+'-actual')
            parent.rename(moved);parent.symlink_to(moved,target_is_directory=True)
            with self.assertRaisesRegex(ValueError, 'symlinks'):
                call()
            parent.unlink();moved.rename(parent);call()
        leaf.write_bytes(changed)
        style['content']['runtime_reference']['references'][style['content']['runtime_reference']['references'].index(row)]['sha256']=hashlib.sha256(changed).hexdigest()
        style_path=self.root/style['path'];style_path.write_text(json.dumps(style['content']))
        registry_path=self.root/creative.BIBLE_REGISTRY;registry=json.loads(registry_path.read_bytes())
        registry['shared_style_authority']['sha256']=hashlib.sha256(style_path.read_bytes()).hexdigest()
        registry_path.write_text(json.dumps(registry))
        with self.assertRaisesRegex(ValueError, 'binding changed'):
            creative.validate_bible_binding(self.ref,root=self.root)

    def test_each_public_bind_reads_each_leaf_once_and_rechecks_parent_symlinks(self):
        from collections import Counter
        from unittest.mock import patch
        counts=Counter(); read_bytes=Path.read_bytes
        def record(path):
            counts[path]+=1
            return read_bytes(path)
        with patch.object(Path,'read_bytes',record):
            self.assertEqual(creative.bind_region_bible('thorn_forest',self.root)[1],self.ref)
            self.assertTrue(counts)
            self.assertEqual(set(counts.values()),{1})
            first=dict(counts)
            self.assertEqual(creative.bind_region_bible('thorn_forest',self.root)[1],self.ref)
            self.assertEqual(dict(counts),{path:count*2 for path,count in first.items()})
        # Drive-relative and rooted Windows paths must not reset the checked root.
        from pathlib import PureWindowsPath
        reader=creative._ValidationFiles(self.root)
        for unsafe in ('C:relative', r'C:\absolute', r'\rooted'):
            with self.subTest(path=unsafe),patch.object(creative,'Path',PureWindowsPath),self.assertRaisesRegex(ValueError,'repository relative'):
                reader.path(unsafe)
        # Path checks themselves are never cached, even inside one call's reader.
        reader=creative._ValidationFiles(self.root)
        directory=self.root/'mutable-parent';directory.mkdir();(directory/'leaf').write_bytes(b'leaf')
        reader.read('mutable-parent/leaf')
        moved=self.root/'real-parent';directory.rename(moved);directory.symlink_to(moved,target_is_directory=True)
        with self.assertRaisesRegex(ValueError, 'symlinks'):
            reader.read('mutable-parent/leaf')


if __name__ == '__main__':
    unittest.main()
