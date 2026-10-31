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
OWNED = ['game/world/components/shot_latch.gd','game/world/components/backside_shot_latch.gd',
    'game/world/generation/plains_region_assembler.gd','game/bosses/encounter/boss_arena_seal.gd',
    'game/presentation/world/underworld_plains/underworld_objects.gd',
    'tests/underworld_plains/test_underworld_r3_objects.gd','tools/run_underworld_r3_object_tests.py',
    'tools/build_underworld_r3_objects.py']
OWNED += [str(p.relative_to(ROOT)) for p in sorted((ROOT/'assets/underworld_plains/objects').glob('*')) if p.suffix in ('.png','.json')]
CHEST_OWNED = [
    'game/presentation/effects/art/chest_art_library.gd','game/presentation/effects/art/chest_art_library.gd.uid',
    'game/presentation/effects/art/chest_art_layer.gd','game/presentation/effects/art/chest_art_layer.gd.uid',
    'config/chest_art.json',
    'assets/objects/chests/chest-tiers-v1.source.png',
    'assets/objects/chests/chest-tiers-v1.source.png.import',
    'game/world/levels/providers/plains_region_stage.gd','game/world/levels/providers/thorn_forest_region_stage.gd',
    'game/presentation/world/presentation/forest_bible_presentation.gd','game/presentation/world/art/p1_unity_props.gd',
    'shaders/item_v5_world_sprite.gdshader','shaders/item_v5_world_sprite.gdshader.uid',
    'tests/chest_art_runner.gd','tests/chest_art_runner.gd.uid']
OWNED += CHEST_OWNED

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
    native_deadline = time.monotonic() + 150
    output = run_engine(arguments,300 if args.capture else 150)
    (OUT/('gpu_runtime.log' if args.capture else 'runtime.log')).write_text(output)
    if 'ERROR:' in output or not re.search(r'^UNDERWORLD R3 OBJECTS: [1-9]\d* assertions, 0 failures$',output,re.M):
        raise RuntimeError('R3 objects failed or clean completion marker missing')
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
    chest_checks = None
    if not args.capture:
        # Both actual native suites share the original 150s runtime allowance.
        # The editor remains the original separate 90s step; capture is unchanged.
        remaining = native_deadline - time.monotonic()
        if remaining <= 0: raise RuntimeError('Original 150s native budget exhausted before chest consumers')
        chest_output = run_engine([
            '--headless','--path','.','--audio-driver','Dummy','--fixed-fps','60',
            '--script','tests/chest_art_runner.gd'],remaining)
        (OUT/'chest_runtime.log').write_text(chest_output)
        chest_marker = re.search(r'^CHEST ART: ([1-9]\d*) checks, 0 failures$',chest_output,re.M)
        if re.search(r'ERROR:|Parse Error:|ObjectDB.*leaked|resources? still in use at exit',chest_output):
            raise RuntimeError('Chest consumers emitted native/script/shader errors or leaked resources')
        if chest_marker is None or int(chest_marker.group(1)) < 192:
            raise RuntimeError('Chest consumers failed or required complete 192-check marker missing')
        chest_checks = int(chest_marker.group(1))
    after = snapshot(OWNED)
    if before != after: raise RuntimeError('Owned component source changed during execution')
    binding = {'scope':'owned R3 objects component files only; shared runtime may be changing in parallel, final whole-source guard belongs to integration','mode':'gpu_cache_only' if args.cache_only else 'gpu' if args.capture else 'headless','started_ns':started_ns,'receipt':receipt_name,'source_before':before,'source_after':after,'owned_source_unchanged':before==after,'checks':receipt['checks'],'failures':0}
    if chest_checks is not None: binding['chest_native_checks'] = chest_checks
    (OUT/('gpu_cache_binding.json' if args.cache_only else 'gpu_binding.json' if args.capture else 'headless_binding.json')).write_text(json.dumps(binding,indent=2)+'\n')
    print('PASS: Underworld R3 objects actual consumers'+ (' and six unobscured native cache GPU images' if args.cache_only else ' and thirteen native GPU images' if args.capture else '; GPU pixels separate'))

if __name__ == '__main__': main()
