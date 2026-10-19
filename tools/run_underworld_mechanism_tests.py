"""Run actual source/physics/projectile consumers; pixels require --capture."""
import argparse
import re
from pathlib import Path
from run_tests import run_engine

parser = argparse.ArgumentParser()
parser.add_argument('--capture', action='store_true')
parser.add_argument('--feedback-only', action='store_true')
args = parser.parse_args()
if args.feedback_only and not args.capture:
    parser.error('--feedback-only requires --capture')
run_engine(['--headless', '--path', '.', '--editor', '--quit'], 90)
mode = ['--rendering-method', 'gl_compatibility'] if args.capture else ['--headless']
arguments = [*mode, '--fixed-fps', '60', '--audio-driver', 'Dummy', '--path', '.',
             '--script', 'tests/underworld_plains/test_underworld_mechanisms.gd']
if args.capture:
    arguments += ['--', '--capture']
    if args.feedback_only:
        arguments += ['--feedback-only']
output = run_engine(arguments, 240)
directory = Path('build/underworld_plains/mechanisms')
directory.mkdir(parents=True, exist_ok=True)
(directory / ('feedback_gpu.log' if args.feedback_only else 'gpu.log' if args.capture else 'runtime.log')).write_text(output)
if 'ERROR:' in output or not re.search(r'^UNDERWORLD MECHANISMS: [1-9]\d* assertions, 0 failures$', output, re.M):
    raise RuntimeError('Underworld mechanism consumer failed or clean completion missing')
print('PASS: Underworld mechanisms' + (' / actual consumers and GPU material samples' if args.capture else ' / actual source, physics and accepted projectile consumers; pixels separate'))
