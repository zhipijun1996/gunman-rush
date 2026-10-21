"""Additional v15 versions and actual historical App rebuilds, not original327."""
import argparse
import contextlib
import copy
import json
from pathlib import Path
import re
import subprocess
import time

from forest_bible_world_sources import inventory
from run_tests import run_engine

ROOT = Path(__file__).resolve().parents[1]
BIBLE = 'forest-bible-world-v15'
OLD_LAYOUTS = ('forest-interwoven-canopy-v13', 'forest-fruit-routes-v14')
SCOPE = 'Additional Bible compatibility; original327/schema6/24 remain separate; no route or release admission'


def validate(data):
    expected = re.search(r'^const EXPECTED_PUBLIC_LAYOUT := "([^"]+)"$',
                        (ROOT / 'tests/forest_depth_version_runner.gd').read_text(), re.M).group(1)
    if expected not in (*OLD_LAYOUTS, BIBLE):
        raise ValueError('Known independently selected public layout required')
    checks = data.get('checks', [])
    if (data.get('schema_version') != 1 or data.get('scope') != SCOPE
            or type(data.get('assertions')) is not int or data['assertions'] != 56
            or type(data.get('failures')) is not int or data['failures'] != 0
            or len(checks) != 56 or any(type(r.get('passed')) is not bool or not r['passed'] for r in checks)):
        raise ValueError('Complete additional56 native ledger required')
    cases = data.get('cases', [])
    identities = [(r.get('id'), r.get('map'), r.get('layout')) for r in cases]
    required = [(kind, index, layout) for index in (1, 2) for kind, layout in
                [('candidate_data', None), ('public_app', None), *[('recorded_app', v) for v in OLD_LAYOUTS]]]
    if identities != required or any(type(r.get('map')) is not int for r in cases):
        raise ValueError('Exact two candidate/two public/four historical App cases required')
    for row in cases:
        index = row['map']
        if row['id'] == 'candidate_data':
            m = row.get('manifest', {})
            negatives = row.get('negative_cases', [])
            if (m.get('layout_version') != BIBLE or m.get('map_index') != index
                    or m.get('seed') != f'bible-version-map-{index}'
                    or m.get('version') != 'thorn-forest-region-v2' or m.get('requires') != ['grapple']
                    or m.get('production_pool') is not False or row.get('dedicated_complete_equal') is not True
                    or m.get('bible_world_contract', {}).get('native_verified') is not False
                    or [r.get('kind') for r in negatives] != ['fruit', 'discovery', 'shortcut', 'drop', 'admission']
                    or any(r.get('rejected') is not True for r in negatives)):
                raise ValueError('Strict v15 candidate and explicit pending admission required')
        elif row['id'] == 'public_app':
            m = row.get('manifest', {})
            if (row.get('layout_argument') != '' or row.get('expected_layout') != expected
                    or m.get('layout_version') != expected or m.get('map_index') != index
                    or m.get('seed') != f'bible-version-public/thorn_forest/map_{index}'
                    or row.get('complete_manifest_equal') is not True):
                raise ValueError('Actual unpinned full independently expected public output required')
        else:
            original, restored = row.get('original_manifest', {}), row.get('restored_manifest', {})
            before, after = row.get('before', {}), row.get('after', {})
            if (original != restored or original.get('layout_version') != row['layout']
                    or original.get('map_index') != index or not original.get('manifest_hash')
                    or row.get('forced_request') != BIBLE or row.get('recorded_layout_after') != row['layout']
                    or row.get('same_state') is not True or not before or before != after
                    or before.get('claimed', {}).get('version_only_claim_fixture') is not True
                    or before.get('opened', {}).get('version_only_open_fixture') is not True
                    or before.get('mechanisms', {}).get('version_only_mechanism_fixture') != {'open': True}
                    or not before.get('actors') or row.get('old_actor_id') == row.get('new_actor_id')
                    or type(row.get('saved_health')) not in (int, float) or row['saved_health'] <= 0
                    or row.get('restored_health') != row['saved_health']):
                raise ValueError('Actual exact old hash/ledgers/nondefault actor reconstruction required')


def negative_controls(actual):
    """Synthetic mutations of actual reports; never native gameplay evidence."""
    mutations = {
        'missing_case': lambda d: d['cases'].pop(),
        'false_check': lambda d: d['checks'][0].update(passed=False),
        'relabel_as_original327': lambda d: d.update(scope='original327', assertions=327),
        'candidate_claims_admitted': lambda d: d['cases'][0]['manifest'].update(production_pool=True),
        'unverified_claims_native': lambda d: d['cases'][0]['manifest']['bible_world_contract'].update(native_verified=True),
        'public_covert_pin': lambda d: d['cases'][1].update(layout_argument=BIBLE),
        'public_not_full_equal': lambda d: d['cases'][1].update(complete_manifest_equal=False),
        'old_layout_relabelled': lambda d: d['cases'][2]['restored_manifest'].update(layout_version=BIBLE),
        'old_claims_lost': lambda d: d['cases'][2]['after']['claimed'].clear(),
        'old_actor_reset': lambda d: d['cases'][2].update(restored_health=999),
    }
    rejected = []
    for name, mutate in mutations.items():
        edited = copy.deepcopy(actual)
        mutate(edited)
        try:
            validate(edited)
        except (ValueError, KeyError, TypeError):
            rejected.append(name)
        else:
            raise RuntimeError('Reader negative control escaped: ' + name)
    return rejected


def validate_json_replay(data):
    labels = []
    for seed in ('campaign-integration', 'forest-depth-hollow-00'):
        for index in (1, 2):
            prefix = f'{seed}/map{index} '
            labels.extend(prefix + suffix for suffix in (
                'exact actual producer', 'faithful JSON accepts integral numeric fields',
                'validation leaves parsed data unchanged',
                *[f'rehashed {kind} rejects' for kind in (
                    'fractional_index', 'bool_index', 'fractional_geometry',
                    'missing_face', 'extra_surface_field', 'foreign_face')]))
    checks = data.get('checks', [])
    if (data.get('scope') != 'actual producers and JSON parser, no movement or visual proof'
            or type(data.get('failures')) is not int or data['failures'] != 0
            or len(checks) != 36 or [r.get('check') for r in checks] != labels
            or any(r.get('passed') is not True for r in checks)):
        raise ValueError('Complete separate36 actual JSON replay ledger required')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', required=True, type=Path)
    args = parser.parse_args()
    output = args.output_dir.resolve()
    if not output.is_relative_to(ROOT / 'build') or output.exists():
        parser.error('Fresh output below repository build required')
    output.mkdir(parents=True)
    receipt = {'scope': SCOPE, 'source_before': inventory(), 'import_cap_seconds': 90,
               'native_cap_seconds': 90, 'passed': False}
    started = time.monotonic()
    try:
        with (output / 'import.log').open('w') as stream, contextlib.redirect_stdout(stream):
            run_engine(['--headless', '--path', '.', '--editor', '--quit'], 90)
        native_deadline = time.monotonic() + 90
        with (output / 'native.log').open('w') as stream, contextlib.redirect_stdout(stream):
            text = run_engine(['--headless', '--fixed-fps', '60', '--path', '.', '--script',
                               'tests/forest_bible_versions_runner.gd', '--',
                               '--output=res://' + (output / 'capture.json').relative_to(ROOT).as_posix()],
                              max(0, native_deadline - time.monotonic()))
        if not re.search(r'^FOREST BIBLE VERSIONS: 56 assertions, 0 failures$', text, re.M):
            raise RuntimeError('Missing complete additional56 native completion')
        data = json.loads((output / 'capture.json').read_text())
        validate(data)
        receipt['synthetic_reader_negatives_rejected'] = negative_controls(data)
        with (output / 'json-replay-native.log').open('w') as stream, contextlib.redirect_stdout(stream):
            text = run_engine(['--headless', '--fixed-fps', '60', '--path', '.', '--script',
                               'tests/forest_bible_json_replay_runner.gd', '--',
                               '--output=res://' + (output / 'json-replay.json').relative_to(ROOT).as_posix()],
                              max(0, native_deadline - time.monotonic()))
        if not re.search(r'^FOREST BIBLE JSON REPLAY: 36 assertions / 0 failures$', text, re.M):
            raise RuntimeError('Missing complete separate36 JSON replay completion')
        validate_json_replay(json.loads((output / 'json-replay.json').read_text()))
        receipt['json_replay'] = {'assertions': 36, 'failures': 0, 'strict_reader_passed': True,
                                  'shared_native_cap_seconds': 90}
        receipt['passed'] = True
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        receipt['error'] = str(error)
    finally:
        receipt['source_after'] = inventory()
        receipt['source_stable'] = receipt['source_before'] == receipt['source_after']
        receipt['passed'] = receipt['passed'] and receipt['source_stable']
        receipt['elapsed_seconds'] = time.monotonic() - started
        (output / 'receipt.json').write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + '\n')
    if not receipt['passed']:
        raise RuntimeError(receipt.get('error', 'Source changed during additional compatibility check'))
    print('FOREST BIBLE VERSIONS: 56 assertions, 0 failures; original327 remains separate')
    print('FOREST BIBLE JSON REPLAY: 36 assertions / 0 failures; shared native90 budget')


if __name__ == '__main__':
    main()
