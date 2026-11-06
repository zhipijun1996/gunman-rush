"""Validate project documentation without claiming game runtime coverage."""
from pathlib import Path
from quality import task_index_lines
import json
import os
import re
import sys
import subprocess
from check_world_design import validate as validate_world_design

ROOT = Path(__file__).resolve().parents[1]
def sparse_document_targets(root):
    """Index paths are enough for a navigation existence check, not byte validation.

    Only explicitly skip-worktree paths may be absent. Ordinary local deletions
    still fail and changed evidence is validated by its original consumers.
    """
    result = subprocess.run(["git", "ls-files", "-t", "-z"], cwd=root,
                            capture_output=True, check=True, timeout=30)
    return {entry[2:] for entry in result.stdout.decode().split("\0") if entry.startswith("S ")}


def document_target_exists(root, source, target, sparse_paths):
    path = (source.parent / target.split("#")[0]).resolve()
    root = root.resolve()
    if not path.is_relative_to(root):
        return False
    if path.exists():
        return True
    relative = path.relative_to(root).as_posix()
    return relative in sparse_paths or any(name.startswith(relative.rstrip("/") + "/") for name in sparse_paths)


def validate(root=ROOT):
    from check_context_storage import validate as validate_storage
    errors = validate_storage(root)
    errors.extend(validate_world_design(root=root))
    required = ['README.md', 'AGENTS.md', 'docs/README.md', 'docs/bible/combat_and_recharge.md', 'docs/bible/controls_contract.md', 'docs/bible/damage_and_respawn.md', 'docs/bible/game_design.md', 'docs/bible/home_and_save.md', 'docs/bible/platforming_modules.md', 'docs/bible/player_mechanics.md', 'docs/bible/procedural_generation.md', 'docs/bible/rewards_and_builds.md', 'docs/bible/run_and_routes.md', 'docs/bible/story.md', 'docs/bible/visual_bible.md', 'docs/data/README.md', 'docs/data/abilities.md', 'docs/data/audio.md', 'docs/data/bosses/bellstrider.md', 'docs/data/bosses/rootbell_guardian.md', 'docs/data/bosses/thorn_queen_canopy.md', 'docs/data/bosses/thorn_queen_weave.md', 'docs/data/bosses/windkeeper.md', 'docs/data/enemies/forest.md', 'docs/data/enemies/plains.md', 'docs/data/enemies/plains_charger.md', 'docs/data/player_actions.md', 'docs/data/story/regions.md', 'docs/data/weapons.md', 'docs/data/world_objects.md', 'docs/project/architecture.md', 'docs/project/ci-test-inventory.md', 'docs/project/cloud_production.md', 'docs/project/content_pipeline.md', 'docs/project/current_state.md', 'docs/project/development.md', 'docs/project/enemy_completion.md', 'docs/project/environment.md', 'docs/project/foundry.md', 'docs/project/harness.md', 'docs/project/item_authoring.md', 'docs/project/level_design.md', 'docs/project/level_review.md', 'docs/project/module_map.md', 'docs/project/production_loop.md', 'docs/project/project_management.md', 'docs/project/region_context.md', 'docs/project/review_method.md', 'docs/project/tasks.md', 'docs/project/visual_capture.md', 'docs/project/web_loading.md']
    for name in required:
        if not (root / name).is_file():
            errors.append(f'Missing {name}')
    def documentation_paths(root):
        # Check current navigation; generated artifacts are outside the source context.
        for base, directories, filenames in os.walk(root):
            directories[:] = [name for name in directories if name not in {'.git', '.godot', '__pycache__'}
                              and not (Path(base) == root and name in {'build', 'preview'})
                              and not (Path(base) == root / 'docs' and name in {'evidence', 'archive'})
                              ]
            for name in sorted(filenames):
                if name.endswith('.md'):
                    yield Path(base) / name


    sparse_paths = sparse_document_targets(root)
    for path in documentation_paths(root):
        content = path.read_text(encoding='utf-8')
        if not content.strip():
            errors.append(f'Empty {path.relative_to(root)}')
        for target in re.findall(r'\[[^\]]*\]\(([^)]+)\)', content):
            if target.startswith(('https:', 'http:', '#', 'mailto:')):
                continue
            if not document_target_exists(root, path, target, sparse_paths):
                errors.append(f'Broken link {path.relative_to(root)}: {target}')
    tasks = {}
    for line in task_index_lines(root):
        cells = [cell.strip() for cell in line.split('|')[1:-1]]
        if len(cells) == 5 and re.fullmatch(r'[A-Z][A-Z0-9_-]*', cells[0]):
            if cells[0] in tasks:
                errors.append(f'Duplicate task {cells[0]}')
            tasks[cells[0]] = cells
    visiting, visited = set(), set()
    def visit(task):
        if task in visiting:
            errors.append(f'Cyclic dependency at {task}')
            return
        if task in visited:
            return
        visiting.add(task)
        for dependency in tasks[task][2].split(','):
            dependency = dependency.strip()
            if dependency == '—':
                continue
            if dependency not in tasks:
                errors.append(f'Unknown dependency {task}: {dependency}')
            else:
                visit(dependency)
        visiting.remove(task)
        visited.add(task)
    for task in tasks:
        visit(task)
        if tasks[task][3] not in {'planned', 'ready', 'in_progress', 'review', 'awaiting-device', 'done', 'blocked'}:
            errors.append(f'Unknown status {task}')
    contract = json.loads((root / 'docs/bible/design_contract.json').read_text())
    if contract.get('schema_version') != 2 or contract.get('target') != 'fixed_world_metroidvania':
        errors.append('Expected fixed-world design contract')
    if contract.get('implementation', {}).get('fixed_world_runtime') is not False:
        errors.append('MV-MIGRATION-01 must not claim fixed-world runtime completion')
    for document in ('world_structure', 'world_progression', 'room_authoring', 'home_and_save'):
        if not (root / 'docs/bible' / (document + '.md')).is_file():
            errors.append('Missing current design authority: ' + document)
    for path in [root / 'AGENTS.md', root / 'docs/project/development.md',
                 root / 'docs/project/content_pipeline.md', root / '.agents/skills/game-quality-gate/SKILL.md']:
        if re.search(r'不设(?:置)?灰盒阶段', path.read_text()):
            errors.append('Obsolete graybox prohibition: ' + str(path))

    tuning = json.loads((root / 'config/player_tuning.json').read_text())
    if tuning['physics_hz'] != 60 or tuning['max_air_shots'] != 1:
        errors.append('Current D084 time-energy baseline must retain 60Hz and exactly one airborne round')
    if tuning['max_jumps'] < 0 or not tuning['jump_speeds'] or any(v >= 0 for v in tuning['jump_speeds']):
        errors.append('Invalid jump capability configuration')
    if tuning['recoil_tau'] <= 0:
        errors.append('Invalid tuning values')
    if tuning.get('recoil_mode') not in ('shot_burst', 'legacy_impulse'):
        errors.append('Invalid recoil mode')
    if not isinstance(tuning.get('variable_jump_enabled'), bool):
        errors.append('Invalid variable jump enable flag')
    for name in ('jump_hold_duration', 'jump_min_hold_duration', 'jump_release_speed'):
        value = tuning.get(name)
        if not isinstance(value, (int, float)) or isinstance(value, bool) or not -float('inf') < value < float('inf'):
            errors.append(f'Invalid variable jump setting: {name}')
    if not 0 <= tuning['jump_min_hold_duration'] <= tuning['jump_hold_duration'] or tuning['jump_release_speed'] > 0:
        errors.append('Invalid variable jump bounds')
    for name in ('shot_burst_speed', 'shot_burst_duration'):
        value = tuning.get(name)
        if not isinstance(value, (int, float)) or isinstance(value, bool) or not 0 < value < float('inf'):
            errors.append(f'Invalid shot burst configuration: {name}')
    if not isinstance(tuning.get('air_focus_enabled'), bool):
        errors.append('Invalid air focus enable flag')
    for name in ('focus_stamina_capacity', 'focus_stamina_drain', 'focus_stamina_recovery', 'focus_time_scale', 'focus_max_air_duration', 'focus_rearm_stamina'):
        value = tuning.get(name)
        if not isinstance(value, (int, float)) or isinstance(value, bool) or not -float('inf') < value < float('inf'):
            errors.append(f'Invalid air focus setting: {name}')
    if not (tuning['focus_stamina_capacity'] > 0 and tuning['focus_stamina_drain'] > 0 and tuning['focus_stamina_recovery'] >= 0 and 0 < tuning['focus_time_scale'] <= 1 and tuning['focus_max_air_duration'] > 0 and 0 <= tuning['focus_rearm_stamina'] <= tuning['focus_stamina_capacity']):
        errors.append('Invalid air focus bounds')
    profile_path = root / 'config/input_profile.json'
    if not profile_path.is_file():
        errors.append('Missing config/input_profile.json')
    else:
        profile = json.loads(profile_path.read_text())
        if not 0 <= profile['right_exit_deadzone'] < profile['right_enter_deadzone'] < 1:
            errors.append('Invalid gamepad hysteresis')
        if not 0 <= profile['left_deadzone'] < 1 or not 0 < profile['touch_deadzone'] < 1:
            errors.append('Invalid input deadzones')
        if any(profile[key] <= 0 for key in ('arm_confirm_ticks', 'center_confirm_ticks', 'left_sensitivity', 'right_sensitivity', 'response_curve', 'touch_radius', 'touch_jump_radius')):
            errors.append('Invalid input profile values')
    for name in ('projectile_speed', 'projectile_radius', 'projectile_damage', 'projectile_lifetime'):
        value = tuning.get(name)
        if not isinstance(value, (int, float)) or isinstance(value, bool) or not 0 < value < float('inf'):
            errors.append(f'Invalid attack projectile configuration: {name}')
    return errors


def main():
    errors = validate()
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print("PASS: current documentation, navigation, task dependencies and tuning. Game runtime not tested.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
