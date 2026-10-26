"""Real formal App fixtures and native mouse/touch/gamepad gear controls."""
import argparse
import re
from run_tests import run_engine

parser = argparse.ArgumentParser()
parser.add_argument('--capture', action='store_true')
args = parser.parse_args()
run_engine(['--headless', '--path', '.', '--editor', '--quit'], 90)
mode = ['--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy'] if args.capture else ['--headless', '--audio-driver', 'Dummy']
output = run_engine([*mode, '--resolution', '1280x720', '--path', '.', '--script', 'tests/run_gear_ui_runner.gd', *(['--', '--capture'] if args.capture else [])], 120)
if not re.search(r'^GEAR UI: [1-9]\d* checks, 0 failures$', output, re.MULTILINE):
    raise RuntimeError('Formal equipment GUI did not complete cleanly')
print('PASS: formal equipment native UI and lifecycle' + (' with rendered captures' if args.capture else ' (pixels unverified)'))
