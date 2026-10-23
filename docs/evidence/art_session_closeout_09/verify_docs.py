"""Bounded documentation checks; no game runtime/CI/art approval claim."""
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[3]
BASE = '42f673c27d94926df2517d9c2d5e783fb153f7a6'
SOURCE = '641be9a5fb50b6ffdc8c5405f64e8b4a20b306dc'

def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True).strip()

paths = git('diff', '--name-only', BASE, SOURCE).splitlines()
assert len(paths) == 14
assert all(p.startswith(('docs/', '.agents/skills/')) for p in paths)
links = 0
for name in paths:
    path = ROOT / name
    current = path.read_text()
    before = subprocess.run(['git', 'show', f'{BASE}:{name}'], cwd=ROOT,
                            capture_output=True, text=True)
    old_links = set(re.findall(r'\[[^\]]*\]\(([^)]+)\)', before.stdout))
    for target in set(re.findall(r'\[[^\]]*\]\(([^)]+)\)', current)) - old_links:
        if target.startswith(('http:', 'https:', '#', 'mailto:')):
            continue
        target_path = (path.parent / target.split('#')[0]).resolve()
        assert target_path.is_file(), (name, target)
        links += 1
    if name.endswith('SKILL.md') and '所有后续region create/optimize' in current:
        assert '当前共享画风与用户细粒度选择：style-v5' in current
        assert '家族的16px/32wu' not in current

frozen = ['docs/creative_direction/bibles/' + name for name in [
    '1-windchime_plains_region_bible_v2.md', '2-thorn_forest_region_bible_v2.md',
    'style-continuity-20261022-v4.json', 'style-continuity-20261022-v5.json']]
for name in frozen:
    assert git('rev-parse', f'{BASE}:{name}') == git('hash-object', name)
for ref in ['35a9cd8', '0c1d1e5', '7f332ff', '73c9add', 'efd7843', '4a41fd7', 'f554e6b', '6befe56']:
    subprocess.run(['git', 'merge-base', '--is-ancestor', ref, SOURCE], cwd=ROOT, check=True)
report = {'status': 'passed', 'source_commit': SOURCE, 'baseline_commit': BASE,
          'documentation_paths_checked': paths, 'new_local_links_checked': links,
          'unchanged_authority_files': frozen, 'all_eight_rounds_are_ancestors': True,
          'runtime_changes_this_task': False, 'full_docs_profile_executed': False,
          'scope': 'changed documentation/link/authority consistency only; no runtime, independent art or device approval'}
(ROOT / 'docs/evidence/art_session_closeout_09/verification.json').write_text(
    json.dumps(report, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(report, ensure_ascii=False))
