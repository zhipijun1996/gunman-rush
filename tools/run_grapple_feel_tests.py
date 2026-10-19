"""Shared real-Motor grapple feel and adapter aiming contracts, with strict exits."""
import re
from run_tests import run_engine


def main():
    run_engine(['--headless', '--path', '.', '--editor', '--quit'], 90)
    cases = (
        ('tests/grapple_feel_runner.gd', r'^GRAPPLE FEEL RESULT: [1-9]\d* checks, 0 failures$'),
        ('tests/grapple_aim_input_runner.gd', r'^GRAPPLE AIM INPUT: [1-9]\d* checks, 0 failures$'),
        ('tests/grapple_laser_input_runner.gd', r'^GRAPPLE LASER INPUT: [1-9]\d* assertions, 0 failures$'),
    )
    for script, pattern in cases:
        output = run_engine(['--headless', '--path', '.', '--script', script], 90)
        if not re.search(pattern, output, re.M):
            raise RuntimeError('Missing complete grapple contract result: ' + script)
    print('PASS: grapple feel, hanging lifecycle and dual aim input')


if __name__ == '__main__':
    main()
