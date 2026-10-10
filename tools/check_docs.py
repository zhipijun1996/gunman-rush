"""Validate project documentation without claiming game runtime coverage."""
from pathlib import Path
import json
import re
import sys
import xml.etree.ElementTree as ET
from check_world_design import validate as validate_world_design

ROOT = Path(__file__).resolve().parents[1]
errors = []
errors.extend(validate_world_design())
required = ['README.md', 'AGENTS.md'] + [f'docs/{name}.md' for name in
    ['game_design', 'mvp01_spec', 'architecture', 'controls_contract',
     'player_mechanics', 'combat_and_recharge', 'level_design',
     'procedural_generation', 'content_pipeline', 'acceptance_tests',
     'roadmap', 'decisions', 'environment', 'project_management', 'tasks', 'handoff',
     'visual_and_gamefeel', 'ability_components', 'world_components', 'enemies_and_bosses',
     'run_and_routes', 'rewards_and_builds', 'damage_and_respawn', 'home_and_save', 'module_map',
     'platforming_modules', 'difficulty_profiles', 'world_and_story', 'biome_challenge_design', 'wall_slide_design', 'plains_branch_revision']]
for name in required:
    if not (ROOT / name).is_file():
        errors.append(f'Missing {name}')
for path in ROOT.rglob('*.md'):
    if '.git' in path.parts:
        continue
    content = path.read_text(encoding='utf-8')
    if not content.strip():
        errors.append(f'Empty {path.relative_to(ROOT)}')
    for target in re.findall(r'\[[^\]]*\]\(([^)]+)\)', content):
        if target.startswith(('https:', 'http:', '#', 'mailto:')):
            continue
        if not (path.parent / target.split('#')[0]).exists():
            errors.append(f'Broken link {path.relative_to(ROOT)}: {target}')
tasks = {}
for line in (ROOT / 'docs/tasks.md').read_text().splitlines():
    cells = [cell.strip() for cell in line.split('|')[1:-1]]
    if len(cells) == 5 and re.fullmatch(r'[A-Z]+(?:-[A-Z]+)*-\d+', cells[0]):
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
    if tasks[task][3] not in {'planned', 'ready', 'in_progress', 'review', 'done', 'blocked', 'awaiting-device'}:
        errors.append(f'Unknown status {task}')
# Design-only contract prevents the shortened test profile replacing release rules.
contract = {}
contract_path = ROOT / 'docs/design_contract.json'
if not contract_path.is_file():
    errors.append('Missing docs/design_contract.json')
else:
    contract = json.loads(contract_path.read_text())
    formal = contract.get('formal_run', {})
    development = contract.get('development_run', {})
    if contract.get('schema_version') != 1 or contract.get('kind') != 'design_contract_not_runtime_configuration':
        errors.append('Invalid design contract version or scope')
    if formal.get('stages_per_biome') != 8 or formal.get('boss_stage') != 8:
        errors.append('Formal run must have eight stages with Boss at eight')
    if formal.get('profile_id') != 'formal_eight' or formal.get('definition_version') != 2:
        errors.append('Formal eight-stage profile must declare the migration identity and version')
    if development.get('stages_per_biome') != 3 or development.get('boss_stage') != 3 or development.get('development_only') is not True:
        errors.append('Three-stage profile must remain explicitly development-only')
    expected_sets = {
        'stage_types': {'combat', 'shop', 'coin_reward', 'health_reward', 'item_reward', 'boss'},
        'item_rarities': {'BLUE', 'PURPLE', 'GOLD'},
        'reward_kinds': {'RUN_COIN', 'HEAL_CURRENT', 'INCREASE_MAX_HEALTH', 'ITEM'},
        'resource_types': {'Health', 'Stamina', 'ActionResources'},
        'random_streams': {'map', 'route', 'reward', 'shop', 'boss_pattern'},
        'unconfirmed_stamina_actions': {'move', 'jump', 'shoot'},
    }
    for field, expected in expected_sets.items():
        actual = contract.get(field, [])
        if not isinstance(actual, list) or len(actual) != len(set(actual)) or not expected.issubset(set(actual)):
            errors.append(f'Missing or duplicate design definition: {field}')
    decisions = (ROOT / 'docs/decisions.md').read_text()
    decision_rows = {}
    for line in decisions.splitlines():
        cells = [cell.strip() for cell in line.split('|')[1:-1]]
        if len(cells) == 3 and re.fullmatch(r'(D|Q)\d{3}', cells[0]):
            decision_rows[cells[0]] = cells
    for decision in contract.get('tentative_decisions', []):
        if decision not in decision_rows or decision_rows[decision][1] != '暂定':
            errors.append(f'Tentative policy must not be recorded as user-confirmed: {decision}')
    for decision in contract.get('pending_decisions', []):
        if decision not in decision_rows:
            errors.append(f'Missing pending decision: {decision}')
    acceptance = (ROOT / 'docs/acceptance_tests.md').read_text()
    acceptance_ids = re.findall(r'^\| (A\d+) \|', acceptance, re.MULTILINE)
    for acceptance_id in contract.get('acceptance_ids', []):
        if acceptance_ids.count(acceptance_id) != 1:
            errors.append(f'New acceptance must be defined exactly once: {acceptance_id}')
    for document in ('run_and_routes', 'rewards_and_builds', 'damage_and_respawn', 'home_and_save'):
        if f'docs/{document}.md' not in (ROOT / 'AGENTS.md').read_text():
            errors.append(f'AGENTS missing design authority: {document}')

# Check authored generation catalog and SVG structure; not physics validation.
modules = contract.get('generation_modules', [])
module_doc = (ROOT / 'docs/platforming_modules.md').read_text()
if len(modules) != 8 or len(set(modules)) != 8:
    errors.append('Generation design must have eight unique starter modules')
for module_id in modules:
    if len(re.findall(r'^## \d+\. `' + re.escape(module_id) + r'`', module_doc, re.MULTILINE)) != 1:
        errors.append(f'Module blueprint missing or duplicated: {module_id}')
if not {'horizontal_chain', 'vertical_ascent', 'square_loop'}.issubset(contract.get('spatial_layouts', [])):
    errors.append('Missing horizontal, vertical or square topology')
if set(contract.get('difficulty_axes', [])) != {'P', 'C', 'T', 'R'}:
    errors.append('Difficulty design must separate P/C/T/R')
for diagram in ('platforming_modules.svg', 'stage_topologies.svg'):
    try:
        element = ET.parse(ROOT / 'docs/diagrams' / diagram).getroot()
        if not element.tag.endswith('svg') or element.find('{http://www.w3.org/2000/svg}title') is None:
            errors.append(f'Missing accessible SVG design title: {diagram}')
    except (OSError, ET.ParseError) as error:
        errors.append(f'Invalid generation design SVG {diagram}: {error}')

tuning = json.loads((ROOT / 'config/player_tuning.json').read_text())
if tuning['physics_hz'] != 60 or tuning['max_air_shots'] != 2:
    errors.append('Confirmed prototype baseline changed; update decisions and checker intentionally')
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
profile_path = ROOT / 'config/input_profile.json'
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
if errors:
    print('\n'.join(errors), file=sys.stderr)
    sys.exit(1)
print(f'PASS: {len(required)} required documents, local links, {len(tasks)} task dependencies and tuning. Game runtime not tested.')
