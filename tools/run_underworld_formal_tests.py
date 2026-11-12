"""Exercise default formal actor/UI consumers and normal lifecycle, strict exit."""
import re
from run_tests import run_engine
output=run_engine(['--headless','--audio-driver','Dummy','--fixed-fps','60','--path','.','--script','tests/underworld_plains/test_underworld_formal.gd'],120)
if not re.search(r'^UNDERWORLD_FORMAL checks=[1-9]\d* failures=0 maps=2$',output,re.M):
    raise RuntimeError('Missing actual formal two-map consumer completion')
print('PASS: Underworld default formal actor/UI consumers and lifecycle')
