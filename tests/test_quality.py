"""Adversarial checks for completion claims; fixtures do not certify real content."""
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

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
        for path in ('scripts/game.gd', 'config/player_tuning.json', 'project.godot'):
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


if __name__ == '__main__':
    unittest.main(verbosity=2)
