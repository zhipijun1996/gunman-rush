"""Isolated wrapper refusal tests; these fake processes certify no game content."""
import contextlib
import hashlib
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
import run_forest_exploration_contract as wrapper


class WrapperTests(unittest.TestCase):
    def run_case(self, failure=None):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / 'scripts/example.gd'
            source.parent.mkdir()
            source.write_text('before')
            calls, heads = [], []

            def git(*arguments):
                if arguments[0] == 'rev-parse':
                    heads.append(True)
                    return (('b' * 40 if failure == 'head_drift' and len(heads) > 1 else 'a' * 40) + '\n').encode()
                return b'scripts/example.gd\0'

            def inventory():
                return {'scripts/example.gd': hashlib.sha256(source.read_bytes()).hexdigest()}

            def engine(arguments, timeout):
                self.assertEqual(timeout, 90)
                calls.append(arguments)
                if '--editor' in arguments:
                    return 'SIMULATED import\n'
                self.assertEqual(arguments[arguments.index('--fixed-fps') + 1], '60')
                script = arguments[arguments.index('--script') + 1]
                labels = {
                    'tests/forest_exploration_modules_runner.gd': 'FOREST EXPLORATION MODULES',
                    'tests/forest_exploration_world_runner.gd': 'FOREST EXPLORATION WORLD',
                    'tests/forest_thorn_corridor_modules_runner.gd': 'FOREST THORN CORRIDORS',
                    'tests/forest_exploration_ecology_runner.gd': 'FOREST EXPLORATION ECOLOGY',
                    'tests/forest_exploration_menu_runner.gd': 'FOREST EXPLORATION MENU',
                }
                label = labels[script]
                is_module = script == 'tests/forest_exploration_modules_runner.gd'
                partial = 'SIMULATED partial native output\nsecond native line\n'
                if is_module and failure in {'native_nonzero', 'timeout'}:
                    print(partial, end='')
                    if failure == 'timeout':
                        raise subprocess.TimeoutExpired(['SIMULATED'], timeout, output=partial.encode())
                    raise RuntimeError('Godot returned 7')
                for argument in arguments:
                    if argument.startswith('--output='):
                        target = root / argument.split('res://', 1)[1]
                    elif argument.startswith('--output-dir='):
                        target = root / argument.split('res://', 1)[1] / 'report.json'
                    else:
                        continue
                    target.parent.mkdir(parents=True, exist_ok=True)
                    data = {'assertions': 1, 'failures': 0}
                    if is_module and failure == 'report_count':
                        data['assertions'] = 2
                    if is_module and failure == 'zero_report':
                        data['assertions'] = 0
                    target.write_text(json.dumps(data))
                if len(calls) == 5:
                    self.assertIn('--borrow-pod-only', arguments)
                    if failure == 'source_drift':
                        source.write_text('after')
                text = label + ': 1 assertions, 0 failures\n'
                if is_module and failure == 'missing_marker':
                    text = 'SIMULATED no completion\n'
                if is_module and failure == 'zero_marker':
                    text = label + ': 0 assertions, 0 failures\n'
                if is_module and failure == 'duplicate_marker':
                    text *= 2
                print(text, end='')
                return text

            output = root / 'build/fresh'
            stdout, stderr = io.StringIO(), io.StringIO()
            with (patch.object(wrapper, 'ROOT', root), patch.object(wrapper, 'git', git),
                  patch.object(wrapper, 'inventory', inventory), patch.object(wrapper, 'run_engine', engine),
                  contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr)):
                code = wrapper.main(['--output-dir', str(output)])
            self.assertEqual(code, 0 if failure is None else 1)
            self.assertEqual(len(calls), 6, 'A failed check must not suppress the remaining contracts')
            receipt = json.loads((output / 'receipt.json').read_text())
            self.assertEqual(receipt['exit_code'], code)
            self.assertEqual(len(receipt['checks']), 6)
            self.assertEqual(receipt['baseline_head'], 'a' * 40)
            for name in ('import', 'modules', 'world', 'corridor', 'borrow-pod', 'menu'):
                self.assertTrue((output / (name + '.log')).is_file())
            if failure in {'native_nonzero', 'timeout'}:
                self.assertIn('SIMULATED partial native output\nsecond native line\n',
                              (output / 'modules.log').read_text())
                self.assertIn('WRAPPER FAILURE:', (output / 'modules.log').read_text())
            before = json.loads((output / 'source-before.json').read_text())
            after = json.loads((output / 'source-after.json').read_text())
            for phase, expected in (('before', 'before'), ('after', 'after' if failure == 'source_drift' else 'before')):
                archived = json.loads((output / ('source-bytes-' + phase + '.json')).read_text())
                self.assertEqual(archived['baseline_head'], 'a' * 40)
                row = archived['files']['scripts/example.gd']
                original = output / row['path']
                self.assertEqual(original.read_text(), expected)
                self.assertEqual(hashlib.sha256(original.read_bytes()).hexdigest(), row['sha256'])
                self.assertEqual(row['sha256'], (before if phase == 'before' else after)['scripts/example.gd'])
            if failure is None:
                self.assertTrue(receipt['source_stable'])
                self.assertEqual(before, after)
                self.assertEqual(stdout.getvalue(), 'PASS: forest exploration contracts\n')
                self.assertFalse((output / 'source-snapshot-after').exists(), 'Stable bytes reuse their original copy')
            else:
                self.assertNotIn('PASS: forest exploration contracts', stdout.getvalue())
            if failure in {'source_drift', 'head_drift'}:
                self.assertFalse(receipt['source_stable'])
                self.assertTrue(all(row['passed'] for row in receipt['checks']))
            elif failure is not None:
                self.assertFalse(receipt['checks'][1]['passed'])
                self.assertTrue(all(row['passed'] for row in receipt['checks'][2:]))

    def test_success_preserves_exact_changed_source_bytes_and_complete_inventory(self):
        self.run_case()

    def test_native_nonzero_preserves_complete_partial_log_and_continues(self):
        self.run_case('native_nonzero')

    def test_timeout_preserves_complete_partial_log_and_continues(self):
        self.run_case('timeout')

    def test_missing_zero_or_nonunique_completion_is_refused(self):
        for failure in ('missing_marker', 'zero_marker', 'duplicate_marker'):
            with self.subTest(failure=failure):
                self.run_case(failure)

    def test_nonempty_report_and_marker_count_must_agree(self):
        for failure in ('report_count', 'zero_report'):
            with self.subTest(failure=failure):
                self.run_case(failure)

    def test_changed_source_fails_even_when_every_native_check_passes(self):
        self.run_case('source_drift')

    def test_changed_head_fails_even_when_every_native_check_passes(self):
        self.run_case('head_drift')


if __name__ == '__main__':
    unittest.main()
