"""Run actual candidate place compilation; does not certify art or Motor traversal."""
import fcntl
import hashlib
import json
import math
import re
import subprocess
import time
from pathlib import Path

from level_formal import source_files
from run_root_bell_ecology import godot_lock_path
from run_tests import run_engine

ROOT = Path(__file__).resolve().parents[1]


def numeric_shape(row):
    """Identity renames cannot count as a different physical arrangement."""
    def number(value):
        if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
            raise ValueError('Non-finite/non-numeric structural coordinate')
        return float(value)
    translations = [[number(v) for v in item['translation']] for item in row['place_instances']]
    connections = [{'path': [[number(v) for v in point] for point in edge['path']],
                    'gap': number(edge['gap_world']), 'rise': number(edge['rise_world'])}
                   for edge in row['connections']]
    return json.dumps({'translations': translations, 'connections': connections}, sort_keys=True)


def numeric_local_shape(row):
    """Compare actual within-place polygons; disregard world placement and labels."""
    def number(value):
        if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
            raise ValueError('Non-finite/non-numeric local terrain coordinate')
        return round(float(value), 5)
    places = []
    for polygons in row['local_terrain']:
        normalized = []
        for polygon in polygons:
            points = [tuple(number(value) for value in point) for point in polygon]
            if len(points) < 3 or any(len(point) != 2 for point in points):
                raise ValueError('Local terrain requires actual polygon coordinates')
            # Start vertex and traversal direction are irrelevant to occupied shape.
            cycles = [points[i:] + points[:i] for i in range(len(points))]
            reverse = list(reversed(points))
            cycles += [reverse[i:] + reverse[:i] for i in range(len(reverse))]
            normalized.append(min(cycles))
        if not normalized:
            raise ValueError('Missing actual local terrain polygons')
        places.append(sorted(normalized))
    if not places:
        raise ValueError('Missing actual local terrain corpus')
    return json.dumps(sorted(places), sort_keys=True)


def main():
    folder = ROOT / 'build/plains_places/contract' / time.strftime('%Y%m%dT%H%M%SZ', time.gmtime())
    folder.mkdir(parents=True, exist_ok=False)
    report = {'status': 'failed', 'scope': 'Actual bounded place compilation/replay/refusals; not art, live traversal, release or device admission', 'runs': []}
    started = time.monotonic()
    try:
        lock_path = godot_lock_path(ROOT)
        lock_path.parent.mkdir(parents=True, exist_ok=True)
        with lock_path.open('a') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            report['engine_lock_wait_seconds'] = time.monotonic() - started
            args = ['--headless', '--path', '.', '--editor', '--quit']
            output = run_engine(args, 120)
            (folder / 'import.log').write_text(output)
            if re.search(r'(^|\n)ERROR:', output):
                raise RuntimeError('Native import emitted an error')
            before = source_files()
            args = ['--headless', '--path', '.', '--script', 'tests/plains_places_plan_runner.gd', '--', '--output=' + str(folder / 'actual.json')]
            output = run_engine(args, 120)
            (folder / 'contract.log').write_text(output)
            report['runs'].append({'argv': ['bash', 'tools/godot.sh', *args], 'exit_code': 0, 'log': str((folder / 'contract.log').relative_to(ROOT)), 'log_sha256': hashlib.sha256(output.encode()).hexdigest()})
            if not re.search(r'^PLAINS PLACES CONTRACT: [1-9]\d* assertions, 0 failures$', output, re.M) or re.search(r'(^|\n)ERROR:', output):
                raise RuntimeError('Missing complete contract success or native error')
            actual = json.loads((folder / 'actual.json').read_text())
            shapes = [numeric_shape(row) for row in actual['actual']]
            report['numeric_structure'] = {'distinct': len(set(shapes)), 'sample_count': len(shapes),
                                          'projection': 'finite numeric world translations, actual connection paths, gap and rise; no names, hashes, phases or decoration',
                                          'claim': 'Physical arrangement differences only, not art or gameplay variety'}
            if len(shapes) != len(actual['preregistered_seeds']) or len(set(shapes)) < 2:
                raise RuntimeError('Actual corpus did not prove numeric structural variation')
            local_shapes = [numeric_local_shape(row) for row in actual['actual']]
            report['numeric_local_structure'] = {'distinct': len(set(local_shapes)), 'sample_count': len(local_shapes),
                                                 'projection': 'actual collision polygons minus place translation, normalized vertex order; excludes IDs, phase and place ordering',
                                                 'claim': 'Within-place physical shape differences only; not art acceptance'}
            if len(set(local_shapes)) < 2:
                raise RuntimeError('Actual corpus only rearranged fixed local terrain')
            report['source_before'] = before
            report['source_after'] = source_files()
            if report['source_after'] != before:
                raise RuntimeError('Source changed during frozen contract check')
            report['status'] = 'passed'
    except (OSError, RuntimeError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
        report['error'] = type(error).__name__ + ': ' + str(error)
    report['elapsed_seconds'] = time.monotonic() - started
    (folder / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print('PLAINS PLACES SUITE: ' + report['status'] + ' ' + str(folder.relative_to(ROOT)))
    return 0 if report['status'] == 'passed' else 1


if __name__ == '__main__':
    raise SystemExit(main())
