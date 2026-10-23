"""Run the current time-energy policy without replacing historical regressions."""
import re
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from run_tests import run_engine

run_engine(['--headless', '--path', '.', '--editor', '--quit'], 90)
output = run_engine(['--headless', '--path', '.', '--audio-driver', 'Dummy', '--script', 'tests/demo_ui_01/r3_energy_runner.gd'], 180)
if not re.search(r'^DEMO UI R3 ENERGY: [1-9]\d* checks, 0 failures$', output, re.M):
    raise RuntimeError('Current time-energy regression did not complete cleanly')
print('PASS: current time energy, one-round baseline and actor-following HUD')
