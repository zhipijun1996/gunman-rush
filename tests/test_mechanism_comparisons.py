"""Promotion dependency tests. Synthetic records never stand for play evidence."""
import copy
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from level_design_contracts import validate_mechanism_comparisons
import production_loop


def fixture():
    basis = dict(source='fixture-source', capability='H,R', entry='same entrance',
                 resources='same HP and ammo', phase='same first phase')
    cases = [dict(role=role, basis=copy.deepcopy(basis), evidence=[role],
                  observed='Synthetic observation, not a real runtime result')
             for role in ('intended', 'cheap', 'ablation')]
    cases[2]['ablated'] = 'H request'
    return dict(owner='author', reviewed_commit='fixture-source', evidence=[
        *[dict(id=role, kind='runtime_trace', source_commit='fixture-source') for role in ('intended', 'cheap', 'ablation')],
        dict(id='review', kind='review', reviewer='separate reviewer', implementers=['author'],
             source_commit='fixture-source', independent=True, independence_basis='Different author; independently inspected all cases', verdict='ACCEPT')],
        mechanism_comparisons=[dict(id='test mechanism', alternatives=['lateral interception', 'falling redirection'],
            claim='Changing direction creates a reachable firing opportunity', basis=basis, cases=cases,
            review_evidence='review', decision='continue')])


class MechanismComparisons(unittest.TestCase):
    def test_complete_declaration_only_is_structurally_valid(self):
        self.assertEqual(validate_mechanism_comparisons(fixture()), [])

    def test_each_case_and_review_are_required(self):
        for role in ('intended', 'cheap', 'ablation'):
            record = fixture()
            record['mechanism_comparisons'][0]['cases'] = [
                c for c in record['mechanism_comparisons'][0]['cases'] if c['role'] != role]
            self.assertTrue(validate_mechanism_comparisons(record), role)
        record = fixture(); record['evidence'].pop()
        self.assertTrue(validate_mechanism_comparisons(record))

    def test_mismatched_resources_rejected(self):
        record = fixture()
        record['mechanism_comparisons'][0]['cases'][1]['basis']['resources'] = 'infinite health'
        self.assertTrue(validate_mechanism_comparisons(record))

    def test_prose_is_not_a_runtime_case(self):
        record = fixture(); record['evidence'][1]['kind'] = 'spec'
        self.assertTrue(validate_mechanism_comparisons(record))

    def test_other_source_or_untyped_kind_cannot_bypass(self):
        for index in range(4):
            record = fixture(); record['evidence'][index]['source_commit'] = 'other source'
            self.assertTrue(validate_mechanism_comparisons(record))
        record = fixture(); record['mechanism_comparisons'][0]['basis']['source'] = 'other source'
        self.assertTrue(validate_mechanism_comparisons(record))
        record = fixture(); record['evidence'][0]['kind'] = {}
        self.assertTrue(validate_mechanism_comparisons(record))

    def test_self_review_reject_and_unverified_cannot_promote(self):
        for change in ({'reviewer': 'author'}, {'independent': False}, {'verdict': 'REJECT'},
                       {'verdict': 'UNVERIFIED'}, {'implementers': []}):
            record = fixture(); record['evidence'][-1].update(change)
            self.assertTrue(validate_mechanism_comparisons(record), change)
        for decision in ('revise', 'drop', 'unverified'):
            record = fixture(); record['mechanism_comparisons'][0]['decision'] = decision
            self.assertTrue(validate_mechanism_comparisons(record))

    def test_hypotheses_and_named_ablation_required(self):
        for alternatives in ([], ['same', 'same'], ['one']):
            record = fixture(); record['mechanism_comparisons'][0]['alternatives'] = alternatives
            self.assertTrue(validate_mechanism_comparisons(record))
        record = fixture(); record['mechanism_comparisons'][0]['cases'][2].pop('ablated')
        self.assertTrue(validate_mechanism_comparisons(record))

    def test_malformed_nested_values_fail_closed_without_crashing(self):
        for value in (None, [], {}, 4, True):
            for field in ('role', 'evidence', 'basis', 'observed', 'ablated'):
                record = fixture(); record['mechanism_comparisons'][0]['cases'][2][field] = value
                self.assertTrue(validate_mechanism_comparisons(record), (field, value))
            record = fixture(); record['mechanism_comparisons'][0]['review_evidence'] = value
            self.assertTrue(validate_mechanism_comparisons(record))
        record = fixture(); record['evidence'][0]['id'] = []
        self.assertTrue(validate_mechanism_comparisons(record))
        record = fixture(); record['mechanism_comparisons'][0]['cases'][0]['evidence'] = [{}]
        self.assertTrue(validate_mechanism_comparisons(record))
        record = fixture(); record['evidence'].append(copy.deepcopy(record['evidence'][0]))
        self.assertTrue(validate_mechanism_comparisons(record))

    def test_technical_green_cannot_bypass_stage_dependency(self):
        record = fixture()
        record.update(task_id='synthetic', deliverables=['synthetic'], affected_paths=['fixture'],
                      gates={'G0': {'status': 'passed'}}, criteria=[{'gate': 'G0', 'status': 'passed'}],
                      creative_decisions=[], production_snapshot=production_loop.digest({}))
        task = dict(id='synthetic', quality_record='synthetic.json', completion='stage', required_gates=['G0'], mechanism_review=True)
        green = dict(errors=[], task_complete=True, verdict='ACCEPT')
        with patch.object(production_loop.quality, 'local_file', return_value=Path('synthetic.json')), \
             patch.object(production_loop.quality, 'read_json', return_value=record), \
             patch.object(production_loop, 'snapshot', return_value={}), \
             patch.object(production_loop.quality, 'validate_record', side_effect=lambda *a, **k: copy.deepcopy(green)):
            self.assertTrue(production_loop.check_task_quality(task)['scope_complete'])
            record['mechanism_comparisons'][0]['decision'] = 'revise'
            self.assertFalse(production_loop.check_task_quality(task)['scope_complete'])


if __name__ == '__main__':
    unittest.main()
