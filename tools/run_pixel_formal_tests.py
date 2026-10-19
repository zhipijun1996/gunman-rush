"""Current pixel art consumers; historical painted fixtures remain separate."""
import re
from run_tests import run_engine
for script,pattern in [
 ('tests/test_pixel_formal_terrain.gd',r'PIXEL_FORMAL_TERRAIN checks=[1-9]\d* failures=0'),
]:
 output=run_engine(['--headless','--fixed-fps','60','--path','.','--script',script],120)
 if not re.search(pattern,output):raise RuntimeError('Missing clean formal pixel completion: '+script)
print('PASS: current formal pixel terrain geometry and actual platform consumers')
