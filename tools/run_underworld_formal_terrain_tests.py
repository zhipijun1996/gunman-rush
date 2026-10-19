#!/usr/bin/env python3
"""Run actual Stage geometry and Boss lifecycle coverage; not player traversal."""
import re
from run_tests import run_engine
output=run_engine(['--headless','--audio-driver','Dummy','--path','.','--script','tests/underworld_plains/test_underworld_formal_terrain.gd'],240)
if not re.search(r'UNDERWORLD_FORMAL_TERRAIN checks=[1-9]\d* failures=0 consumers=20',output):
    raise RuntimeError('Missing 20-formal-consumer clean terrain completion')
print('PASS: Underworld 20 formal Stage geometries and actual Boss-break refresh')
