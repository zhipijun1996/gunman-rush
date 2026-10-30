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
    'scripts/underworld_plains/underworld_foreground.gd': ['_refresh', '_protection', '_sync_residents', '_render_receipt'],
    'scripts/underworld_plains/underworld_presentation.gd': ['refresh'],
    'scripts/underworld_plains/underworld_parallax.gd': ['_update'],
    'scripts/underworld_plains/underworld_home_world.gd': ['update_focus'],
    'scripts/demo/demo_app.gd': ['_process', '_physics_process', '_layout_region_hud'],
    'scripts/demo/home_scene.gd': ['_process', '_physics_process'],
    'scripts/demo/plains_region_stage.gd': ['_physics_process', 'capture_state', '_update_context_signs'],
    'scripts/enemies/enemy_actor.gd': ['_physics_process'],
    'scripts/player/player_controller.gd': ['_physics_process'],
}
HELPER = '''
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
    args = p.parse_args()
    info = json.loads((args.bundle / 'build-info.json').read_text())
    commit = info['source_commit']
    original = args.bundle / info['pack']
    digest = sha(original.read_bytes())
    assert digest.startswith(info['build_id']), 'Input pack does not match metadata'
    args.output.mkdir(parents=True, exist_ok=False)
    pack = Pack(original)
    replacements, skip, sources, mutations = {}, set(), {}, []
    for path, methods in MEASURE.items():
        raw = subprocess.check_output(['git', 'show', commit + ':' + path], cwd=ROOT)
        baseline_source_sha = sha(raw)
        if args.foreground_candidate and path == 'scripts/underworld_plains/underworld_foreground.gd':
            raw = args.foreground_candidate.read_bytes()
        source = raw.decode()
        sources[path] = sha(raw)
        for method in methods:
            match = re.search(r'^func ' + re.escape(method) + r'\(([^\n]*)\) -> void:', source, re.M)
            assert match, (path, method)
            arguments = match.group(1)
            parameters = [part.strip().split(':')[0].split('=')[0].strip() for part in arguments.split(',') if part.strip()]
            unique = '_fps04_impl_' + method
            source = source[:match.start()] + source[match.start():].replace('func ' + method + '(', 'func ' + unique + '(', 1)
            source += ('\nfunc ' + method + '(' + arguments + ') -> void:\n'
                       '\tvar _fps04_start := Time.get_ticks_usec()\n'
                       '\t' + unique + '(' + ', '.join(parameters) + ')\n'
                       '\t_fps04_record(' + json.dumps(path + ':' + method) + ', Time.get_ticks_usec()-_fps04_start)\n')
        if path == 'scripts/demo/demo_app.gd':
            hook = 'func _ready() -> void:\n'
            assert source.count(hook) == 1
            source = source.replace(hook, hook + '\tadd_child.call_deferred(load("res://fps04_profile.gd").new())\n', 1)
        source += HELPER
        replacements[path] = source.encode()
        skip.add(path + '.remap')
        mutations.append({'path': path, 'baseline_source_sha256': baseline_source_sha, 'source_sha256': sha(raw), 'instrumented_sha256': sha(source.encode()), 'methods': methods})
    replacements['fps04_profile.gd'] = (Path(__file__).parent / 'frame_profile.gd').read_bytes()
    target = args.output / 'diagnostic.pck'
    write_pack(pack, replacements, skip, target)
    receipt = {'baseline_info': info, 'baseline_pack_sha256': digest, 'diagnostic_pack_sha256': sha(target.read_bytes()),
               'replaced': mutations, 'removed_remaps': sorted(skip), 'source_sha256': sources,
               'probe_sha256': sha(replacements['fps04_profile.gd']), 'unchanged_entries': len(set(pack.entries)-skip-set(replacements)),
               'source_commit': commit, 'foreground_candidate': str(args.foreground_candidate) if args.foreground_candidate else None, 'main_scene': 'Unchanged original exported demo.tscn and project.binary',
               'scope': 'Shared timing wrappers add overhead; nested elapsed costs inclusive and not additive. Only current-root capture metadata and diagnostic JS are written. No GPU or physical phone timing claim.'}
    (args.output / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({'output': str(args.output), 'source_commit': commit, 'unchanged_entries': receipt['unchanged_entries'], 'diagnostic_pack_sha256': receipt['diagnostic_pack_sha256']}))


if __name__ == '__main__':
    main()
