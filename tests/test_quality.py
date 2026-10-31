"""Adversarial checks for completion claims; fixtures do not certify real content."""
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import struct
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from quality import initialize, validate_record, validate_asset, read_json, policy
from check_quality_diff import weakened_checks, removed_checks, validate as validate_diff
from quality_drills import review, RULES

SHA = 'a' * 40


class QualityTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.record = self.complete_record('process')

    def evidence(self, kind):
        suffix = {'video': '.webm', 'screenshot': '.png'}.get(kind, '.txt')
        path = self.root / (kind + suffix)
        path.write_text('Synthetic unit-test evidence, not real execution or media')
        item = {'id': kind, 'path': path.name, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                'kind': kind, 'producer': 'user' if kind == 'user_feedback' else 'test', 'source_commit': SHA,
                'content_version': 'candidate-v1', 'method': 'isolated unit fixture', 'observed': 'synthetic test'}
        if kind == 'command':
            item.update(command='synthetic', exit_code=0, environment='unit test')
        if kind == 'review':
            item.update(reviewer='separate-reviewer', implementers=['implementer'], independent=True,
                        independence_basis='synthetic identity for negative tests', verdict='ACCEPT')
        if kind == 'user_feedback':
            item.update(source='synthetic unit fixture', quote='synthetic approval', accepted=True,
                        covers=['visual', 'animation', 'audio_vfx', 'gameplay'])
        if kind in ('measurement', 'device_measurement'):
            item.update(device='synthetic', environment='unit', scenario='fixture', budget_source='fixture', physical=True)
        return item

    def complete_record(self, kind):
        data = initialize('QUALITY-TEST-01', kind, SHA)
        data.update(workflow='done', purpose='Test honest completion rules', player_experience='No production change',
                    affected_paths=['docs/test.md'], deliverables=['quality contract'], unverified_items=[])
        types = ['spec', 'command'] if kind == 'process' else ['spec', 'command', 'runtime_trace', 'screenshot', 'video', 'gui', 'review', 'user_feedback', 'device_measurement']
        data['evidence'] = [self.evidence(k) for k in types]
        p = policy()
        dim_kind = {'design': 'spec', 'technical': 'command', 'formal_integration': 'gui', 'visual': 'screenshot',
                    'animation': 'video', 'audio_vfx': 'video', 'gameplay': 'user_feedback', 'performance': 'device_measurement',
                    'independent_review': 'review', 'device': 'device_measurement', 'player_acceptance': 'user_feedback'}
        for name, entry in data['dimensions'].items():
            if name in p['task_types'][kind]['dimensions']:
                entry.update(status='passed', reason='Synthetic positive control', evidence=[dim_kind[name]])
            else:
                entry.update(status='not_applicable', reason='No production content in process test')
        for gate, entry in data['gates'].items():
            if gate in p['task_types'][kind]['gates']:
                kinds = ['command'] if kind == 'process' and gate == 'G4' else p['gate_evidence'][gate]
                entry.update(status='passed', reason='Synthetic positive control', evidence=kinds)
            else:
                entry.update(status='not_applicable', reason='No production content in process test')
        for dim in p['task_types'][kind]['dimensions']:
            gate = next(g for g in p['task_types'][kind]['gates'] if dim in p['gates'][g])
            data['criteria'].append({'id': dim, 'gate': gate, 'dimension': dim, 'scenario': 'isolated test',
                'method': 'validate synthetic positive and mutated negative records', 'expected': 'consistent record',
                'failure': 'false completion accepted', **copy.deepcopy(data['dimensions'][dim])})
        # G1 and G4 can share technical, but need their own explicit scenarios.
        for gate in p['task_types'][kind]['gates']:
            if not any(c['gate'] == gate for c in data['criteria']):
                data['criteria'].append({'id': gate, 'gate': gate, 'dimension': p['gates'][gate][0],
                    'scenario': 'gate fixture', 'method': 'synthetic', 'expected': 'consistent', 'failure': 'false pass',
                    **copy.deepcopy(data['gates'][gate])})
        return data

    def rejected(self, data):
        result = validate_record(data, self.root)
        self.assertFalse(result['task_complete'], result)
        self.assertEqual(result['verdict'], 'REJECT', result)

    def test_light_process_can_complete_without_future_game_approval(self):
        self.record['dimensions']['independent_review'].update(status='unverified', reason='No independent reviewer')
        result = validate_record(self.record, self.root)
        self.assertEqual(result['errors'], [])
        self.assertTrue(result['task_complete'], result)
        self.assertFalse(result['content_complete'])

    def test_enemy_positive_control(self):
        result = validate_record(self.complete_record('enemy'), self.root)
        self.assertTrue(result['content_complete'], result)

    def test_unfinished_is_valid_but_not_complete(self):
        result = validate_record(initialize('ENEMY-TEST-01', 'enemy', SHA), self.root)
        self.assertFalse(result['errors'])
        self.assertFalse(result['task_complete'])
        self.assertEqual(result['verdict'], 'UNVERIFIED')

    def test_done_cannot_be_claimed_from_initial_record(self):
        data = initialize('ENEMY-TEST-01', 'enemy', SHA)
        data['workflow'] = 'done'
        self.rejected(data)

    def test_missing_contract_fields(self):
        for field in ('baseline_commit', 'reviewed_commit', 'purpose', 'constraints', 'criteria', 'formal_impact'):
            with self.subTest(field=field):
                data = copy.deepcopy(self.record)
                del data[field]
                self.rejected(data)

    def test_bad_states_and_no_na_reason(self):
        for mutation in ({'status': 'done'}, {'status': 'not_applicable', 'reason': ''}, {'status': 'passed', 'evidence': []}):
            with self.subTest(mutation=mutation):
                data = copy.deepcopy(self.record)
                data['dimensions']['design'].update(mutation)
                self.rejected(data)

    def test_malformed_state_entry_is_rejected_without_crash(self):
        self.record['dimensions']['design'] = None
        self.rejected(self.record)

    def test_missing_corrupt_external_and_stale_evidence(self):
        for patch in ({'path': 'missing'}, {'path': '../outside'}, {'sha256': 'bad'}, {'source_commit': 'b'*40},
                      {'content_version': 'old'}, {'exit_code': 1}, {'exit_code': True}, {'kind': 'invented'}):
            with self.subTest(patch=patch):
                data = copy.deepcopy(self.record)
                data['evidence'][1].update(patch)
                self.rejected(data)

    def test_failed_optional_dimension_prevents_done(self):
        self.record['dimensions']['visual'].update(status='failed', reason='Failure cannot be hidden as optional')
        self.rejected(self.record)

    def test_optional_content_work_needs_pass_or_explicit_inapplicability(self):
        data = self.complete_record('region')
        data['dimensions']['animation'].update(status='unverified', reason='New animation remains incomplete')
        self.rejected(data)

    def test_awaiting_device_cannot_hide_technical_failure(self):
        data = initialize('DEVICE-TEST-01', 'enemy', SHA)
        data['workflow'] = 'awaiting-device'
        self.rejected(data)

    def test_empty_criteria_prevents_done(self):
        self.record['criteria'] = []
        self.rejected(self.record)

    def test_failed_criterion_prevents_done(self):
        self.record['criteria'][0]['status'] = 'failed'
        self.rejected(self.record)

    def test_content_cannot_skip_formal_player_or_device(self):
        for dim in ('formal_integration', 'independent_review', 'visual', 'device', 'player_acceptance'):
            with self.subTest(dim=dim):
                data = self.complete_record('enemy')
                data['dimensions'][dim].update(status='unverified', evidence=[])
                self.rejected(data)

    def test_self_review_ai_approval_and_virtual_device_rejected(self):
        for kind, patch in [('review', {'reviewer': 'implementer'}), ('review', {'independent': False}),
                            ('review', {'verdict': 'REJECT'}), ('user_feedback', {'producer': 'ai'}),
                            ('user_feedback', {'accepted': False}), ('user_feedback', {'covers': ['visual']}),
                            ('device_measurement', {'physical': False})]:
            with self.subTest(kind=kind, patch=patch):
                data = self.complete_record('enemy')
                next(e for e in data['evidence'] if e['kind'] == kind).update(patch)
                self.rejected(data)

    def test_static_text_cannot_be_video(self):
        data = self.complete_record('enemy')
        video = next(e for e in data['evidence'] if e['kind'] == 'video')
        video.update(path='command.txt', sha256=next(e['sha256'] for e in data['evidence'] if e['kind'] == 'command'))
        self.rejected(data)

    def test_process_cannot_hide_game_changes(self):
        for path in ('game/player/player.gd', 'scripts/game.gd', 'config/player_tuning.json', 'project.godot'):
            with self.subTest(path=path):
                data = copy.deepcopy(self.record)
                data['affected_paths'] = [path]
                self.rejected(data)

    def test_creative_confirmation_requires_linked_user_evidence(self):
        self.record['creative_decisions'] = [{'status': 'user_confirmed', 'decision': 'new boss mechanic', 'basis': 'AI says so'}]
        self.rejected(self.record)

    def test_duplicate_json_field_rejected(self):
        path = self.root / 'duplicate.json'
        path.write_text('{"workflow":"review","workflow":"done"}')
        with self.assertRaisesRegex(ValueError, 'Duplicate'):
            read_json(path)

    def test_asset_claim_needs_provenance_and_user_evidence(self):
        self.assertTrue(validate_asset({'visual_status': 'passed'}, self.root))

    def test_removed_or_changed_test_guards_detected(self):
        self.assertTrue(weakened_checks('assert health == 3\n', 'assert health >= 0\n'))
        self.assertTrue(weakened_checks('assert safe_path\n', '# assert safe_path\n'))
        self.assertFalse(weakened_checks('assert safe_path\n', 'assert safe_path\nassert recovery\n'))

    def test_removed_suite_detected_even_without_assertion_change(self):
        old = {'checks': {'core': {}, 'web': {}}, 'profiles': {'full': ['core', 'web']}}
        new = {'checks': {'core': {}, 'web': {}}, 'profiles': {'full': ['core']}}
        self.assertEqual(removed_checks(json.dumps(old), json.dumps(new)), ['full:web'])

    def test_three_drills_reject_and_never_auto_approve(self):
        for kind, rules in RULES.items():
            with self.subTest(kind=kind):
                bad = review({'id': kind, 'type': kind, 'observations': {f: False for f in rules}})
                self.assertEqual(bad['verdict'], 'REJECT')
                self.assertEqual(len(bad['findings']), len(rules))
                self.assertFalse(bad['actual_skill_invocation'])
                good = review({'id': kind, 'type': kind, 'observations': {f: True for f in rules}})
                self.assertEqual(good['verdict'], 'UNVERIFIED')

    def test_diff_guard_checks_actual_git_scope_and_new_done(self):
        def run(*args):
            return subprocess.check_output(['git', *args], cwd=self.root, text=True)
        (self.root / 'docs').mkdir()
        (self.root / 'docs/tasks.md').write_text('| TEST-01 | process | — | review | awaiting |\n')
        run('init', '-q')
        run('add', '.')
        run('-c', 'user.name=Unit', '-c', 'user.email=unit@example.invalid', 'commit', '-qm', 'base')
        base = run('rev-parse', 'HEAD').strip()
        self.assertEqual(validate_diff(base, self.root)[0], [])
        (self.root / 'scripts').mkdir()
        (self.root / 'scripts/new.gd').write_text('extends Node\n')
        (self.root / 'docs/tasks.md').write_text('| TEST-01 | process | — | done | done |\n')
        errors, _ = validate_diff(base, self.root)
        self.assertTrue(any('Production change' in e for e in errors), errors)
        self.assertTrue(any('New done task' in e for e in errors), errors)

    def test_diff_guard_rejects_reusing_old_completed_evidence(self):
        def run(*args):
            return subprocess.check_output(['git', *args], cwd=self.root, text=True)
        (self.root / 'docs/quality/records').mkdir(parents=True)
        (self.root / 'docs/tasks.md').write_text('| QUALITY-TEST-01 | process | — | review | candidate |\n')
        (self.root / 'tools').mkdir()
        (self.root / 'tools/helper.py').write_text('VALUE = 1\n')
        run('init', '-q')
        run('add', '.')
        run('-c', 'user.name=Unit', '-c', 'user.email=unit@example.invalid', 'commit', '-qm', 'base')
        base = run('rev-parse', 'HEAD').strip()
        data = copy.deepcopy(self.record)
        data.update(reviewed_commit=base, baseline_commit=base, affected_paths=['tools/helper.py'])
        for evidence in data['evidence']:
            evidence['source_commit'] = base
        (self.root / 'docs/quality/records/test.json').write_text(json.dumps(data))
        (self.root / 'docs/tasks.md').write_text('| QUALITY-TEST-01 | process | — | done | tested |\n')
        self.assertEqual(validate_diff(base, self.root)[0], [])
        (self.root / 'tools/helper.py').write_text('VALUE = 99\n')
        self.assertTrue(any('stale' in e for e in validate_diff(base, self.root)[0]))

    def test_routed_lowercase_done_requires_complete_quality_record(self):
        def run(*args):
            return subprocess.check_output(['git', *args], cwd=self.root, text=True)
        (self.root / 'docs/quality/records').mkdir(parents=True)
        task = 'level-optimize-design'
        (self.root / 'docs/tasks.md').write_text(f'| {task} | process | — | review | candidate |\n')
        run('init', '-q')
        run('add', '.')
        run('-c', 'user.name=Unit', '-c', 'user.email=unit@example.invalid', 'commit', '-qm', 'base')
        base = run('rev-parse', 'HEAD').strip()
        self.assertEqual(validate_diff(base, self.root)[0], [])
        (self.root / 'docs/tasks.md').write_text(f'| {task} | process | — | done | claimed |\n')
        self.assertTrue(any('New done task' in e for e in validate_diff(base, self.root)[0]))
        record = copy.deepcopy(self.record)
        record.update(task_id=task, reviewed_commit=base, baseline_commit=base)
        for evidence in record['evidence']:
            evidence['source_commit'] = base
        (self.root / 'docs/quality/records/routed.json').write_text(json.dumps(record))
        self.assertEqual(validate_diff(base, self.root)[0], [])
        record['gates']['G4']['status'] = 'unverified'
        (self.root / 'docs/quality/records/routed.json').write_text(json.dumps(record))
        self.assertTrue(any('New done task' in e for e in validate_diff(base, self.root)[0]))


    def asset_record(self):
        source = self.root / 'assets/source.png'
        source.parent.mkdir(parents=True, exist_ok=True)
        source.write_bytes(b'SYNTHETIC source, not image quality evidence')
        consumer = self.root / 'scripts/consumer.gd'
        consumer.parent.mkdir(parents=True, exist_ok=True)
        consumer.write_text('extends Node\n')
        return {'schema_version': policy()['schema_version'], 'asset_id': 'synthetic-asset',
                'content_version': 'test-v1', 'source_path': 'assets/source.png',
                'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
                'tool': 'unit fixture', 'model': 'none', 'prompt_or_reference': 'synthetic source',
                'processing': 'none', 'usage_scope': 'unit only', 'license_source': 'synthetic fixture',
                'license_status': 'unknown', 'visual_status': 'unverified',
                'runtime_paths': ['scripts/consumer.gd']}

    def associated_file(self, name='assets/production/prompt.txt', role='generation_record'):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text('SYNTHETIC offline production record, not a runtime consumer')
        return {'path': name, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'role': role}

    def test_asset_legacy_runtime_and_empty_runtime_rejection_preserved(self):
        data = self.asset_record()
        self.assertEqual(validate_asset(data, self.root), [])
        data['runtime_paths'] = []
        data['non_runtime_reason'] = 'A reason alone does not opt into non-runtime disposition'
        self.assertTrue(validate_asset(data, self.root))

    def test_asset_explicit_non_runtime_dispositions_are_honest(self):
        data = self.asset_record()
        data.update(runtime_paths=[], non_runtime_reason='Rejected original retained for audit; no runtime consumer')
        for disposition in ['rejected_evidence_only', 'production_record_only']:
            with self.subTest(disposition=disposition):
                data['disposition'] = disposition
                self.assertEqual(validate_asset(data, self.root), [])

    def test_asset_runtime_dispositions_never_waive_actual_consumers(self):
        for disposition in ['runtime_candidate', 'limited_preview', 'legacy_fixture_only']:
            with self.subTest(disposition=disposition):
                data = self.asset_record()
                data['disposition'] = disposition
                self.assertEqual(validate_asset(data, self.root), [])
                data['runtime_paths'] = []
                data['non_runtime_reason'] = 'Cannot claim runtime disposition without consumers'
                self.assertTrue(validate_asset(data, self.root))

    def test_asset_non_runtime_requires_reason_and_cannot_claim_consumers(self):
        data = self.asset_record()
        data.update(disposition='rejected_evidence_only', runtime_paths=[])
        for reason in [None, '', '   ']:
            with self.subTest(reason=reason):
                data['non_runtime_reason'] = reason
                self.assertTrue(validate_asset(data, self.root))
        data['non_runtime_reason'] = 'Rejected original'
        data['runtime_paths'] = ['scripts/consumer.gd']
        self.assertTrue(validate_asset(data, self.root))
        data['runtime_paths'] = None
        self.assertTrue(validate_asset(data, self.root))

    def test_asset_non_runtime_cannot_fake_visual_pass(self):
        data = self.asset_record()
        data.update(disposition='production_record_only', runtime_paths=[], non_runtime_reason='Offline spec',
                    visual_status='passed', license_status='verified', user_acceptance_evidence=['assets/source.png'])
        self.assertTrue(any('cannot claim visual passed' in e for e in validate_asset(data, self.root)))
        data['disposition'] = 'unknown_bypass'
        self.assertTrue(validate_asset(data, self.root))

    def test_asset_associated_roles_have_exact_local_hashes(self):
        data = self.asset_record()
        data['associated_files'] = []
        for role in ['generation_record', 'reference', 'processing_record', 'source_contract', 'documentation']:
            data['associated_files'].append(self.associated_file('assets/production/' + role + '.txt', role))
        self.assertEqual(validate_asset(data, self.root), [])
        (self.root / data['associated_files'][0]['path']).write_text('altered bytes')
        self.assertTrue(any('hash mismatch' in e for e in validate_asset(data, self.root)))

    def test_asset_associated_bad_hash_role_shape_or_duplicate_rejected(self):
        data = self.asset_record()
        entry = self.associated_file()
        for field, value in [('sha256', '0' * 64), ('sha256', 'not-a-hash'), ('role', 'runtime'), ('role', [])]:
            with self.subTest(field=field, value=value):
                bad = dict(entry)
                bad[field] = value
                data['associated_files'] = [bad]
                self.assertTrue(validate_asset(data, self.root))
        for entries in [None, ['not an object'], [{}], [dict(entry, extra=True)], [entry, entry]]:
            with self.subTest(entries=entries):
                data['associated_files'] = entries
                self.assertTrue(validate_asset(data, self.root))

    def test_asset_associated_paths_cannot_cover_directory_glob_or_external(self):
        data = self.asset_record()
        entry = self.associated_file()
        for name in ['assets/production', 'assets/production/*', 'assets/production/../source.png',
                     'assets/production/missing.txt', str((self.root / entry['path']).resolve())]:
            with self.subTest(name=name):
                data['associated_files'] = [dict(entry, path=name)]
                self.assertTrue(validate_asset(data, self.root))
        external = Path(self.temp.name).parent / (self.root.name + '-external.txt')
        external.write_text('outside repository')
        self.addCleanup(external.unlink)
        (self.root / 'assets/external-link.txt').symlink_to(external)
        data['associated_files'] = [dict(entry, path='assets/external-link.txt')]
        self.assertTrue(validate_asset(data, self.root))

    def asset_diff_fixture(self):
        def run(*args):
            return subprocess.check_output(['git', *args], cwd=self.root, text=True)
        (self.root / 'docs/quality/records').mkdir(parents=True)
        (self.root / 'docs/quality/asset_records').mkdir()
        (self.root / 'docs/tasks.md').write_text('| QUALITY-TEST-01 | art | — | review | candidate |\n')
        run('init', '-q')
        run('add', '.')
        run('-c', 'user.name=Unit', '-c', 'user.email=unit@example.invalid', 'commit', '-qm', 'base')
        base = run('rev-parse', 'HEAD').strip()
        asset = self.asset_record()
        asset['associated_files'] = [self.associated_file()]
        record = initialize('QUALITY-TEST-01', 'art', base)
        record.update(formal_impact=True, affected_paths=['assets/source.png', 'scripts/consumer.gd',
                                                       'assets/production/prompt.txt'])
        (self.root / 'docs/quality/records/test.json').write_text(json.dumps(record))
        return base, asset

    def test_diff_asset_associated_exact_paths_only_after_full_validation(self):
        base, asset = self.asset_diff_fixture()
        record_path = self.root / 'docs/quality/asset_records/test.json'
        record_path.write_text(json.dumps(asset))
        self.assertEqual(validate_diff(base, self.root)[0], [])
        asset['associated_files'][0]['sha256'] = '0' * 64
        record_path.write_text(json.dumps(asset))
        errors, _ = validate_diff(base, self.root)
        self.assertTrue(any('provenance metadata: assets/source.png' in e for e in errors), errors)
        self.assertTrue(any('provenance metadata: assets/production/prompt.txt' in e for e in errors), errors)

    def test_game_production_change_requires_non_process_record(self):
        base, asset = self.asset_diff_fixture()
        (self.root / 'docs/quality/asset_records/test.json').write_text(json.dumps(asset))
        self.assertEqual(validate_diff(base, self.root)[0], [])
        name = 'game/combat/actor.gd'
        consumer = self.root / name
        consumer.parent.mkdir(parents=True)
        consumer.write_text('extends Node\n')
        errors, changed = validate_diff(base, self.root)
        self.assertIn(name, changed)
        self.assertIn('Production change lacks non-process task record: ' + name, errors)
        record_path = self.root / 'docs/quality/records/test.json'
        record = json.loads(record_path.read_text())
        record['affected_paths'].append(name)
        record_path.write_text(json.dumps(record))
        self.assertEqual(validate_diff(base, self.root)[0], [])

    def test_game_asset_consumer_cannot_bypass_literal_or_dynamic_audit(self):
        from check_quality_diff import known_asset_consumers
        asset = self.root / 'assets/fixture.png'
        asset.parent.mkdir()
        asset.write_bytes(b'synthetic source bytes, not rendered')
        consumer = self.root / 'game/presentation/actor.gd'
        consumer.parent.mkdir(parents=True)
        consumer.write_text('var texture = preload("res://assets/fixture.png")\n')
        self.assertIn('assets/fixture.png', known_asset_consumers(self.root))
        for reference in ('res://assets/missing.png', 'res://assets/%s.png'):
            with self.subTest(reference=reference):
                consumer.write_text('var texture = load("' + reference + '")\n')
                with self.assertRaisesRegex(ValueError, 'Unresolved asset reference needs finite consumer adapter'):
                    known_asset_consumers(self.root)

    def test_diff_asset_omitted_file_never_inherits_directory_coverage(self):
        base, asset = self.asset_diff_fixture()
        (self.root / 'docs/quality/asset_records/test.json').write_text(json.dumps(asset))
        omitted = self.root / 'assets/production/omitted.txt'
        omitted.write_text('not listed in associated files')
        errors, _ = validate_diff(base, self.root)
        self.assertTrue(any('provenance metadata: assets/production/omitted.txt' in e for e in errors), errors)
        self.assertTrue(any('Production change lacks non-process task record: assets/production/omitted.txt' in e for e in errors), errors)

    def test_diff_asset_unknown_associated_role_invalidates_all_coverage(self):
        base, asset = self.asset_diff_fixture()
        asset['associated_files'][0]['role'] = 'anything'
        (self.root / 'docs/quality/asset_records/test.json').write_text(json.dumps(asset))
        errors, _ = validate_diff(base, self.root)
        self.assertTrue(any('provenance metadata: assets/source.png' in e for e in errors), errors)
        self.assertTrue(any('provenance metadata: assets/production/prompt.txt' in e for e in errors), errors)


    def test_diff_known_preload_cannot_be_disguised_as_non_runtime(self):
        base, asset = self.asset_diff_fixture()
        (self.root / 'scripts/consumer.gd').write_text('extends Node\nconst LIVE = preload("res://assets/source.png")\n')
        asset.update(disposition='rejected_evidence_only', runtime_paths=[], non_runtime_reason='False declaration under test')
        (self.root / 'docs/quality/asset_records/test.json').write_text(json.dumps(asset))
        errors, _ = validate_diff(base, self.root)
        self.assertTrue(any('Known runtime asset lacks runtime provenance' in e and 'assets/source.png' in e for e in errors), errors)

    def test_diff_known_preload_cannot_be_disguised_as_associated_documentation(self):
        base, asset = self.asset_diff_fixture()
        entry = self.associated_file('assets/live.png', 'documentation')
        asset['associated_files'].append(entry)
        (self.root / 'scripts/consumer.gd').write_text('extends Node\nconst LIVE = preload("res://assets/live.png")\n')
        record_path = self.root / 'docs/quality/records/test.json'
        record = json.loads(record_path.read_text())
        record['affected_paths'].append('assets/live.png')
        record_path.write_text(json.dumps(record))
        (self.root / 'docs/quality/asset_records/test.json').write_text(json.dumps(asset))
        errors, _ = validate_diff(base, self.root)
        self.assertTrue(any('Known runtime asset lacks runtime provenance' in e and 'assets/live.png' in e for e in errors), errors)
        asset['runtime_paths'].append('assets/live.png')
        (self.root / 'docs/quality/asset_records/test.json').write_text(json.dumps(asset))
        self.assertEqual(validate_diff(base, self.root)[0], [])

    def test_diff_dynamic_semantic_family_cannot_claim_offline_source(self):
        base, asset = self.asset_diff_fixture()
        family = self.root / 'assets/region_production_v3/spaces/unit_family'
        family.mkdir(parents=True)
        (family / 'source.png').write_bytes(b'SYNTHETIC finite family source')
        source = (family / 'source.png').relative_to(self.root).as_posix()
        family_json = (family / 'family.json').relative_to(self.root).as_posix()
        (family / 'family.json').write_text(json.dumps({'path': source, 'sha256': hashlib.sha256((family / 'source.png').read_bytes()).hexdigest()}))
        script = self.root / 'scripts/art/plains_semantic_landscape.gd'
        script.parent.mkdir(parents=True)
        script.write_text('extends RefCounted\nconst PILOT_FAMILIES := ["unit_family"]\nconst FAMILY_ROOT := "res://assets/region_production_v3/spaces/"\nfunc read_family(family_id):\n\treturn JSON.parse_string(FileAccess.get_file_as_string(FAMILY_ROOT + family_id + "/family.json"))\n')
        asset.update(source_path=source, source_sha256=hashlib.sha256((family / 'source.png').read_bytes()).hexdigest(),
                     disposition='production_record_only', runtime_paths=[], non_runtime_reason='False dynamic-consumer claim')
        asset['associated_files'].append({'path': family_json, 'sha256': hashlib.sha256((family / 'family.json').read_bytes()).hexdigest(), 'role': 'source_contract'})
        (self.root / 'docs/quality/asset_records/test.json').write_text(json.dumps(asset))
        errors, _ = validate_diff(base, self.root)
        self.assertTrue(any('Known runtime asset lacks runtime provenance' in e and source in e for e in errors), errors)
        self.assertTrue(any('Known runtime asset lacks runtime provenance' in e and family_json in e for e in errors), errors)
        script.write_text(script.read_text() + '\nfunc unknown(selection):\n\treturn read_family(selection)\n')
        errors, _ = validate_diff(base, self.root)
        self.assertTrue(any('Asset consumer audit unresolved' in e for e in errors), errors)

    def test_diff_offline_guide_png_allowed_but_unresolved_reference_rejected(self):
        base, asset = self.asset_diff_fixture()
        guide = self.associated_file('assets/production/layout_guide.png', 'reference')
        asset['associated_files'].append(guide)
        record_path = self.root / 'docs/quality/records/test.json'
        record = json.loads(record_path.read_text())
        record['affected_paths'].append(guide['path'])
        record_path.write_text(json.dumps(record))
        (self.root / 'docs/quality/asset_records/test.json').write_text(json.dumps(asset))
        self.assertEqual(validate_diff(base, self.root)[0], [])
        (self.root / 'scripts/consumer.gd').write_text('extends Node\nconst LIVE = preload("res://assets/missing.png")\n')
        errors, _ = validate_diff(base, self.root)
        self.assertTrue(any('Asset consumer audit unresolved' in e for e in errors), errors)
        (self.root / 'scripts/consumer.gd').write_text('extends Node\nfunc fetch(id):\n\treturn load("res://assets/%s.png" % id)\n')
        errors, _ = validate_diff(base, self.root)
        self.assertTrue(any('Asset consumer audit unresolved' in e for e in errors), errors)


    def connected_runtime_fixture(self):
        # Actual frozen consumer source, synthetic asset bytes; no Godot claim.
        family = self.root / 'assets/production_repair/rooted_plants_v1'
        family.mkdir(parents=True)
        source = family / 'raw.png'
        source.write_bytes(b'SYNTHETIC connected family source')
        manifest = family / 'family.json'
        manifest.write_text(json.dumps({'path':'res://assets/production_repair/rooted_plants_v1/raw.png',
            'sha256':hashlib.sha256(source.read_bytes()).hexdigest()}))
        script = self.root / 'scripts/art/plains_connected_landscape.gd'
        script.parent.mkdir(parents=True)
        script.write_bytes((Path(__file__).resolve().parents[1]/'scripts/art/plains_connected_landscape.gd').read_bytes())
        return script, manifest, source

    def test_diff_connected_directory_resolves_only_verified_files(self):
        from check_quality_diff import known_asset_consumers
        script, manifest, source = self.connected_runtime_fixture()
        (source.parent.parent/'unused.png').write_bytes(b'not a consumer')
        known = known_asset_consumers(self.root)
        self.assertIn(source.relative_to(self.root).as_posix(), known)
        self.assertIn(manifest.relative_to(self.root).as_posix(), known)
        self.assertNotIn('assets/production_repair/', known)
        self.assertNotIn('assets/production_repair/unused.png', known)

    def test_diff_connected_files_cannot_pose_as_offline_provenance(self):
        base, asset = self.asset_diff_fixture()
        script, manifest, source = self.connected_runtime_fixture()
        source_name = source.relative_to(self.root).as_posix()
        manifest_name = manifest.relative_to(self.root).as_posix()
        asset.update(source_path=source_name, source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
                     disposition='production_record_only', runtime_paths=[], non_runtime_reason='False connected-consumer claim')
        asset['associated_files'].append({'path':manifest_name,'sha256':hashlib.sha256(manifest.read_bytes()).hexdigest(),'role':'source_contract'})
        (self.root/'docs/quality/asset_records/test.json').write_text(json.dumps(asset))
        errors, _ = validate_diff(base, self.root)
        for name in [source_name, manifest_name]:
            self.assertTrue(any('Known runtime asset lacks runtime provenance' in error and name in error for error in errors), errors)

    def test_diff_connected_external_callers_cannot_escape_finite_adapter(self):
        from check_quality_diff import known_asset_consumers
        self.connected_runtime_fixture()
        external = self.root/'scripts/external.gd'
        for code in (
            'return PlainsConnectedLandscape.read_family("hidden")',
            'var reader = PlainsConnectedLandscape; return reader.read_family("hidden")',
            'return load("res://scripts/art/plains_connected_landscape.gd").read_family("hidden")',
            'return instance.call("read_family", "hidden")',
        ):
            with self.subTest(code=code):
                external.write_text('extends Node\nfunc hidden_reader():\n\t'+code+'\n')
                with self.assertRaises(ValueError):known_asset_consumers(self.root)

    def test_diff_connected_adapter_refuses_dynamic_missing_escaped_and_stale(self):
        from check_quality_diff import known_asset_consumers
        script, manifest, source = self.connected_runtime_fixture()
        original_script, original_manifest, original_source = script.read_text(), manifest.read_text(), source.read_bytes()
        mutations = {
            'extra_root_reader':lambda:script.write_text(original_script+'\nfunc hidden_reader():\n\treturn FileAccess.get_file_as_string(ROOT+"hidden/family.json")\n'),
            'reflective_call':lambda:script.write_text(original_script+'\nfunc hidden_reader(selection):\n\treturn call("read_family", selection)\n'),
            'reader_alias':lambda:script.write_text(original_script+'\nvar reader_alias = read_family\n'),
            'even_comment_requires_adapter_review':lambda:script.write_text(original_script+'\n# changed consumer\n'),
            'dynamic_call':lambda:script.write_text(original_script+'\nfunc unknown(selection):\n\treturn read_family(selection)\n'),
            'unknown_literal':lambda:script.write_text(original_script+'\nvar unknown = read_family("future_family")\n'),
            'changed_root':lambda:script.write_text(original_script.replace('res://assets/production_repair/','res://assets/elsewhere/')),
            'missing_manifest':lambda:manifest.unlink(),
            'missing_png':lambda:source.unlink(),
            'stale_sha':lambda:source.write_bytes(b'changed source without contract'),
            'escape_family':lambda:manifest.write_text(json.dumps({'path':'res://assets/other/raw.png','sha256':'a'*64})),
            'path_traversal':lambda:manifest.write_text(json.dumps({'path':'res://assets/production_repair/rooted_plants_v1/../raw.png','sha256':'a'*64})),
        }
        for name, mutate in mutations.items():
            with self.subTest(mutation=name):
                script.write_text(original_script);manifest.write_text(original_manifest);source.write_bytes(original_source)
                mutate()
                with self.assertRaises(ValueError):known_asset_consumers(self.root)

    def style_runtime_fixture(self):
        # Real frozen loader sources, synthetic resource bytes. No engine claim.
        from check_quality_diff import STYLE_CONSUMER_SHA256, style_asset_inventory
        repository = Path(__file__).resolve().parents[1]
        for name in STYLE_CONSUMER_SHA256:
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes((repository / name).read_bytes())
        required, _optional = style_asset_inventory()
        for name in required:
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b'SYNTHETIC finite style resource; not renderable')
        return required

    def test_diff_style_finite_inventory_excludes_unknown_siblings(self):
        from check_quality_diff import known_asset_consumers, style_asset_inventory
        required = self.style_runtime_fixture()
        for name in ('retro/secret.png', 'cavern/ice/chime_props.png',
                     'retro/generated/source_props.png', 'retro/source/Environment.png'):
            path = self.root / ('assets/style_exploration/' + name)
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b'not a reviewed runtime consumer')
        known = known_asset_consumers(self.root)
        self.assertEqual(known, required)
        optional = 'assets/style_exploration/cavern/forest/background_far.png'
        (self.root / optional).write_bytes(b'SYNTHETIC optional depth layer')
        self.assertEqual(known_asset_consumers(self.root), required | {optional})

    def test_diff_style_missing_required_assets_are_rejected(self):
        from check_quality_diff import known_asset_consumers
        self.style_runtime_fixture()
        for name in ('retro/terrain.png', 'basic/terrain.tres', 'underworld/player.json',
                     'cavern/plains/chime_props.json', 'underworld/gear/background_sky.png',
                     'scribble/original/character_roundPurple.png'):
            with self.subTest(asset=name):
                path = self.root / ('assets/style_exploration/' + name)
                original = path.read_bytes()
                path.unlink()
                with self.assertRaises(ValueError): known_asset_consumers(self.root)
                path.write_bytes(original)

    def test_diff_style_partial_consumers_are_rejected(self):
        from check_quality_diff import known_asset_consumers
        self.style_runtime_fixture()
        (self.root / 'scripts/style_exploration/style_scenery.gd').unlink()
        with self.assertRaises(ValueError): known_asset_consumers(self.root)

    def test_diff_style_changed_dynamic_alias_reflection_and_even_comment_rejected(self):
        from check_quality_diff import known_asset_consumers
        self.style_runtime_fixture()
        path = self.root / 'scripts/style_exploration/style_actor_visual.gd'
        original = path.read_text()
        for extra in ('\n# caller changed\n', '\nvar hidden = ROOT + "secret.png"\n',
                      '\nvar reader_alias = _load_generated\n',
                      '\nfunc reflection():\n\treturn call("_load_generated")\n'):
            with self.subTest(extra=extra):
                path.write_text(original + extra)
                with self.assertRaises(ValueError): known_asset_consumers(self.root)
        path.write_text(original)

    def test_diff_style_unknown_root_consumer_and_dynamic_template_rejected(self):
        from check_quality_diff import known_asset_consumers
        self.style_runtime_fixture()
        caller = self.root / 'scripts/unknown_style.gd'
        for code in ('const ROOT = "res://assets/style_exploration/"',
                     'func hidden(id):\n\treturn load("res://assets/style_exploration/%s/secret.png" % id)'):
            with self.subTest(code=code):
                caller.write_text('extends Node\n' + code + '\n')
                with self.assertRaises(ValueError): known_asset_consumers(self.root)

    def test_diff_style_asset_symlink_escape_is_rejected(self):
        from check_quality_diff import known_asset_consumers
        self.style_runtime_fixture()
        with tempfile.TemporaryDirectory() as elsewhere:
            external = Path(elsewhere) / 'external.png'
            external.write_bytes(b'external')
            path = self.root / 'assets/style_exploration/basic/terrain.png'
            path.unlink()
            path.symlink_to(external)
            with self.assertRaises(ValueError): known_asset_consumers(self.root)

    def write_item_png(self, path, width, height):
        # Genuine synthetic RGBA PNG, generated using only the standard library.
        def chunk(kind, payload):
            return struct.pack('>I', len(payload)) + kind + payload + struct.pack('>I', zlib.crc32(kind + payload) & 0xffffffff)
        compressor = zlib.compressobj()
        row = b'\0' + bytes(width*4)
        payload = b''.join(compressor.compress(row) for _ in range(height)) + compressor.flush()
        path.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)) + chunk(b'IDAT', payload) + chunk(b'IEND', b''))

    def item_art_fixture(self):
        # Frozen actual loader plus tiny genuine PNGs; isolated from runtime files.
        from check_quality_diff import ITEM_ART_LOADER
        repository = Path(__file__).resolve().parents[1]
        path = self.root / ITEM_ART_LOADER
        path.parent.mkdir(parents=True)
        path.write_bytes((repository / ITEM_ART_LOADER).read_bytes())
        name = 'assets/items/v5/icons/synthetic.source.png'
        png = self.root / name
        png.parent.mkdir(parents=True)
        self.write_item_png(png, 4, 4)
        config = {'schema_version': 1, 'icons': {'synthetic': {'texture': 'res://' + name, 'region': [0, 0, 4, 4]}}, 'clips': {}, 'entities': {}, 'cues': {}}
        (self.root / 'config').mkdir()
        (self.root / 'config/item_v5_art.json').write_text(json.dumps(config))
        manifest = {'schema_version': 1, 'assets': [{'path': name, 'sha256': hashlib.sha256(png.read_bytes()).hexdigest()}]}
        (self.root / 'assets/items/v5/manifest.json').write_text(json.dumps(manifest))
        return config, manifest, name

    def test_diff_item_art_finite_source_family_excludes_siblings(self):
        from check_quality_diff import known_asset_consumers
        config, manifest, name = self.item_art_fixture()
        (self.root / 'assets/items/v5/unknown.png').write_bytes(b'not registered')
        self.assertEqual(known_asset_consumers(self.root), {name})
        # New data-only source is admitted only with a matching exact identity.
        added = name.replace('synthetic', 'added')
        (self.root / added).write_bytes((self.root / name).read_bytes())
        manifest['assets'].append({'path': added, 'sha256': manifest['assets'][0]['sha256']})
        config['clips']['added'] = {'texture': 'res://' + added, 'regions': [[0, 0, 4, 4]], 'fps': 24, 'loop': False, 'world_size': [4, 4], 'pivot': [0.5, 0.5]}
        (self.root / 'config/item_v5_art.json').write_text(json.dumps(config))
        (self.root / 'assets/items/v5/manifest.json').write_text(json.dumps(manifest))
        self.assertEqual(known_asset_consumers(self.root), {name, added})

    def test_diff_item_art_registry_and_manifest_corruption_rejected(self):
        from check_quality_diff import known_asset_consumers
        config, manifest, name = self.item_art_fixture()
        registry = self.root / 'config/item_v5_art.json'
        source_family = self.root / 'assets/items/v5/manifest.json'
        for broken in (None, {}, {**config, 'icons': []}, {**config, 'schema_version': True}):
            with self.subTest(config=broken):
                registry.write_text(json.dumps(broken))
                with self.assertRaises(ValueError): known_asset_consumers(self.root)
        registry.write_text(json.dumps(config))
        for broken in ({}, {**manifest, 'assets': []}, {**manifest, 'assets': manifest['assets']*2}, {**manifest, 'assets': [{'path': name, 'sha256': '0'*64}]}):
            with self.subTest(manifest=broken):
                source_family.write_text(json.dumps(broken))
                with self.assertRaises(ValueError): known_asset_consumers(self.root)
        source_family.write_text(json.dumps(manifest))
        for texture in ('res://assets/items/v5/../secret.png', 'res://assets/items/v5/%s.png', 'res://assets/elsewhere.png', 'res://assets/items/v5/missing.png'):
            with self.subTest(texture=texture):
                config['icons']['synthetic']['texture'] = texture
                registry.write_text(json.dumps(config))
                with self.assertRaises(ValueError): known_asset_consumers(self.root)

    def test_diff_item_art_clip_mapping_and_budget_rejected(self):
        from check_quality_diff import known_asset_consumers
        config, manifest, name = self.item_art_fixture()
        registry = self.root / 'config/item_v5_art.json'
        clip = {'texture': 'res://' + name, 'regions': [[0, 0, 4, 4]], 'fps': 24, 'loop': False, 'world_size': [4, 4], 'pivot': [0.5, 0.5]}
        for broken in ({**clip, 'fps': 0}, {**clip, 'loop': 1}, {**clip, 'regions': []}, {**clip, 'pivot': [2, 0]}, {**clip, 'geometry': 'radius'}):
            with self.subTest(clip=broken):
                config['clips'] = {'bad': broken}
                registry.write_text(json.dumps(config))
                with self.assertRaises(ValueError): known_asset_consumers(self.root)
        config['clips'] = {'valid': clip}
        for group in ('entities', 'cues'):
            config[group] = {'bad': {'default': 'missing'}}
            registry.write_text(json.dumps(config))
            with self.assertRaises(ValueError): known_asset_consumers(self.root)
            config[group] = {}
        config['clips'] = {}
        registry.write_text(json.dumps(config))
        # Tiny compressed PNG, genuine >64MiB decoded RGBA upper bound.
        self.write_item_png(self.root / name, 4097, 4097)
        manifest['assets'][0]['sha256'] = hashlib.sha256((self.root / name).read_bytes()).hexdigest()
        (self.root / 'assets/items/v5/manifest.json').write_text(json.dumps(manifest))
        with self.assertRaisesRegex(ValueError, '64MiB'): known_asset_consumers(self.root)

    def test_diff_item_art_changed_loader_unknown_dynamic_and_escape_rejected(self):
        from check_quality_diff import known_asset_consumers, ITEM_ART_LOADER
        config, manifest, name = self.item_art_fixture()
        loader = self.root / ITEM_ART_LOADER
        original = loader.read_bytes()
        loader.write_bytes(original + b'\n# Changed loader requires review\n')
        with self.assertRaises(ValueError): known_asset_consumers(self.root)
        loader.write_bytes(original)
        unknown = self.root / 'scripts/unknown.gd'
        unknown.write_text('const ROOT = "res://assets/items/v5/"')
        with self.assertRaises(ValueError): known_asset_consumers(self.root)
        unknown.unlink()
        with tempfile.TemporaryDirectory() as elsewhere:
            outside = Path(elsewhere) / 'source.png'
            outside.write_bytes((self.root / name).read_bytes())
            (self.root / name).unlink()
            (self.root / name).symlink_to(outside)
            with self.assertRaises(ValueError): known_asset_consumers(self.root)

    def test_diff_item_art_png_container_corruption_with_matching_identity_rejected(self):
        from check_quality_diff import known_asset_consumers
        _config, manifest, name = self.item_art_fixture()
        path = self.root / name
        original = path.read_bytes()
        for broken in (b'not PNG', original[:-1], original + b'trailing', original[:20] + bytes([original[20] ^ 1]) + original[21:]):
            with self.subTest(size=len(broken)):
                path.write_bytes(broken)
                manifest['assets'][0]['sha256'] = hashlib.sha256(broken).hexdigest()
                (self.root / 'assets/items/v5/manifest.json').write_text(json.dumps(manifest))
                with self.assertRaises(ValueError): known_asset_consumers(self.root)

    def test_diff_item_art_region_and_png_corruption_rejected(self):
        from check_quality_diff import known_asset_consumers
        config, manifest, name = self.item_art_fixture()
        registry = self.root / 'config/item_v5_art.json'
        for region in ([0, 0, 5, 4], [0, 0, 0, 4], [True, 0, 4, 4], [0.5, 0, 4, 4], None):
            with self.subTest(region=region):
                config['icons']['synthetic']['region'] = region
                registry.write_text(json.dumps(config))
                with self.assertRaises(ValueError): known_asset_consumers(self.root)
        config['icons']['synthetic']['region'] = [0, 0, 4, 4]
        registry.write_text(json.dumps(config))
        (self.root / name).write_bytes(b'corrupted PNG')
        with self.assertRaises(ValueError): known_asset_consumers(self.root)



if __name__ == '__main__':
    unittest.main(verbosity=2)
