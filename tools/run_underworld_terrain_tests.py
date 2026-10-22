#!/usr/bin/env python3
"""Run source-native terrain checks through the project's strict engine wrapper."""
import re
from run_tests import run_engine
output=run_engine(['--headless','--audio-driver','Dummy','--path','.','--script','tests/underworld_plains/test_underworld_terrain.gd'],120)
if not re.search(r'UNDERWORLD_TERRAIN .*"failures":\[\].*"gpu":false',output):
    raise RuntimeError('Missing native-terrain bounded completion')
equivalence=run_engine(['--headless','--fixed-fps','60','--path','.',
                       '--script','tests/underworld_plains/test_terrain_border_equivalence.gd'],20)
if not re.search(r'^TERRAIN BORDER EQUIVALENCE: [1-9]\d* assertions / 0 failures / world=false$',equivalence,re.M):
    raise RuntimeError('Missing ordered border-equivalence completion')
print('PASS: Underworld source-native exact terrain geometry')
