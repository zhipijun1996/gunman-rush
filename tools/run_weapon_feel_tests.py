"""Six weapon feedback contracts against real Controller/Motor/Entity consumers."""
import re
from run_tests import run_engine
run_engine(['--headless','--path','.','--editor','--quit'],90)
output=run_engine(['--headless','--path','.','--script','tests/weapon_feel_runner.gd'],180)
if not re.search(r'^WEAPON FEEL: [1-9]\d* assertions, 0 failures$',output,re.M):
    raise RuntimeError('Missing complete weapon-feel result')
print('PASS: weapon feel and action timing')
