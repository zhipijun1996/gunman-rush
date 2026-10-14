"""Actual motion budgets, timing and adapter contracts; strict complete-result guard."""
import re
from run_tests import run_engine
run_engine(['--headless','--path','.','--editor','--quit'],90)
output=run_engine(['--headless','--path','.','--max-fps','120','--script','tests/action_budget_runner.gd'],240)
if not re.search(r'^ACTION BUDGET: [1-9]\d* assertions, 0 failures$',output,re.M):
    raise RuntimeError('Missing complete action-budget result')
print('PASS: action budgets and shared aim')
