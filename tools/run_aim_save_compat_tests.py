"""Finite historical aim-tuning replay and actual saved-map reload regressions."""
import re
from run_tests import run_engine


def main():
    run_engine(['--headless', '--path', '.', '--editor', '--quit'], 90)
    output = run_engine(['--headless', '--path', '.', '--script', 'tests/aim_save_compat_runner.gd', '--', '--output=res://build/verification/aim_save_compat.json'], 120)
    if not re.search(r'^AIM SAVE COMPAT: [1-9]\d* assertions / 0 failures$', output, re.M):
        raise RuntimeError('Missing complete historical tuning/save compatibility result')
    print('PASS: historical aim tuning and actual saved-map compatibility')


if __name__ == '__main__':
    main()
