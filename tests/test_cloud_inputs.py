"""Real temporary sparse Git worktrees and historical consumers; no fake PASS."""
import contextlib
import copy
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import cloud_inputs as inputs


class CloudInputsTests(unittest.TestCase):
    def git(self, root, *args):
        return subprocess.check_output(['git', '-C', str(root), *args], stderr=subprocess.PIPE).decode().strip()

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.source, self.target = self.base / 'source', self.base / 'target'
        self.source.mkdir()
        self.git(self.source, 'init', '-q')
        self.git(self.source, 'config', 'user.name', 'Input Test')
        self.git(self.source, 'config', 'user.email', 'inputs@example.invalid')
        self.proof = 'docs/evidence/historical/fixture.json'
        self.unrelated = 'docs/evidence/unrelated/not-selected.bin'
        historical = 'import json\nfrom pathlib import Path\nassert json.loads(Path("' + self.proof + '").read_text())["version"] == 1\nprint("HISTORICAL FIXTURE: passed")\n'
        files = {self.proof: '{"version":1,"note":"historical immutable fixture"}\n',
                 self.unrelated: 'unrelated evidence must stay sparse\n',
                 'tools/historical.py': historical,
                 'tools/check_quality.py': 'print("QUALITY fixture")\n',
                 'docs/quality/policy.json': '{"templates":[]}',
                 'docs/quality/records/OLD.json': json.dumps({'evidence': [{'path': self.proof}]}),
                 'docs/tasks.md': 'fixture task index', 'docs/development_quality.md': 'fixture quality contract',
                 'docs/quality/README.md': 'fixture quality entry', '.gitignore': 'build/\n'}
        for name, content in files.items():
            path = self.source / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content)
        self.git(self.source, 'add', '.')
        self.git(self.source, 'commit', '-qm', 'historical fixture and original consumer')
        self.historical_commit = self.git(self.source, 'rev-parse', 'HEAD')
        self.historical_blob = self.git(self.source, 'rev-parse', 'HEAD:' + self.proof)
        check = {'argv': ['python3', 'tools/historical.py'], 'timeout_seconds': 10,
                 'success_pattern': '^HISTORICAL FIXTURE: passed$', 'inputs': [self.proof]}
        self.manifest = {'schema_version': 1, 'checks': {'historical': check,
                         'quality': {'argv': ['python3', 'tools/check_quality.py'], 'timeout_seconds': 10, 'success_pattern': '^QUALITY fixture$'}},
                         'profiles': {'historical-only': ['historical'], 'quality-only': ['quality']}}
        path = self.source / 'tools/harness/profiles.json'
        path.parent.mkdir()
        path.write_text(json.dumps(self.manifest))
        self.git(self.source, 'add', '.')
        self.git(self.source, 'commit', '-qm', 'current Harness selects preserved historical fixture')
        self.head = self.git(self.source, 'rev-parse', 'HEAD')
        subprocess.run(['git', 'clone', '-q', '--local', '--no-hardlinks', str(self.source), str(self.target)], check=True)
        self.git(self.target, 'sparse-checkout', 'init', '--no-cone')
        self.set_sparse('/*\n!/docs/evidence/**\n')

    def set_sparse(self, patterns):
        subprocess.run(['git', '-C', str(self.target), 'sparse-checkout', 'set', '--no-cone', '--stdin'],
                       input=patterns, text=True, check=True, capture_output=True)

    def plan(self, **kwargs):
        return inputs.make_plan(self.target, checks=['historical'], **kwargs)

    def hydrate(self):
        return inputs.materialize(self.target, checks=['historical'])

    def test_registered_game_directory_materializes_only_selected_application_inputs(self):
        selected = 'game/application/run_session.gd'
        unrelated = 'game/presentation/not_selected.gd'
        for name in (selected, unrelated):
            path = self.source/name; path.parent.mkdir(parents=True, exist_ok=True); path.write_text('extends RefCounted\n')
        manifest = copy.deepcopy(self.manifest)
        # Test the existing materializer with a finite application source prefix;
        # no engine executes and the fixture does not claim runtime approval.
        manifest['checks']['run-session'] = {**manifest['checks']['historical'], 'inputs': ['game/application']}
        (self.source/'tools/harness/profiles.json').write_text(json.dumps(manifest))
        self.git(self.source, 'add', '.')
        self.git(self.source, 'commit', '-qm', 'fixture application input contract')
        self.git(self.target, 'fetch', '-q', 'origin')
        self.git(self.target, 'merge', '-q', '--ff-only', 'FETCH_HEAD')
        self.set_sparse('/*\n!/docs/evidence/**\n!/game/**\n')
        plan = inputs.make_plan(self.target, checks=['run-session'])
        self.assertEqual({row['path'] for row in plan['inputs']}, {selected})
        self.assertEqual(plan['status'], 'needs_materialization')
        report = inputs.materialize(self.target, checks=['run-session'])
        self.assertEqual(report['status'], 'ready')
        self.assertFalse(report['tests_executed'])
        self.assertEqual((self.target/selected).read_bytes(), (self.source/selected).read_bytes())
        self.assertFalse((self.target/unrelated).exists())

    def test_plan_reports_exact_historical_blob_size_without_hydrating(self):
        plan = self.plan()
        self.assertEqual(plan['status'], 'needs_materialization')
        self.assertEqual(plan['checks'], ['historical'])
        row = plan['inputs'][0]
        self.assertEqual(row['commit'], self.head)
        self.assertEqual(row['blob'], self.historical_blob)
        self.assertEqual(row['path'], self.proof)
        self.assertEqual(row['size'], (self.source / self.proof).stat().st_size)
        self.assertTrue(row['materializable'])
        self.assertFalse((self.target / self.proof).exists())
        self.assertFalse((self.target / self.unrelated).exists())

    def test_explicit_hydration_runs_original_historical_consumer(self):
        before = (self.target / '.git/info/sparse-checkout').read_bytes()
        report = self.hydrate()
        self.assertEqual(report['status'], 'ready')
        self.assertEqual((self.target / self.proof).read_bytes(), (self.source / self.proof).read_bytes())
        self.assertEqual(report['materialized'][0]['blob'], self.historical_blob)
        self.assertFalse(report['tests_executed'])
        self.assertEqual((self.target / '.git/info/sparse-checkout').read_bytes(), before)
        self.assertFalse((self.target / self.unrelated).exists())
        result = subprocess.run([sys.executable, 'tools/historical.py'], cwd=self.target, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('HISTORICAL FIXTURE: passed', result.stdout)

    def test_profile_selects_same_existing_preflight(self):
        with patch.object(inputs.production, 'required_input_preflight', wraps=inputs.production.required_input_preflight) as existing:
            plan = inputs.make_plan(self.target, profiles=['historical-only'])
        self.assertEqual(existing.call_count, 1)
        self.assertEqual(plan['checks'], ['historical'])
        self.assertEqual([row['path'] for row in plan['inputs']], [self.proof])

    def test_direction_refusal_snapshots_hydrate_without_unrelated_evidence(self):
        snapshots = ['docs/evidence/four_line_integration_20261023/direction-history/'
                     + region + '-' + revision + '.json'
                     for region in ('windchime_plains', 'thorn_forest')
                     for revision in ('v10-before-hud-layout', 'v12-before-foreground-cpu')]
        for name in snapshots:
            path = self.source / name
            path.parent.mkdir(parents=True, exist_ok=True)
            version = 'creative-v12' if '-v12-' in name else 'creative-v10'
            path.write_text(json.dumps({'version': version}) + '\n')
        runner = self.source / 'tests/test_region_creative_direction.py'
        runner.parent.mkdir(exist_ok=True)
        runner.write_text('print("direction fixture")\n')
        manifest = copy.deepcopy(self.manifest)
        manifest['checks']['direction'] = {'argv': ['python3', runner.relative_to(self.source).as_posix()],
                                           'timeout_seconds': 10, 'success_pattern': '^direction fixture$'}
        (self.source / 'tools/harness/profiles.json').write_text(json.dumps(manifest))
        self.git(self.source, 'add', '.')
        self.git(self.source, 'commit', '-qm', 'direction snapshot inputs')
        self.git(self.target, 'fetch', '-q', 'origin')
        self.git(self.target, 'merge', '-q', '--ff-only', 'FETCH_HEAD')
        plan = inputs.make_plan(self.target, checks=['direction'])
        self.assertEqual({row['path'] for row in plan['inputs']}, set(snapshots))
        report = inputs.materialize(self.target, checks=['direction'])
        self.assertEqual(report['status'], 'ready')
        self.assertEqual({row['path'] for row in report['materialized']}, set(snapshots))
        for name in snapshots:
            self.assertEqual((self.target / name).read_bytes(), (self.source / name).read_bytes())
        self.assertFalse((self.target / self.unrelated).exists())

    def test_encounter_portable_restore_hydrates_only_two_endpoint_inputs(self):
        endpoint = 'docs/evidence/plains_redesign/encounter/frozen_50fb10c/'
        required = {endpoint + 'manifest.json': b'{"portable":"endpoint fixture"}\n',
                    endpoint + 'delta.tar.gz': b'immutable endpoint archive fixture\n'}
        for name, content in required.items():
            path = self.source / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(content)
        runner = 'tools/run_plains_encounter_policy_tests.py'
        (self.source / runner).write_text('print("encounter fixture")\n')
        manifest = copy.deepcopy(self.manifest)
        for check, flags in [('plains-encounter-policy', []),
                             ('plains-encounter-policy-with-legacy', ['--with-legacy'])]:
            manifest['checks'][check] = {'argv': ['python3', runner, *flags],
                                        'timeout_seconds': 10,
                                        'success_pattern': '^encounter fixture$'}
        (self.source / 'tools/harness/profiles.json').write_text(json.dumps(manifest))
        self.git(self.source, 'add', '.')
        self.git(self.source, 'commit', '-qm', 'encounter portable boundary endpoint inputs')
        self.git(self.target, 'fetch', '-q', 'origin')
        self.git(self.target, 'merge', '-q', '--ff-only', 'FETCH_HEAD')
        patterns = (self.target / '.git/info/sparse-checkout').read_bytes()
        for check in ('plains-encounter-policy', 'plains-encounter-policy-with-legacy'):
            plan = inputs.make_plan(self.target, checks=[check])
            self.assertEqual({row['path'] for row in plan['inputs']}, set(required))
            self.assertTrue(all(row['required_by'] == ['selected encounter boundary portable restore']
                                for row in plan['inputs']))
        self.assertEqual({row['path'] for row in self.plan()['inputs']}, {self.proof})
        report = inputs.materialize(self.target, checks=['plains-encounter-policy'])
        self.assertEqual(report['status'], 'ready')
        self.assertEqual({row['path'] for row in report['materialized']}, set(required))
        self.assertEqual(report['materialized_bytes'], sum(map(len, required.values())))
        self.assertFalse(report['tests_executed'])
        for row in report['materialized']:
            self.assertEqual((self.target / row['path']).read_bytes(), required[row['path']])
            self.assertEqual(row['blob'], self.git(self.source, 'rev-parse', 'HEAD:' + row['path']))
        self.assertFalse((self.target / self.proof).exists())
        self.assertFalse((self.target / self.unrelated).exists())
        self.assertEqual((self.target / '.git/info/sparse-checkout').read_bytes(), patterns)
        self.assertEqual(inputs.make_plan(self.target, checks=['plains-encounter-policy-with-legacy'])['status'], 'ready')

    def test_missing_quality_index_hydrates_then_reveals_actual_evidence_edge(self):
        self.set_sparse('/*\n!/docs/evidence/**\n!/docs/quality/records/**\n')
        plan = inputs.make_plan(self.target, checks=['quality'])
        self.assertEqual([r['path'] for r in plan['inputs']], ['docs/quality/records/OLD.json'])
        report = inputs.materialize(self.target, checks=['quality'])
        self.assertEqual(report['status'], 'ready')
        self.assertEqual(len(report['rounds']), 2)
        self.assertEqual({r['path'] for r in report['materialized']}, {'docs/quality/records/OLD.json', self.proof})
        self.assertFalse((self.target / self.unrelated).exists())

    def test_ordinary_deletion_is_not_repaired(self):
        self.hydrate()
        self.git(self.target, 'update-index', '--no-skip-worktree', self.proof)
        (self.target / self.proof).unlink()
        report = self.hydrate()
        self.assertEqual(report['status'], 'blocked')
        self.assertEqual(report['materialized'], [])
        self.assertFalse((self.target / self.proof).exists())

    def test_existing_local_edit_is_never_overwritten_by_stale_plan(self):
        row = self.plan()['inputs'][0]
        path = self.target / self.proof
        path.parent.mkdir(parents=True)
        path.write_text('local edit')
        with self.assertRaisesRegex(inputs.InputError, 'locally present'):
            inputs.restore_input(self.target, row)
        self.assertEqual(path.read_text(), 'local edit')

    def test_staged_index_drift_is_refused(self):
        row = self.plan()['inputs'][0]
        other = self.git(self.target, 'rev-parse', 'HEAD:' + self.unrelated)
        self.git(self.target, 'update-index', '--cacheinfo', '100644,' + other + ',' + self.proof)
        with self.assertRaisesRegex(inputs.InputError, 'index differs'):
            self.plan()
        with self.assertRaises(inputs.InputError):
            inputs.restore_input(self.target, row)
        self.assertFalse((self.target / self.proof).exists())

    def test_wrong_commit_is_refused_even_when_fixture_blob_matches(self):
        with self.assertRaisesRegex(inputs.InputError, 'exact current'):
            self.plan(commit=self.historical_commit)

    def test_planned_wrong_blob_or_size_is_refused(self):
        row = self.plan()['inputs'][0]
        with self.assertRaises(inputs.InputError):
            inputs.restore_input(self.target, row | {'blob': '1' * 40})
        with self.assertRaisesRegex(inputs.InputError, 'SHA/size differs'):
            inputs.restore_input(self.target, row | {'size': row['size'] + 1})
        self.assertFalse((self.target / self.proof).exists())

    def test_path_escape_and_symlink_ancestors_are_refused(self):
        row = self.plan()['inputs'][0]
        for path in ('../outside', '/outside', 'docs/../outside', 'docs\\outside', '.git/config', 'docs//outside'):
            with self.subTest(path=path), self.assertRaises(inputs.InputError):
                inputs.restore_input(self.target, row | {'path': path})
        outside = self.base / 'outside'
        outside.mkdir()
        (self.target / 'docs/evidence').symlink_to(outside, target_is_directory=True)
        with self.assertRaisesRegex(inputs.InputError, 'Symlink'):
            self.plan()
        self.assertEqual(list(outside.iterdir()), [])

    def test_object_corruption_fails_without_creating_target(self):
        object_path = self.target / '.git/objects' / self.historical_blob[:2] / self.historical_blob[2:]
        object_path.chmod(0o644)
        object_path.write_bytes(b'corrupt object')
        with contextlib.redirect_stdout(io.StringIO()) as output:
            result = inputs.main(['--root', str(self.target), '--check', 'historical', '--materialize'])
        self.assertEqual(result, 1)
        self.assertEqual(json.loads(output.getvalue())['status'], 'blocked')
        self.assertFalse((self.target / self.proof).exists())

    def test_absent_blob_size_is_explicit_and_no_implicit_fetch_occurs(self):
        object_path = self.target / '.git/objects' / self.historical_blob[:2] / self.historical_blob[2:]
        object_path.unlink()
        plan = self.plan()
        self.assertEqual(plan['unknown_size_objects'], [self.historical_blob])
        self.assertIsNone(plan['inputs'][0]['size'])
        self.assertFalse(object_path.exists())
        with contextlib.redirect_stdout(io.StringIO()):
            result = inputs.main(['--root', str(self.target), '--check', 'historical', '--materialize'])
        self.assertEqual(result, 1)
        self.assertFalse((self.target / self.proof).exists())

    def test_untracked_build_reports_do_not_block_selected_hydration(self):
        report = self.target / 'build/other/report.json'
        report.parent.mkdir(parents=True)
        report.write_text('{"unrelated":"unfinished"}')
        self.assertEqual(self.hydrate()['status'], 'ready')
        self.assertTrue(report.exists())

    def test_skip_flag_without_real_sparse_checkout_is_not_hydrated(self):
        self.git(self.target, 'config', '--worktree', 'core.sparseCheckout', 'false')
        report = self.hydrate()
        self.assertEqual(report['status'], 'blocked')
        self.assertFalse((self.target / self.proof).exists())

    def test_staged_deleted_required_input_or_runner_cannot_disappear_from_plan(self):
        for path in (self.proof, 'tools/historical.py'):
            with self.subTest(path=path):
                self.git(self.target, 'update-index', '--force-remove', path)
                with self.assertRaisesRegex(inputs.InputError, 'HEAD/index path structure changed'):
                    self.plan()
                self.git(self.target, 'reset', '-q', 'HEAD', '--', path)

    def test_bounded_prefetch_restores_selected_blob_without_unrelated_missing_blob(self):
        self.git(self.source, 'config', 'uploadpack.allowFilter', 'true')
        self.git(self.source, 'config', 'uploadpack.allowAnySHA1InWant', 'true')
        self.git(self.target, 'remote', 'set-url', 'origin', self.source.as_uri())
        self.git(self.target, 'config', 'remote.origin.promisor', 'true')
        self.git(self.target, 'config', 'remote.origin.partialclonefilter', 'blob:none')
        # Use the real Git transport: ambient negotiation settings must not
        # override the same noop mode Git uses for promisor lazy fetching.
        self.git(self.target, 'config', 'fetch.negotiationAlgorithm', 'skipping')
        unrelated_blob = self.git(self.target, 'rev-parse', 'HEAD:' + self.unrelated)
        for oid in (self.historical_blob, unrelated_blob):
            (self.target / '.git/objects' / oid[:2] / oid[2:]).unlink()
        self.assertIsNone(self.plan()['inputs'][0]['size'])
        report = self.hydrate()
        self.assertEqual(report['status'], 'ready')
        self.assertEqual(report['prefetch'][0]['objects'], [self.historical_blob])
        self.assertEqual(report['prefetch'][0]['status'], 'fetched')
        self.assertEqual(inputs.blob_sizes(self.target, [unrelated_blob]), {unrelated_blob: None})
        self.assertFalse((self.target / self.unrelated).exists())

    def test_prefetch_failure_has_nonzero_cli_and_retained_failure_record(self):
        object_path = self.target / '.git/objects' / self.historical_blob[:2] / self.historical_blob[2:]
        object_path.unlink()
        self.git(self.target, 'config', 'remote.origin.promisor', 'true')
        self.git(self.target, 'remote', 'set-url', 'origin', (self.base / 'missing-remote').as_uri())
        with contextlib.redirect_stdout(io.StringIO()) as output:
            code = inputs.main(['--root', str(self.target), '--check', 'historical', '--materialize', '--output', 'build/failed-prefetch.json'])
        report = json.loads(output.getvalue())
        self.assertEqual(code, 1)
        self.assertEqual(report['prefetch'][0]['status'], 'failed')
        self.assertNotEqual(report['prefetch'][0]['exit_code'], 0)
        self.assertFalse((self.target / self.proof).exists())
        self.assertEqual(json.loads((self.target / 'build/failed-prefetch.json').read_text())['status'], 'blocked')

    def test_report_output_cannot_overwrite_source_existing_evidence_or_old_report(self):
        old_report = self.target / 'build/previous.json'
        old_report.parent.mkdir()
        old_report.write_text('original report')
        targets = (self.target / 'tools/historical.py', self.target / 'docs/tasks.md', old_report)
        originals = {path: path.read_bytes() for path in targets}
        for path in targets:
            with self.subTest(path=path), contextlib.redirect_stdout(io.StringIO()) as stdout:
                self.assertEqual(inputs.main(['--root', str(self.target), '--check', 'historical', '--output', str(path)]), 1)
                self.assertEqual(json.loads(stdout.getvalue())['status'], 'blocked')
                self.assertEqual(path.read_bytes(), originals[path])

    def test_report_output_rejects_symlink_ancestor_and_traversal(self):
        outside = self.base / 'outside'
        outside.mkdir()
        (self.target / 'build').symlink_to(outside, target_is_directory=True)
        for path in ('build/report.json', 'build/../docs/new.json', str(outside / 'new.json')):
            with self.subTest(path=path), contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(inputs.main(['--root', str(self.target), '--check', 'historical', '--output', path]), 1)
        self.assertEqual(list(outside.iterdir()), [])

    def test_new_build_report_is_available_without_claiming_test_execution(self):
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(inputs.main(['--root', str(self.target), '--check', 'historical', '--output', 'build/new/report.json']), 2)
        report = json.loads((self.target / 'build/new/report.json').read_text())
        self.assertFalse(report['tests_executed'])
        self.assertEqual(report['status'], 'needs_materialization')

    def test_cli_codes_distinguish_ready_missing_and_failure(self):
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(inputs.main(['--root', str(self.target), '--check', 'historical']), 2)
            self.assertEqual(inputs.main(['--root', str(self.target), '--check', 'historical', '--materialize']), 0)
            self.assertEqual(inputs.main(['--root', str(self.target), '--check', 'unknown']), 1)
        env = os.environ.copy()
        env['PYTHONPATH'] = str(Path(inputs.production.__file__).parent)
        result = subprocess.run([sys.executable, str(Path(inputs.__file__)), '--root', str(self.target), '--profile', 'not-a-profile'], env=env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(json.loads(result.stdout)['status'], 'blocked')


if __name__ == '__main__':
    unittest.main()
