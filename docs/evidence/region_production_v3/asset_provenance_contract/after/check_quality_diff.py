"""Check new work against a Git base without grandfathering new false completion."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys
from quality import ROOT, read_json, validate_record, validate_asset

PRODUCTION = ('scripts/', 'scenes/', 'resources/', 'config/', 'assets/', 'shaders/')


def git(root, *args):
    return subprocess.check_output(['git', *args], cwd=root, text=True)


def weakened_checks(before, after):
    """Conservative signal, not proof of semantic equivalence of arbitrary test code."""
    pattern = re.compile(r'assert|expect|success_pattern|error_patterns|failure_pattern|SUITES\s*=|timeout_seconds|timeout=|Parse Error|SCRIPT ERROR', re.I)
    old = {s.strip() for s in before.splitlines() if pattern.search(s) and not s.lstrip().startswith('#')}
    new = {s.strip() for s in after.splitlines() if pattern.search(s) and not s.lstrip().startswith('#')}
    return sorted(old - new)


def removed_checks(before, after):
    old, new = json.loads(before), json.loads(after)
    removed = [f'check:{name}' for name in old['checks'] if name not in new['checks']]
    for profile, checks in old['profiles'].items():
        removed.extend(f'{profile}:{c}' for c in checks if c not in new['profiles'].get(profile, []))
    return removed


def task_states(text):
    result = {}
    for line in text.splitlines():
        cells = [c.strip() for c in line.split('|')[1:-1]]
        # Match the IDs accepted by production_loop, including routed lower-case IDs.
        if len(cells) == 5 and re.fullmatch(r'[A-Za-z0-9_-]+', cells[0]):
            result[cells[0]] = cells[3]
    return result


def validate(base, root=ROOT):
    # Validate revision as an object before using it; base never becomes shell code.
    sha = git(root, 'rev-parse', '--verify', f'{base}^{{commit}}').strip()
    changed = set(git(root, 'diff', '--name-only', sha, '--').splitlines())
    changed.update(git(root, 'ls-files', '--others', '--exclude-standard').splitlines())
    errors = []
    records = [read_json(p) for p in (root / 'docs/quality/records').glob('*.json')]
    for path in sorted(changed):
        if path.startswith('docs/quality/records/') and path.endswith('.json') and (root / path).is_file():
            prior = subprocess.run(['git', 'cat-file', '-e', f'{sha}:{path}'], cwd=root, capture_output=True)
            record = read_json(root / path)
            if prior.returncode != 0 and record.get('formal_impact') and 'consumer_coverage' not in record:
                errors.append(f'New formal record must declare consumer_coverage (null until observed): {path}')
    valid_records = [r for r in records if not validate_record(r, root)['errors']]
    assets = [read_json(p) for p in (root / 'docs/quality/asset_records').glob('*.json')]
    # Coverage is granted only after the entire record validates, including all
    # explicitly named offline production files and their actual byte hashes.
    valid_assets = [a for a in assets if not validate_asset(a, root)]
    provenance_paths = {name for a in valid_assets for name in
                        [a['source_path'], *a['runtime_paths'],
                         *(item['path'] for item in a.get('associated_files', []))]}
    for name in sorted(changed):
        runtime = name.startswith(PRODUCTION) or name in {'project.godot', 'export_presets.cfg'}
        covering = [r for r in valid_records if name in r['affected_paths']]
        if runtime and not any(r['task_type'] != 'process' for r in covering):
            errors.append(f'Production change lacks non-process task record: {name}')
        if runtime and covering and not any(r['task_type'] != 'process' and (r['task_type'] != 'small_fix' or r['formal_impact']) for r in covering):
            errors.append(f'Runtime small_fix must declare formal_impact: {name}')
        # Freeze executable/skill/policy claims to their actual reviewed Git contents.
        # Handoff/task/evidence wrappers may be added after that implementation commit.
        implementation = runtime or name.startswith(('tools/', 'tests/', '.agents/', '.github/')) or name == 'docs/quality/policy.json'
        if implementation and covering and all(r['workflow'] == 'done' for r in covering):
            current = (root / name).read_bytes() if (root / name).is_file() else None
            fresh = False
            for record in covering:
                prior = subprocess.run(['git', 'show', f'{record["reviewed_commit"]}:{name}'], cwd=root, capture_output=True)
                fresh |= (prior.stdout == current if prior.returncode == 0 else current is None)
            if not fresh:
                errors.append(f'Completed record is stale for current implementation: {name}')
        if name.startswith('assets/') and (root / name).is_file() and not name.endswith(('.import', '.uid')):
            if name not in provenance_paths:
                errors.append(f'Changed asset lacks provenance metadata: {name}')
        if name.startswith(('tests/', 'tools/')) and name.endswith(('.gd', '.py', '.json', '.mjs', '.sh')):
            exists = subprocess.run(['git', 'cat-file', '-e', f'{sha}:{name}'], cwd=root, capture_output=True).returncode == 0
            if not exists:
                continue
            before = git(root, 'show', f'{sha}:{name}')
            after = (root / name).read_text() if (root / name).is_file() else ''
            sensitive = name.startswith('tests/') or 'run_' in name or name in {'tools/harness.py', 'tools/harness/profiles.json'}
            weakened = weakened_checks(before, after) if sensitive else []
            removed = removed_checks(before, after) if name == 'tools/harness/profiles.json' and after else []
            if not after or weakened or removed:
                reviewed = any(r['dimensions']['independent_review']['status'] == 'passed' and r.get('test_change_justification') for r in covering)
                if not reviewed:
                    errors.append(f'Test/check deletion or changed guard needs independent review and test_change_justification: {name}; removed guards={weakened + removed}')
    old_tasks = task_states(git(root, 'show', f'{sha}:docs/tasks.md'))
    new_tasks = task_states((root / 'docs/tasks.md').read_text())
    for task, state in new_tasks.items():
        if state == 'done' and old_tasks.get(task) != 'done':
            if not any(r['task_id'] == task and r['workflow'] == 'done' and validate_record(r, root)['task_complete'] for r in valid_records):
                errors.append(f'New done task lacks complete quality record: {task}')
    return errors, sorted(changed)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base', required=True)
    args = parser.parse_args()
    errors, changed = validate(args.base)
    if errors:
        print('\n'.join(errors), file=sys.stderr)
        return 1
    print(f'PASS: diff scope, new completion and test guard preservation ({len(changed)} files); semantic review still required.')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
        print(f'Diff validation failed: {error}', file=sys.stderr)
        sys.exit(1)
