"""Verify the current world through actual input, a separate restart, and failure fixtures."""
import re
import subprocess
import sys
from pathlib import Path
from run_tests import run_engine
from world.build import build

ROOT=Path(__file__).resolve().parents[1]
def main():
    build()
    for script,marker,timeout in [
        ('state_contracts.gd',r'WORLD STATE: \d+ assertions, 0 failures',30),
        ('service_contracts.gd',r'WORLD SERVICES: \d+ assertions, 0 failures',60),
        ('economy.gd',r'WORLD GOLD: \d+ assertions, 0 failures',60),
        ('economy_restart.gd',r'WORLD GOLD RESTART: 0 failures',30),
        ('traversal_contracts.gd',r'WORLD TRAVERSAL: \d+ assertions, 0 failures',60),
        ('room_contracts.gd',r'WORLD ROOMS: \d+ assertions, 0 failures',60),
        ('ui_contracts.gd',r'WORLD UI: \d+ assertions, 0 failures',60),
        ('presentation_contracts.gd',r'WORLD PRESENTATION: \d+ assertions, 0 failures',60),
        ('demo_regressions.gd',r'WORLD DEMO: \d+ assertions, 0 failures',60),
        ('focus_heal.gd',r'WORLD HEAL: \d+ assertions, 0 failures',90),
        ('focus_heal_restart.gd',r'WORLD HEAL RESTART: 0 failures',30),
        ('lifecycle.gd',r'WORLD LIFECYCLE: \d+ assertions, 0 failures',60),
        ('first_loop.gd',r'WORLD LOOP: 0 failures',240),
        ('restart.gd',r'WORLD RESTART: 0 failures',30),
        ('service_ui.gd',r'WORLD SERVICE UI: 0 failures',120),
        ('service_restart.gd',r'WORLD SERVICE RESTART: 0 failures',30),
    ]:
        output=run_engine(['--headless','--path','.', '--script','tests/world/'+script],timeout)
        if 'SCRIPT ERROR:' in output or re.search(r'^ERROR:',output,re.M) or not re.search(marker,output):
            raise RuntimeError('World validation failed: '+script)
    print('PASS: first world loop, real combat/reward/return, isolated disk restart and lifecycle counterexamples')
if __name__=='__main__':main()
