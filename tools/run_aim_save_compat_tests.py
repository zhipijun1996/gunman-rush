"""Verify immutable replay and real saved-map reload in isolated compiler domains.

The decoded historical prefix was never passed to the independent actual App.
Each consumer retains strict native teardown; both share the original 120 seconds.
"""
import argparse
import contextlib
import hashlib
import json
from pathlib import Path
import re
import time
import uuid

from run_tests import REPO, run_engine

SOURCES = ('tests/aim_save_compat_data.gd', 'tests/aim_save_compat_runner.gd',
           'tests/aim_save_compat_case.gd', 'tools/run_aim_save_compat_tests.py')
COUNTS = {'data': 56, 'world': 120}
SCRIPTS = {'data': SOURCES[0], 'world': SOURCES[1]}
SUMMARY = {'data': 'AIM SAVE DATA', 'world': 'AIM SAVE COMPAT'}


class Tee:
    def __init__(self, target, raw):
        self.target, self.raw = target, raw

    def write(self, value):
        self.raw.write(value)
        return self.target.write(value)

    def flush(self):
        self.raw.flush()
        self.target.flush()


def source_identity():
    return {name: hashlib.sha256((REPO / name).read_bytes()).hexdigest() for name in SOURCES}


def case_ids(phase, cases):
    if not isinstance(cases, list) or len(cases) != 4:
        raise RuntimeError(f'{phase}: incomplete case report')
    if phase == 'world':
        identities = [(row.get('region'), row.get('map')) for row in cases]
        if identities != [('plains', 1), ('plains', 2), ('thorn_forest', 1), ('thorn_forest', 2)]:
            raise RuntimeError('world: unexpected case identities or ordering')
        return [f'world/{region}/map{index}' for region, index in identities]
    expected = [('original_archived_plains_prefix', None),
                ('actual_old_source_plains_prefix', 'legacy_v10'),
                ('actual_old_source_plains_prefix', 'v2'),
                ('actual_old_source_plains_prefix', 'v3')]
    if [(row.get('kind'), row.get('mode')) for row in cases] != expected:
        raise RuntimeError('data: unexpected historical case identities or ordering')
    return ['data/original_archive', 'data/main_dbc6ba08/legacy_v10',
            'data/main_dbc6ba08/v2', 'data/main_dbc6ba08/v3']


def validate_phase(phase, report, raw, run_id, sources):
    starts = re.findall(r'^AIM SAVE PHASE: (.+)$', raw, re.M)
    if len(starts) != 1:
        raise RuntimeError(f'{phase}: missing or ambiguous native identity')
    identity = json.loads(starts[0])
    expected = {'phase': phase, 'run_id': run_id, 'script': 'res://' + SCRIPTS[phase],
                'script_sha256': sources[SCRIPTS[phase]]}
    if (not isinstance(identity, dict) or any(identity.get(k) != v for k, v in expected.items())
            or type(identity.get('engine_pid')) is not int or identity['engine_pid'] <= 0
            or report.get('identity') != identity):
        raise RuntimeError(f'{phase}: stale or foreign native report identity')
    checks = report.get('checks')
    if (type(report.get('failures')) is not int or report['failures'] != 0
            or not isinstance(checks, list) or len(checks) != COUNTS[phase]
            or any(not isinstance(row, dict) or type(row.get('passed')) is not bool
                   or not row['passed'] or not isinstance(row.get('label'), str)
                   or not row['label'] for row in checks)):
        raise RuntimeError(f'{phase}: incomplete or failed business checks')
    if not re.search(r'^' + SUMMARY[phase] + ': ' + str(COUNTS[phase]) + r' assertions / 0 failures$', raw, re.M):
        raise RuntimeError(f'{phase}: missing complete native summary')
    ids = case_ids(phase, report.get('cases'))
    return identity, ids


def aggregate(reports, receipts, run_id, sources):
    if list(reports) != ['data', 'world'] or list(receipts) != ['data', 'world']:
        raise RuntimeError('Missing or reordered consumer phase')
    checks, cases = [], []
    for phase in ('data', 'world'):
        receipt = receipts[phase]
        if receipt.get('status') != 'passed' or receipt.get('exit_code') != 0:
            raise RuntimeError(f'{phase}: native phase did not succeed')
        raw = (REPO / receipt['rawlog']).read_text()
        if hashlib.sha256(raw.encode()).hexdigest() != receipt['rawlog_sha256']:
            raise RuntimeError(f'{phase}: native raw log changed')
        _, ids = validate_phase(phase, reports[phase], raw, run_id, sources)
        checks.extend(dict(row, check_id=f'{phase}/{index:03d}')
                      for index, row in enumerate(reports[phase]['checks']))
        cases.extend(dict(row, case_id=case_id) for row, case_id in zip(reports[phase]['cases'], ids))
    if len(checks) != 176 or len(cases) != 8 or len({row['case_id'] for row in cases}) != 8:
        raise RuntimeError('Incomplete historical data and actual-world aggregate')
    return {'checks': checks, 'cases': cases, 'failures': 0, 'run_id': run_id,
            'phases': receipts, 'source_sha256': sources,
            'owner_observations': reports['world']['owner_observations'],
            'scope': 'Two independent native consumers: immutable prefix replay followed by actual map-state reload. No historical full-run resume API exists.'}


def run_phase(phase, directory, run_id, deadline, sources, failure_probe):
    remaining = deadline - time.monotonic()
    if remaining <= 0:
        raise RuntimeError('Original shared 120-second native budget exhausted')
    report_path, raw_path = directory / f'{phase}.json', directory / f'{phase}.log'
    # Unique run directory plus fresh paths prevent any previous output being reused.
    report_path.unlink(missing_ok=True)
    arguments = ['--headless', '--path', '.', '--script', SCRIPTS[phase], '--',
                 '--output=res://' + str(report_path.relative_to(REPO)), '--run-id=' + run_id]
    if failure_probe and phase == 'world':
        arguments.append('--failure-probe')
    started = time.monotonic()
    receipt = {'phase': phase, 'argv': ['bash', str(REPO / 'tools/godot.sh'), *arguments],
               'timeout_seconds': remaining, 'source_sha256': sources, 'status': 'failed',
               'exit_code': None, 'rawlog': str(raw_path.relative_to(REPO))}
    try:
        import sys
        with raw_path.open('w') as raw, contextlib.redirect_stdout(Tee(sys.stdout, raw)):
            output = run_engine(arguments, remaining)
        receipt['exit_code'] = 0
        report = json.loads(report_path.read_text())
        identity, _ = validate_phase(phase, report, output, run_id, sources)
        receipt.update({'status': 'passed', 'engine_pid': identity['engine_pid']})
        return report, receipt
    except Exception as error:
        receipt['error'] = str(error)
        match = re.fullmatch(r'Godot returned (-?\d+)', str(error))
        if match:
            receipt['exit_code'] = int(match.group(1))
        raise
    finally:
        receipt['duration_seconds'] = time.monotonic() - started
        if raw_path.exists():
            raw = raw_path.read_text()
            receipt['rawlog_sha256'] = hashlib.sha256(raw.encode()).hexdigest()
            starts = re.findall(r'^AIM SAVE PHASE: (.+)$', raw, re.M)
            if len(starts) == 1:
                receipt['native_identity'] = json.loads(starts[0])
                receipt['engine_pid'] = receipt['native_identity']['engine_pid']
        (directory / f'{phase}-receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--failure-probe', action='store_true')
    args = parser.parse_args()
    output = REPO / 'build/verification/aim_save_compat.json'
    output.parent.mkdir(parents=True, exist_ok=True)
    output.unlink(missing_ok=True)
    sources = source_identity()
    run_engine(['--headless', '--path', '.', '--editor', '--quit'], 90)
    run_id = uuid.uuid4().hex
    directory = output.parent / 'aim_save_compat' / run_id
    directory.mkdir(parents=True)
    native_started = time.monotonic()
    deadline = native_started + 120
    reports, receipts = {}, {}
    for phase in ('data', 'world'):
        reports[phase], receipts[phase] = run_phase(phase, directory, run_id, deadline, sources, args.failure_probe)
    if time.monotonic() > deadline or source_identity() != sources:
        raise RuntimeError('Shared native budget exceeded or fixture source changed')
    result = aggregate(reports, receipts, run_id, sources)
    result['native_duration_seconds'] = time.monotonic() - native_started
    output.write_text(json.dumps(result, indent=2) + '\n')
    print('AIM SAVE AGGREGATE: 176 assertions / 0 failures across 2 native consumers')
    print('PASS: historical aim tuning and actual saved-map compatibility')


if __name__ == '__main__':
    main()
