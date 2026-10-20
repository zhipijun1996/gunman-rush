"""Replay fresh two-consumer evidence and refuse cross-channel identity tampering.

No engine is launched here. --native-dir must be an actual successful split run.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

import run_forest_depth_versions as verifier

NATIVE_DIR = None


class NativeAggregationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir=verifier.ROOT / 'build')
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.reports, self.receipts = {}, {}
        original = json.loads((NATIVE_DIR / 'receipt.json').read_text())
        self.run_id, self.sources = original['run_id'], original['verifier_before']
        for phase in verifier.PHASES:
            for suffix in ('json', 'log'):
                shutil.copyfile(NATIVE_DIR / f'{phase}.{suffix}', self.directory / f'{phase}.{suffix}')
            self.reports[phase] = json.loads((self.directory / f'{phase}.json').read_text())
            receipt = json.loads((NATIVE_DIR / f'{phase}-receipt.json').read_text())
            receipt['rawlog'] = str((self.directory / f'{phase}.log').relative_to(verifier.ROOT))
            receipt['report'] = str((self.directory / f'{phase}.json').relative_to(verifier.ROOT))
            receipt['argv'] = [('--output=res://' + receipt['report']) if arg.startswith('--output=') else arg for arg in receipt['argv']]
            self.receipts[phase] = receipt

    def call(self):
        return verifier.aggregate(self.reports, self.receipts, self.run_id, self.sources, self.directory)

    def resign_report(self, phase):
        path = self.directory / f'{phase}.json'
        path.write_text(json.dumps(self.reports[phase], ensure_ascii=False, indent=2) + '\n')
        self.receipts[phase]['report_sha256'] = verifier.file_sha(path)

    def identity_everywhere(self, phase, **edits):
        identity = self.reports[phase]['identity']
        raw_path = self.directory / f'{phase}.log'
        old = next(line for line in raw_path.read_text().splitlines() if line.startswith('FOREST VERSION PHASE: '))
        identity.update(edits)
        raw_path.write_text(raw_path.read_text().replace(old, 'FOREST VERSION PHASE: ' + json.dumps(identity)))
        self.receipts[phase]['native_identity'] = copy.deepcopy(identity)
        self.receipts[phase]['engine_pid'] = identity['engine_pid']
        self.receipts[phase]['rawlog_sha256'] = verifier.file_sha(raw_path)
        self.resign_report(phase)

    def refused(self):
        with self.assertRaises((ValueError, RuntimeError, KeyError)):
            self.call()

    def test_exact_original327_and24(self):
        actual = self.call()
        self.assertEqual((actual['assertions'], len(actual['checks']), len(actual['cases'])), (327, 327, 24))
        self.assertEqual(actual['checks'], self.reports['data']['checks'][:276] + self.reports['world']['checks'] + self.reports['data']['checks'][276:])
        verifier.validate_fruit_version(actual)

    def test_stale_run_id(self):
        self.run_id = 'f' * 32
        self.refused()

    def test_foreign_source_map(self):
        self.sources = dict(self.sources, **{verifier.PHASE_SCRIPTS['data']: '0' * 64})
        self.refused()

    def test_foreign_script_even_resigned(self):
        self.identity_everywhere('world', script_sha256='0' * 64)
        self.refused()

    def test_same_pid_even_resigned(self):
        self.identity_everywhere('world', engine_pid=self.reports['data']['identity']['engine_pid'])
        self.refused()

    def test_wrong_pid_receipt(self):
        self.receipts['world']['engine_pid'] += 1
        self.refused()

    def test_reordered_phase(self):
        self.reports = {'world': self.reports['world'], 'data': self.reports['data']}
        self.refused()

    def test_missing_phase(self):
        self.reports.pop('world')
        self.refused()

    def test_wrong_phase_receipt_order(self):
        self.receipts['world']['sequence'] = 0
        self.refused()

    def test_missing_case_even_resigned(self):
        self.reports['data']['cases'].pop()
        self.resign_report('data')
        self.refused()

    def test_wrong_case_order_even_resigned(self):
        self.reports['world']['cases'].reverse()
        self.resign_report('world')
        self.refused()

    def test_bool_map_not_integer_even_resigned(self):
        self.reports['world']['cases'][0]['map'] = True
        self.resign_report('world')
        self.refused()

    def test_omitted_assertion_even_resigned(self):
        self.reports['data']['checks'].pop()
        self.resign_report('data')
        self.refused()

    def test_label_changed_even_resigned(self):
        self.reports['world']['checks'][0]['label'] = 'unrelated check'
        self.resign_report('world')
        self.refused()

    def test_native_check_false_even_resigned(self):
        self.reports['world']['checks'][0]['passed'] = False
        self.resign_report('world')
        self.refused()

    def test_typed_bool_pass_counter(self):
        self.reports['world']['failures'] = False
        self.resign_report('world')
        self.refused()

    def test_complete_fruit_validator_not_bypassed(self):
        self.reports['data']['cases'][-1]['candidate_manifest']['version'] = 'future'
        self.resign_report('data')
        self.refused()

    def test_raw_log_mutated(self):
        path = self.directory / 'world.log'
        path.write_text(path.read_text() + '\nchanged\n')
        self.refused()

    def test_raw_error_even_rehashed(self):
        path = self.directory / 'world.log'
        path.write_text(path.read_text() + '\nERROR: deliberate native failure\n')
        self.receipts['world']['rawlog_sha256'] = verifier.file_sha(path)
        self.refused()

    def test_report_bytes_mutated(self):
        path = self.directory / 'world.json'
        path.write_text(path.read_text() + '\n')
        self.refused()

    def test_foreign_in_memory_report(self):
        self.reports['world']['cases'][0]['fallback']['same_state'] = False
        self.refused()

    def test_failed_native_receipt(self):
        self.receipts['world']['status'] = 'failed'
        self.receipts['world']['exit_code'] = 1
        self.refused()

    def test_each90_instead_of_shared90(self):
        self.receipts['world']['timeout_seconds'] = 90
        self.refused()

    def test_budget_overrun(self):
        self.receipts['world']['shared_elapsed_end'] = 90.001
        self.refused()

    def test_native_phase_overlap(self):
        self.receipts['world']['shared_elapsed_start'] = 0
        self.receipts['world']['timeout_seconds'] = 90
        self.refused()

    def test_wrong_script_argv(self):
        args = self.receipts['world']['argv']
        args[args.index('--script') + 1] = verifier.PHASE_SCRIPTS['data']
        self.refused()

    def test_missing_run_id_argv(self):
        self.receipts['world']['argv'] = [arg for arg in self.receipts['world']['argv'] if not arg.startswith('--run-id=')]
        self.refused()

    def test_wrong_output_argv(self):
        self.receipts['world']['argv'] = ['--output=res://build/foreign.json' if arg.startswith('--output=') else arg for arg in self.receipts['world']['argv']]
        self.refused()

    def test_removed_fixed_fps_argv(self):
        args = self.receipts['world']['argv']
        index = args.index('--fixed-fps')
        del args[index:index+2]
        self.refused()

    def test_changed_fixed_fps_argv(self):
        args = self.receipts['world']['argv']
        args[args.index('--fixed-fps') + 1] = '30'
        self.refused()

    def test_success_receipt_cannot_be_failure_probe(self):
        self.receipts['world']['argv'].append('--failure-probe')
        self.refused()

    def test_boolean_phase_sequence(self):
        self.receipts['data']['sequence'] = False
        self.refused()

    def test_boolean_receipt_pid(self):
        self.receipts['world']['engine_pid'] = True
        self.refused()

    def test_forged_duration(self):
        self.receipts['world']['duration_seconds'] += 1
        self.refused()

    def test_report_identity_equal_float_pid(self):
        self.reports['world']['identity']['engine_pid'] = float(self.reports['world']['identity']['engine_pid'])
        self.resign_report('world')
        self.refused()

    def test_receipt_identity_equal_float_pid(self):
        self.receipts['world']['native_identity']['engine_pid'] = float(self.receipts['world']['native_identity']['engine_pid'])
        self.refused()

    def test_all_identity_pid_type_channels(self):
        for phase in verifier.PHASES:
            for channel in ('report', 'receipt'):
                identity = self.reports[phase]['identity'] if channel == 'report' else self.receipts[phase]['native_identity']
                old = identity['engine_pid']
                for value in (float(old), True, None, str(old)):
                    with self.subTest(phase=phase, channel=channel, value=value):
                        identity['engine_pid'] = value
                        if channel == 'report':self.resign_report(phase)
                        self.refused()
                identity['engine_pid'] = old
                if channel == 'report':self.resign_report(phase)

    def test_shared_timing_rejects_boolean_nonfinite_and_string(self):
        receipt = self.receipts['world']
        for key in ('timeout_seconds', 'shared_elapsed_start', 'shared_elapsed_end', 'duration_seconds'):
            old = receipt[key]
            for value in (True, float('nan'), float('inf'), str(old), None):
                with self.subTest(field=key, value=value):
                    receipt[key] = value
                    self.refused()
            receipt[key] = old

    def test_phase_sequence_rejects_equal_float(self):
        self.receipts['world']['sequence'] = 1.0
        self.refused()

    def test_top_level_pid_rejects_equal_float(self):
        self.receipts['world']['engine_pid'] = float(self.receipts['world']['engine_pid'])
        self.refused()

    def test_native_identity_extra_field(self):
        self.reports['world']['identity']['foreign'] = 'extra'
        self.resign_report('world')
        self.refused()

    def test_native_identity_missing_field(self):
        self.receipts['world']['native_identity'].pop('run_id')
        self.refused()

    def test_engine_major_equal_float(self):
        self.reports['world']['engine']['major'] = float(self.reports['world']['engine']['major'])
        self.resign_report('world')
        self.refused()

    def test_both_native_engines_cannot_be_null(self):
        for phase in verifier.PHASES:
            self.reports[phase]['engine'] = None
            self.resign_report(phase)
        self.refused()

    def test_existing_output_refused_before_native(self):
        before = {p.name: verifier.file_sha(p) for p in NATIVE_DIR.iterdir() if p.is_file()}
        result = subprocess.run([sys.executable, str(verifier.ROOT / 'tools/run_forest_depth_versions.py'), '--output-dir', str(NATIVE_DIR)], cwd=verifier.ROOT, capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 2)
        self.assertIn('Fresh output', result.stderr)
        self.assertNotIn('PASS:', result.stdout)
        self.assertEqual(before, {p.name: verifier.file_sha(p) for p in NATIVE_DIR.iterdir() if p.is_file()})


def main():
    global NATIVE_DIR
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--native-dir', type=Path, required=True)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    NATIVE_DIR = args.native_dir.resolve()
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(NativeAggregationTests)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps({'tests_run': result.testsRun, 'failures': len(result.failures), 'errors': len(result.errors), 'actual_native_receipt': str(NATIVE_DIR / 'receipt.json'), 'actual_native_receipt_sha256': verifier.file_sha(NATIVE_DIR / 'receipt.json'), 'test_source_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(), 'scope': 'One positive and cross-channel tamper/reuse refusals; Python validation only, no new native execution'}, indent=2) + '\n')
    return 0 if result.wasSuccessful() else 1


if __name__ == '__main__':
    raise SystemExit(main())
