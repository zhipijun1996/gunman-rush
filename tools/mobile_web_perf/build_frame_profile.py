"""Append observation-only timing wrappers to an exact exported real demo pack.

No scene replacement, debug routing, position/seed writes, audio policy changes or
rendering knockouts. The ordinary production bundle remains unchanged.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_web_bundle import Pack
from build_probe import write_pack

MEASURE = {
    'game/presentation/world/underworld_plains/underworld_foreground.gd': ['_refresh', '_protection', '_sync_residents', '_render_receipt'],
    'game/presentation/world/underworld_plains/underworld_presentation.gd': ['refresh'],
    'game/presentation/world/underworld_plains/underworld_parallax.gd': ['_update'],
    'game/presentation/world/underworld_plains/underworld_home_world.gd': ['update_focus'],
    'game/application/demo_app.gd': ['_process', '_physics_process', '_layout_region_hud'],
    'game/progression/home/home_scene.gd': ['_process', '_physics_process'],
    'game/world/levels/providers/plains_region_stage.gd': ['_physics_process', 'capture_state', '_update_context_signs'],
    'game/enemies/enemy_actor.gd': ['_physics_process'],
    'game/player/player_controller.gd': ['_physics_process'],
}
ACTION_MEASURE = {
    'game/presentation/effects/art/chest_art_library.gd': ['pose', 'place_sprite', 'texture', 'draw_chest'],
    'game/combat/weapons/shoot_ability.gd': ['_emit_round'],
    'game/combat/projectiles/player_projectile.gd': ['advance'],
    'game/combat/weapons/presentation/weapon_feel.gd': ['_shot'],
    'game/combat/weapons/presentation/weapon_feel_v2.gd': ['_shot'],
    'game/player/presentation/motion_feel.gd': ['_land'],
}
STATIC_HELPER = '''
static func _fps04_static_record(method: String, elapsed: int) -> void:
\tvar tree := Engine.get_main_loop() as SceneTree
\tif tree == null or not tree.root.get_meta("fps04_active", false): return
\tvar rows: Dictionary = tree.root.get_meta("fps04_costs", {})
\tvar row: Array = rows.get(method, [0,0,0])
\trow[0] += elapsed
\trow[1] += 1
\trow[2] = maxi(int(row[2]), elapsed)
\trows[method] = row
'''
HELPER = '''
func _fps04_event(event: String) -> void:
\tif not is_inside_tree(): return
\tvar root := get_tree().root
\tif not root.get_meta("fps04_active", false): return
\tvar events: Dictionary = root.get_meta("fps04_events", {})
\tevents[event] = int(events.get(event,0)) + 1
\t_fps04_record("event:"+event,0)

func _fps04_record(method: String, elapsed: int) -> void:
\tif not is_inside_tree(): return
\tvar root := get_tree().root
\tif not root.get_meta("fps04_active", false): return
\tvar rows: Dictionary = root.get_meta("fps04_costs", {})
\tvar row: Array = rows.get(method, [0,0,0])
\trow[0] += elapsed
\trow[1] += 1
\trow[2] = maxi(int(row[2]), elapsed)
\trows[method] = row
'''


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--bundle', required=True, type=Path)
    p.add_argument('--output', required=True, type=Path)
    p.add_argument('--foreground-candidate', type=Path, help='Explicit single-file candidate; all other source stays at the bundle commit')
    p.add_argument('--action-detail', action='store_true', help='Observe per-frame costs/objects and chest presentation methods')
    p.add_argument('--candidate-source', action='append', default=[], choices=['game/presentation/effects/art/chest_art_library.gd', 'game/world/levels/providers/plains_region_stage.gd'], help='Explicit current-worktree candidate, recorded separately from the baseline commit')
    args = p.parse_args()
    info = json.loads((args.bundle / 'build-info.json').read_text())
    commit = info['source_commit']
    original = args.bundle / info['pack']
    digest = sha(original.read_bytes())
    assert digest.startswith(info['build_id']), 'Input pack does not match metadata'
    args.output.mkdir(parents=True, exist_ok=False)
    pack = Pack(original)
    replacements, skip, sources, mutations = {}, set(), {}, []
    measured = dict(MEASURE)
    if args.action_detail:
        measured.update(ACTION_MEASURE)
        measured['game/presentation/world/underworld_plains/underworld_foreground.gd'] = MEASURE['game/presentation/world/underworld_plains/underworld_foreground.gd'] + ['_observe']
        measured['game/presentation/world/underworld_plains/underworld_presentation.gd'] = MEASURE['game/presentation/world/underworld_plains/underworld_presentation.gd'] + ['install_item']
    assert not args.candidate_source or args.action_detail, 'Candidate source requires action detail profile'
    for path, methods in measured.items():
        raw = subprocess.check_output(['git', 'show', commit + ':' + path], cwd=ROOT)
        baseline_source_sha = sha(raw)
        if args.foreground_candidate and path == 'game/presentation/world/underworld_plains/underworld_foreground.gd':
            raw = args.foreground_candidate.read_bytes()
        if path in args.candidate_source:
            raw = (ROOT / path).read_bytes()
        source = raw.decode()
        sources[path] = sha(raw)
        for method in methods:
            match = re.search(r'^(static )?func ' + re.escape(method) + r'\(([^\n]*)\) -> ([\w\[\]]+):', source, re.M)
            assert match, (path, method)
            static = match.group(1) or ''
            arguments = match.group(2)
            result_type = match.group(3)
            parameters = [part.strip().split(':')[0].split('=')[0].strip() for part in arguments.split(',') if part.strip()]
            # Parent and child may both override the same method (WeaponFeel).
            # Distinct implementation names prevent dynamic dispatch recursion.
            unique = '_fps04_impl_' + sha(path.encode())[:8] + '_' + method
            source = source[:match.start()] + source[match.start():].replace('func ' + method + '(', 'func ' + unique + '(', 1)
            invocation = unique + '(' + ', '.join(parameters) + ')'
            recorder = '_fps04_static_record' if static else '_fps04_record'
            source += ('\n' + static + 'func ' + method + '(' + arguments + ') -> ' + result_type + ':\n'
                       '\tvar _fps04_start := Time.get_ticks_usec()\n'
                       '\t' + (invocation if result_type == 'void' else 'var _fps04_result: ' + result_type + ' = ' + invocation) + '\n'
                       '\tvar _fps04_elapsed := Time.get_ticks_usec()-_fps04_start\n'
                       '\t' + recorder + '(' + json.dumps(path + ':' + method) + ', _fps04_elapsed)\n'
                       + ('\treturn _fps04_result\n' if result_type != 'void' else ''))
            if args.action_detail and method == '_emit_round':
                source += '\tif not grounded: _fps04_event("airborne_round")\n'
            if args.action_detail and method == '_land':
                source += '\tif heavy and airborne: _fps04_event("heavy_landing")\n'
            if args.action_detail and method == '_observe':
                source += '\tvar _fps04_script := node.get_script() as Script\n\t_fps04_record("observe:"+(_fps04_script.resource_path if _fps04_script != null else node.get_class()),_fps04_elapsed)\n'
        if path == 'game/application/demo_app.gd':
            hook = 'func _ready() -> void:\n'
            assert source.count(hook) == 1
            source = source.replace(hook, hook + '\tadd_child.call_deferred(load("res://fps04_profile.gd").new())\n', 1)
        source += STATIC_HELPER if path == 'game/presentation/effects/art/chest_art_library.gd' else HELPER
        replacements[path] = source.encode()
        skip.add(path + '.remap')
        mutations.append({'path': path, 'baseline_source_sha256': baseline_source_sha, 'source_sha256': sha(raw), 'instrumented_sha256': sha(source.encode()), 'methods': methods})
    replacements['fps04_profile.gd'] = (Path(__file__).parent / ('action_profile.gd' if args.action_detail else 'frame_profile.gd')).read_bytes()
    target = args.output / 'diagnostic.pck'
    write_pack(pack, replacements, skip, target)
    receipt = {'baseline_info': info, 'baseline_pack_sha256': digest, 'diagnostic_pack_sha256': sha(target.read_bytes()),
               'replaced': mutations, 'removed_remaps': sorted(skip), 'source_sha256': sources,
               'probe_sha256': sha(replacements['fps04_profile.gd']), 'unchanged_entries': len(set(pack.entries)-skip-set(replacements)),
               'source_commit': commit, 'foreground_candidate': str(args.foreground_candidate) if args.foreground_candidate else None, 'candidate_sources':args.candidate_source, 'action_detail':args.action_detail, 'main_scene': 'Unchanged original exported demo.tscn and project.binary',
               'scope': 'Shared timing wrappers add overhead; nested elapsed costs inclusive and not additive. Only current-root capture metadata and diagnostic JS are written. No GPU or physical phone timing claim.'}
    (args.output / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({'output': str(args.output), 'source_commit': commit, 'unchanged_entries': receipt['unchanged_entries'], 'diagnostic_pack_sha256': receipt['diagnostic_pack_sha256']}))


if __name__ == '__main__':
    main()
