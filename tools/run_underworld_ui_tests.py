"""Production native UI mouse paths. --capture needs a real DISPLAY."""
import argparse,re
from run_tests import run_engine
parser=argparse.ArgumentParser();parser.add_argument('--capture',action='store_true');args=parser.parse_args()
run_engine(['--headless','--path','.','--editor','--quit'],90)
mode=['--rendering-method','gl_compatibility','--audio-driver','Dummy'] if args.capture else ['--headless','--audio-driver','Dummy']
text=run_engine([*mode,'--path','.','--script','tests/underworld_plains/test_underworld_ui.gd',*(['--','--capture'] if args.capture else [])],180)
if not re.search(r'^UNDERWORLD UI: [1-9][0-9]* checks, 0 failures$',text,re.M):raise RuntimeError('Native Underworld UI did not complete cleanly')
print('PASS: Underworld UI actual native mouse paths'+(' and GPU images' if args.capture else ' (pixels unverified)'))
