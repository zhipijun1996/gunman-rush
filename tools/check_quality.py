"""Static skill/template/record checks. Does not invoke Codex or judge game quality."""
from pathlib import Path
import re
import sys
from quality import task_record_paths, ROOT, policy, read_json, validate_record, validate_asset


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
    for path in task_record_paths(root):
        data = read_json(path)
        result = validate_record(data, root)
        errors.extend(f'{path.name}: {e}' for e in result['errors'])
        if data['task_id'] in records:
            errors.append(f'Duplicate task record: {data["task_id"]}')
        records[data['task_id']] = data
    if f'版本 **{p["schema_version"]}**' not in (root / 'docs/project/development.md').read_text():
        errors.append('Quality version mismatch: development.md')
    return errors


def main():
    errors = validate()
    if errors:
        print('\n'.join(errors), file=sys.stderr)
        return 1
    print(f'PASS: {len(policy()["core_skills"])} core skills, references, {len(policy()["templates"])} templates, current content records; STATIC ONLY.')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (ValueError, OSError, KeyError, TypeError) as error:
        print(f'Quality structure failed: {error}', file=sys.stderr)
        sys.exit(1)
