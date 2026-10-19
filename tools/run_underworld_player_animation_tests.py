#!/usr/bin/env python3
"""Strict actual Motor/Router/player body animation checks, not visual approval."""
import re
from run_tests import run_engine
output=run_engine(['--headless','--fixed-fps','60','--audio-driver','Dummy','--path','.','--script','tests/underworld_plains/test_underworld_player_animation.gd'],120)
if not re.search(r'UNDERWORLD_PLAYER_ANIMATION checks=[1-9]\d* failures=0 real_motor_frames=583 states=7',output):
    raise RuntimeError('Missing current player animation true-Motor completion')
print('PASS: Underworld generated player body frames, actual left/right Motor, anchors and accepted lifecycle')
