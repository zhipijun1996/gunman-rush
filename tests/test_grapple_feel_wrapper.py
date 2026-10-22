"""The registered CLI must reject early exits and incomplete native summaries."""
import importlib.util
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
spec = importlib.util.spec_from_file_location('grapple_cli', ROOT / 'tools/run_grapple_feel_tests.py')
CLI = importlib.util.module_from_spec(spec)
spec.loader.exec_module(CLI)


class GrappleCompletion(unittest.TestCase):
    def test_complete_both_consumers(self):
        with patch.object(CLI, 'run_engine', side_effect=['', 'GRAPPLE FEEL RESULT: 38 checks, 0 failures\n', 'GRAPPLE AIM INPUT: 119 checks, 0 failures\n', 'GRAPPLE LASER INPUT: 174 assertions, 0 failures\n', 'GRAPPLE FOCUS HUD: 1 checks / 0 failures\n', 'GRAPPLE CHAIN INPUT: 1 checks / 0 failures\n', 'FIXED HOOK JUMP RESULT: 43 checks, 0 failures\n']) as native:
            CLI.main()
        self.assertEqual(len(native.call_args_list), 7)
        self.assertEqual(native.call_args_list[3].args[0][-1], 'tests/grapple_laser_input_runner.gd')
        self.assertEqual(native.call_args_list[4].args[0][-1], 'tests/grapple_focus_hud_runner.gd')
        self.assertEqual(native.call_args_list[5].args[0][-1], 'tests/grapple_chain_input_runner.gd')
        self.assertEqual(native.call_args_list[6].args[0][-1], 'tests/fixed_hook_jump_height_runner.gd')
        self.assertTrue(all(call.args[1] == 90 for call in native.call_args_list))

    def test_zero_exit_without_each_complete_summary(self):
        for outputs in (['', ''], ['', 'GRAPPLE FEEL RESULT: 38 checks, 0 failures\n', ''], ['', 'GRAPPLE FEEL RESULT: 38 checks, 0 failures\n', 'GRAPPLE AIM INPUT: 119 checks, 0 failures\n', '']):
            with self.subTest(outputs=outputs), patch.object(CLI, 'run_engine', side_effect=outputs):
                with self.assertRaisesRegex(RuntimeError, 'Missing complete'):
                    CLI.main()

    def test_hud_requires_its_complete_summary(self):
        outputs = ['', 'GRAPPLE FEEL RESULT: 38 checks, 0 failures\n',
                   'GRAPPLE AIM INPUT: 119 checks, 0 failures\n',
                   'GRAPPLE LASER INPUT: 174 assertions, 0 failures\n', '']
        with patch.object(CLI, 'run_engine', side_effect=outputs):
            with self.assertRaisesRegex(RuntimeError, 'grapple_focus_hud_runner'):
                CLI.main()

    def test_chain_requires_its_complete_summary(self):
        outputs = ['', 'GRAPPLE FEEL RESULT: 38 checks, 0 failures\n',
                   'GRAPPLE AIM INPUT: 119 checks, 0 failures\n',
                   'GRAPPLE LASER INPUT: 174 assertions, 0 failures\n',
                   'GRAPPLE FOCUS HUD: 1 checks / 0 failures\n', '']
        with patch.object(CLI, 'run_engine', side_effect=outputs):
            with self.assertRaisesRegex(RuntimeError, 'grapple_chain_input_runner'):
                CLI.main()

    def test_new_native_failure_and_timeout_propagate(self):
        prefix = ['', 'GRAPPLE FEEL RESULT: 38 checks, 0 failures\n',
                  'GRAPPLE AIM INPUT: 119 checks, 0 failures\n',
                  'GRAPPLE LASER INPUT: 174 assertions, 0 failures\n']
        for index in (0, 1):
            for failure in (RuntimeError('native exit 1'), subprocess.TimeoutExpired('native', 90)):
                outputs = prefix + (['GRAPPLE FOCUS HUD: 1 checks / 0 failures\n'] if index else []) + [failure]
                with self.subTest(index=index, failure=failure), patch.object(CLI, 'run_engine', side_effect=outputs):
                    with self.assertRaises(type(failure)):
                        CLI.main()

    def test_fixed_jump_requires_its_own_complete_summary_and_propagates_failures(self):
        prefix = ['', 'GRAPPLE FEEL RESULT: 38 checks, 0 failures\n',
                  'GRAPPLE AIM INPUT: 119 checks, 0 failures\n',
                  'GRAPPLE LASER INPUT: 174 assertions, 0 failures\n',
                  'GRAPPLE FOCUS HUD: 1 checks / 0 failures\n',
                  'GRAPPLE CHAIN INPUT: 1 checks / 0 failures\n']
        for output in ('', 'FIXED HOOK JUMP RESULT: 43 checks, 1 failures\n',
                       'FIXED HOOK JUMP RESULT: 0 checks, 0 failures\n'):
            with self.subTest(output=output), patch.object(CLI, 'run_engine', side_effect=prefix+[output]):
                with self.assertRaisesRegex(RuntimeError, 'fixed_hook_jump_height_runner'):
                    CLI.main()
        for failure in (RuntimeError('native exit 1'), subprocess.TimeoutExpired('native', 90)):
            with self.subTest(failure=failure), patch.object(CLI, 'run_engine', side_effect=prefix+[failure]):
                with self.assertRaises(type(failure)):
                    CLI.main()

    def test_native_failure_and_timeout_remain_failures(self):
        for failure in (RuntimeError('native exit 1'), subprocess.TimeoutExpired('native', 90)):
            with self.subTest(failure=failure), patch.object(CLI, 'run_engine', side_effect=['', failure]):
                with self.assertRaises(type(failure)):
                    CLI.main()


if __name__ == '__main__':
    unittest.main()
