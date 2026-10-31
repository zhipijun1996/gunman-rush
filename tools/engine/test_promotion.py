#!/usr/bin/env python3
"""Real local ZIP/byte checks and a fake release transport; no GitHub writes."""
import copy
import io
import json
from pathlib import Path
import shutil
import tempfile
from types import SimpleNamespace
import unittest
import urllib.request
import zipfile

import promote
import test_build_contract as contracts
from test_build_contract import TEST_COMMIT, TEST_RUN


class FakeGitHub:
    def __init__(self, pins, files):
        self.pins = pins
        self.files = files
        self.assets = {}
        self.events = []
        self.corrupt_upload = False
        self.release = {'id': pins.release, 'tag_name': pins.tag, 'target_commitish': pins.source,
                        'draft': True, 'prerelease': False,
                        'upload_url': 'https://uploads.github.com/repos/'+pins.repository+
                        '/releases/'+str(pins.release)+'/assets{?name,label}'}
        self.tag = {'object': {'type': 'commit', 'sha': pins.source}}

    def json(self, method, path, body=None):
        self.events.append((method, path))
        if method == 'PATCH':
            assert body == {'draft': False}
            assert set(self.assets) == set(self.files)
            assert all(self.assets[name]['bytes'] == data for name, data in self.files.items())
            self.release['draft'] = False
            return copy.deepcopy(self.release)
        if path.startswith('/git/ref/'):
            return copy.deepcopy(self.tag)
        if path.endswith('/assets?per_page=100'):
            return [{'id': value['id'], 'name': name, 'state': 'uploaded', 'size': len(value['bytes'])}
                    for name, value in self.assets.items()]
        return copy.deepcopy(self.release)

    def add(self, name, data):
        self.assets[name] = {'id': len(self.assets)+1, 'bytes': data}

    def download(self, path, destination):
        self.events.append(('DOWNLOAD', path))
        value = next(row for row in self.assets.values() if path.endswith('/'+str(row['id'])))
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(value['bytes'])

    def upload(self, url, path):
        self.events.append(('UPLOAD', path.name))
        assert path.name not in self.assets
        data = path.read_bytes()
        self.add(path.name, (b'!' + data[1:]) if self.corrupt_upload else data)
        return {'id': self.assets[path.name]['id']}


class PromotionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.pins = SimpleNamespace(repository='zhipijun1996/gunman-rush', source=TEST_COMMIT,
            run=int(TEST_RUN), artifact=17, release=23, tag='toolchain-'+promote.pack.RECIPE['id'])
        self.pins.base_url = 'https://github.com/'+self.pins.repository+'/releases/download/'+self.pins.tag+'/'
        self.inputs = self.root/'inputs'; self.inputs.mkdir()
        contracts.EngineBuildContract().fixture(self.inputs)
        self.distribution = self.root/'distribution'
        promote.pack.package(self.inputs, self.distribution, self.pins.base_url, TEST_COMMIT, TEST_RUN)
        self.files = {path.name: path.read_bytes() for path in self.distribution.iterdir()}
        self.expected = {path.name: {'sha256': promote.pack.sha(path), 'bytes': path.stat().st_size}
                         for path in self.distribution.iterdir()}
        self.pins.lock_digest = promote.pack.sha(self.distribution/'godot-lock-candidate.json')
        self.zip = self.root/'artifact.zip'
        self.archive()

    def archive(self):
        with zipfile.ZipFile(self.zip, 'w') as archive:
            for path in sorted(self.distribution.iterdir()):
                archive.write(path, path.name)
        self.pins.digest = promote.pack.sha(self.zip)
        self.pins.size = self.zip.stat().st_size

    def test_metadata_rejects_wrong_run_source_state_size_digest_and_owner(self):
        run = {'id': self.pins.run, 'head_sha': TEST_COMMIT, 'status': 'completed', 'conclusion': 'success'}
        artifact = {'id': 17, 'name': 'engine-distribution-candidate', 'size_in_bytes': self.pins.size,
                    'digest': 'sha256:'+self.pins.digest, 'expired': False,
                    'workflow_run': {'id': self.pins.run, 'head_sha': TEST_COMMIT}}
        promote.verify_metadata(run, artifact, self.pins)
        for key, value in [('id', 1), ('head_sha', 'b'*40), ('status', 'in_progress'), ('conclusion', 'failure')]:
            bad = dict(run); bad[key] = value
            with self.assertRaises(ValueError): promote.verify_metadata(bad, artifact, self.pins)
        for key, value in [('id', 2), ('name', 'other'), ('size_in_bytes', 0), ('digest', 'sha256:'+'0'*64),
                           ('expired', True), ('workflow_run', {'id': self.pins.run, 'head_sha': 'b'*40})]:
            bad = dict(artifact); bad[key] = value
            with self.assertRaises(ValueError): promote.verify_metadata(run, bad, self.pins)

    def test_complete_actual_package_revalidates_through_original_packager(self):
        folder, observed = promote.verify_distribution(self.zip, self.root/'verified', self.pins)
        self.assertEqual(observed, self.expected)
        self.assertEqual(len(observed), 8)
        self.assertEqual(json.loads((folder/'godot-lock-candidate.json').read_text())['templates']['files'],
                         json.loads((self.distribution/'godot-lock-candidate.json').read_text())['templates']['files'])

    def test_rehashed_source_command_log_or_member_drift_still_fails(self):
        original = (self.distribution/'build-provenance.json').read_bytes()
        for mutation in ('source', 'command', 'log'):
            proof = json.loads(original)
            row = proof['lanes']['linux-editor']
            if mutation == 'source': row['source']['source_commit'] = 'b'*40
            if mutation == 'command': row['commands'][0]['argv'].append('optimize=none')
            if mutation == 'log': row['commands'][0]['log_sha256'] = '0'*64
            promote.pack.write(self.distribution/'build-provenance.json', proof)
            self.archive()
            with self.assertRaises(ValueError):
                promote.verify_distribution(self.zip, self.root/mutation, self.pins)
        (self.distribution/'build-provenance.json').write_bytes(original)
        self.archive(); self.pins.lock_digest = '0'*64
        with self.assertRaisesRegex(ValueError, 'lock SHA'):
            promote.verify_distribution(self.zip, self.root/'bad-lock', self.pins)

    def test_safe_zip_rejects_extra_duplicate_symlink_and_escape(self):
        for index, name in enumerate(('extra', '../escape', '/absolute', 'dir\\file')):
            with zipfile.ZipFile(self.zip, 'w') as z: z.writestr(name, 'untrusted')
            with self.assertRaises(ValueError):
                promote.extract_exact(self.zip, self.root/str(index), {'wanted'} if name == 'extra' else {name})
        with zipfile.ZipFile(self.zip, 'w') as z:
            info = zipfile.ZipInfo('wanted'); info.create_system = 3; info.external_attr = 0o120777 << 16
            z.writestr(info, 'outside')
        with self.assertRaises(ValueError): promote.extract_exact(self.zip, self.root/'link', {'wanted'})
        with zipfile.ZipFile(self.zip, 'w') as z:
            z.writestr('wanted', 'one')
            with self.assertWarns(UserWarning): z.writestr('wanted', 'two')
        with self.assertRaises(ValueError): promote.extract_exact(self.zip, self.root/'duplicate', {'wanted'})
        self.assertFalse((self.root.parent/'escape').exists())

    def test_dry_run_is_read_only_and_matching_partial_draft_is_completed_once(self):
        api = FakeGitHub(self.pins, self.files)
        first = sorted(self.files)[0]; api.add(first, self.files[first])
        result = promote.promote(api, self.pins, self.distribution, self.expected, self.root/'dry')
        self.assertEqual(result['status'], 'validated_only')
        self.assertFalse(any(method in ('UPLOAD', 'PATCH') for method, _ in api.events))
        result = promote.promote(api, self.pins, self.distribution, self.expected, self.root/'publish', True)
        self.assertEqual(result['status'], 'published_verified')
        self.assertEqual(sum(method == 'UPLOAD' for method, _ in api.events), 7)
        self.assertEqual(sum(method == 'PATCH' for method, _ in api.events), 1)
        before = len(api.events)
        result = promote.promote(api, self.pins, self.distribution, self.expected, self.root/'again', True)
        self.assertEqual(result['status'], 'already_published_verified')
        self.assertFalse(any(method in ('UPLOAD', 'PATCH') for method, _ in api.events[before:]))

    def test_different_existing_asset_rejects_before_any_upload_or_publish(self):
        for case in ('bytes', 'name', 'published-missing'):
            api = FakeGitHub(self.pins, self.files)
            name = sorted(self.files)[0]; data = self.files[name]
            if case == 'bytes': api.add(name, b'!'+data[1:])
            if case == 'name': api.add('unreviewed.bin', b'unreviewed')
            if case == 'published-missing': api.release['draft'] = False
            with self.assertRaises(ValueError):
                promote.promote(api, self.pins, self.distribution, self.expected, self.root/case, True)
            self.assertFalse(any(method in ('UPLOAD', 'PATCH') for method, _ in api.events))

    def test_uploaded_byte_mismatch_cannot_publish(self):
        api = FakeGitHub(self.pins, self.files); api.corrupt_upload = True
        with self.assertRaisesRegex(ValueError, 'bytes differ'):
            promote.promote(api, self.pins, self.distribution, self.expected, self.root/'corrupt-upload', True)
        self.assertTrue(api.release['draft'])
        self.assertFalse(any(method == 'PATCH' for method, _ in api.events))

    def test_wrong_release_tag_target_or_upload_host_cannot_mutate(self):
        for case in ('release', 'tag', 'target', 'upload', 'schema'):
            api = FakeGitHub(self.pins, self.files)
            if case == 'release': api.release['id'] += 1
            if case == 'tag': api.tag['object']['sha'] = 'b'*40
            if case == 'target': api.release['target_commitish'] = 'publisher-branch'
            if case == 'upload': api.release['upload_url'] = 'https://example.invalid/steal'
            if case == 'schema': del api.release['draft']
            with self.assertRaises(ValueError):
                promote.promote(api, self.pins, self.distribution, self.expected, self.root/case, True)
            self.assertFalse(any(method in ('UPLOAD', 'PATCH') for method, _ in api.events))

    def test_download_redirect_never_forwards_runner_token_to_storage(self):
        request = urllib.request.Request('https://api.github.com/repos/a/b/actions/artifacts/1/zip',
                                         headers={'Authorization': 'Bearer SYNTHETIC', 'Accept': 'application/octet-stream'})
        redirected = promote.SafeRedirect().redirect_request(request, None, 302, 'Found', {},
                                                             'https://blob.example.invalid/file?signature=synthetic')
        self.assertFalse(redirected.has_header('Authorization'))
        self.assertEqual(redirected.get_header('Accept'), 'application/octet-stream')

    def test_upload_stream_sends_exact_content_length_and_bytes_to_github_only(self):
        api = promote.GitHub(self.pins.repository, 'SYNTHETIC_TOKEN')
        recorded = {}
        class Opener:
            def open(self, request, timeout):
                recorded.update(url=request.full_url, method=request.method,
                                length=request.get_header('Content-length'), body=request.data.read())
                return io.BytesIO(b'{"id":42}')
        api.opener = Opener()
        file = self.distribution/'build-provenance.json'
        result = api.upload('https://uploads.github.com/repos/example/repo/releases/1/assets?name=proof', file)
        self.assertEqual(result, {'id': 42})
        self.assertEqual(recorded['method'], 'POST')
        self.assertEqual(int(recorded['length']), file.stat().st_size)
        self.assertEqual(recorded['body'], file.read_bytes())
        with self.assertRaisesRegex(ValueError, 'outside GitHub'):
            api.upload('https://example.invalid/steal', file)


if __name__ == '__main__':
    unittest.main()
