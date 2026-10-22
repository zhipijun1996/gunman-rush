"""Real artifact storage, restoration and cache refusals; no engine required."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import zipfile

SPEC = importlib.util.spec_from_file_location('harness', Path(__file__).resolve().parents[1] / 'tools/harness.py')
h = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(h)


class ArchiveTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.artifacts = self.root / 'artifacts'; self.artifacts.mkdir()
        self.name = 'build/proof/large.json'
        self.source = self.root / self.name
        self.source.parent.mkdir(parents=True)
        self.source.write_text(json.dumps({'payload': 'x' * h.ARTIFACT_JSON_THRESHOLD}))
        self.digest = h._file_sha(self.source)

    def collect(self):
        h.collect_artifacts(self.root, self.artifacts, {self.name: self.digest})
        return json.loads((self.artifacts / h.ARTIFACT_INDEX).read_text())

    def cache(self):
        item = {'log': 'COMPLETE\n', 'log_sha256': hashlib.sha256(b'COMPLETE\n').hexdigest(),
                'result': {'status': 'passed', 'exit_code': 0}, 'commit': 'a' * 40,
                'artifact_directory': str(self.artifacts), 'artifact_fingerprint': h.artifact_fingerprint(self.artifacts),
                'live_output_fingerprint': {str(self.source): self.digest}}
        path = self.root / 'cache.json'; path.write_text(json.dumps(item))
        return path

    def test_exact_restore_and_immutable_archive(self):
        self.collect(); archive = self.artifacts / h.ARTIFACT_ARCHIVE
        original = archive.read_bytes()
        restored = self.root / 'restored.json'
        h.restore_archived_artifact(self.artifacts, self.name, restored)
        self.assertEqual(h._file_sha(restored), self.digest)
        self.assertEqual(json.loads(restored.read_text()), json.loads(self.source.read_text()))
        with self.assertRaises(FileExistsError):
            h.restore_archived_artifact(self.artifacts, self.name, restored)
        self.source.write_text('changed live')
        self.assertEqual(archive.read_bytes(), original)
        self.assertFalse((self.artifacts / self.name).exists())

    def test_cache_refuses_archive_corruption_and_missing_pair(self):
        self.collect(); cache = self.cache(); check = {'success_pattern': '^COMPLETE$'}
        log = self.root / 'reused.log'
        self.assertTrue(h.cached_result(check, cache, log)['reused'])
        archive = self.artifacts / h.ARTIFACT_ARCHIVE; original = archive.read_bytes()
        archive.write_bytes(original[:-8]); self.assertIsNone(h.cached_result(check, cache, log))
        archive.write_bytes(original)
        index = self.artifacts / h.ARTIFACT_INDEX; text = index.read_text(); index.unlink()
        self.assertIsNone(h.cached_result(check, cache, log))
        index.write_text(text); archive.unlink()
        self.assertIsNone(h.cached_result(check, cache, log))

    def test_live_corruption_and_deletion_still_miss(self):
        self.collect(); cache = self.cache(); check = {'success_pattern': '^COMPLETE$'}
        self.source.write_text('wrong'); self.assertIsNone(h.cached_result(check, cache, self.root / 'log'))
        self.source.unlink(); self.assertIsNone(h.cached_result(check, cache, self.root / 'log'))

    def test_member_index_mismatch_even_with_rebound_archive_hash(self):
        index = self.collect(); archive = self.artifacts / h.ARTIFACT_ARCHIVE
        for case in ('wrong_bytes', 'missing', 'extra', 'duplicate', 'traversal', 'absolute', 'symlink'):
            with self.subTest(case=case):
                with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED) as bundle:
                    if case == 'wrong_bytes': bundle.writestr(self.name, b'z' * self.source.stat().st_size)
                    elif case == 'missing': pass
                    elif case == 'extra':
                        bundle.write(self.source, self.name); bundle.writestr('build/extra.json', '{}')
                    elif case == 'duplicate':
                        bundle.write(self.source, self.name); bundle.write(self.source, self.name)
                    elif case == 'symlink':
                        info = zipfile.ZipInfo(self.name); info.external_attr = 0o120777 << 16
                        info.compress_type = zipfile.ZIP_DEFLATED; bundle.writestr(info, str(self.source))
                    else: bundle.write(self.source, '../escape.json' if case == 'traversal' else '/absolute.json')
                index['archive_sha256'] = h._file_sha(archive)
                with self.assertRaises((ValueError, zipfile.BadZipFile)):
                    h._verify_artifact_archive(archive, index)

    def test_metadata_forgery_partial_and_symlink_refused(self):
        index = self.collect(); archive = self.artifacts / h.ARTIFACT_ARCHIVE
        for key, value in [('size', True), ('size', h.ARTIFACT_JSON_THRESHOLD + 20), ('sha256', 'a' * 64), ('path', '../escape.json')]:
            bad = json.loads(json.dumps(index)); bad['members'][0][key] = value
            with self.assertRaises(ValueError): h._verify_artifact_archive(archive, bad)
        partial = self.artifacts / 'large-json.zip.partial'; partial.touch()
        with self.assertRaises(ValueError): h.artifact_fingerprint(self.artifacts)
        partial.unlink()
        for name in (h.ARTIFACT_ARCHIVE, h.ARTIFACT_INDEX):
            p = self.artifacts / name; saved = self.root / name; p.rename(saved); p.symlink_to(saved)
            with self.assertRaises(ValueError): h.artifact_fingerprint(self.artifacts)
            p.unlink(); saved.rename(p)
        dest = self.root / 'dest'; dest.symlink_to(self.source)
        with self.assertRaises(ValueError): h.restore_archived_artifact(self.artifacts, self.name, dest)

    def test_source_symlink_and_parent_symlink_refused(self):
        saved = self.root / 'outside.json'; self.source.rename(saved); self.source.symlink_to(saved)
        with self.assertRaises(ValueError): self.collect()
        self.source.unlink(); saved.rename(self.source)
        folder = self.source.parent; outside = self.root / 'external'; folder.rename(outside); folder.symlink_to(outside, target_is_directory=True)
        with self.assertRaises(ValueError): self.collect()
        for name in ('../escape.json', '/absolute.json', 'assets/foo.json'):
            with self.assertRaises(ValueError): h.collect_artifacts(self.root, self.artifacts, {name: self.digest})

    def test_real_source_mutation_during_archive_rejected(self):
        original_write = zipfile._ZipWriteFile.write
        changed = False
        def mutate(writer, chunk):
            nonlocal changed
            result = original_write(writer, chunk)
            if not changed:
                changed = True
                with self.source.open('r+b') as stream: stream.seek(100); stream.write(b'Z')
            return result
        with patch.object(zipfile._ZipWriteFile, 'write', mutate):
            with self.assertRaisesRegex(ValueError, 'changed during'): self.collect()
        self.assertEqual(list(self.artifacts.iterdir()), [])
        self.assertTrue(self.source.exists())

    def test_archive_and_index_write_failures_preserve_original(self):
        with patch.object(zipfile._ZipWriteFile, 'write', side_effect=OSError(28, 'No space left')):
            with self.assertRaises(OSError): self.collect()
        self.assertEqual(list(self.artifacts.iterdir()), [])
        original_replace = Path.replace
        def fail_index(path, target):
            if path.name == 'large-json.index.json.partial': raise OSError(28, 'No space left')
            return original_replace(path, target)
        with patch.object(Path, 'replace', fail_index):
            with self.assertRaises(OSError): self.collect()
        self.assertEqual(list(self.artifacts.iterdir()), [])
        self.assertEqual(h._file_sha(self.source), self.digest)

    def test_real_subprocess_execute_changed_only_small_paths_and_cache(self):
        def git(*args): subprocess.run(['git', *args], cwd=self.root, check=True, capture_output=True)
        git('init', '-q'); git('config', 'user.email', 'test@example.invalid'); git('config', 'user.name', 'Test')
        (self.root / '.gitignore').write_text('build/\nartifacts/\n')
        (self.root / 'input').write_text('input'); git('add', '.'); git('commit', '-qm', 'fixture')
        source = "from pathlib import Path; import json; p=Path('build/proof/new.json'); p.write_text(json.dumps({'payload':'N'*(8*1024*1024)})); Path('build/proof/small.json').write_text('{}'); print('COMPLETE')"
        check = {'argv': ['python3', '-c', source], 'timeout_seconds': 5, 'success_pattern': '^COMPLETE$', 'cacheable': True, 'inputs': ['input'], 'artifact_paths': ['build/proof']}
        with patch.object(h, 'ROOT', self.root), patch.object(h, 'toolchain_identity', return_value={}):
            def execute(name):
                folder = self.root / 'build/verification/harness' / name; folder.mkdir(parents=True)
                return h.execute_checks({'checks': {'proof': check}}, ['proof'], folder, reuse=True)[0]
            first = execute('first'); self.assertEqual(first['status'], 'passed'); self.assertFalse(first['reused'])
            artifacts = Path(first['artifact_directory']); index = h._artifact_archive_index(artifacts)
            self.assertEqual([r['path'] for r in index['members']], ['build/proof/new.json'])
            self.assertEqual((artifacts / 'build/proof/small.json').read_text(), '{}')
            self.assertTrue((artifacts / 'check.log').exists())
            self.assertFalse((artifacts / self.name).exists())
            self.assertTrue(execute('reuse')['reused'])
            (self.root / 'build/proof/new.json').write_text('corrupt')
            self.assertFalse(execute('corrupt')['reused'])


if __name__ == '__main__': unittest.main()
