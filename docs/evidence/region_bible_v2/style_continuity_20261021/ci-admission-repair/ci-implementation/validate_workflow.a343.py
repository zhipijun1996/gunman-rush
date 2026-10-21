"""Offline checks of actual workflow YAML and its finite GitHub identity expressions."""
from pathlib import Path
import copy
import hashlib
import json
import re
import yaml

ROOT = Path(__file__).resolve().parents[3]
path = ROOT / '.github/workflows/environment.yml'
workflow = yaml.load(path.read_text(), Loader=yaml.BaseLoader)
expected = '${{ github.event.pull_request.head.sha || github.sha }}'
checkout_jobs = []
for name, job in workflow['jobs'].items():
    for step in job.get('steps', []):
        if step.get('uses') == 'actions/checkout@v4':
            assert step['with']['ref'] == expected, (name, step)
            checkout_jobs.append(name)
assert checkout_jobs == ['prepare', 'core_checks', 'core', 'windows', 'web', 'android', 'verify_public']
assert '"$(git rev-parse HEAD)"' in workflow['jobs']['prepare']['steps'][3]['run']
assert '$GITHUB_SHA' not in path.read_text()
assert workflow['jobs']['core_checks']['strategy']['matrix']['lane'] == ['parallel', 'serial']
assert workflow['jobs']['deploy_web']['concurrency'] == {'group': 'pages-playtest', 'cancel-in-progress': 'false'}

# Interpret only the actual expression subset in this workflow; no eval or API.
def value(expression, context):
    def atom(token):
        token = token.strip()
        if token.startswith("'") and token.endswith("'"): return token[1:-1]
        if token.startswith('github.'):
            result = context
            for key in token.split('.')[1:]:
                result = result.get(key, {}) if isinstance(result, dict) else {}
            return result if result != {} else None
        raise AssertionError('Unsupported expression atom: ' + token)
    def compare(text):
        parts = text.split(' == ')
        return atom(parts[0]) == atom(parts[1]) if len(parts) == 2 else atom(text)
    def conjunction(text):
        result = None
        for part in text.split(' && '):
            result = compare(part)
            if not result: break
        return result
    for part in expression.strip().split(' || '):
        result = conjunction(part)
        if result: return result
    return result

def render(template, context):
    return re.sub(r'\$\{\{(.*?)\}\}', lambda m: str(value(m[1], context)), template)

head = 'h' * 40; merge = 'm' * 40
push = {'workflow': 'Godot core', 'event_name': 'push', 'repository': 'owner/repo',
        'ref_name': 'feature/test', 'sha': head, 'event': {}}
pr = {**copy.deepcopy(push), 'event_name': 'pull_request', 'ref_name': '99/merge', 'sha': merge,
      'event': {'pull_request': {'head': {'sha': head, 'ref': 'feature/test', 'repo': {'full_name': 'owner/repo'}}}}}
manual = {**copy.deepcopy(push), 'event_name': 'workflow_dispatch'}
other_branch = {**copy.deepcopy(push), 'ref_name': 'feature/other'}
main = {**copy.deepcopy(push), 'ref_name': 'main'}
fork = copy.deepcopy(pr);fork['event']['pull_request']['head'].update(ref='main', repo={'full_name': 'fork/repo'})
group = workflow['concurrency']['group']
checks = {
    'push_PR_same_repo_branch_share_group': render(group, push) == render(group, pr),
    'PR_checkout_is_actual_head_not_synthetic_merge': render(expected, pr) == head != merge,
    'push_checkout_preserves_event_SHA': render(expected, push) == head,
    'manual_checkout_preserves_event_SHA': render(expected, manual) == head,
    'manual_does_not_cancel_automatic': render(group, manual) != render(group, push),
    'different_branch_does_not_cancel': render(group, other_branch) != render(group, push),
    'fork_same_branch_does_not_cancel_target_main': render(group, fork) != render(group, main),
}
assert all(checks.values()), checks
proposal = json.loads((path.parents[2] / 'build/region_bible_v2/ci-exact-source-event-proposal-first/proposal.json').read_text())
assert hashlib.sha256((ROOT / '.github/workflows/docs.yml').read_bytes()).hexdigest() == proposal['source_hashes']['.github/workflows/docs.yml']
result = {'scope': 'Actual YAML parse/finite expression and guard controls; not a GitHub execution or artifact pass',
          'workflow_sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'checkout_jobs': checkout_jobs,
          'identity_controls': checks, 'docs_workflow_unchanged': True,
          'source': str(path.relative_to(ROOT))}
print(json.dumps(result, indent=2))
