#!/usr/bin/env python3
"""Exercise the real curl downloader against a local HTTP failure server."""
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import tempfile
import threading
import unittest
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
