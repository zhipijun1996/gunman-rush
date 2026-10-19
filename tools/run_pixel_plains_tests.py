"""One-screen pixel consumer and unchanged real player/lifecycle checks."""
import subprocess,re
from run_tests import run_engine
subprocess.run(['python3','tools/build_pixel_plains_art.py','--check'],check=True)
output=run_engine(['--headless','--fixed-fps','60','--path','.','--script','tests/test_pixel_plains.gd'],90)
if not re.search(r'^PIXEL_PLAINS checks=[1-9]\d* failures=0',output,re.M):raise RuntimeError('Missing successful pixel consumer completion')
print('PASS: pixel plains actual viewport, route and lifetime')
