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
        with patch.object(CLI, 'run_engine', side_effect=['', 'GRAPPLE FEEL RESULT: 38 checks, 0 failures\n', 'GRAPPLE AIM INPUT: 119 checks, 0 failures\n', 'GRAPPLE LASER INPUT: 174 assertions, 0 failures\n']) as native:
            CLI.main()
        self.assertEqual(len(native.call_args_list), 4)
        self.assertEqual(native.call_args_list[-1].args[0][-1], 'tests/grapple_laser_input_runner.gd')

    def test_zero_exit_without_each_complete_summary(self):
        for outputs in (['', ''], ['', 'GRAPPLE FEEL RESULT: 38 checks, 0 failures\n', ''], ['', 'GRAPPLE FEEL RESULT: 38 checks, 0 failures\n', 'GRAPPLE AIM INPUT: 119 checks, 0 failures\n', '']):
            with self.subTest(outputs=outputs), patch.object(CLI, 'run_engine', side_effect=outputs):
                with self.assertRaisesRegex(RuntimeError, 'Missing complete'):
                    CLI.main()

    def test_native_failure_and_timeout_remain_failures(self):
        for failure in (RuntimeError('native exit 1'), subprocess.TimeoutExpired('native', 90)):
            with self.subTest(failure=failure), patch.object(CLI, 'run_engine', side_effect=['', failure]):
                with self.assertRaises(type(failure)):
                    CLI.main()


if __name__ == '__main__':
    unittest.main()
