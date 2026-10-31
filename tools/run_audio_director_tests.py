#!/usr/bin/env python3
"""Run the Audio Director transport checks through the existing strict audio runner."""
import argparse
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=Path('build/audio_director/runtime'))
    args = parser.parse_args()
    return subprocess.run([
        sys.executable, 'tools/run_audio_lifecycle_tests.py',
        '--script', 'res://tests/audio_director_runtime.gd',
        '--marker', r'^AUDIO_DIRECTOR_RUNTIME checks=\d+ failures=0$',
        '--timeout', '90', '--output', str(args.output),
    ], cwd=ROOT).returncode


if __name__ == '__main__':
    raise SystemExit(main())
