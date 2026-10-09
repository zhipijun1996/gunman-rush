"""Validate project documentation without claiming game runtime coverage."""
from pathlib import Path
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
errors = []
required = ['README.md', 'AGENTS.md'] + [f'docs/{name}.md' for name in
    ['game_design', 'mvp01_spec', 'architecture', 'controls_contract',
     'player_mechanics', 'combat_and_recharge', 'level_design',
     'procedural_generation', 'content_pipeline', 'acceptance_tests',
     'roadmap', 'decisions', 'environment', 'project_management', 'tasks', 'handoff',
     'visual_and_gamefeel', 'ability_components', 'world_components', 'enemies_and_bosses']]
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
tuning = json.loads((ROOT / 'config/player_tuning.json').read_text())
if tuning['physics_hz'] != 60 or tuning['max_air_shots'] != 2:
    errors.append('Confirmed prototype baseline changed; update decisions and checker intentionally')
if tuning['max_jumps'] < 0 or not tuning['jump_speeds'] or any(v >= 0 for v in tuning['jump_speeds']):
    errors.append('Invalid jump capability configuration')
if not 0 < tuning['aim_deadzone'] < 1 or tuning['recoil_tau'] <= 0:
    errors.append('Invalid tuning values')
if errors:
    print('\n'.join(errors), file=sys.stderr)
    sys.exit(1)
print(f'PASS: {len(required)} required documents, local links, {len(tasks)} task dependencies and tuning. Game runtime not tested.')
