#!/usr/bin/env python3
"""Strict current accepted damage/real contact/Motor regression; no visual signoff."""
import re
from run_tests import run_engine
output=run_engine(['--headless','--fixed-fps','60','--audio-driver','Dummy','--path','.','--script','tests/underworld_plains/test_underworld_damage_r3.gd'],120)
if not re.search(r'^UNDERWORLD_DAMAGE_R3 checks=[1-9]\d* failures=0$',output,re.MULTILINE):
    raise RuntimeError('Missing complete current R3 damage pass')
print('PASS: accepted R3 hurt/feedback, environment exit-entry, actual force and boundary regressions')
