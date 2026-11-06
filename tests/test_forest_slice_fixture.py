"""Fixture identity guards for retained real-controller forest regressions."""
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from forest_slice_fixture import PATH, load_fixture


class ForestSliceFixtureTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.data = json.loads((ROOT / PATH).read_bytes())
        for case in self.data['cases'].values():
            for field in ('runner', 'traversal'):
                p = self.root / case[field]
                p.parent.mkdir(parents=True, exist_ok=True)
                p.write_bytes((ROOT / case[field]).read_bytes())
        (self.root / PATH).parent.mkdir(parents=True, exist_ok=True)
        self.write_fixture()

    def write_fixture(self):
        (self.root / PATH).write_text(json.dumps(self.data))

    def test_h_only_fixtures_need_no_live_design_stage_or_gate(self):
        for kind in ('current', 'historical'):
            receipt = load_fixture(kind, self.root)
            self.assertEqual(receipt['allowed_capabilities'], ['H'])
            for source in receipt['sources']:
                self.assertEqual(source['sha256'], hashlib.sha256((self.root / source['path']).read_bytes()).hexdigest())

    def test_extra_capability_cannot_silently_change_regression_scope(self):
        self.data['allowed_capabilities'].append('D')
        self.write_fixture()
        with self.assertRaisesRegex(ValueError, 'Invalid legacy'):
            load_fixture('current', self.root)

    def test_swapped_consumer_and_missing_resource_fail_closed(self):
        for field in ('runner', 'traversal'):
            original = self.data['cases']['current'][field]
            self.data['cases']['current'][field] = self.data['cases']['historical'][field]
            self.write_fixture()
            with self.assertRaisesRegex(ValueError, 'real runner/traversal'):
                load_fixture('current', self.root)
            self.data['cases']['current'][field] = original
        self.write_fixture()
        (self.root / self.data['cases']['current']['traversal']).unlink()
        with self.assertRaises(FileNotFoundError):
            load_fixture('current', self.root)

    def test_changed_resource_updates_receipt_instead_of_reusing_old_hash(self):
        before = load_fixture('historical', self.root)
        (self.root / before['case']['traversal']).write_text('changed fixture bytes')
        self.assertNotEqual(before['sources'], load_fixture('historical', self.root)['sources'])

    def test_manual_registration_matches_fixture_runners(self):
        checks = json.loads((ROOT / 'tools/harness/profiles.json').read_bytes())['checks']
        for name, script in [('forest-current-slice', 'tools/run_forest_current_slice_tests.py'),
                             ('forest-historical-slice', 'tools/run_forest_h_slice_tests.py')]:
            self.assertEqual(checks[name]['mode'], 'manual')
            self.assertEqual(checks[name]['argv'], ['python3', script])
        self.assertNotIn('forest-h-slice', checks)  # Old frozen-registry ID stays retired.


if __name__ == '__main__':
    unittest.main()
