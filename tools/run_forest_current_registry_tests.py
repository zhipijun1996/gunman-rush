"""Current default registry and real App guard; historical replay stays separate."""
import argparse
import contextlib
import hashlib
import json
import math
from pathlib import Path
import re
import subprocess
import time

import level_formal
from run_tests import run_engine

ROOT = Path(__file__).resolve().parents[1]
SCOPE = 'Current V15 registry, current App refusal and current-state reload; no frozen historical replay'
SOURCES = ('tests/forest_current_registry_runner.gd', 'tools/run_forest_current_registry_tests.py',
           'game/world/generation/thorn_forest_region_generator.gd', 'game/application/demo_app.gd')


def hashes():
    return level_formal.source_files(extra_paths=SOURCES)


def validate(data):
    if not isinstance(data, dict):
        raise ValueError('Current report must be an object')
    checks, rows = data.get('checks', []), data.get('cases', [])
    if (not isinstance(checks, list) or not isinstance(rows, list)
            or any(not isinstance(row, dict) for row in checks + rows)):
        raise ValueError('Typed native check and case arrays required')
    if (type(data.get('schema_version')) is not int or data['schema_version'] != 1 or data.get('scope') != SCOPE
            or type(data.get('assertions')) is not int or data['assertions'] != 88
            or data.get('assertions') != len(checks) or type(data.get('failures')) is not int or data['failures'] != 0
            or not checks or any(r.get('passed') is not True for r in checks)):
        raise ValueError('Complete nonempty current native assertion ledger required')
    positives = [r for r in rows if r.get('id') == 'current_data']
    expected = {(f'version-contract-{i:02d}/thorn_forest/map_{m}', m) for i in range(4) for m in (1, 2)}
    if any(type(row.get('map')) is not int for row in positives) or len(rows) != 11 or len(positives) != 8 or {(r.get('seed'), r.get('map')) for r in positives} != expected:
        raise ValueError('Exact four seeds/two maps plus two App/refusal cases required')
    for row in positives:
        manifest = row.get('manifest', {})
        if (not isinstance(manifest, dict) or row.get('version') != 'thorn-forest-region-v2' or row.get('layout') != 'forest-bible-world-v15'
                or any(row.get(k) is not True for k in ('complete_output_equal', 'strict_validation', 'unsupported_rehashed_rejected'))
                or manifest.get('version') != row['version'] or manifest.get('layout_version') != row['layout']
                or manifest.get('seed') != row['seed'] or type(manifest.get('map_index')) is not int or manifest['map_index'] != row['map']):
            raise ValueError('Actual complete current registry result required')
    refusals = [r for r in rows if r.get('id') == 'registry_refusals']
    if len(refusals) != 1 or len(refusals[0].get('negative_cases', [])) != 7 or any(r.get('refused') is not True for r in refusals[0]['negative_cases']):
        raise ValueError('All seven actual unknown/empty/malformed registry refusals required')
    kinds = [row.get('kind') for row in refusals[0]['negative_cases']]
    expected_prefix = ['version/unknown', 'version/thorn-forest-region-v999', 'version/',
                       'malformed_version', 'layout/forest-future-v999', 'layout/']
    if (any(not isinstance(kind, str) for kind in kinds) or len(set(kinds)) != 7
            or kinds[:6] != expected_prefix or not kinds[6].startswith('layout/{')):
        raise ValueError('Distinct actual version/layout refusal inventory required')
    apps = [r for r in rows if r.get('id') == 'current_app']
    if any(type(row.get('map')) is not int for row in apps) or len(apps) != 2 or {r.get('map') for r in apps} != {1, 2}:
        raise ValueError('Both actual current App maps required')
    for row in apps:
        fields = ('complete_output_equal', 'home_unknown_unchanged', 'home_empty_unchanged', 'active_unchanged',
                  'unknown_snapshot_refused', 'malformed_snapshot_refused', 'reload_same_manifest',
                  'reload_same_state', 'reload_ledgers_health')
        if (row.get('version') != 'thorn-forest-region-v2' or row.get('layout') != 'forest-bible-world-v15'
                or any(row.get(k) is not True for k in fields)
                or type(row.get('saved_health')) not in (int, float) or not math.isfinite(row['saved_health']) or row['saved_health'] <= 0
                or type(row.get('restored_health')) not in (int, float) or not math.isfinite(row['restored_health']) or row['restored_health'] <= 0
                or row['restored_health'] != row['saved_health']):
            raise ValueError('Actual current refusal, snapshots and reload state required')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', type=Path, required=True)
    args = parser.parse_args()
    out = args.output_dir.resolve()
    if not out.is_relative_to(ROOT / 'build/forest_current_registry') or out.exists():
        parser.error('Fresh output below build/forest_current_registry required')
    out.mkdir(parents=True)
    before = hashes()
    receipt = {'scope': SCOPE, 'source_before': before, 'passed': False,
               'import_cap_seconds': 90, 'native_cap_seconds': 90,
               'base_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
               'git_status_before': subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT, text=True)}
    start = time.monotonic()
    try:
        with (out / 'import.log').open('x') as log, contextlib.redirect_stdout(log):
            run_engine(['--headless', '--path', '.', '--editor', '--quit'], 90)
        with (out / 'native.log').open('x') as log, contextlib.redirect_stdout(log):
            text = run_engine(['--headless', '--fixed-fps', '60', '--path', '.', '--script',
                               'tests/forest_current_registry_runner.gd', '--',
                               '--output=res://' + (out / 'capture.json').relative_to(ROOT).as_posix()], 90)
        if not re.search(r'^FOREST CURRENT REGISTRY: 88 assertions, 0 failures$', text, re.M):
            raise RuntimeError('Missing complete actual current native marker')
        data = json.loads((out / 'capture.json').read_text())
        validate(data)
        receipt['assertions'] = data['assertions']
        receipt['passed'] = True
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        receipt['error'] = str(error)
    finally:
        receipt['source_after'] = hashes()
        receipt['source_stable'] = before == receipt['source_after']
        receipt['passed'] = receipt['passed'] and receipt['source_stable']
        receipt['seconds'] = time.monotonic() - start
        (out / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    if not receipt['passed']:
        raise RuntimeError(receipt.get('error', 'Current registry source changed'))
    print(f"PASS: current forest registry and actual App; {receipt['assertions']} assertions, 0 failures")


if __name__ == '__main__':
    main()
