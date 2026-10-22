#!/usr/bin/env python3
"""Real-projectile narrow enemy presentation consumer; preserves native failures."""
import argparse
import re
from run_tests import run_engine

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline', action='store_true')
    parser.add_argument('--output', default='res://build/enemy-feedback-01/trace.json')
    args = parser.parse_args()
    run_engine(['--headless', '--path', '.', '--editor', '--quit'], 90)
    extra = [] if args.baseline else ['--candidate']
    output = run_engine(['--headless', '--fixed-fps', '60', '--audio-driver', 'Dummy',
                         '--path', '.', '--script', 'tests/enemy_feedback_01/test_feedback.gd',
                         '--', '--output=' + args.output, *extra], 120)
    if not re.search(r'^ENEMY_FEEDBACK_01 checks=[1-9]\d* cases=4 failures=0$', output, re.M):
        raise RuntimeError('Missing complete real-projectile enemy sample pass')
    print('PASS: enemy feedback actual projectile fixture (not full formal-stage or visual acceptance)')

if __name__ == '__main__':
    main()
