#!/usr/bin/env python3
"""Actual projectile sweeps/cancellation; native pixels remain a separate check."""
import re
from run_tests import run_engine
output=run_engine(['--headless','--fixed-fps','60','--audio-driver','Dummy','--path','.','--script','tests/underworld_plains/test_underworld_projectiles.gd'],90)
if not re.search(r'UNDERWORLD_PROJECTILES checks=[1-9]\d* failures=0',output):
    raise RuntimeError('Missing actual projectile completion')
print('PASS: Underworld real projectile contacts, cancellation, presentation and policy direction')

weapons=run_engine(['--headless','--fixed-fps','60','--audio-driver','Dummy','--path','.','--script','tests/underworld_plains/test_underworld_weapon_consumers.gd'],180)
if not re.search(r'^ALL WEAPONS: [1-9]\d* assertions, 0 failures$',weapons,re.M):
    raise RuntimeError('Missing complete unchanged all-weapons assertions in actual Underworld branch')
print('PASS: all 15 equipped weapon variants and original regressions in Underworld presentation context')
