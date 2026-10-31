"""Exercise default formal actor/UI consumers and normal lifecycle, strict exit."""
import re
import time
from run_tests import run_engine
deadline=time.monotonic()+120
output=run_engine(['--headless','--audio-driver','Dummy','--fixed-fps','60','--path','.','--script','tests/underworld_plains/test_underworld_formal.gd'],120)
if not re.search(r'^UNDERWORLD_FORMAL checks=[1-9]\d* failures=0 maps=2$',output,re.M):
    raise RuntimeError('Missing actual formal two-map consumer completion')
remaining=deadline-time.monotonic()
if remaining<=0:
    raise RuntimeError('Original formal consumer time budget exhausted')
output=run_engine(['--headless','--audio-driver','Dummy','--fixed-fps','60','--path','.','--script','tests/underworld_plains/test_foreground_fixed_cache.gd'],remaining)
if not re.search(r'^FOREGROUND_FIXED_CACHE checks=[1-9]\d* failures=0 output=\S.*$',output,re.M):
    raise RuntimeError('Missing actual foreground cache equivalence completion')
print('PASS: Underworld default formal actor/UI consumers and lifecycle')
