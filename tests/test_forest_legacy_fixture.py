"""Real small Git trees and byte restoration; no Godot process or edited old test."""
import gzip
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

ROOT = next(p for p in Path(__file__).resolve().parents
            if (p / 'tools/forest_legacy_fixture.py').is_file())
sys.path.insert(0, str(ROOT / 'tools'))
import forest_legacy_fixture as fixture
import run_forest_v1_regressions as legacy_runner


class FrozenForestTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.repo = self.base / 'source'
        self.repo.mkdir()
        subprocess.run(['git', 'init', '-q', str(self.repo)], check=True)
        for name, data in {
            'scripts/example.gd': b'extends Node\n', 'assets/a.bin': b'actual old asset\x00',
            'project.godot': b'config_version=5\n', 'docs/omitted.md': b'inventory-only\n',
            'tools/harness/profiles.json': json.dumps({'checks': {key: {
                'argv': ['python3', '-c', 'print("original")'], 'timeout_seconds': 7,
                'success_pattern': '^original$', 'serial': True} for key in fixture.CHECK_IDS}}).encode(),
        }.items():
            target = self.repo / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
        subprocess.run(['git', 'add', '.'], cwd=self.repo, check=True)
        subprocess.run(['git', '-c', 'user.name=Fixture Test', '-c', 'user.email=fixture@example.invalid',
                        'commit', '-qm', 'genuine miniature fixture'], cwd=self.repo, check=True)
        self.commit = fixture.git(self.repo, 'rev-parse', 'HEAD').decode().strip()
        self.basis = self.base / 'archive'
        self.manifest = fixture.freeze(self.repo, self.basis, self.commit)
        self.patch = patch.object(fixture, 'BASELINE', self.commit)
        self.patch.start()
        self.addCleanup(self.patch.stop)

    def restore(self, name='restored'):
        return fixture.restore(self.repo, self.base / name, self.basis)

    def test_exact_bytes_real_git_head_index_and_no_shared_cache(self):
        project, manifest = self.restore()
        fixture.verify(project, manifest)
        self.assertEqual(fixture.git(project, 'rev-parse', 'HEAD').decode().strip(), self.commit)
        self.assertEqual(set(fixture.git(project, 'ls-files', '-z').split(b'\0')),
                         set(fixture.git(self.repo, 'ls-files', '-z').split(b'\0')))
        self.assertFalse((project / 'docs/omitted.md').exists())
        self.assertFalse((project / '.godot').exists())
        self.assertFalse((project / '.git/objects/info/alternates').exists())
        for name in manifest['members'] | manifest['assets']:
            self.assertEqual((project / name).read_bytes(), (self.repo / name).read_bytes())
        self.assertEqual(manifest['checks']['forest-region-matrix']['timeout_seconds'], 7)

    def test_source_edit_detected(self):
        project, manifest = self.restore()
        (project / 'scripts/example.gd').write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, 'differs'):
            fixture.verify(project, manifest)

    def test_unexpected_source_refused(self):
        project, manifest = self.restore()
        (project / 'scripts/injected.gd').write_text('extends Node\n')
        with self.assertRaisesRegex(ValueError, 'Unexpected fixture source'):
            fixture.verify(project, manifest)

    def test_source_missing_detected(self):
        project, manifest = self.restore()
        (project / 'scripts/example.gd').unlink()
        with self.assertRaisesRegex(ValueError, 'Missing'):
            fixture.verify(project, manifest)

    def test_asset_edit_or_missing_refused_without_original_blob(self):
        asset = self.repo / 'assets/a.bin'
        asset.write_bytes(b'new asset')
        with self.assertRaisesRegex(ValueError, 'Exact old asset blob required'):
            self.restore('changed')
        asset.unlink()
        with self.assertRaisesRegex(ValueError, 'Exact old asset blob required'):
            self.restore('missing')

    def test_real_old_blob_restores_changed_and_missing_asset(self):
        item = self.manifest['assets']['assets/a.bin']
        old = fixture.git(self.repo, 'cat-file', 'blob', item['git_blob'])
        retained = self.basis / 'asset_blobs' / item['git_blob']
        retained.parent.mkdir()
        retained.write_bytes(old)
        (self.repo / 'assets/a.bin').write_bytes(b'new')
        project, _ = self.restore('changed')
        self.assertEqual((project / 'assets/a.bin').read_bytes(), old)
        (self.repo / 'assets/a.bin').unlink()
        project, _ = self.restore('missing')
        self.assertEqual((project / 'assets/a.bin').read_bytes(), old)

    def test_corrupt_retained_blob_rejected(self):
        item = self.manifest['assets']['assets/a.bin']
        retained = self.basis / 'asset_blobs' / item['git_blob']
        retained.parent.mkdir()
        retained.write_bytes(b'invented')
        (self.repo / 'assets/a.bin').unlink()
        with self.assertRaisesRegex(ValueError, 'fingerprint'):
            self.restore()

    def test_archive_and_inventory_corruption_rejected(self):
        for name in ('source.tar.gz', 'inventory.json'):
            p = self.basis / name
            raw = p.read_bytes()
            p.write_bytes(raw + b'tamper')
            with self.assertRaisesRegex(ValueError, 'fingerprint'):
                self.restore(name)
            p.write_bytes(raw)

    def test_missing_and_corrupt_source_member_rejected_even_with_new_archive_digest(self):
        archive = self.basis / 'source.tar.gz'
        original = archive.read_bytes()
        for missing in (False, True):
            output = io.BytesIO()
            with tarfile.open(fileobj=io.BytesIO(original), mode='r:gz') as source:
                with tarfile.open(fileobj=output, mode='w:gz') as target:
                    for entry in source:
                        data = source.extractfile(entry).read()
                        if entry.name == 'scripts/example.gd':
                            if missing:
                                continue
                            data = b'changed source'
                            entry.size = len(data)
                        target.addfile(entry, io.BytesIO(data))
            data = output.getvalue()
            archive.write_bytes(data)
            manifest = json.loads((self.basis / 'manifest.json').read_text())
            manifest['archive_sha256'] = fixture.sha(data)
            (self.basis / 'manifest.json').write_text(json.dumps(manifest))
            with self.assertRaisesRegex(ValueError, 'member set|Corrupt frozen source'):
                self.restore('missingmember' if missing else 'corruptmember')

    def test_symlink_asset_is_not_accepted_as_current_raw_file(self):
        old = self.repo / 'assets/a.bin'
        alternate = self.repo / 'copy.bin'
        alternate.write_bytes(old.read_bytes())
        old.unlink()
        old.symlink_to(alternate)
        with self.assertRaisesRegex(ValueError, 'Symlink'):
            self.restore()

    def test_original_head_change_detected(self):
        project, manifest = self.restore()
        (project / '.git/HEAD').write_text('0' * 40 + '\n')
        with self.assertRaises(ValueError):
            fixture.verify(project, manifest)

    def test_repeated_destination_and_archive_overwrite_refused(self):
        self.restore()
        with self.assertRaisesRegex(ValueError, 'Fresh'):
            self.restore()
        with self.assertRaisesRegex(ValueError, 'overwrite'):
            fixture.freeze(self.repo, self.basis, self.commit)

    def test_unsafe_names_rejected(self):
        for name in ('../outside', '/outside', 'a/../outside', 'a\\outside', './a'):
            with self.assertRaises(ValueError):
                fixture.safe_path(name)


    def test_runtime_original_configuration_mutations_rejected(self):
        path = self.basis / 'manifest.json'
        original = path.read_text()
        mutations = {'argv': [sys.executable, '-c', 'print("fake")'],
                     'timeout_seconds': 999999, 'success_pattern': '.*', 'serial': False}
        for key, value in mutations.items():
            manifest = json.loads(original)
            manifest['checks']['forest-region-matrix'][key] = value
            path.write_text(json.dumps(manifest))
            with self.subTest(key=key), self.assertRaisesRegex(ValueError, 'Original check'):
                self.restore('mutated-' + key)
        path.write_text(original)
        project, manifest = self.restore('verified')
        manifest['checks']['forest-region-matrix']['success_pattern'] = '.*'
        with self.assertRaisesRegex(ValueError, 'Original check'):
            fixture.verify(project, manifest)

    def test_runtime_original_check_set_mutations_rejected(self):
        path = self.basis / 'manifest.json'
        original = path.read_text()
        for extra in (False, True):
            manifest = json.loads(original)
            if extra:
                manifest['checks']['fake'] = manifest['checks']['forest-ecology']
            else:
                del manifest['checks']['forest-ecology']
            path.write_text(json.dumps(manifest))
            with self.assertRaisesRegex(ValueError, 'Original check'):
                self.restore('extra' if extra else 'missing-check')

    def test_source_directory_symlink_ancestor_rejected(self):
        project, manifest = self.restore()
        original = project / 'scripts'
        external = self.base / 'external-source'
        original.rename(external)
        original.symlink_to(external, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, 'Symlink'):
            fixture.verify(project, manifest)

    def test_current_asset_directory_symlink_ancestor_rejected(self):
        original = self.repo / 'assets'
        external = self.base / 'external-assets'
        original.rename(external)
        original.symlink_to(external, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, 'Symlink'):
            self.restore()

    def test_retained_asset_directory_symlink_ancestor_rejected(self):
        item = self.manifest['assets']['assets/a.bin']
        data = (self.repo / 'assets/a.bin').read_bytes()
        (self.repo / 'assets/a.bin').unlink()
        external = self.base / 'external-blobs'
        external.mkdir()
        (external / item['git_blob']).write_bytes(data)
        (self.basis / 'asset_blobs').symlink_to(external, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, 'Symlink'):
            self.restore()

    def test_basis_and_archive_symlinks_rejected(self):
        link = self.base / 'linked-basis'
        link.symlink_to(self.basis, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, 'Symlink'):
            fixture.restore(self.repo, self.base / 'restore-link', link)
        archive = self.basis / 'source.tar.gz'
        external = self.base / 'archive-external.tar.gz'
        archive.rename(external)
        archive.symlink_to(external)
        with self.assertRaisesRegex(ValueError, 'Symlink'):
            self.restore()

    def test_output_ancestor_symlink_rejected_before_write(self):
        external = self.base / 'outside'
        external.mkdir()
        link = self.base / 'linked-output'
        link.symlink_to(external, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, 'Symlink'):
            fixture.restore(self.repo, link / 'new', self.basis)
        self.assertEqual(list(external.iterdir()), [])
        process = subprocess.run([sys.executable, str(ROOT / 'tools/run_forest_v1_regressions.py'),
            '--check', 'forest-ecology', '--output', str(link / 'runner')],
            capture_output=True, text=True)
        self.assertNotEqual(process.returncode, 0)
        self.assertIn('Symlink', process.stderr)
        self.assertEqual(list(external.iterdir()), [])

    def test_git_index_and_object_ancestor_symlinks_rejected(self):
        for relative in ('.git/index', '.git/objects'):
            project, manifest = self.restore(relative.rsplit('/', 1)[-1])
            original = project / relative
            external = self.base / ('external-' + original.name)
            original.rename(external)
            original.symlink_to(external, target_is_directory=external.is_dir())
            with self.subTest(relative=relative), self.assertRaisesRegex(ValueError, 'Symlink'):
                fixture.verify(project, manifest)

    def test_evidence_transfer_preserves_authenticated_source_and_original_parameters(self):
        output = self.repo / 'build/full'
        project, manifest = fixture.restore(self.repo, output / 'fixture', self.basis)
        original = fixture.original_checks(project, manifest)
        source_hashes = {name: fixture.sha((project / name).read_bytes())
                         for name in manifest['members'] | manifest['assets']}
        log = project / 'build/real/capture.json'
        log.parent.mkdir(parents=True)
        log.write_text('{"actual_fixture_result":true}\n')
        name = str(log.relative_to(output))
        report = {'status': 'passed', 'evidence_files': {name: fixture.sha(log.read_bytes())}}
        (output / 'report.json').write_text(json.dumps(report))
        legacy_runner.copy_evidence(output, self.repo / 'build/evidence', report, root=self.repo)
        fixture.verify(project, manifest)
        self.assertEqual(fixture.original_checks(project, manifest), original)
        self.assertEqual({name: fixture.sha((project / name).read_bytes()) for name in source_hashes}, source_hashes)


class EvidenceCopyTests(unittest.TestCase):
    """Only terminal evidence transfer; never construct or run an engine fixture."""
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.output = self.root / 'build/full'
        self.output.mkdir(parents=True)
        files = {'import.log': b'actual outer log\n',
                 'fixture/project/build/check/run.log': b'actual child log\n',
                 'fixture/project/build/check/capture.json': b'{"trace":[1,2,3]}\n',
                 'fixture/project/build/check/movie.avi': b'retained movie',
                 'fixture/project/assets/a.png': b'retained asset',
                 'fixture/project/.godot/cache.json': b'retained cache',
                 'fixture/project/scripts/source.gd': b'extends Node\n',
                 'fixture/manifest.json': b'{"source_inventory":true}\n'}
        self.original = {}
        for name, raw in files.items():
            path = self.output / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(raw)
            self.original[name] = raw
        self.report = {'status': 'failed', 'checks': {'old': {'timeout_seconds': 7}},
                       'evidence_files': {name: fixture.sha(raw) for name, raw in files.items()}}
        self.save_report()

    def save_report(self):
        (self.output / 'report.json').write_text(json.dumps(self.report))

    def copy(self, name='evidence'):
        return legacy_runner.copy_evidence(self.output, self.root / 'build' / name, self.report, root=self.root)

    def test_copies_real_child_logs_json_and_report_with_hashes_but_no_inputs_cache_media(self):
        receipt = self.copy()
        expected = {'report.json', 'import.log', 'fixture/project/build/check/run.log',
                    'fixture/project/build/check/capture.json'}
        self.assertEqual(set(receipt['files']), expected)
        self.assertEqual(receipt['status'], 'passed', 'Transfer success does not turn the failed check into a pass')
        for name in expected:
            raw = (self.root / 'build/evidence' / name).read_bytes()
            self.assertEqual(raw, (self.output / name).read_bytes())
            self.assertEqual(receipt['files'][name]['source_sha256'], fixture.sha(raw))
            self.assertEqual(receipt['files'][name]['copied_sha256'], fixture.sha(raw))
        self.assertEqual(json.loads((self.root / 'build/evidence/report.json').read_text())['status'], 'failed')
        self.assertEqual({str(p.relative_to(self.root / 'build/evidence')) for p in
                          (self.root / 'build/evidence').rglob('*') if p.is_file()}, expected | {'evidence-receipt.json'})
        for name, raw in self.original.items():
            self.assertEqual((self.output / name).read_bytes(), raw)

    def test_existing_evidence_is_never_overwritten(self):
        self.copy()
        path = self.root / 'build/evidence/report.json'
        before = path.read_bytes()
        with self.assertRaisesRegex(ValueError, 'Fresh'):
            self.copy()
        self.assertEqual(path.read_bytes(), before)

    def test_paths_cannot_escape_or_overlap_source(self):
        for name in ('../escape.json', '/absolute.json', 'fixture/project/build/../escape.json', 'bad\\escape.json'):
            with self.subTest(name=name):
                self.report['evidence_files'][name] = '0' * 64
                self.save_report()
                with self.assertRaises(ValueError): self.copy()
                del self.report['evidence_files'][name]
        self.save_report()
        for destination in (self.root / 'outside', self.output, self.output / 'nested', self.root / 'build'):
            with self.subTest(destination=destination), self.assertRaises(ValueError):
                legacy_runner.copy_evidence(self.output, destination, self.report, root=self.root)

    def test_source_file_and_ancestor_symlinks_refused(self):
        original = self.output / 'fixture/project/build/check/run.log'
        external = self.root / 'external.log'
        original.rename(external)
        original.symlink_to(external)
        with self.assertRaisesRegex(ValueError, 'Symlink'): self.copy()
        original.unlink(); original.write_bytes(external.read_bytes())
        directory = original.parent
        external_directory = self.root / 'external-directory'
        directory.rename(external_directory)
        directory.symlink_to(external_directory, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, 'Symlink'): self.copy()

    def test_destination_symlink_ancestor_refused_without_external_writes(self):
        outside = self.root / 'outside'; outside.mkdir()
        link = self.root / 'build/linked'; link.symlink_to(outside, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, 'Symlink'):
            legacy_runner.copy_evidence(self.output, link / 'evidence', self.report, root=self.root)
        self.assertEqual(list(outside.iterdir()), [])

    def test_missing_changed_unlisted_or_cache_result_cannot_be_bridged(self):
        path = self.output / 'fixture/project/build/check/capture.json'
        path.write_text('changed')
        with self.assertRaisesRegex(ValueError, 'fingerprint'): self.copy()
        path.unlink()
        with self.assertRaisesRegex(ValueError, 'regular'): self.copy()
        path.write_bytes(self.original[str(path.relative_to(self.output))])
        (self.output / 'unlisted.log').write_text('not in terminal ledger')
        with self.assertRaisesRegex(ValueError, 'missing'): self.copy()
        (self.output / 'unlisted.log').unlink()
        name = 'fixture/project/build/.godot/cache.json'
        cache = self.output / name;cache.parent.mkdir(parents=True);cache.write_text('{}')
        self.report['evidence_files'][name] = fixture.sha(cache.read_bytes());self.save_report()
        with self.assertRaisesRegex(ValueError, 'cache'): self.copy()

    def test_bridge_failure_fails_wrapper_after_success_and_optional_flag_preserves_old_path(self):
        # Mock only engine-dependent setup to test the real wrapper control flow.
        # These status stubs are unit inputs, not a claimed original-check pass.
        basis = self.root / 'basis';basis.mkdir();(basis / 'manifest.json').write_text('{}')
        original_config = {'argv': ['python3', '-c', 'print("original")'],
                           'timeout_seconds': 7, 'success_pattern': '^original$'}
        for with_bridge in (False, True):
            output = self.root / 'build' / ('bridge-run' if with_bridge else 'original-run')
            seen = []
            def restore(_repo, destination, _basis):
                project = destination / 'project';project.mkdir(parents=True)
                return project, {'source_commit': 'unit-control-flow-only'}
            def run_check(config, log, **_kwargs):
                seen.append(json.loads(json.dumps(config)))
                log.write_text('unit stub output; no engine was run\n')
                return {'status': 'passed'}
            spec = SimpleNamespace(loader=SimpleNamespace(exec_module=lambda _module: None))
            def bridge_failure(_output, _destination, report):
                self.assertEqual(report['status'], 'passed', 'Only transfer is failing in this case')
                raise OSError('unit transfer failure')
            argv = ['wrapper', '--check', 'forest-ecology', '--output', str(output)]
            if with_bridge: argv += ['--evidence-output', str(self.root / 'build/bridge-evidence')]
            with patch.object(legacy_runner, 'ROOT', self.root), patch.object(legacy_runner, 'BASIS', basis), \
                    patch.object(legacy_runner, 'restore', side_effect=restore), \
                    patch.object(legacy_runner, 'verify'), \
                    patch.object(legacy_runner, 'original_checks', return_value={'forest-ecology': original_config}), \
                    patch.object(legacy_runner.importlib.util, 'spec_from_file_location', return_value=spec), \
                    patch.object(legacy_runner.importlib.util, 'module_from_spec', return_value=SimpleNamespace(run_check=run_check)), \
                    patch.object(legacy_runner, 'copy_evidence', side_effect=bridge_failure) as transfer, \
                    patch.object(sys, 'argv', argv):
                result = legacy_runner.main()
            self.assertEqual(result, 1 if with_bridge else 0)
            self.assertEqual(transfer.call_count, 1 if with_bridge else 0)
            report = json.loads((output / 'report.json').read_text())
            self.assertEqual(report['status'], 'failed' if with_bridge else 'passed')
            if with_bridge: self.assertIn('unit transfer failure', report['evidence_bridge_error'])
            self.assertEqual(seen[0], {'argv': ['bash', 'tools/godot.sh', '--headless', '--path', '.', '--editor', '--quit'],
                                      'timeout_seconds': 90, 'success_pattern': r'Godot Engine v4\.7\.2'})
            self.assertEqual(seen[1], original_config)


class OriginalHarnessFailureTests(unittest.TestCase):
    """Invoke actual archived run_check with Python children, never Godot."""
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.base = Path(cls.tmp.name)
        archive = fixture.BASIS / 'source.tar.gz'
        manifest = json.loads((fixture.BASIS / 'manifest.json').read_text())
        if fixture.sha(archive.read_bytes()) != manifest['archive_sha256']:
            raise ValueError('Corrupt original archive')
        with tarfile.open(archive, 'r:gz') as tar:
            data = tar.extractfile('tools/harness.py').read()
            profiles = json.loads(tar.extractfile('tools/harness/profiles.json').read())
        if fixture.sha(data) != manifest['members']['tools/harness.py']['sha256']:
            raise ValueError('Corrupt original harness')
        for name in fixture.CHECK_IDS:
            if manifest['checks'][name] != profiles['checks'][name]:
                raise ValueError('Original argv/cap/marker changed')
        path = cls.base / 'harness.py'
        path.write_bytes(data)
        spec = importlib.util.spec_from_file_location('actual_bee_original_harness', path)
        cls.harness = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.harness)

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def run_child(self, source, cap=5):
        log = self.base / (self.id().rsplit('.', 1)[-1] + '.log')
        result = self.harness.run_check({'argv': [sys.executable, '-c', source],
            'timeout_seconds': cap, 'success_pattern': '^COMPLETE$'}, log, root=self.base)
        return result, log.read_text()

    def test_real_nonzero_refused_even_with_marker(self):
        result, text = self.run_child('print("COMPLETE"); raise SystemExit(3)')
        self.assertEqual(result['status'], 'failed')
        self.assertEqual(result['exit_code'], 3)
        self.assertIn('COMPLETE', text)

    def test_missing_completion_refused(self):
        result, _ = self.run_child('print("not complete")')
        self.assertEqual(result['failure_reason'], 'missing_completion')

    def test_real_timeout_refused(self):
        result, _ = self.run_child('import time; time.sleep(5)', .05)
        self.assertEqual(result['status'], 'timeout')

    def test_original_marker_zero_exit_passes(self):
        result, text = self.run_child('print("COMPLETE")')
        self.assertEqual(result['status'], 'passed')
        self.assertEqual(text, 'COMPLETE\n')


if __name__ == '__main__':
    unittest.main()
