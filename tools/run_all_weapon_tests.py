"""Actual one-loadout weapon behaviors, resources and collision regressions."""
import re
from run_tests import run_engine
run_engine(['--headless','--path','.','--editor','--quit'],90)
output=run_engine(['--headless','--path','.','--script','tests/all_weapons_runner.gd'],240)
if not re.search(r'^ALL WEAPONS: [1-9]\d* assertions, 0 failures$',output,re.M):
    raise RuntimeError('Missing complete all-weapons result')
print('PASS: all weapon runtime behaviors and resources')
