#!/usr/bin/env python3
"""Run source-native terrain checks through the project's strict engine wrapper."""
import re
from run_tests import run_engine
output=run_engine(['--headless','--audio-driver','Dummy','--path','.','--script','tests/underworld_plains/test_underworld_terrain.gd'],120)
if not re.search(r'UNDERWORLD_TERRAIN .*"failures":\[\].*"gpu":false',output):
    raise RuntimeError('Missing native-terrain bounded completion')
print('PASS: Underworld source-native exact terrain geometry')
