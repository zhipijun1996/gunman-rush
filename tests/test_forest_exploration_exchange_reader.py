"""Exchange evidence must keep actual target identity and lifecycle semantics."""
import copy
import importlib.util
from pathlib import Path
import sys
import unittest

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
spec=importlib.util.spec_from_file_location('exchange_reader',ROOT/'tools/run_forest_exploration_motor.py')
reader=importlib.util.module_from_spec(spec)
spec.loader.exec_module(reader)


def chain(live):
    states=('hook_cast','hook_fly','hook_pull','hook_contact_kick','hook_kick','free') if live else ('hook_cast','hook_fly','hook_pull','hook_hang','hook_kick','free')
    return [{'tick':i+1,'kind':state,'target_instance':73 if state!='free' else 0} for i,state in enumerate(states)]


class ExchangeLifecycle(unittest.TestCase):
    def test_live_auto_contact_and_fixed_hang_have_separate_actual_lifecycles(self):
        for live in (False,True):
            self.assertIsNotNone(reader.ordered_exchange_states(chain(live),73,live))
            self.assertIsNone(reader.ordered_exchange_states(chain(live),73,not live))

    def test_wrong_actual_motor_and_missing_contact_are_rejected(self):
        for live in (False,True):
            sample=chain(live)
            self.assertIsNone(reader.ordered_exchange_states(sample,74,live))
            self.assertIsNone(reader.ordered_exchange_states(sample[:3]+sample[4:],73,live))

    def test_failure_duplicate_or_reversed_events_are_rejected(self):
        for live in (False,True):
            sample=chain(live)
            for changed in (sample+[{'tick':3,'kind':'hook_miss'}],sample+[copy.deepcopy(sample[3])]):
                self.assertIsNone(reader.ordered_exchange_states(changed,73,live))
            changed=copy.deepcopy(sample);changed[3]['tick']=10
            self.assertIsNone(reader.ordered_exchange_states(changed,73,live))

    def test_actual_resource_vector_overrides_script_default(self):
        self.assertEqual(reader.definition_vector('hook_kick','resources/player/traversal.tres','scripts/player/traversal_definition.gd'),[240.,-240.])


if __name__=='__main__':unittest.main()
