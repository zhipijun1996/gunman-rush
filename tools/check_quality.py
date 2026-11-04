"""Static skill/template/record checks. Does not invoke Codex or judge game quality."""
from pathlib import Path
import re
import sys
from quality import ROOT, policy, read_json, validate_record, validate_asset


def skill_workflow_errors(content):
    errors = []
    for heading in ('适用任务', '操作', '验证与交付'):
        matches = list(re.finditer(r'^## ' + heading + r'\s*$', content, re.MULTILINE))
        if len(matches) != 1:
            errors.append(f'Expected one skill section: {heading}')
            continue
        section = content[matches[0].end():].split('\n## ', 1)[0].strip()
        if not section:
            errors.append(f'Empty skill section: {heading}')
    return errors


def validate(root=ROOT):
    errors = []
    p = policy()
    names = set()
    paths = list((root / '.agents/skills').glob('*/SKILL.md'))
    for path in paths:
        content = path.read_text()
        meta = re.match(r'^---\nname: ([a-z0-9-]+)\ndescription: ([^\n]+)\n---\n', content)
        if not meta or meta[1] != path.parent.name or meta[1] in names:
            errors.append(f'Invalid/duplicate skill metadata: {path}')
            continue
        names.add(meta[1])
        if meta[1] in p['core_skills']:
            errors.extend(f'{meta[1]}: {error}' for error in skill_workflow_errors(content))
        for target in re.findall(r'\[[^\]]*\]\(([^)]+)\)', content):
            if not target.startswith(('http:', 'https:', '#')) and not (path.parent / target.split('#')[0]).is_file():
                errors.append(f'Broken skill reference: {path}: {target}')
    if not set(p['core_skills']) <= names:
        errors.append('Missing core skills')
    for name in p['templates']:
        path = root / name
        if not path.is_file():
            errors.append(f'Missing template: {name}')
            continue
        text = path.read_text()
        for field in ('task_id', 'baseline_commit', 'content_version', '玩家体验', '交付物', '失败', '证据', '未验', '方法'):
            if field not in text:
                errors.append(f'Template missing {field}: {name}')
    records = {}
    for path in sorted((root / 'docs/quality/records').glob('*.json')):
        data = read_json(path)
        result = validate_record(data, root)
        errors.extend(f'{path.name}: {e}' for e in result['errors'])
        if data['task_id'] in records:
            errors.append(f'Duplicate task record: {data["task_id"]}')
        records[data['task_id']] = data
    for path in (root / 'docs/quality/asset_records').glob('*.json'):
        errors.extend(f'{path.name}: {e}' for e in validate_asset(read_json(path), root))
    task_rows = {}
    for line in (root / 'docs/tasks.md').read_text().splitlines():
        cells = [c.strip() for c in line.split('|')[1:-1]]
        if len(cells) == 5:
            task_rows[cells[0]] = cells[3]
    for task, data in records.items():
        if task_rows.get(task) != data['workflow']:
            errors.append(f'Task index/record mismatch: {task}')
    for doc in ('docs/development_quality.md', 'docs/quality/README.md'):
        if f'版本 **{p["schema_version"]}**' not in (root / doc).read_text():
            errors.append(f'Quality version mismatch: {doc}')
    return errors


def main():
    errors = validate()
    if errors:
        print('\n'.join(errors), file=sys.stderr)
        return 1
    print(f'PASS: {len(policy()["core_skills"])} core skills, references, {len(policy()["templates"])} templates, quality records and asset metadata; STATIC ONLY.')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (ValueError, OSError, KeyError, TypeError) as error:
        print(f'Quality structure failed: {error}', file=sys.stderr)
        sys.exit(1)
