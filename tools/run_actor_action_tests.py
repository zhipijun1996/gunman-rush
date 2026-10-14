"""Run actual shared actors and input; no visual/player approval claims."""
import re
from run_tests import run_engine
run_engine(['--headless','--path','.','--editor','--quit'],90)
output=run_engine(['--headless','--path','.','--max-fps','120','--script','tests/actor_actions_runner.gd'],180)
if not re.search(r'^ACTOR ACTIONS: [1-9]\d* assertions, 0 failures$',output,re.M):
    raise RuntimeError('Missing actor-action completion')
print('PASS: actor actions runtime and input')
