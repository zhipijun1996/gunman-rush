"""Verify approved terrain on both default region consumers, including thin solids."""
import re
from run_tests import run_engine
run_engine(['--headless', '--path', '.', '--editor', '--quit'], 90)
text = run_engine(['--headless', '--fixed-fps', '60', '--path', '.', '--script',
                   'tests/terrain_production_runner.gd'], 180)
if not re.search(r'^TERRAIN PRODUCTION: [1-9]\d* assertions, 0 failures$', text, re.M):
    raise RuntimeError('Missing terrain production completion')
print('PASS: terrain production regression')
