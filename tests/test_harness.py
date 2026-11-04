"""The manual runner must reject incomplete and failed processes."""
import contextlib
import io
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
import harness as h


class RunnerTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.log = self.root / 'native.log'

    def run_code(self, code, timeout=3):
        check = {'argv': [sys.executable, '-c', code],
                 'timeout_seconds': timeout, 'success_pattern': '^COMPLETE$'}
        return h.run_check(check, self.log, root=self.root)

    def test_success_requires_real_exit_and_completion(self):
        self.assertEqual(self.run_code("print('COMPLETE')")['status'], 'passed')
        self.assertEqual(self.run_code("print('partial')")['failure_reason'], 'missing_completion')
        self.assertEqual(self.run_code("print('COMPLETE'); raise SystemExit(7)")['failure_reason'], 'nonzero_exit')

    def test_runtime_errors_fail_even_after_completion(self):
        for message in ['SCRIPT ERROR: bad', 'Parse Error: bad', 'SHADER ERROR: bad',
                        'ERROR: Failed to load script bad', 'ObjectDB instances leaked at exit',
                        '2 resources still in use at exit']:
            with self.subTest(message=message):
                result = self.run_code(f"print('COMPLETE'); print({message!r})")
                self.assertEqual(result['status'], 'failed')

    def test_timeout_after_completion_still_fails(self):
        result = self.run_code("import time; print('COMPLETE', flush=True); time.sleep(30)", timeout=0.15)
        self.assertEqual(result['status'], 'timeout')
        self.assertEqual(result['failure_reason'], 'timeout')
        self.assertLess(result['duration_seconds'], 5)

    def test_timeout_cleans_up_child(self):
        pidfile = self.root / 'child.pid'
        self.run_code("import pathlib,subprocess,sys,time; child=subprocess.Popen([sys.executable,'-c','import time; time.sleep(30)']); pathlib.Path('child.pid').write_text(str(child.pid)); time.sleep(30)", timeout=0.3)
        pid = int(pidfile.read_text())
        # A reparented zombie is already dead and cannot execute further work.
        process = Path(f'/proc/{pid}/stat')
        if process.exists():
            self.assertEqual(process.read_text().rpartition(')')[2].split()[0], 'Z')

    def test_missing_executable_fails(self):
        result = h.run_check({'argv': ['/missing/engine'], 'timeout_seconds': 1,
                              'success_pattern': '^COMPLETE$'}, self.log, root=self.root)
        self.assertEqual(result['failure_reason'], 'launch_error')

    def test_default_list_and_plan_do_not_execute(self):
        data = {'checks': {'test': {'mode': 'manual', 'argv': ['python3', 'test.py'],
                                  'timeout_seconds': 1, 'success_pattern': '^COMPLETE$'}}}
        with patch.object(h, 'load_manifest', return_value=data), patch.object(h, 'run_check') as run:
            for argv in [[], ['--list'], ['--check', 'test', '--plan']]:
                with contextlib.redirect_stdout(io.StringIO()):
                    self.assertEqual(h.main(argv), 0)
            run.assert_not_called()

    def test_selected_tests_stop_at_failure(self):
        data = {'checks': {name: {'mode': 'manual', 'argv': ['python3', f'{name}.py'],
                                 'timeout_seconds': 1, 'success_pattern': '^COMPLETE$'}
                           for name in ['first', 'second']}}
        failure = {'status': 'failed', 'failure_reason': 'missing_completion'}
        def fail(check, log):
            log.write_text('early exit\n')
            return failure
        with patch.object(h, 'ROOT', self.root), patch.object(h, 'load_manifest', return_value=data), \
             patch.object(h, 'run_check', side_effect=fail) as run, contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(h.main(['--check', 'first', '--check', 'second']), 1)
            self.assertEqual(run.call_count, 1)
        report = json.loads(next((self.root / 'build').rglob('report.json')).read_text())
        self.assertEqual([item['id'] for item in report['checks']], ['first'])

    def test_registry_has_only_explicit_manual_commands(self):
        data = h.load_manifest()
        self.assertEqual(data['profiles'], {})
        for check in data['checks'].values():
            self.assertEqual(set(check), {'mode', 'argv', 'timeout_seconds', 'success_pattern'})
            self.assertEqual(check['mode'], 'manual')


if __name__ == '__main__':
    unittest.main()
