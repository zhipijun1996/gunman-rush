"""Actual full game static composition at explicitly staged poses, not traversal."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import selectors
import shutil
import subprocess
import time
from run_tests import run_engine
from forest_bible_world_sources import inventory
ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--compare-plains', action='store_true')
    parser.add_argument('--near-scene', action='store_true')
    parser.add_argument('--guardian-scene', action='store_true')
    parser.add_argument('--ecology-scenes', action='store_true')
    args = parser.parse_args()
    out = args.output.resolve()
    if not out.is_relative_to(ROOT / 'build') or out.exists():
        parser.error('Fresh output below repository build required')
    out.mkdir(parents=True)
    before = inventory()
    receipt = {'scope': __doc__, 'sources_before': before, 'exit_code': 1}
    display = None
    started = time.monotonic()
    try:
        run_engine(['--headless','--path','.','--editor','--quit'],90)
        binary = shutil.which('Xvfb') or str(ROOT/'build/forest_revision04/display-final-W6/runtime/usr/bin/Xvfb')
        with (out/'display.log').open('wb') as log:
            display = subprocess.Popen([binary,'-displayfd','1','-screen','0','1280x720x24','-nolisten','tcp','-ac'],stdout=subprocess.PIPE,stderr=log)
            with selectors.DefaultSelector() as ready:
                ready.register(display.stdout,selectors.EVENT_READ)
                if not ready.select(20): raise RuntimeError('display timeout')
                number = display.stdout.readline().decode().strip()
                if not number.isdigit(): raise RuntimeError('invalid display')
            env = {**os.environ,'DISPLAY':':'+number,'LIBGL_ALWAYS_SOFTWARE':'1','OMP_NUM_THREADS':'1'}
            cmd = ['bash','tools/godot.sh','--path','.','--rendering-method','gl_compatibility','--audio-driver','Dummy','--script','tests/forest_bible_golden_runner.gd','--','--output=res://'+out.relative_to(ROOT).as_posix()]
            if args.compare_plains: cmd.append('--compare-plains')
            if args.near_scene: cmd.append('--near-scene')
            if args.guardian_scene: cmd.append('--guardian-scene')
            if args.ecology_scenes: cmd.append('--ecology-scenes')
            receipt['command'] = cmd
            with (out/'native.log').open('wb') as native:
                result = subprocess.run(cmd,env=env,stdout=native,stderr=subprocess.STDOUT,timeout=120)
            receipt['native_exit_code'] = result.returncode
            text = (out/'native.log').read_text()
            if result.returncode or re.search(r'SCRIPT ERROR:|Parse Error:|SHADER ERROR:|^ERROR:',text,re.M): raise RuntimeError('native failure')
            expected = (8 if args.compare_plains else 6) + int(args.near_scene) + int(args.guardian_scene) + (8 if args.ecology_scenes else 0)
            receipt['expected_images'] = expected
            if f'FOREST BIBLE GOLDEN: {expected} images / 0 failures' not in text: raise RuntimeError('complete selected compositions required')
            data = json.loads((out/'capture.json').read_text())
            if data.get('failures') or len(data.get('rows',[])) != expected: raise RuntimeError('capture incomplete')
            receipt['images'] = {row['image']: hashlib.sha256((out/row['image']).read_bytes()).hexdigest() for row in data['rows']}
            receipt['exit_code'] = 0
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as error:
        receipt['error'] = str(error)
    finally:
        if display is not None:
            display.terminate(); display.wait(timeout=5); display.stdout.close()
        try:
            receipt['sources_after'] = inventory()
            receipt['source_stable'] = before == receipt['sources_after']
            if not receipt['source_stable']:
                receipt.update(exit_code=1, error='source changed')
        except OSError as error:
            receipt.update(exit_code=1, source_stable=False, error=str(error))
        receipt['elapsed_seconds'] = time.monotonic()-started
        (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps({k:v for k,v in receipt.items() if k not in ('sources_before','sources_after')}))
    return receipt['exit_code']

if __name__ == '__main__':
    raise SystemExit(main())
