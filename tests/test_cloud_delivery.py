"""Adversarial delivery checks: stale identity, byte tampering and main isolation."""
import gzip
import hashlib
import json
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
import cloud_delivery as delivery


def run(root, *args):
    return subprocess.check_output(['git', '-C', str(root), *args], text=True).strip()


def minimal_pack(name, data, extra=None):
    """Build a valid standalone format-4 PCK; production uses the real parser."""
    entries = [(name, data)] + list(extra or [])
    payload = b''.join(value for _, value in entries)
    header = bytearray(112)
    header[:4] = b'GDPC'
    struct.pack_into('<I', header, 4, 4)
    struct.pack_into('<I', header, 20, 2)
    struct.pack_into('<QQ', header, 24, 112, 112 + len(payload))
    directory, offset = struct.pack('<I', len(entries)), 0
    for name, value in entries:
        encoded = name.encode() + b'\0'
        directory += struct.pack('<I', len(encoded)) + encoded
        directory += struct.pack('<QQ', offset, len(value)) + hashlib.md5(value).digest() + struct.pack('<I', 0)
        offset += len(value)
    return bytes(header) + payload + directory


class DeliveryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / 'source'
        self.host = Path(self.temp.name) / 'hosting'
        for root, remote in ((self.root, 'zhipijun1996/gunman-rush'), (self.host, delivery.HOST_REPOSITORY)):
            root.mkdir()
            run(root, 'init', '-q')
            run(root, 'remote', 'add', 'origin', 'https://github.com/' + remote + '.git')
        (self.root / 'tools').mkdir()
        for name in ('cloud_delivery.py', 'style_exploration_delivery.py', 'preview_host_workflow.yml'):
            shutil.copyfile(Path(delivery.__file__).parent / name, self.root / 'tools' / name)
        (self.root / 'scenes/dev').mkdir(parents=True)
        (self.root / delivery.BOOTSTRAP).write_text('[gd_scene format=3]\n[node name="Preview" type="Node"]\n')
        self.consumer = 'scenes/dev/consumer_test.tscn'
        (self.root / self.consumer).write_text('[gd_scene format=3]\n[node name="Consumer" type="Node"]\n')
        (self.root / '.gitignore').write_text('build/\n')
        run(self.root, 'add', '.')
        run(self.root, '-c', 'user.name=Delivery Test', '-c', 'user.email=delivery@example.invalid', 'commit', '-qm', 'fixture source')
        self.head = run(self.root, 'rev-parse', 'HEAD')
        self.bundle = self.root / 'build/web'
        self.bundle.mkdir(parents=True)
        pack = minimal_pack(delivery.BOOTSTRAP, (self.root / delivery.BOOTSTRAP).read_bytes(),
                            [(self.consumer, (self.root / self.consumer).read_bytes())])
        checksum = hashlib.sha256(pack).hexdigest()
        self.pack_name = 'index.' + checksum[:12] + '.pck'
        (self.bundle / self.pack_name).write_bytes(pack)
        (self.bundle / 'chunks').mkdir()
        compressed = gzip.compress(pack, mtime=0)
        (self.bundle / 'chunks' / (checksum + '.gz')).write_bytes(compressed)
        resource_map = {self.pack_name: {'sha256': checksum, 'bytes': len(pack), 'chunks': [
            {'sha256': checksum, 'bytes': len(pack), 'gzip_bytes': len(compressed), 'url': 'chunks/' + checksum + '.gz'}]}}
        (self.bundle / 'index.cache-sw.js').write_text('const RESOURCE_MAP = ' + json.dumps(resource_map) + ';\n')
        (self.bundle / 'index.html').write_text('<!doctype html><body><script>engine.startGame({}).then(() => {});</script></body>')
        (self.bundle / 'build-info.json').write_text(json.dumps({'source_commit': self.head, 'build_id': checksum[:12], 'pack': self.pack_name, 'pack_bytes': len(pack)}))
        self.refresh_report()

    def refresh_report(self):
        files = [p for p in self.bundle.rglob('*') if p.is_file() and p.name != 'build_report.json']
        (self.bundle / 'build_report.json').write_text(json.dumps({'platform': 'web', 'export_exit_code': 0, 'artifacts': [
            {'path': p.relative_to(self.root).as_posix(), 'bytes': p.stat().st_size, 'sha256': delivery.sha(p)} for p in files]}))

    def stage(self, task='CLOUD-TEST-01', **kwargs):
        return delivery.stage_preview(self.bundle, self.host, task, 'fixed-seed', source_root=self.root, **kwargs)

    def test_review_need_controls_delivery_not_task_length(self):
        self.assertEqual(delivery.select_delivery(observe=True)['delivery'], 'video')
        self.assertEqual(delivery.select_delivery(interact=True)['delivery'], 'web')
        self.assertEqual(delivery.select_delivery(observe=True, interact=True)['delivery'], 'both')
        result = delivery.select_delivery(engineering=True, long_task=True)
        self.assertEqual(result['delivery'], 'engineering')
        self.assertTrue(result['milestone'])
        with self.assertRaises(ValueError):
            delivery.select_delivery(long_task=True)

    def test_task_kind_selects_media_without_manual_flags(self):
        expectations = {'local_animation': 'video', 'local_vfx': 'video', 'controls': 'web',
                        'weapon': 'both', 'enemy': 'both', 'boss': 'both', 'region': 'web',
                        'ui': 'both', 'home': 'web', 'tool': 'engineering', 'performance': 'engineering'}
        for kind, expected in expectations.items():
            with self.subTest(kind=kind):
                result = delivery.select_delivery(kind=kind)
                self.assertEqual(result['delivery'], expected)
                self.assertEqual(result['kind'], kind)
                self.assertEqual(result['kind_source'], 'task_kind')
                self.assertIn(kind, result['reason'])

    def test_explicit_review_needs_add_to_kind_defaults(self):
        self.assertEqual(delivery.select_delivery(kind='local_vfx', interact=True)['delivery'], 'both')
        self.assertEqual(delivery.select_delivery(kind='controls', observe=True)['delivery'], 'both')
        self.assertEqual(delivery.select_delivery(kind='boss', engineering=True)['delivery'], 'both')
        self.assertEqual(delivery.select_delivery(kind='tool', interact=True)['delivery'], 'web')
        self.assertEqual(delivery.select_delivery(kind='tool', interact=True)['required_evidence'], ['web', 'engineering'])
        self.assertEqual(delivery.select_delivery(kind='performance', observe=True)['required_evidence'], ['video', 'engineering'])
        self.assertEqual(delivery.select_delivery(kind='weapon', observe=True)['delivery'], 'both')

    def test_long_production_adds_checkpoint_without_forcing_web(self):
        result = delivery.select_delivery(kind='local_animation', long_task=True)
        self.assertEqual(result['delivery'], 'video')
        self.assertTrue(result['milestone'])
        self.assertEqual(delivery.select_delivery(kind='tool', long_task=True)['delivery'], 'engineering')

    def test_immutable_route_and_real_startup_arguments(self):
        result = self.stage(pr=23)
        destination = self.host / 'site/previews/CLOUD-TEST-01' / self.head / result['build_id']
        self.assertTrue((destination / 'preview.json').is_file())
        page = (destination / 'index.html').read_text()
        self.assertIn('res://scenes/dev/cloud_preview.tscn', page)
        self.assertIn('--seed=fixed-seed', page)
        self.assertIn('--entry=actions', page)
        self.assertFalse((destination / self.pack_name).exists())
        verified = delivery.validate_site(self.host / 'site')
        self.assertEqual(verified['status'], 'verified')
        self.assertEqual(delivery.sha(destination / self.pack_name), delivery.sha(self.bundle / self.pack_name))
        self.assertEqual(result['pr'], 23)

    def test_self_contained_scene_entry_is_pack_verified_and_forwarded(self):
        scene = 'res://' + self.consumer
        result = self.stage(entry='scene', scene=scene)
        self.assertEqual(result['scene'], scene)
        self.assertEqual(result['entry'], 'scene')
        folder = self.host / 'site/previews/CLOUD-TEST-01' / self.head / result['build_id']
        page = (folder / 'index.html').read_text()
        self.assertIn('--entry=scene', page)
        self.assertIn('--scene=' + scene, page)
        self.assertIn('actual consumer validation', result['validation'])
        delivery.validate_site(self.host / 'site')

    def test_scene_entry_requires_canonical_safe_nonrecursive_scene(self):
        invalid = (None, '', 'scenes/dev/consumer_test.tscn', 'res://assets/test.tscn',
                   'res://scenes/../demo/demo.tscn', 'res://scenes/dev\\test.tscn',
                   'res://scenes//test.tscn', 'res://scenes/./test.tscn',
                   'res://scenes/test.gd', 'res://scenes/name..tscn',
                   'res://scenes/dev/cloud_preview.tscn')
        for scene in invalid:
            with self.subTest(scene=scene), self.assertRaises(ValueError):
                self.stage(entry='scene', scene=scene)
        with self.assertRaisesRegex(ValueError, 'only with --entry scene'):
            self.stage(entry='actions', scene='res://' + self.consumer)
        self.assertFalse((self.host / 'site').exists())

    def test_valid_scene_path_without_actual_pck_entry_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'PCK missing runtime resource'):
            self.stage(entry='scene', scene='res://scenes/dev/missing_test.tscn')
        self.assertFalse((self.host / 'site').exists())

    def test_never_stage_into_main_repository(self):
        run(self.host, 'remote', 'set-url', 'origin', 'https://github.com/zhipijun1996/gunman-rush.git')
        with self.assertRaisesRegex(ValueError, 'main hosting is forbidden'):
            self.stage()
        self.assertFalse((self.host / 'site').exists())

    def test_reject_old_sha_even_with_self_consistent_export_report(self):
        info = json.loads((self.bundle / 'build-info.json').read_text())
        info['source_commit'] = '1' * 40
        (self.bundle / 'build-info.json').write_text(json.dumps(info))
        self.refresh_report()
        with self.assertRaisesRegex(ValueError, 'exact current HEAD'):
            self.stage()

    def test_reject_tampered_pack_before_staging(self):
        with (self.bundle / self.pack_name).open('ab') as stream:
            stream.write(b'poison')
        with self.assertRaisesRegex(ValueError, 'artifact bytes changed'):
            self.stage()
        self.assertFalse((self.host / 'site').exists())

    def test_reject_rehashed_pack_when_original_cache_contract_disagrees(self):
        with (self.bundle / self.pack_name).open('ab') as stream:
            stream.write(b'poison')
        self.refresh_report()
        with self.assertRaisesRegex(ValueError, 'Existing full PCK differs'):
            self.stage()

    def test_illegal_task_cannot_escape_host_directory(self):
        for task in ('../main', '/main', '.', 'x/y', 'x\\y', '任务', 'a' * 65):
            with self.subTest(task=task), self.assertRaises(ValueError):
                self.stage(task=task)
        self.assertFalse((self.host / 'site').exists())

    def test_existing_identity_is_never_overwritten(self):
        result = self.stage()
        path = self.host / 'site/previews/CLOUD-TEST-01' / self.head / result['build_id'] / 'index.html'
        before = path.read_bytes()
        with self.assertRaisesRegex(ValueError, 'refusing overwrite'):
            self.stage(entry='menu')
        self.assertEqual(path.read_bytes(), before)

    def test_docs_dirty_allowed_runtime_dirty_refused(self):
        (self.root / 'notes.md').write_text('unfinished documentation')
        self.stage(task='DOCS-DIRTY')
        (self.root / delivery.BOOTSTRAP).write_text('changed runtime')
        with self.assertRaisesRegex(ValueError, 'Runtime source is dirty'):
            self.stage(task='RUNTIME-DIRTY')

    def test_dirty_export_or_publish_producer_refuses_staging(self):
        producer = self.root / 'tools/style_exploration_delivery.py'
        producer.write_text(producer.read_text() + '\n# uncommitted producer change\n')
        with self.assertRaisesRegex(ValueError, 'Runtime source is dirty.*tools/style_exploration_delivery.py'):
            self.stage()
        self.assertFalse((self.host / 'site').exists())

    def test_helper_install_failure_retains_explicit_partial_staging(self):
        real_copy = shutil.copyfile

        def fail_helper(source, destination, *args, **kwargs):
            if Path(destination).parent.name == '_tools':
                raise OSError('injected hosting helper write failure')
            return real_copy(source, destination, *args, **kwargs)

        with patch.object(delivery.shutil, 'copyfile', side_effect=fail_helper):
            with self.assertRaisesRegex(ValueError, 'Partial staging retained.*injected hosting helper write failure') as failure:
                self.stage()
        previews = list((self.host / 'site').glob('previews/*/*/*/preview.json'))
        self.assertEqual(len(previews), 1)
        self.assertTrue((previews[0].parent / 'index.html').is_file())
        self.assertIn(str(previews[0].parent), str(failure.exception))
        self.assertIn('must not be overwritten', str(failure.exception))
        with self.assertRaisesRegex(ValueError, 'refusing overwrite'):
            self.stage()

    def test_staged_html_tampering_blocks_host_publish(self):
        result = self.stage()
        folder = self.host / 'site/previews/CLOUD-TEST-01' / self.head / result['build_id']
        (folder / 'index.html').write_text('stale page')
        with self.assertRaisesRegex(ValueError, 'Staged preview bytes changed'):
            delivery.validate_site(self.host / 'site')

    def test_storage_cap_blocks_stage_without_deleting_history(self):
        result = self.stage()
        original = self.host / 'site/previews/CLOUD-TEST-01' / self.head / result['build_id'] / 'index.html'
        before = original.read_bytes()
        with patch.object(delivery, 'LIMIT', 1):
            with self.assertRaisesRegex(ValueError, 'would exceed 900MiB'):
                self.stage(task='OVER-BUDGET')
        self.assertEqual(original.read_bytes(), before)
        self.assertFalse((self.host / 'site/previews/OVER-BUDGET').exists())

    def test_forged_bootstrap_path_is_not_enough_without_pck_entry(self):
        # Keep all integrity hashes valid, but request a missing bootstrap resource.
        with patch.object(delivery, 'BOOTSTRAP', 'scenes/dev/not_exported.tscn'):
            with self.assertRaisesRegex(ValueError, 'PCK missing runtime resource'):
                self.stage()
        self.assertFalse((self.host / 'site').exists())

    def test_symlink_cannot_escape_bundle_inventory(self):
        (self.bundle / 'outside').symlink_to(self.root / '.git/config')
        with self.assertRaisesRegex(ValueError, 'Symlinks'):
            self.stage()

    def test_chunk_tampering_blocks_reconstruction(self):
        result = self.stage()
        folder = self.host / 'site/previews/CLOUD-TEST-01' / self.head / result['build_id']
        chunk = next((folder / 'chunks').glob('*.gz'))
        chunk.write_bytes(b'broken')
        with self.assertRaisesRegex(ValueError, 'Staged preview bytes changed'):
            delivery.validate_site(self.host / 'site')


if __name__ == '__main__':
    unittest.main()
