"""Hand-authored executor inputs for unit tests; never a production route generator."""
from region_creative_direction import bind_region_bible, load_bible_registry


def selected_mission(region='thorn_forest', skills=None):
    _, binding = bind_region_bible(region)
    return {'schema_version': 1, 'content_domain': 'fixed_world',
            'objective': 'SIMULATED scoped region review', 'max_calls': 2, 'max_rounds': 1,
            'call_timeout_seconds': 10, 'tasks': [
                {'id': 'BIBLE', 'goal': 'Inspect current canonical requirements',
                 'region_id': region, 'region_bible': binding,
                 'skills': skills or ['gameplay-reviewer'], 'checks': ['docs'], 'read_only': True}]}


def proposed_mission(region='firefly_marsh'):
    style = load_bible_registry()['shared_style_authority']
    return {'schema_version': 1, 'content_domain': 'fixed_world',
            'objective': 'SIMULATED document proposal', 'max_calls': 2, 'max_rounds': 1,
            'call_timeout_seconds': 10, 'tasks': [
                {'id': 'PROPOSED', 'goal': 'Propose a region document', 'region_id': region,
                 'skills': ['region-creative-director'], 'checks': ['docs'], 'preproduction_only': True,
                 'allowed_paths': ['docs/bible/regions/' + region + '.md'], 'completion': 'stage',
                 'required_gates': ['G0'], 'quality_record': 'build/test-fixtures/PROPOSED.json',
                 'shared_style_authority': style}]}
