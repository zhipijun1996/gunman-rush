"""Repeatable template drills. No Codex Skill invocation or independent AI review."""
import json
import sys
from quality import ROOT, read_json

RULES = {
    'enemy': {'distinct_player_decision': 'E01: lacks unique combat value', 'readable_telegraph': 'E02: lacks warning/counterplay', 'continuous_animation_feedback': 'E04: static image is not animation/impact feedback', 'formal_encounter_matrix': 'E02: no formal encounter design'},
    'boss': {'phase_decision_change': 'B01: phases only change HP/speed', 'unique_core_mechanic': 'B01: no memorable core mechanic', 'recoil_interaction': 'B02: no recoil interaction', 'aligned_attack_timeline': 'B02: missing visual/attack timing'},
    'region': {'action_variety': 'R03: geometry/hash is not gameplay diversity', 'real_motor_runs': 'R01: no actual input proof', 'exploration_rhythm': 'R04: no learning/recovery rhythm', 'risk_reward_routes': 'R02: no risk/reward route design', 'whole_route_playtest': 'R02: isolated module is not whole exploration'},
}


def review(sample):
    findings = [message for field, message in RULES[sample['type']].items() if sample['observations'].get(field) is not True]
    return {'case': sample['id'], 'verdict': 'REJECT' if findings else 'UNVERIFIED', 'findings': findings,
            'mode': 'template_drill', 'actual_skill_invocation': False, 'independent_review': False,
            'limit': 'Human-authored observations exercise explicit rubric; cannot establish semantic reviewer ability or content PASS.'}


def main():
    count = 0
    for path in sorted((ROOT / 'docs/quality/drills').glob('*.json')):
        sample = read_json(path)
        result = review(sample)
        print(json.dumps(result, ensure_ascii=False))
        if result['verdict'] != sample['expected_verdict'] or len(result['findings']) != sample['expected_findings']:
            return 1
        count += 1
    if count != 3:
        print('Expected exactly three baseline drills', file=sys.stderr)
        return 1
    print('PASS: 3 template drills rejected low-quality samples; actual Skill invocation UNVERIFIED.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
