#!/usr/bin/env python3
"""Exercise the real curl downloader against a local HTTP failure server."""
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import copy
import io
import json
from pathlib import Path
import subprocess
import tempfile
import threading
import unittest
import urllib.error
from unittest.mock import patch

import setup_environment as setup

BODY = b'locked-artifact' * 1024


class Handler(BaseHTTPRequestHandler):
    requests = []
    def log_message(self, *args): pass
    def do_GET(self):
        type(self).requests.append((self.path, self.headers.get('Range')))
        if self.path == '/forbidden':
            self.send_error(403); return
        if self.path == '/rate-limited':
            self.send_error(429); return
        if self.path == '/always-unavailable':
            self.send_error(503); return
        if self.path == '/unavailable' and sum(p == self.path for p, _ in self.requests) == 1:
            self.send_error(503); return
        offset = int(self.headers.get('Range', 'bytes=0-').split('=')[1].split('-')[0])
        self.send_response(206 if offset else 200)
        self.send_header('Content-Length', str(len(BODY) - offset))
        if offset: self.send_header('Content-Range', f'bytes {offset}-{len(BODY)-1}/{len(BODY)}')
        self.end_headers()
        if self.path == '/interrupted' and offset == 0:
            self.wfile.write(BODY[:100]); self.wfile.flush(); self.close_connection = True; return
        self.wfile.write(BODY[offset:])


class Downloads(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True); cls.thread.start()
    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown(); cls.server.server_close(); cls.thread.join()
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.patcher = patch.object(setup, 'ROOT', self.root); self.patcher.start(); self.addCleanup(self.patcher.stop)
        Handler.requests = []
    def spec(self, route):
        return {'url': f'http://127.0.0.1:{self.server.server_port}{route}', 'sha256': hashlib.sha256(BODY).hexdigest()}
    def ledger(self): return [json.loads(v) for v in (self.root/'downloads/test.zip.attempts.jsonl').read_text().splitlines()]
    def github_fixture(self, *, primary=('504',), api_route='/ok', digest=None):
        spec = {'url': 'https://github.com/locked-owner/game/releases/download/godot-fixed/engine.zip',
                'sha256': digest or hashlib.sha256(BODY).hexdigest()}
        api = 'https://api.github.com/repos/locked-owner/game'
        asset_url = api + '/releases/assets/23'
        release = {'id': 17, 'tag_name': 'godot-fixed', 'draft': False, 'url': api + '/releases/17',
                   'assets': [{'id': 23, 'name': 'engine.zip', 'state': 'uploaded', 'size': len(BODY),
                               'digest': 'sha256:' + spec['sha256'], 'url': asset_url,
                               'browser_download_url': spec['url']}]}
        calls, lookups = [], []
        real_run = subprocess.run
        statuses = iter(primary)
        def lookup(request, **kwargs):
            self.assertEqual(request.full_url, api + '/releases/tags/godot-fixed')
            self.assertEqual(request.get_header('Accept'), 'application/vnd.github+json')
            self.assertIsNone(request.get_header('Authorization'))
            self.assertEqual(kwargs['timeout'], 30)
            lookups.append(request.full_url)
            return io.BytesIO(json.dumps(release).encode())
        def transfer(command, **kwargs):
            calls.append(command)
            self.assertEqual(command[0], 'curl')
            self.assertFalse(any('authorization' in p.lower() for p in command))
            if command[-1] == spec['url']:
                status = next(statuses)
                return subprocess.CompletedProcess(command, 28 if status == '000' else 22, status, 'simulated primary failure')
            self.assertEqual(command[-1], asset_url)
            self.assertIn('Accept: application/octet-stream', command)
            self.assertIn('X-GitHub-Api-Version: 2022-11-28', command)
            # Exercise actual curl, HTTP errors and Range behavior after the
            # identity-checked API URL is routed to this test's local server.
            return real_run(command[:-1] + [self.spec(api_route)['url']], **kwargs)
        for target, name, value in [(setup, 'CONFIG', {'godot': {'linux_x86_64': spec}}),
                                    (setup.urllib.request, 'urlopen', lookup),
                                    (setup.subprocess, 'run', transfer), (setup.time, 'sleep', lambda _: None)]:
            patcher = patch.object(target, name, value); patcher.start(); self.addCleanup(patcher.stop)
        return spec, release, calls, lookups
    def test_interrupted_transfer_resumes_real_range_and_cache_reuses(self):
        spec = self.spec('/interrupted')
        self.assertEqual(setup.download(spec, 'test.zip').read_bytes(), BODY)
        self.assertEqual(Handler.requests, [('/interrupted', None), ('/interrupted', 'bytes=100-')])
        self.assertEqual([v['status'] for v in self.ledger()], ['transient_failure', 'verified_download'])
        setup.download(spec, 'test.zip')
        self.assertEqual(len(Handler.requests), 2)
        self.assertEqual(self.ledger()[-1]['status'], 'verified_cache')
    def test_forbidden_is_terminal_and_not_retried(self):
        with self.assertRaisesRegex(RuntimeError, 'HTTP=403'): setup.download(self.spec('/forbidden'), 'test.zip')
        self.assertEqual(len(Handler.requests), 1)
        self.assertEqual(self.ledger()[-1]['status'], 'terminal_failure')
    def test_checksum_error_quarantines_and_never_installs(self):
        spec = self.spec('/ok'); spec['sha256'] = '0' * 64
        with self.assertRaisesRegex(RuntimeError, 'SHA256 mismatch'): setup.download(spec, 'test.zip')
        self.assertFalse((self.root/'downloads/test.zip').exists())
        self.assertTrue(list((self.root/'downloads').glob('*.rejected-*')))
        self.assertEqual(self.ledger()[-1]['status'], 'integrity_failure')
    def test_server_failure_has_bounded_retry(self):
        self.assertEqual(setup.download(self.spec('/unavailable'), 'test.zip').read_bytes(), BODY)
        self.assertEqual(len(Handler.requests), 2)
    def test_persisted_partial_recovers_in_a_new_invocation(self):
        cache=self.root/'downloads'; cache.mkdir()
        spec=self.spec('/ok')
        (cache/'test.zip.partial').write_bytes(BODY[:251])
        (cache/'test.zip.partial.sha256').write_text(spec['sha256']+'\n')
        self.assertEqual(setup.download(spec, 'test.zip').read_bytes(), BODY)
        self.assertEqual(Handler.requests, [('/ok', 'bytes=251-')])

    def test_only_gateway_errors_use_the_exact_public_asset(self):
        spec, _, calls, lookups = self.github_fixture(primary=('502', '503', '504'))
        for status in ('502', '503', '504'):
            with self.subTest(status=status):
                self.assertEqual(setup.download(spec, status + '.zip').read_bytes(), BODY)
        self.assertEqual(len(calls), 6)
        self.assertEqual(len(lookups), 3)
        self.assertEqual(Handler.requests, [('/ok', None)] * 3)

    def test_locked_primary_authentication_failure_never_uses_api(self):
        spec, _, calls, lookups = self.github_fixture(primary=('403',))
        with self.assertRaisesRegex(RuntimeError, 'HTTP=403'):
            setup.download(spec, 'test.zip')
        self.assertEqual(len(calls), 1)
        self.assertFalse(lookups)

    def test_non_godot_spec_and_different_hash_cannot_resolve(self):
        spec, _, _, lookups = self.github_fixture()
        changed = dict(spec, sha256='0' * 64)
        self.assertIsNone(setup.github_locked_asset_url(changed))
        self.assertIsNone(setup.github_locked_asset_url(dict(spec, url=spec['url'].replace('/game/', '/other/'))))
        with patch.object(setup, 'CONFIG', {'android': {'jdk_linux_x86_64': spec}}):
            self.assertIsNone(setup.github_locked_asset_url(spec))
        self.assertFalse(lookups)

    def test_api_metadata_rejects_changed_identity_or_digest(self):
        spec, release, _, _ = self.github_fixture()
        original = copy.deepcopy(release)
        variants = []
        for key, value in [('tag_name', 'another-build'), ('url', 'https://api.github.com/repos/other/game/releases/17'),
                           ('draft', True)]:
            variant = copy.deepcopy(original); variant[key] = value; variants.append(variant)
        for key, value in [('name', 'another-engine.zip'), ('state', 'new'), ('id', '23'), ('size', 0),
                           ('url', 'https://api.github.com/repos/other/game/releases/assets/23'),
                           ('browser_download_url', spec['url'].replace('/godot-fixed/', '/different/')),
                           ('digest', 'sha256:' + '0' * 64)]:
            variant = copy.deepcopy(original); variant['assets'][0][key] = value; variants.append(variant)
        duplicate = copy.deepcopy(original); duplicate['assets'] *= 2; variants.append(duplicate)
        for variant in variants:
            with self.subTest(metadata=variant):
                release.clear(); release.update(variant)
                with self.assertRaises(RuntimeError): setup.github_locked_asset_url(spec)

    def test_metadata_rate_limit_is_terminal_and_keeps_verified_install(self):
        spec, _, calls, _ = self.github_fixture()
        install = self.root / 'installed-engine'; install.write_bytes(b'previous-verified-install')
        with patch.object(setup.urllib.request, 'urlopen', side_effect=urllib.error.HTTPError('api', 429, 'limited', {}, None)):
            with self.assertRaisesRegex(RuntimeError, 'lookup HTTP=429'):
                setup.download(spec, 'test.zip')
        self.assertEqual(len(calls), 1)
        self.assertEqual(install.read_bytes(), b'previous-verified-install')
        self.assertFalse((self.root/'downloads/test.zip').exists())
        self.assertEqual(self.ledger()[-1]['status'], 'api_fallback_rejected')

    def test_api_bytes_must_still_match_locked_sha256(self):
        spec, _, calls, _ = self.github_fixture(digest='0' * 64)
        with self.assertRaisesRegex(RuntimeError, 'SHA256 mismatch'):
            setup.download(spec, 'test.zip')
        self.assertEqual(len(calls), 2)
        self.assertFalse((self.root/'downloads/test.zip').exists())
        self.assertTrue(list((self.root/'downloads').glob('*.rejected-*')))
        self.assertEqual(self.ledger()[-1]['status'], 'integrity_failure')

    def test_api_fallback_preserves_actual_range_resume(self):
        spec, _, _, _ = self.github_fixture()
        cache = self.root/'downloads'; cache.mkdir()
        (cache/'test.zip.partial').write_bytes(BODY[:251])
        (cache/'test.zip.partial.sha256').write_text(spec['sha256']+'\n')
        self.assertEqual(setup.download(spec, 'test.zip').read_bytes(), BODY)
        self.assertEqual(Handler.requests, [('/ok', 'bytes=251-')])
        self.assertEqual(self.ledger()[-1]['transport'], 'github_asset_api')

    def test_api_server_failure_remains_bounded(self):
        spec, _, calls, lookups = self.github_fixture(api_route='/always-unavailable')
        with self.assertRaisesRegex(RuntimeError, 'HTTP=503'):
            setup.download(spec, 'test.zip')
        self.assertEqual(len(calls), 3)
        self.assertEqual(len(lookups), 1)
        self.assertEqual(len(Handler.requests), 2)
        self.assertFalse((self.root/'downloads/test.zip').exists())

    def test_api_rate_limit_is_terminal(self):
        spec, _, calls, _ = self.github_fixture(api_route='/rate-limited')
        with self.assertRaisesRegex(RuntimeError, 'HTTP=429'):
            setup.download(spec, 'test.zip')
        self.assertEqual(len(calls), 2)
        self.assertEqual(self.ledger()[-1]['status'], 'terminal_failure')

    def test_late_gateway_failure_allows_only_one_extra_api_transfer(self):
        spec, _, calls, lookups = self.github_fixture(primary=('000', '000', '504'))
        self.assertEqual(setup.download(spec, 'test.zip').read_bytes(), BODY)
        self.assertEqual(len(calls), 4)
        self.assertEqual(len(lookups), 1)


def load_tests(loader, tests, pattern):
    # Keep this existing CI check as the complete non-engine installation gate.
    import importlib.util
    root = Path(__file__).resolve().parent.parent
    for name, path in [('engine_build_contract_tests', root / 'tools/engine/test_build_contract.py'),
                       ('godot_identity_tests', root / 'tests/test_godot_identity.py')]:
        spec = importlib.util.spec_from_file_location(name, path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        tests.addTests(loader.loadTestsFromModule(module))
    return tests


if __name__ == '__main__': unittest.main()
