"""Wind Chime Plains sample consumers, strict engine exit and real Motor routes."""
import re
import subprocess
from run_tests import run_engine
subprocess.run(['python3','tools/build_windchime_art.py','--check'],check=True)
for runner,marker in [('tests/test_windchime_layout.gd','WINDCHIME_LAYOUT'),('tests/test_windchime_lab.gd','WINDCHIME_LAB')]:
 output=run_engine(['--headless','--fixed-fps','60','--path','.','--script',runner],90)
 if not re.search(r'^'+marker+r' checks=[1-9]\d* failures=0',output,re.M):
  raise RuntimeError('Missing successful completion: '+marker)
print('PASS: windchime tiles, real sample Motor routes and lab lifecycle')
