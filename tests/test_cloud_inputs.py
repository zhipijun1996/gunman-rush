"""Real temporary sparse Git worktrees and historical consumers; no fake PASS."""
import contextlib
import copy
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import tarfile
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


class CloudInputBundleTests(unittest.TestCase):
    """Real same-source sparse clones; archive bytes never supply Git authority."""
    git = CloudInputsTests.git
    set_sparse = CloudInputsTests.set_sparse

    def setUp(self):
        CloudInputsTests.setUp(self)
        self.executable = 'docs/evidence/historical/consumer.sh'
        executable = self.source / self.executable
        executable.write_text('#!/bin/sh\nprintf "BUNDLE EXECUTABLE: passed\\n"\n')
        executable.chmod(0o755)
        self.manifest['checks']['historical']['inputs'].append(self.executable)
        self.manifest['profiles']['full'] = ['historical']
        self.update_source('same-source bundle fixture')
        self.bundle = self.target / 'build/bundle'
        self.plan_path = self.target / 'build/plan.json'
        self.receipt = self.target / 'build/inputs.json'
        self.run_id = '123456'

    def update_source(self, message):
        (self.source / 'tools/harness/profiles.json').write_text(json.dumps(self.manifest))
        self.git(self.source, 'add', '.')
        self.git(self.source, 'commit', '-qm', message)
        self.git(self.target, 'fetch', '-q', 'origin')
        self.git(self.target, 'merge', '-q', '--ff-only', 'FETCH_HEAD')
        self.head = self.git(self.target, 'rev-parse', 'HEAD')

    def package(self):
        report = inputs.materialize(self.target, profiles=['full'])
        self.receipt.parent.mkdir(parents=True, exist_ok=True)
        self.receipt.write_text(json.dumps(report))
        self.plan_path.write_text(json.dumps({'source_commit': self.head, 'ci_route': 'full_lanes', 'checks': ['historical']}))
        result = inputs.export_bundle(self.target, [], ['full'], 'HEAD', self.plan_path, self.run_id,
                                      [self.receipt], self.bundle)
        self.assertEqual(result['status'], 'ready')
        return result

    def consumer(self, name='consumer'):
        root = self.base / name
        subprocess.run(['git', 'clone', '-q', '--local', '--no-hardlinks', str(self.target), str(root)], check=True)
        self.git(root, 'sparse-checkout', 'init', '--no-cone')
        subprocess.run(['git', '-C', str(root), 'sparse-checkout', 'set', '--no-cone', '--stdin'],
                       input='/*\n!/docs/evidence/**\n', text=True, check=True, capture_output=True)
        (root / 'build').mkdir()
        (root / 'build/plan.json').write_bytes(self.plan_path.read_bytes())
        return root

    def restore(self, root, **kwargs):
        return inputs.restore_bundle(root, [], ['full'], 'HEAD', root / 'build/plan.json', self.run_id, self.bundle, **kwargs)

    def bundle_manifest(self):
        return json.loads((self.bundle / 'manifest.json').read_text())

    def write_manifest(self, manifest):
        (self.bundle / 'manifest.json').write_text(json.dumps(manifest))

    def rewrite_tar(self, transform, manifest=None):
        with tarfile.open(self.bundle / 'inputs.tar', 'r:') as archive:
            members = [(copy.copy(member), archive.extractfile(member).read()) for member in archive]
        members = transform(members)
        with tarfile.open(self.bundle / 'inputs.tar', 'w', format=tarfile.PAX_FORMAT) as archive:
            for member, data in members:
                archive.addfile(member, io.BytesIO(data) if member.isreg() else None)
        manifest = self.bundle_manifest() if manifest is None else manifest
        raw = (self.bundle / 'inputs.tar').read_bytes()
        manifest.update(archive_size=len(raw), archive_sha256=hashlib.sha256(raw).hexdigest())
        self.write_manifest(manifest)

    def test_same_run_bundle_restores_real_consumer_executable_and_original_preflight(self):
        package = self.package()
        root = self.consumer()
        patterns = (root / '.git/info/sparse-checkout').read_bytes()
        with patch.object(inputs, 'restore_input', side_effect=AssertionError('per-file Git restore forbidden')), \
                patch.object(inputs, 'prefetch_blobs', side_effect=AssertionError('network fetch forbidden')), \
                patch.object(inputs.production, 'required_input_preflight', wraps=inputs.production.required_input_preflight) as preflight:
            report = self.restore(root)
        self.assertEqual(report['status'], 'ready')
        self.assertFalse(report['tests_executed'])
        self.assertEqual(report['restored_files'], 2)
        self.assertEqual(report['source_run_id'], self.run_id)
        self.assertEqual(report['archive_sha256'], package['archive_sha256'])
        self.assertEqual(preflight.call_count, 1)
        self.assertEqual((root / '.git/info/sparse-checkout').read_bytes(), patterns)
        self.assertFalse((root / self.unrelated).exists())
        result = subprocess.run([sys.executable, 'tools/historical.py'], cwd=root, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        result = subprocess.run([str(root / self.executable)], cwd=root, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, 'BUNDLE EXECUTABLE: passed\n')
        self.assertEqual(self.restore(root)['restored_files'], 0)

    def test_restore_checks_current_git_not_rebound_manifest_or_outer_archive_hash(self):
        self.package()
        root = self.consumer()
        original = self.bundle_manifest()
        for field, value in [('source_run_id', '999'), ('source_commit', '1' * 40),
                             ('execution_plan_sha256', '1' * 64), ('checks', ['quality'])]:
            with self.subTest(field=field):
                self.write_manifest({**original, field: value})
                with self.assertRaises(inputs.InputError): self.restore(root)
                self.assertFalse((root / self.proof).exists())
        for field, value in [('mode', '100755'), ('blob', '1' * 40)]:
            with self.subTest(field=field):
                changed = copy.deepcopy(original)
                row = next(row for row in changed['files'] if row['path'] == self.proof)
                row[field] = value
                self.write_manifest(changed)
                with self.assertRaisesRegex(inputs.InputError, 'HEAD/index'): self.restore(root)
        self.write_manifest(original)
        changed = copy.deepcopy(original)
        def alter(members):
            result = []
            for member, data in members:
                if member.name == self.proof:
                    data = data.replace(b'"version":1', b'"version":2')
                    row = next(row for row in changed['files'] if row['path'] == self.proof)
                    row['sha256'] = hashlib.sha256(data).hexdigest()
                result.append((member, data))
            return result
        self.rewrite_tar(alter, changed)  # rebind both SHA256 layers, keep actual HEAD authority.
        with self.assertRaisesRegex(inputs.InputError, 'current Git blob/SHA'): self.restore(root)
        self.assertFalse((root / self.proof).exists())
        self.assertFalse((root / self.executable).exists())

    def test_tar_path_type_mode_missing_duplicate_and_extra_members_are_refused_before_publish(self):
        self.package()
        root = self.consumer()
        archive_bytes = (self.bundle / 'inputs.tar').read_bytes()
        manifest_bytes = (self.bundle / 'manifest.json').read_bytes()
        def change_path(members): members[0][0].name = '../outside'; return members
        def change_type(members):
            members[0][0].type, members[0][0].linkname, members[0][0].size = tarfile.SYMTYPE, '../outside', 0
            return members
        def change_mode(members): members[0][0].mode = 0o777; return members
        for name, transform in [('traversal', change_path), ('symlink', change_type), ('mode', change_mode),
                                ('missing', lambda members: members[:-1]),
                                ('duplicate', lambda members: [members[0], members[0], *members[1:]]),
                                ('extra', lambda members: [*members, members[0]])]:
            with self.subTest(name=name):
                (self.bundle / 'inputs.tar').write_bytes(archive_bytes)
                (self.bundle / 'manifest.json').write_bytes(manifest_bytes)
                self.rewrite_tar(transform)
                with self.assertRaises(inputs.InputError): self.restore(root)
                self.assertFalse((root / self.proof).exists())
                self.assertFalse((root / self.executable).exists())
                self.assertFalse((self.base / 'outside').exists())

    def test_rebound_trailing_or_truncated_tar_is_not_a_successful_input_artifact(self):
        self.package()
        original = self.bundle_manifest()
        archive_path = self.bundle / 'inputs.tar'
        archive = archive_path.read_bytes()
        for number, payload in enumerate((archive + b'unlisted trailing payload', b'not a tar archive', archive[:700])):
            root = self.consumer('bad-tar-' + str(number))
            archive_path.write_bytes(payload)
            changed = copy.deepcopy(original)
            changed.update(archive_size=len(payload), archive_sha256=hashlib.sha256(payload).hexdigest())
            self.write_manifest(changed)
            with self.subTest(number=number), contextlib.redirect_stdout(io.StringIO()) as output:
                code = inputs.main(['--root', str(root), '--profile', 'full', '--restore-bundle', str(self.bundle),
                                    '--execution-plan', str(root / 'build/plan.json'), '--run-id', self.run_id,
                                    '--output', 'build/bad-tar.json'])
            self.assertEqual(code, 1)
            self.assertEqual(json.loads(output.getvalue())['status'], 'blocked')
            self.assertFalse((root / self.proof).exists())
            self.assertFalse((root / self.executable).exists())

    def test_missing_manifest_and_tar_entry_cannot_forge_complete_selected_coverage(self):
        self.package()
        root = self.consumer()
        changed = self.bundle_manifest()
        changed['files'] = changed['files'][:1]
        # Rebind the receipt as well: the original preflight must still detect
        # the omitted selected dependency, rather than trusting either layer.
        receipt = json.loads(self.receipt.read_text())
        receipt['materialized'] = [row for row in receipt['materialized']
                                   if row['path'] == changed['files'][0]['path']]
        raw = json.dumps(receipt).encode()
        digest = hashlib.sha256(raw).hexdigest()
        (self.bundle / 'receipts' / (digest + '.json')).write_bytes(raw)
        changed['source_receipts'][0].update(sha256=digest, files=1)
        self.rewrite_tar(lambda members: members[:1], changed)
        with self.assertRaisesRegex(inputs.InputError, 'original selected preflight'): self.restore(root)
        self.assertFalse((root / self.proof).exists())
        self.assertFalse((root / self.executable).exists())

    def test_original_receipt_bytes_scope_and_file_inventory_are_verified(self):
        self.package()
        root = self.consumer()
        original = self.bundle_manifest()
        source = original['source_receipts'][0]
        path = self.bundle / 'receipts' / (source['sha256'] + '.json')
        raw = path.read_bytes()
        self.assertEqual(hashlib.sha256(raw).hexdigest(), source['sha256'])
        path.write_bytes(raw + b'\n')
        with self.assertRaisesRegex(inputs.InputError, 'Original prepare receipt SHA'): self.restore(root)
        path.write_bytes(raw)
        for field, value in [('files', 1), ('checks', []), ('path', 'build/../outside')]:
            changed = copy.deepcopy(original)
            changed['source_receipts'][0][field] = value
            self.write_manifest(changed)
            with self.subTest(field=field), self.assertRaises(inputs.InputError): self.restore(root)
            self.assertFalse((root / self.proof).exists())
        changed = copy.deepcopy(original)
        changed['files'] = changed['files'][:1]
        self.write_manifest(changed)
        with self.assertRaisesRegex(inputs.InputError, 'original prepare receipt inputs'): self.restore(root)
        self.assertFalse((root / self.proof).exists())
        self.write_manifest(original)
        path.unlink()
        with self.assertRaises(FileNotFoundError): self.restore(root)
        self.assertFalse((root / self.proof).exists())
        outside = self.base / 'outside-receipt.json'
        outside.write_bytes(raw)
        path.symlink_to(outside)
        with self.assertRaisesRegex(inputs.InputError, 'Symlink'): self.restore(root)
        self.assertEqual(outside.read_bytes(), raw)
        self.assertFalse((root / self.proof).exists())

    def test_malformed_manifest_or_receipt_types_produce_structured_cli_refusal(self):
        self.package()
        original = self.bundle_manifest()
        malformed = [[], {'source_receipts': []}, {**original, 'source_receipts': [{
            **original['source_receipts'][0], 'checks': [{}]}]}]
        for number, value in enumerate(malformed):
            root = self.consumer('malformed-' + str(number))
            self.write_manifest(value)
            with self.subTest(number=number), contextlib.redirect_stdout(io.StringIO()) as output:
                result = inputs.main(['--root', str(root), '--profile', 'full', '--restore-bundle', str(self.bundle),
                                      '--execution-plan', str(root / 'build/plan.json'), '--run-id', self.run_id,
                                      '--output', 'build/refused.json'])
            self.assertEqual(result, 1)
            self.assertEqual(json.loads(output.getvalue())['status'], 'blocked')
            self.assertEqual(json.loads((root / 'build/refused.json').read_text())['status'], 'blocked')
            self.assertFalse((root / self.proof).exists())
        self.write_manifest(original)
        receipt = json.loads(self.receipt.read_text())
        for number, field in enumerate(('checks', 'materialized')):
            value = copy.deepcopy(receipt)
            value[field] = [{}] if field == 'checks' else ['not-an-input']
            self.receipt.write_text(json.dumps(value))
            with self.subTest(receipt_field=field), self.assertRaises(inputs.InputError):
                inputs.export_bundle(self.target, [], ['full'], 'HEAD', self.plan_path, self.run_id,
                                     [self.receipt], self.target / ('build/malformed-' + str(number)))
        self.receipt.write_text(json.dumps(receipt))

    def test_existing_local_edit_mode_or_symlink_is_not_overwritten(self):
        self.package()
        root = self.consumer()
        path = root / self.proof
        path.parent.mkdir(parents=True)
        path.write_bytes((self.target / self.proof).read_bytes())
        inode = path.stat().st_ino
        self.assertEqual(self.restore(root)['already_identical_files'], 1)
        self.assertEqual(path.stat().st_ino, inode)
        path.write_text('local edit')
        with self.assertRaisesRegex(inputs.InputError, 'never overwritten'): self.restore(root)
        self.assertEqual(path.read_text(), 'local edit')
        path.write_bytes((self.target / self.proof).read_bytes()); path.chmod(0o755)
        with self.assertRaisesRegex(inputs.InputError, 'never overwritten'): self.restore(root)
        other = self.consumer('symlink-consumer')
        outside = self.base / 'outside'; outside.mkdir()
        (other / 'docs/evidence').symlink_to(outside, target_is_directory=True)
        with self.assertRaisesRegex(inputs.InputError, 'Symlink'): self.restore(other)
        self.assertEqual(list(outside.iterdir()), [])

    def test_preexisting_unrelated_staged_index_drift_is_not_same_source(self):
        self.package()
        root = self.consumer()
        blob = self.git(root, 'rev-parse', 'HEAD:' + self.proof)
        self.git(root, 'update-index', '--cacheinfo', '100644,' + blob + ',' + self.unrelated)
        with self.assertRaisesRegex(inputs.InputError, 'HEAD/index'):
            self.restore(root)
        self.assertFalse((root / self.proof).exists())
        self.assertEqual(self.git(root, 'rev-parse', ':' + self.unrelated), blob)

    def test_root_relative_plan_and_receipts_and_outside_provenance_paths(self):
        self.package()
        report = inputs.export_bundle(self.target, [], ['full'], 'HEAD', 'build/plan.json', self.run_id,
                                      [Path('build/inputs.json')], 'build/relative-bundle')
        self.assertEqual(report['status'], 'ready')
        root = self.consumer()
        report = inputs.restore_bundle(root, [], ['full'], 'HEAD', 'build/plan.json', self.run_id, self.bundle)
        self.assertEqual(report['status'], 'ready')
        outside = self.base / 'outside-plan.json'
        outside.write_bytes(self.plan_path.read_bytes())
        with self.assertRaisesRegex(inputs.InputError, 'worktree build/'):
            inputs.restore_bundle(root, [], ['full'], 'HEAD', outside, self.run_id, self.bundle)
        outside = self.base / 'outside-receipt.json'
        outside.write_bytes(self.receipt.read_bytes())
        with self.assertRaisesRegex(inputs.InputError, 'worktree build/'):
            inputs.export_bundle(self.target, [], ['full'], 'HEAD', self.plan_path, self.run_id,
                                 [outside], 'build/outside-receipt-bundle')

    def test_head_or_index_change_during_staging_or_publish_cannot_succeed(self):
        self.package()
        for phase, mutate, trigger in [('stage-head', 'head', 2), ('publish-index', 'index', 3),
                                       ('preflight-index', 'index', 5)]:
            root = self.consumer(phase)
            real = inputs.repository_state
            calls = 0
            def drift(*args, **kwargs):
                nonlocal calls
                calls += 1
                if calls == trigger:
                    if mutate == 'head': self.git(root, '-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '--allow-empty', '-qm', 'concurrent HEAD change')
                    else:
                        blob = self.git(root, 'rev-parse', 'HEAD:' + self.unrelated)
                        self.git(root, 'update-index', '--cacheinfo', '100644,' + blob + ',' + self.proof)
                return real(*args, **kwargs)
            with self.subTest(phase=phase), patch.object(inputs, 'repository_state', side_effect=drift):
                with self.assertRaises(inputs.InputError): self.restore(root)
                self.assertFalse((root / self.proof).exists())
                self.assertFalse((root / self.executable).exists())

    def test_bulk_restore_uses_bounded_git_snapshots_and_visible_progress(self):
        for number in range(25):
            name = 'docs/evidence/historical/bulk-' + str(number) + '.bin'
            (self.source / name).write_bytes(bytes([number]) * 4096)
            self.manifest['checks']['historical']['inputs'].append(name)
        self.update_source('bulk selected input fixture')
        self.package()
        root = self.consumer()
        events = []
        with patch.object(inputs, 'repository_state', wraps=inputs.repository_state) as repository:
            result = self.restore(root, progress=events.append)
        self.assertEqual(result['files'], 27)
        self.assertLessEqual(repository.call_count, 5, 'No two Git subprocess groups per file')
        self.assertEqual(events[-1]['phase'], 'bundle_restore_complete')
        self.assertEqual(events[-1]['files'], 27)

    def test_bundle_reports_actual_disk_volume_and_phase_timing_without_claiming_capacity(self):
        report = self.package()
        before = report['storage']['before']
        self.assertEqual(before['archive_required_bytes'], report['archive_size'])
        self.assertGreaterEqual(before['required_additional_bytes'], report['archive_size'])
        self.assertTrue(before['allocation_lower_bound'])
        self.assertGreater(before['total_bytes'], 0)
        self.assertGreaterEqual(before['wall_seconds'], 0)
        root = self.consumer()
        events = []
        result = self.restore(root, progress=events.append)
        restored = result['storage']['before']
        self.assertEqual(restored['required_additional_bytes'], result['bytes'])
        self.assertEqual(restored['archive_bytes'], report['archive_size'])
        self.assertEqual([event['phase'] for event in events if '_disk_' in event['phase']],
                         ['bundle_restore_disk_before', 'bundle_restore_disk_after'])
        self.assertEqual(events[-1]['phase'], 'bundle_restore_complete')
        self.assertTrue(result['storage']['after']['allocation_lower_bound'])

    def test_export_proved_disk_deficit_fails_before_writing_bundle(self):
        materialized = inputs.materialize(self.target, profiles=['full'])
        self.receipt.parent.mkdir(parents=True, exist_ok=True)
        self.receipt.write_text(json.dumps(materialized))
        self.plan_path.write_text(json.dumps({'source_commit': self.head, 'ci_route': 'full_lanes', 'checks': ['historical']}))
        events = []
        with patch.object(inputs.shutil, 'disk_usage', return_value=shutil._ntuple_diskusage(1024, 1024, 0)):
            with self.assertRaisesRegex(inputs.InputError, 'Insufficient disk space') as failure:
                inputs.export_bundle(self.target, [], ['full'], 'HEAD', self.plan_path, self.run_id,
                                     [self.receipt], self.bundle, progress=events.append)
        self.assertFalse(self.bundle.exists())
        self.assertEqual(failure.exception.details['free_bytes'], 0)
        self.assertGreater(failure.exception.details['required_additional_bytes'], 0)
        self.assertEqual(events[-1]['phase'], 'bundle_export_disk_before')

    def test_restore_proved_disk_deficit_preserves_archive_and_existing_inputs(self):
        self.package()
        root = self.consumer()
        archive = (self.bundle / 'inputs.tar').read_bytes()
        existing = root / self.proof
        existing.parent.mkdir(parents=True, exist_ok=True)
        existing.write_bytes((self.target / self.proof).read_bytes())
        with patch.object(inputs.shutil, 'disk_usage', return_value=shutil._ntuple_diskusage(1024, 1024, 0)):
            with self.assertRaisesRegex(inputs.InputError, 'Insufficient disk space'):
                self.restore(root)
        self.assertEqual(existing.read_bytes(), (self.target / self.proof).read_bytes())
        self.assertFalse((root / self.executable).exists())
        self.assertFalse(list((root / 'build').glob('selected-input-stage-*')))
        self.assertEqual((self.bundle / 'inputs.tar').read_bytes(), archive)

    def test_tar_size_accounting_includes_long_utf8_pax_headers_and_record_padding(self):
        rows = [{'path': 'docs/' + '原始数据-' * 40 + '.json', 'size': 513, 'mode': '100644'},
                {'path': 'consumer.sh', 'size': 3, 'mode': '100755'}]
        output = io.BytesIO()
        with tarfile.open(fileobj=output, mode='w|', format=tarfile.PAX_FORMAT) as archive:
            for row in rows:
                info = tarfile.TarInfo(row['path'])
                info.size, info.mode, info.mtime = row['size'], (0o755 if row['mode'] == '100755' else 0o644), 0
                archive.addfile(info, io.BytesIO(b'x' * row['size']))
        self.assertEqual(inputs.tar_required_bytes(rows), len(output.getvalue()))

    def test_real_long_utf8_git_path_roundtrips_only_its_needed_pax_path_metadata(self):
        name = 'docs/evidence/historical/' + 'frozen-source-' * 10 + '/原始说明.json'
        path = self.source / name
        path.parent.mkdir(parents=True)
        payload = '{"真实输入":"preserved, not a new generated fixture"}\n'.encode()
        path.write_bytes(payload)
        self.manifest['checks']['historical']['inputs'].append(name)
        self.update_source('long UTF-8 exact Git input fixture')
        self.package()
        with tarfile.open(self.bundle / 'inputs.tar') as archive:
            self.assertEqual(archive.getmember(name).pax_headers, {'path': name})
        root = self.consumer()
        self.assertEqual(self.restore(root)['files'], 3)
        self.assertEqual((root / name).read_bytes(), payload)
        negative = self.consumer('unexpected-pax-consumer')
        def extra_metadata(members):
            for member, data in members:
                if member.name == name:
                    member.pax_headers['comment'] = 'unadmitted metadata'
            return members
        self.rewrite_tar(extra_metadata)
        with self.assertRaisesRegex(inputs.InputError, 'bundle member'):
            self.restore(negative)
        self.assertFalse((negative / name).exists())
        self.assertFalse((negative / self.proof).exists())

    def test_export_refuses_changed_source_or_failed_receipt_and_cli_has_real_progress(self):
        self.package()
        root = self.consumer()
        with contextlib.redirect_stdout(io.StringIO()) as stdout, contextlib.redirect_stderr(io.StringIO()) as stderr:
            code = inputs.main(['--root', str(root), '--profile', 'full', '--restore-bundle', str(self.bundle),
                                '--execution-plan', str(root / 'build/plan.json'), '--run-id', self.run_id,
                                '--progress', '--output', 'build/restored.json'])
        self.assertEqual(code, 0)
        self.assertEqual(json.loads(stdout.getvalue())['status'], 'ready')
        self.assertIn('bundle_restore_complete', stderr.getvalue())
        self.assertFalse(json.loads((root / 'build/restored.json').read_text())['tests_executed'])
        original = json.loads(self.receipt.read_text())
        self.receipt.write_text(json.dumps({**original, 'status': 'blocked'}))
        with self.assertRaisesRegex(inputs.InputError, 'successful same-source'):
            inputs.export_bundle(self.target, [], ['full'], 'HEAD', self.plan_path, self.run_id,
                                 [self.receipt], self.target / 'build/refused')
        self.receipt.write_text(json.dumps(original))
        (self.target / self.proof).write_text('changed after prepare')
        with self.assertRaises(inputs.InputError):
            inputs.export_bundle(self.target, [], ['full'], 'HEAD', self.plan_path, self.run_id,
                                 [self.receipt], self.target / 'build/changed')

    def test_archive_hash_corruption_wrong_run_and_sparse_ordinary_deletion_are_rejected(self):
        self.package()
        root = self.consumer()
        original = (self.bundle / 'inputs.tar').read_bytes()
        (self.bundle / 'inputs.tar').write_bytes(original[:-1] + bytes([original[-1] ^ 1]))
        with self.assertRaisesRegex(inputs.InputError, 'archive SHA/size'): self.restore(root)
        (self.bundle / 'inputs.tar').write_bytes(original)
        with self.assertRaisesRegex(inputs.InputError, 'source/run/plan'):
            inputs.restore_bundle(root, [], ['full'], 'HEAD', root / 'build/plan.json', '654321', self.bundle)
        self.git(root, 'update-index', '--no-skip-worktree', self.proof)
        with self.assertRaisesRegex(inputs.InputError, 'not a sparse input'): self.restore(root)
        self.assertFalse((root / self.proof).exists())

    def test_no_overwrite_race_and_inplace_edit_survive_failed_import(self):
        self.package()
        root = self.consumer()
        real_link = inputs.os.link
        first = self.manifest['checks']['historical']['inputs'][0]
        def create_local(source, destination, *args, **kwargs):
            if destination == root / first:
                destination.write_text('concurrent local file')
            return real_link(source, destination, *args, **kwargs)
        with patch.object(inputs.os, 'link', side_effect=create_local):
            with self.assertRaises(FileExistsError): self.restore(root)
        self.assertEqual((root / first).read_text(), 'concurrent local file')
        other = self.consumer('inplace-consumer')
        real_state = inputs.repository_state
        calls = 0
        def edit_published(*args, **kwargs):
            nonlocal calls
            calls += 1
            if calls == 3:
                (other / first).write_text('concurrent inplace edit')
            return real_state(*args, **kwargs)
        with patch.object(inputs, 'repository_state', side_effect=edit_published):
            with self.assertRaisesRegex(inputs.InputError, 'never overwritten'): self.restore(other)
        self.assertEqual((other / first).read_text(), 'concurrent inplace edit')

    def test_export_cli_and_provenance_bind_the_current_full_plan(self):
        self.package()
        with contextlib.redirect_stdout(io.StringIO()) as output, contextlib.redirect_stderr(io.StringIO()) as progress:
            result = inputs.main(['--root', str(self.target), '--profile', 'full', '--export-bundle', 'build/cli-bundle',
                                  '--execution-plan', str(self.plan_path), '--run-id', self.run_id,
                                  '--receipt', str(self.receipt), '--progress', '--output', 'build/export.json'])
        self.assertEqual(result, 0)
        self.assertIn('bundle_export_progress', progress.getvalue())
        report = json.loads(output.getvalue())
        self.assertFalse(report['tests_executed'])
        self.assertEqual(report['source_run_id'], self.run_id)
        manifest = json.loads((self.target / 'build/cli-bundle/manifest.json').read_text())
        self.assertEqual(manifest['execution_plan_sha256'], hashlib.sha256(self.plan_path.read_bytes()).hexdigest())
        self.assertEqual(manifest['source_receipts'][0]['sha256'], hashlib.sha256(self.receipt.read_bytes()).hexdigest())
        original = self.manifest['profiles']['full']
        self.plan_path.write_text(json.dumps({'source_commit': self.head, 'ci_route': 'full_lanes', 'checks': ['quality']}))
        with self.assertRaisesRegex(inputs.InputError, 'exact full execution plan'):
            inputs.export_bundle(self.target, [], ['full'], 'HEAD', self.plan_path, self.run_id,
                                 [self.receipt], self.target / 'build/wrong-plan')


if __name__ == '__main__':
    unittest.main()
