#!/usr/bin/env python3
"""Capture the unchanged real-projectile enemy fixture in an assigned GPU slot."""
import argparse
import contextlib
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time
from capture_underworld_revision2_experience import inventory as runtime_inventory
from run_tests import run_engine
from run_underworld_home_tests import Tee

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = 'tests/enemy_feedback_01/test_feedback.gd'
SCOPES = ['scripts', 'scenes', 'resources', 'config', 'shaders', 'assets',
          'project.godot', FIXTURE, 'tools/capture_enemy_feedback_01.py',
          'tools/run_enemy_feedback_01_tests.py']

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def inventory():
    values = runtime_inventory()
    for name in [FIXTURE, 'tools/capture_enemy_feedback_01.py', 'tools/run_enemy_feedback_01_tests.py']:
        values[name] = sha(ROOT / name)
    return values

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-commit', required=True)
    parser.add_argument('--output', required=True)
    parser.add_argument('--baseline', action='store_true')
    parser.add_argument('--display', default=':98')
    args = parser.parse_args()
    target = (ROOT / args.output).resolve()
    if not target.is_relative_to(ROOT / 'build') or target.exists():
        raise RuntimeError('Use a fresh build directory; preserve failures')
    commit = subprocess.check_output(['git', 'rev-parse', args.source_commit + '^{commit}'], cwd=ROOT, text=True).strip()
    if subprocess.check_output(['git', 'diff', '--name-only', commit, '--', *SCOPES], cwd=ROOT, text=True).strip():
        raise RuntimeError('Runtime or capture producer differs from frozen commit')
    if subprocess.check_output(['git', 'ls-files', '--others', '--exclude-standard', '--', *SCOPES], cwd=ROOT, text=True).strip():
        raise RuntimeError('Untracked runtime/capture source')
    target.mkdir(parents=True)
    os.environ['DISPLAY'] = args.display
    os.environ['LIBGL_ALWAYS_SOFTWARE'] = '1'
    os.environ.setdefault('LP_NUM_THREADS', '1')
    extra = [] if args.baseline else ['--candidate']
    argv = ['--path', '.', '--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy',
            '--fixed-fps', '60', '--write-movie', str(target / 'raw.avi'), '--script', FIXTURE,
            '--', '--output=res://' + str((target / 'trace.json').relative_to(ROOT)), *extra]
    before = inventory()
    receipt = {'source_commit': commit, 'source_before': before, 'baseline': args.baseline,
               'argv': ['bash', 'tools/godot.sh', *argv], 'status': 'failed',
               'scope': 'Initial-position fixture with actual Router/projectile/AI/health; not whole-map natural combat or device/player acceptance',
               'audio_scope': 'Dummy MovieMaker; track presence does not establish listening acceptance'}
    start = time.monotonic()
    try:
        with (target / 'native.log').open('w') as log, contextlib.redirect_stdout(Tee(__import__('sys').stdout, log)):
            output = run_engine(argv, 180)
        if not re.search(r'^ENEMY_FEEDBACK_01 checks=[1-9]\d* cases=4 failures=0$', output, re.M):
            raise RuntimeError('Missing complete successful real-projectile sample')
        trace = json.loads((target / 'trace.json').read_text())
        if trace['failures'] or len(trace['cases']) != 4 or not trace['frames']:
            raise RuntimeError('Incomplete native trace')
        for case in trace['cases']:
            if len(case['hits']) != 3 or case['final_hp'] != 0 or case['defeats'] != 1:
                raise RuntimeError('Representative did not reach real projectile death')
        with (target / 'encode.log').open('w') as log:
            subprocess.run(['ffmpeg', '-y', '-i', str(target / 'raw.avi'), '-c:v', 'libx264',
                            '-crf', '20', '-pix_fmt', 'yuv420p', '-c:a', 'aac', str(target / 'movie.mp4')],
                           stdout=subprocess.DEVNULL, stderr=log, check=True, timeout=120)
        media = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-show_streams',
                                                   '-show_format', '-of', 'json', str(target / 'movie.mp4')], timeout=30))
        video = next(s for s in media['streams'] if s['codec_type'] == 'video')
        if video['avg_frame_rate'] != '60/1' or (video['width'], video['height']) != (1280, 720):
            raise RuntimeError('Wrong normal-speed dimensions or rate')
        subprocess.run(['ffmpeg', '-v', 'error', '-i', str(target / 'movie.mp4'), '-f', 'null', '-'],
                       stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, check=True, timeout=60)
        receipt.update(status='captured', engine_exit_code=0, media=media,
                       checks=trace['checks'], frames=len(trace['frames']))
    except Exception as error:
        receipt['error'] = type(error).__name__ + ': ' + str(error)
        raise
    finally:
        receipt['source_after'] = inventory()
        receipt['source_unchanged'] = before == receipt['source_after']
        receipt['wall_seconds'] = time.monotonic() - start
        if not receipt['source_unchanged']:
            receipt['status'] = 'failed'
        receipt['artifacts'] = {p.name: {'bytes': p.stat().st_size, 'sha256': sha(p)}
                                for p in target.iterdir() if p.is_file() and p.suffix != '.avi'}
        (target / 'receipt.json').write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + '\n')
    if not receipt['source_unchanged']:
        raise RuntimeError('Source changed during capture')
    print('PASS: actual-projectile enemy feedback movie')

if __name__ == '__main__':
    main()
