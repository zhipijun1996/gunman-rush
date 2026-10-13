"""Check actual one-way consumers; --capture additionally exercises the GPU.

For Linux GUI runs, supply a working DISPLAY. No headless result certifies pixels.
"""
import argparse
import re
from run_tests import run_engine

parser = argparse.ArgumentParser()
parser.add_argument('--capture', action='store_true')
args = parser.parse_args()
run_engine(['--headless', '--path', '.', '--editor', '--quit'], 90)
# Pace even the headless host. Fast fixed-fps can terminate immediately after
# free(), before Godot's asynchronous audio mixer releases retired streams.
# Keep the ERROR guard below; do not whitelist shutdown resource failures.
mode = ['--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy'] if args.capture else ['--headless', '--max-fps', '60']
output = run_engine([*mode, '--path', '.', '--script', 'tests/wood_platform_runner.gd',
                     *(['--', '--capture'] if args.capture else [])], 180)
if 'ERROR:' in output or not re.search(r'^WOOD PLATFORMS: [1-9]\d* assertions, 0 failures$', output, re.M):
    raise RuntimeError('Actual consumer regression failed or completion missing')
print('PASS: wood platform consumers' + (' and GPU invariants' if args.capture else ' (pixels unverified)'))
