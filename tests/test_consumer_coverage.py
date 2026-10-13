"""General negative cases for scope/evidence, not platform-specific checklists."""
import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from quality import validate_consumer_coverage

class ConsumerCoverageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'inventory.json').write_text(json.dumps({'consumers': [{'id': 'primary'}, {'id': 'alternate'}]}))
        self.evidence = {
            'inventory': {'kind': 'runtime_trace', 'path': 'inventory.json', 'source_commit': 'a'*40, 'content_version': 'v1'},
            'screen': {'kind': 'screenshot', 'consumers': ['primary', 'alternate'], 'source_commit': 'a'*40, 'content_version': 'v1'},
            'helper': {'kind': 'command', 'consumers': ['primary', 'alternate'], 'source_commit': 'a'*40, 'content_version': 'v1'},
        }
        self.coverage = {'scope': 'two discovered rendering paths', 'inventory_evidence': 'inventory', 'observations': [
            {'consumer': key, 'output': 'visual', 'status': 'passed', 'reason': 'Observed actual pixels', 'evidence': ['screen']}
            for key in ('primary', 'alternate')]}
    def validate(self):
        return validate_consumer_coverage(self.coverage, self.evidence, self.root)
    def test_complete_bounded_observations(self):
        self.assertEqual(self.validate(), ([], []))
    def test_omitted_alternate_rejected(self):
        self.coverage['observations'].pop()
        self.assertTrue(self.validate()[0])
    def test_unused_helper_pass_rejected(self):
        self.coverage['observations'][1]['evidence'] = ['helper']
        self.assertTrue(self.validate()[0])
    def test_one_scene_cannot_cover_another(self):
        self.evidence['screen']['consumers'] = ['primary']
        self.assertTrue(self.validate()[0])
    def test_unobserved_blocks_completion(self):
        self.coverage['observations'][1]['status'] = 'unverified'
        self.assertTrue(self.validate()[1])
    def test_stale_output_rejected(self):
        self.evidence['screen']['source_commit'] = 'b'*40
        self.assertTrue(self.validate()[0])
    def test_duplicate_consumer_rejected(self):
        self.coverage['observations'].append(copy.deepcopy(self.coverage['observations'][0]))
        self.assertTrue(self.validate()[0])

if __name__ == '__main__':
    unittest.main()
