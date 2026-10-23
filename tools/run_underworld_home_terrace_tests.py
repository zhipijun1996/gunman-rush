#!/usr/bin/env python3
"""R3 actual multi-tier Home/App input route. Original R2 tests stay immutable."""
from pathlib import Path
import argparse
import contextlib
import hashlib
import json
import re
import shutil
import subprocess
import sys
import time
from run_tests import run_engine

ROOT = Path(__file__).resolve().parents[1]
OWNED = (
    'scripts/demo/home_scene.gd',
    'scripts/underworld_plains/underworld_home_world.gd',
    'assets/underworld_plains/home/home_build.json',
    'tests/underworld_plains/home_terrace_driver.gd',
    'tests/underworld_plains/test_underworld_home_terraces.gd',
    'tools/run_underworld_home_terrace_tests.py',
    # Preserve every dependency from the R2 component guard, then add actual
    # raw provenance inputs and the new default/immutable legacy fixtures.
    'assets/underworld_plains/home/generation_record.json',
    'assets/underworld_plains/home/home_props.png',
    'assets/underworld_plains/home/sources/home_props_original.png',
    'assets/underworld_plains/decor/identity_props.png',
    'assets/underworld_plains/decor/chime_props.png',
    'scripts/underworld_plains/underworld_player.gd',
    'scripts/underworld_plains/underworld_actors.gd',
    'scripts/ui/underworld_ui.gd',
    'tests/underworld_plains/test_underworld_home.gd',
    'tools/run_underworld_home_tests.py',
    'tests/home_ui_tests.gd',
    'tests/home_app_runner.gd',
    'tests/test_underworld_home_terrace_wrapper.py',
    'tests/fixtures/underworld_home_r2/replay.json',
    'tests/fixtures/underworld_home_r2/scripts__demo__home_scene.gd.source',
    'tests/fixtures/underworld_home_r2/scripts__underworld_plains__underworld_home_world.gd.source',
    'tests/fixtures/underworld_home_r2/assets__underworld_plains__home__home_build.json.source',
    'tests/fixtures/underworld_home_r2/tests__underworld_plains__test_underworld_home.gd.source',
    'tests/fixtures/underworld_home_r2/tests__home_ui_tests.gd.source',
    'tests/fixtures/underworld_home_r2/tests__home_app_runner.gd.source',
    'tests/fixtures/underworld_home_r2/tools__run_underworld_home_tests.py.source',
)

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def preflight(root=ROOT):
    record = json.loads((root / 'assets/underworld_plains/home/generation_record.json').read_text())
    if not record.get('prompt') or record.get('tool') != 'image_gen.imagegen':
        raise RuntimeError('Missing real Home generation prompt/tool')
    if (root / record['source']).read_bytes() != (root / record['image']).read_bytes():
        raise RuntimeError('Home original and consumed PNG differ')
    if digest(root / record['source']) != record['source_sha256'] or digest(root / record['reference']) != record['reference_sha256']:
        raise RuntimeError('Home source/reference provenance hash mismatch')
    spec = json.loads((root / 'assets/underworld_plains/home/home_build.json').read_text())
    if len(spec['slots']) != 12 or sum(slot['active'] for slot in spec['slots']) != 4:
        raise RuntimeError('Expected four original and eight reserved Home slots')
    if {slot['id'] for slot in spec['slots'] if slot['active']} != {'character', 'upgrade', 'achievements', 'departure'}:
        raise RuntimeError('Home cannot invent new active function IDs')
    return record

def read_fresh_receipt(path, since_ns):
    if not path.exists() or path.stat().st_mtime_ns < since_ns:
        raise RuntimeError('Current run did not write a fresh Home terrace receipt')
    return json.loads(path.read_text())

def verify(output, receipt, before, after, expected, exit_code=0):
    if exit_code != 0:
        raise RuntimeError(f'Home terrace engine returned {exit_code}')
    markers = re.findall(r'^UNDERWORLD HOME TERRACES: (\d+) assertions, (\d+) failures$', output, re.M)
    if markers != [(str(expected), '0')]:
        raise RuntimeError(f'Expected exactly {expected} successful current Home assertions; got {markers}')
    if re.search(r'SCRIPT ERROR:|Parse Error:|SHADER ERROR:|ERROR:|ObjectDB.*leaked|resources? still in use at exit', output):
        raise RuntimeError('Current Home emitted a runtime error or leaked native resources')
    if before != after:
        raise RuntimeError('Owned Home source changed during execution')
    if receipt.get('schema') != 'underworld-home-terraces-v1' or receipt.get('checks') != expected or receipt.get('failures') != 0 or receipt.get('driver_errors') != []:
        raise RuntimeError('Missing or inconsistent fresh current Home receipt')
    if len(receipt.get('visits', [])) != 12 or len({x['foot'][1] for x in receipt['visits']}) != 3:
        raise RuntimeError('Actual visits do not cover twelve stations on all three tiers')
    active = {x['expected_action'] for x in receipt['visits'] if x['expected_action']}
    if active != {'character', 'upgrade', 'achievements', 'departure'}:
        raise RuntimeError('Current Home changed active function identity')
    for visit in receipt['visits']:
        if 'meta_before' not in visit or 'meta_after' not in visit:
            raise RuntimeError('Missing complete station Meta snapshots')
        if visit['id'] != 'upgrade' and visit['meta_before'] != visit['meta_after']:
            raise RuntimeError('Non-purchase station changed a Meta field')
    if not receipt.get('trace') or not receipt.get('events') or any(x['hp'] != 5 or x['jumps'] > 1 for x in receipt['trace']):
        raise RuntimeError('Actual route health/basic movement evidence is incomplete')
    if {x['key'] for x in receipt['events']} - {'A', 'D', 'S', 'W', 'Space'}:
        raise RuntimeError('Unexpected route input')

class Tee:
    def __init__(self, stream, file): self.stream, self.file = stream, file
    def write(self, value): self.file.write(value); return self.stream.write(value)
    def flush(self): self.file.flush(); self.stream.flush()

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--capture', action='store_true')
    args = parser.parse_args()
    out = ROOT / 'build/underworld_r3/home'
    run = out / 'runs' / str(time.time_ns())
    run.mkdir(parents=True)
    receipt_path = out / 'receipt.json'
    if receipt_path.exists(): shutil.copy2(receipt_path, run / 'previous_receipt.json'); receipt_path.unlink()
    preflight()
    before = {p: digest(ROOT / p) for p in OWNED}
    command = ['--path', '.', '--audio-driver', 'Dummy', '--fixed-fps', '60']
    command += ['--rendering-method', 'gl_compatibility'] if args.capture else ['--headless']
    command += ['--script', 'tests/underworld_plains/test_underworld_home_terraces.gd']
    if args.capture: command += ['--', '--capture']
    binding = {'schema': 'underworld-home-terrace-source-binding-v2', 'head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(), 'command': ['bash', 'tools/godot.sh', *command], 'capture': args.capture, 'source_before': before, 'guard_scope': 'Explicit Home production, original R2 ten dependencies, generation original/reference, player/actors/UI, current driver/test/wrapper, two original business fixtures, negative verifier and immutable legacy fixtures; shared-worktree component, not a whole-product or all-resources freeze', 'status': 'running', 'fixed_fps_note': 'fixed 60 Hz engine physics, native Input.parse_input_event; simulation may run faster/slower than wall time; not a performance result'}
    log = run / 'engine.log'
    started = time.monotonic()
    since_ns = time.time_ns()
    failure = None
    try:
        with log.open('w') as file, contextlib.redirect_stdout(Tee(sys.stdout, file)):
            output = run_engine(command, 240 if args.capture else 150)
        binding['exit_code'] = 0
        receipt = read_fresh_receipt(receipt_path, since_ns)
        preflight()
        after = {p: digest(ROOT / p) for p in OWNED}
        binding['source_after'] = after
        expected = 190 if args.capture else 181
        verify(output, receipt, before, after, expected, 0)
        saved = run / 'receipt.json'; shutil.copy2(receipt_path, saved)
        binding.update(status='passed', checks=expected, failures=0, receipt=str(saved.relative_to(ROOT)), receipt_sha256=digest(saved))
    except Exception as error:
        failure = error
        binding.update(status='failed', error=f'{type(error).__name__}: {error}', source_after={p: digest(ROOT/p) for p in OWNED})
        if receipt_path.exists(): shutil.copy2(receipt_path, run / 'failed_receipt.json')
    finally:
        binding['elapsed_seconds'] = time.monotonic() - started
        binding['log'] = str(log.relative_to(ROOT))
        if log.exists(): binding['log_sha256'] = digest(log)
        (run / 'source_binding.json').write_text(json.dumps(binding, ensure_ascii=False, indent=2) + '\n')
        shutil.copy2(run / 'source_binding.json', out / ('gpu_binding.json' if args.capture else 'headless_binding.json'))
    if failure: raise failure
    print(f'UNDERWORLD HOME TERRACE CHECK: {binding["checks"]} assertions,0 failures; twelve actual stations, original App business and basic input route')

if __name__ == '__main__': main()
