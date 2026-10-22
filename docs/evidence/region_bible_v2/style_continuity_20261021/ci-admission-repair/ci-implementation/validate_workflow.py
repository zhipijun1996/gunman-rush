"""Offline checks of actual workflow YAML and its finite GitHub identity expressions."""
from pathlib import Path
import copy
import hashlib
import json
import re
import subprocess
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

# Interpret only the actual GitHub expression subset; no eval or API calls.
def value(expression, context):
    tokens = re.findall(r"'(?:[^']|'')*'|[A-Za-z_][A-Za-z_0-9.]*|\&\&|\|\||==|[(),]", expression)
    position = 0
    def take(expected=None):
        nonlocal position
        token = tokens[position];position += 1
        assert expected is None or token == expected
        return token
    def atom():
        if tokens[position] == '(':
            take('('); result = disjunction();take(')');return result
        token = take()
        if token.startswith("'"): return token[1:-1].replace("''", "'")
        if token in ('format', 'contains'):
            take('('); args = [disjunction()]
            while tokens[position] == ',':take(',');args.append(disjunction())
            take(')')
            return args[0].format(*args[1:]) if token == 'format' else str(args[1]).casefold() in str(args[0] or '').casefold()
        assert token.startswith('github.'), token
        result = context
        for key in token.split('.')[1:]:
            result = result.get(key) if isinstance(result, dict) else None
        return result
    def equality():
        result = atom()
        if position < len(tokens) and tokens[position] == '==':
            take('==');other = atom()
            return str(result).casefold() == str(other).casefold()
        return result
    def conjunction():
        result = equality()
        while position < len(tokens) and tokens[position] == '&&':
            take('&&');other = equality(); result = other if result else result
        return result
    def disjunction():
        result = conjunction()
        while position < len(tokens) and tokens[position] == '||':
            take('||');other = conjunction();result = result if result else other
        return result
    result = disjunction()
    assert position == len(tokens)
    return result

def render(template, context):
    return re.sub(r'\$\{\{(.*?)\}\}', lambda m: str(value(m[1], context)), template)

head = 'h' * 40; merge = 'm' * 40
push = {'workflow': 'Godot core', 'event_name': 'push', 'repository': 'owner/repo',
        'ref_name': 'feature/test', 'ref': 'refs/heads/feature/test', 'sha': head, 'event': {'head_commit': {'message': 'normal work'}}}
pr = {**copy.deepcopy(push), 'event_name': 'pull_request', 'ref_name': '99/merge', 'ref': 'refs/pull/99/merge', 'sha': merge,
      'event': {'pull_request': {'head': {'sha': head, 'ref': 'feature/test', 'repo': {'full_name': 'owner/repo'}}}}}
manual = {**copy.deepcopy(push), 'event_name': 'workflow_dispatch'}
other_branch = {**copy.deepcopy(push), 'ref_name': 'feature/other', 'ref': 'refs/heads/feature/other'}
main = {**copy.deepcopy(push), 'ref_name': 'main', 'ref': 'refs/heads/main'}
main_tag = {**copy.deepcopy(main), 'ref': 'refs/tags/main'}
main_pr = copy.deepcopy(pr);main_pr['event']['pull_request']['head']['ref'] = 'main'
fork = copy.deepcopy(main_pr);fork['event']['pull_request']['head']['repo']['full_name'] = 'fork/repo'
actor_push = copy.deepcopy(push);actor_push.update(ref_name='feature/complete-actor-actions', ref='refs/heads/feature/complete-actor-actions');actor_push['event']['head_commit']['message'] = 'release [publish-playtest]'
actor_pr = copy.deepcopy(pr);actor_pr['event']['pull_request']['head']['ref'] = 'feature/complete-actor-actions'
actor_normal = copy.deepcopy(actor_push);actor_normal['event']['head_commit']['message'] = 'normal work'
manual_main = {**copy.deepcopy(main), 'event_name': 'workflow_dispatch'}
group = workflow['concurrency']['group']
checks = {
    'normal_push_PR_same_repo_fullbranch_share_group': render(group, push) == render(group, pr),
    'PR_checkout_is_actual_head_not_synthetic_merge': render(expected, pr) == head != merge,
    'push_checkout_preserves_event_SHA': render(expected, push) == head,
    'manual_checkout_preserves_event_SHA': render(expected, manual) == head,
    'manual_does_not_cancel_automatic': render(group, manual) != render(group, push),
    'different_branch_does_not_cancel': render(group, other_branch) != render(group, push),
    'fork_same_branch_does_not_cancel_target_main': render(group, fork) != render(group, main),
    'fork_same_branch_checks_does_not_cancel_target_PRchecks': render(group, fork) != render(group, main_pr),
    'tag_main_does_not_cancel_branch_main_publish': render(group, main_tag) != render(group, main),
    'main_publish_push_is_not_canceled_by_PR_checks': render(group, main) != render(group, main_pr),
    'explicit_actor_publish_push_is_not_canceled_by_PR_checks': render(group, actor_push) != render(group, actor_pr),
    'ordinary_actor_push_and_PR_still_deduplicate': render(group, actor_normal) == render(group, actor_pr),
    'manual_main_deploy_remains_separate_from_main_push': render(group, manual_main) != render(group, main),
    'only_ordinary_branch_same_source_deduplicates_not_tag': render(group, {**copy.deepcopy(push), 'ref': 'refs/tags/feature/test'}) != render(group, pr),
    'publish_predicates_unchanged': workflow['jobs']['deploy_web']['if'] == yaml.load((path.parents[2] / 'build/region_bible_v2/ci-exact-source-event-proposal-first/environment.before.yml').read_text(), Loader=yaml.BaseLoader)['jobs']['deploy_web']['if'],
}
assert all(checks.values()), checks
proposal = json.loads((path.parents[2] / 'build/region_bible_v2/ci-exact-source-event-proposal-first/proposal.json').read_text())
docs_bytes = (ROOT / '.github/workflows/docs.yml').read_bytes()
docs = yaml.load(docs_bytes, Loader=yaml.BaseLoader)
assert all('ref' not in step.get('with', {}) for step in docs['jobs']['docs']['steps'] if step.get('uses') == 'actions/checkout@v4')
quality = [step for step in docs['jobs']['docs']['steps'] if 'tools/check_quality_diff.py' in step.get('run', '')]
assert len(quality) == 1 and quality[0]['if'] == "github.event_name == 'pull_request'"
assert quality[0]['env']['QUALITY_BASE'] == '${{ github.event.pull_request.base.sha }}'
assert docs['concurrency']['group'] == 'docs-${{ github.event_name }}-${{ github.ref }}'

result = {'scope': 'Actual YAML parse/finite expression and guard controls; not a GitHub execution or artifact pass',
          'workflow_sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'checkout_jobs': checkout_jobs,
          'identity_controls': checks, 'docs_PR_merge_quality_semantics_preserved': True, 'docs_modified_by_this_patch': False,
          'docs_observed_SHA256': hashlib.sha256(docs_bytes).hexdigest(),
          'docs_external_quality_step_reordered': hashlib.sha256(docs_bytes).hexdigest() != proposal['source_hashes']['.github/workflows/docs.yml'],
          'source': str(path.relative_to(ROOT))}
print(json.dumps(result, indent=2))
