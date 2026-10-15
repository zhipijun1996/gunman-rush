"""Read-only proof mutation, no production code writes. Run from repository root."""
import copy
import hashlib
import json
import pathlib
import sys
sys.path.insert(0, str(pathlib.Path('tools').resolve()))
import run_plains_experience_golden_tests as gate

SOURCE = pathlib.Path('build/plains_redesign/experience/run_igiwoygr/positive.json')

def mutate(data, case):
    bad = copy.deepcopy(data)
    for obs in bad['observations']:
        if case == 'remove_all_jump_accepts':
            obs['events'] = [event for event in obs['events'] if event['kind'] != 'accepted_jump']
        elif case == 'remove_all_landing_accepts':
            obs['events'] = [event for event in obs['events'] if event['kind'] != 'accepted_landing']
        elif case == 'remove_all_drop_through':
            obs['events'] = [event for event in obs['events'] if not (event['kind'] == 'input_request' and event['action'] == 'drop_through')]
        elif case == 'erase_callback_event_timing':
            for event in obs['events']:
                if event['kind'] == 'grounded_island_callback':
                    event['tick'] = 0
                    event['position'] = [0, 282]
        elif case == 'remove_remote_latch_health_commit' and obs['kind'] == 'remote':
            obs['events'] = [event for event in obs['events'] if event['kind'] != 'latch_health_commit']
    return bad

if __name__ == '__main__':
    data = json.loads(SOURCE.read_text())
    cases = ['remove_all_jump_accepts', 'remove_all_landing_accepts', 'remove_all_drop_through', 'erase_callback_event_timing', 'remove_remote_latch_health_commit']
    results = [{'case': case, 'accepted': gate.valid(mutate(data, case)), 'expected': False} for case in cases]
    output = {'source': str(SOURCE), 'sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(), 'original_valid': gate.valid(data), 'results': results}
    print(json.dumps(output, indent=2))
    pathlib.Path('build/plains_redesign/review_experience_completion/reproduced_validator_gaps.json').write_text(json.dumps(output, indent=2) + '\n')
    sys.exit(1 if any(result['accepted'] for result in results) else 0)
