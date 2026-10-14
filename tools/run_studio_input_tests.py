"""Studio UI ownership and actual existing enemy movement; GUI gestures tested separately."""
import re
from run_tests import run_engine
run_engine(['--headless','--path','.','--editor','--quit'],90)
output=run_engine(['--headless','--path','.','--max-fps','120','--script','tests/studio_input_runner.gd'],90)
if not re.search(r'^STUDIO INPUT: [1-9]\d* assertions, 0 failures$',output,re.M):
    raise RuntimeError('Missing complete Studio input result')
print('PASS: studio input and patrol runtime')
