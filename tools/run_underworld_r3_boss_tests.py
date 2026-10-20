"""Strict R3 continuous-Boss consumers and optional full actual-App battles."""
import argparse
import json
import re
from pathlib import Path
from run_tests import run_engine


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--full-fights', action='store_true')
    args = parser.parse_args()
    directory = Path('build/underworld_r3/boss')
    directory.mkdir(parents=True, exist_ok=True)
    run_engine(['--headless', '--path', '.', '--editor', '--quit'], 90)
    common = ['--headless', '--fixed-fps', '60', '--audio-driver', 'Dummy', '--path', '.']
    output = run_engine([*common, '--script', 'tests/underworld_plains/test_underworld_r3_boss.gd'], 180)
    (directory / 'runtime.log').write_text(output)
    if 'ERROR:' in output or not re.search(r'^UNDERWORLD R3 BOSS: [1-9]\d* checks, 0 failures$', output, re.M):
        raise RuntimeError('R3 actual Boss consumers did not complete cleanly')
    receipt = json.loads((directory / 'continuous_combat.json').read_text())
    if receipt['failures'] or receipt['checks'] < 90:
        raise RuntimeError('R3 Boss receipt incomplete or failed')
    directions = run_engine([*common, '--script', 'tests/underworld_plains/test_underworld_boss_hit_direction.gd'], 120)
    (directory / 'directional_hits_runtime.log').write_text(directions)
    if not re.search(r'^UNDERWORLD R3 BOSS HIT DIRECTION: 16 checks, 0 failures$', directions, re.M):
        raise RuntimeError('Actual Boss projectile directions or accepted Motor knockback failed')
    output = run_engine([*common, '--script', 'tests/underworld_plains/test_underworld_r3_boss_lifecycle.gd'], 180)
    (directory / 'lifecycle_runtime.log').write_text(output)
    if 'ERROR:' in output or not re.search(r'^UNDERWORLD R3 BOSS LIFECYCLE: [1-9]\d* checks, 0 failures$', output, re.M):
        raise RuntimeError('R3 actual projectile lifecycle consumers did not complete cleanly')
    lifecycle = json.loads((directory / 'lifecycle.json').read_text())
    if lifecycle['failures'] or lifecycle['checks'] < 40:
        raise RuntimeError('R3 Boss lifecycle receipt incomplete or failed')
    if args.full_fights:
        for map_index in (1, 2):
            output = run_engine([*common, '--script', 'tests/underworld_plains/capture_underworld_r3_boss_fight.gd', '--', f'--map={map_index}'], 180)
            (directory / f'full_fight_map{map_index}_runtime.log').write_text(output)
            if 'ERROR:' in output or not re.search(rf'^UNDERWORLD R3 FULL BOSS MAP{map_index}: [1-9]\d* frames, 0 failures$', output, re.M):
                raise RuntimeError(f'R3 full Boss map {map_index} failed')
            fight = json.loads((directory / f'full_fight_map{map_index}.json').read_text())
            if fight['failures'] or fight['boss_hp'] != 0 or fight['player_hp'] <= 0 or not fight['no_midfight_injection']:
                raise RuntimeError(f'R3 full Boss map {map_index} receipt failed')
    print('PASS: Underworld R3 Boss continuous damage, actual contact, lifecycle' + (' and two full actual-App battles' if args.full_fights else ''))


if __name__ == '__main__':
    main()
