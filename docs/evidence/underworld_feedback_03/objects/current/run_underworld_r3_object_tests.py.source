"""Strict original/new actual projectile and formal cache consumers; GPU separate."""
import argparse
import hashlib
import json
import re
import time
from pathlib import Path
from run_tests import run_engine
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/underworld_r3/objects'
OWNED = ['scripts/world/shot_latch.gd','scripts/world/backside_shot_latch.gd',
    'scripts/generation/plains_region_assembler.gd','scripts/bosses/boss_arena_seal.gd',
    'scripts/underworld_plains/underworld_objects.gd',
    'tests/underworld_plains/test_underworld_r3_objects.gd','tools/run_underworld_r3_object_tests.py',
    'tools/build_underworld_r3_objects.py']
OWNED += [str(p.relative_to(ROOT)) for p in sorted((ROOT/'assets/underworld_plains/objects').glob('*')) if p.suffix in ('.png','.json')]

def snapshot(paths):
    return {p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in paths}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--capture',action='store_true')
    parser.add_argument('--cache-only',action='store_true')
    args = parser.parse_args()
    if args.cache_only and not args.capture: parser.error("--cache-only requires --capture")
    OUT.mkdir(parents=True,exist_ok=True)
    before = snapshot(OWNED)
    run_engine(['--headless','--path','.','--editor','--quit'],90)
    mode = ['--rendering-method','gl_compatibility'] if args.capture else ['--headless']
    arguments = [*mode,'--path','.','--audio-driver','Dummy','--fixed-fps','60','--script','tests/underworld_plains/test_underworld_r3_objects.gd']
    if args.capture: arguments += ['--','--capture']
    if args.cache_only: arguments += ['--cache-only']
    started_ns = time.time_ns()
    output = run_engine(arguments,300 if args.capture else 150)
    after = snapshot(OWNED)
    (OUT/('gpu_runtime.log' if args.capture else 'runtime.log')).write_text(output)
    if 'ERROR:' in output or not re.search(r'^UNDERWORLD R3 OBJECTS: [1-9]\d* assertions, 0 failures$',output,re.M):
        raise RuntimeError('R3 objects failed or clean completion marker missing')
    if before != after: raise RuntimeError('Owned component source changed during execution')
    receipt_path = OUT/'receipt.json'
    if not receipt_path.exists() or receipt_path.stat().st_mtime_ns < started_ns: raise RuntimeError('Missing fresh actual consumer receipt')
    receipt = json.loads(receipt_path.read_text())
    marker = re.search(r'^UNDERWORLD R3 OBJECTS: ([1-9]\d*) assertions, 0 failures$',output,re.M)
    if receipt['failures'] != 0 or receipt['checks'] != int(marker.group(1)): raise RuntimeError('Actual consumer receipt differs from completion marker')
    receipt_name = 'gpu_cache_receipt.json' if args.cache_only else 'gpu_receipt.json' if args.capture else 'headless_receipt.json'
    (OUT/receipt_name).write_bytes(receipt_path.read_bytes())
    if args.capture:
        expected = [f'map{m}_{name}.png' for m in (1,2) for name in ('cache_closed','cache_open','cache_reloaded')] if args.cache_only else ['material_catalog.png'] + [f'map{m}_{name}.png' for m in (1,2) for name in ('shortcut_closed','shortcut_open','cache_closed','cache_open','cache_reloaded','boss_seal_saved_closed')]
        for name in expected:
            p = OUT/name
            if not p.exists() or p.stat().st_mtime_ns < started_ns: raise RuntimeError('Missing fresh actual GPU capture: '+name)
    binding = {'scope':'owned R3 objects component files only; shared runtime may be changing in parallel, final whole-source guard belongs to integration','mode':'gpu_cache_only' if args.cache_only else 'gpu' if args.capture else 'headless','started_ns':started_ns,'receipt':receipt_name,'source_before':before,'source_after':after,'owned_source_unchanged':before==after,'checks':receipt['checks'],'failures':0}
    (OUT/('gpu_cache_binding.json' if args.cache_only else 'gpu_binding.json' if args.capture else 'headless_binding.json')).write_text(json.dumps(binding,indent=2)+'\n')
    print('PASS: Underworld R3 objects actual consumers'+ (' and six unobscured native cache GPU images' if args.cache_only else ' and thirteen native GPU images' if args.capture else '; GPU pixels separate'))

if __name__ == '__main__': main()
