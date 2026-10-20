#!/usr/bin/env python3
"""Legacy R2 one-floor Home fixture: strict receipt/source/teardown checks.

Current production uses run_underworld_home_terrace_tests.py (155 assertions,
real three-tier input route and original App business). This v1 fixture and its
exact matching source are retained under tests/fixtures/underworld_home_r2/.
Run this historical entry only in the matching frozen 0fab13f checkout.
"""
from pathlib import Path
import argparse
import contextlib
import hashlib
import json
import re
import shutil
import subprocess
import sys
import time
from run_tests import run_engine

ROOT = Path(__file__).resolve().parents[1]
TIMEOUT = 100
COMPLETION = re.compile(r"^UNDERWORLD HOME: ([1-9]\d*) assertions, 0 failures$")

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def verify_evidence(output, receipt, before, after, expected_checks, exit_code):
    """Validate actual consumer evidence; also used by bounded wrapper negatives."""
    if exit_code != 0:
        raise RuntimeError(f"Home engine returned {exit_code}")
    if re.search(r"SCRIPT ERROR:|Parse Error:|SHADER ERROR:|ERROR:|ObjectDB.*leaked|resources? still in use at exit", output):
        raise RuntimeError("Home log contains a script/shader/runtime error or leaked owner")
    markers = [match for line in output.splitlines() if (match := COMPLETION.fullmatch(line))]
    if len(markers) != 1:
        raise RuntimeError("Home must emit exactly one complete positive/zero-failure marker")
    checks = int(markers[0].group(1))
    if checks != expected_checks:
        raise RuntimeError(f"Expected original {expected_checks} Home assertions, got {checks}")
    if receipt.get('schema') != 'underworld-home-actual-consumer-v1':
        raise RuntimeError("Missing actual Home consumer receipt schema")
    if type(receipt.get('checks')) is not int or receipt['checks'] != checks or receipt.get('failures') != 0:
        raise RuntimeError("Receipt counters disagree with exact successful completion")
    changed = sorted(path for path in set(before) | set(after) if before.get(path) != after.get(path))
    if changed:
        raise RuntimeError("Home source changed during execution: " + ', '.join(changed))
    return checks

def read_fresh_receipt(path, fresh_since_ns):
    if not path.exists() or path.stat().st_mtime_ns < fresh_since_ns:
        raise RuntimeError('Current run did not write a fresh Home receipt')
    return json.loads(path.read_text())

class Tee:
    def __init__(self, stream, logfile):
        self.stream, self.logfile = stream, logfile
    def write(self, text):
        self.logfile.write(text)
        return self.stream.write(text)
    def flush(self):
        self.logfile.flush()
        self.stream.flush()

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--capture', action='store_true')
    args = parser.parse_args()
    out = ROOT / 'build/underworld_home'
    out.mkdir(parents=True, exist_ok=True)
    run_id = str(time.time_ns())
    run_dir = out / 'runs' / run_id
    run_dir.mkdir(parents=True)
    # The fixture writes one fixed owned path. Remove that prior result from
    # its consumer slot before starting; preserve its exact bytes in history.
    receipt_path = out / 'receipt.json'
    if receipt_path.exists():
        receipt_path.replace(run_dir / 'previous_receipt_not_current.json')
    mode = 'component_gpu' if args.capture else 'component_headless'
    for previous in (out / (mode + '.log'), out / (mode + '_binding.json')):
        if previous.exists():
            shutil.copy2(previous, run_dir / ('previous_' + previous.name))
    record = json.loads((ROOT / 'assets/underworld_plains/home/generation_record.json').read_text())
    if not record['prompt'] or record['tool'] != 'image_gen.imagegen':
        raise RuntimeError('Missing real generation prompt/tool')
    if (ROOT / record['source']).read_bytes() != (ROOT / record['image']).read_bytes():
        raise RuntimeError('Home original and consumed PNG differ')
    if digest(ROOT / record['source']) != record['source_sha256'] or digest(ROOT / record['reference']) != record['reference_sha256']:
        raise RuntimeError('Home source/reference provenance hash mismatch')
    spec = json.loads((ROOT / 'assets/underworld_plains/home/home_build.json').read_text())
    if len(spec['slots']) != 12 or sum(x['active'] for x in spec['slots']) != 4:
        raise RuntimeError('Expected four original and eight reserved sockets')
    if {x['id'] for x in spec['slots'] if x['active']} != {'character', 'upgrade', 'achievements', 'departure'}:
        raise RuntimeError('Home cannot invent new active function IDs')
    tracked = ['scripts/demo/home_scene.gd', 'scripts/underworld_plains/underworld_home_world.gd', 'assets/underworld_plains/home/home_build.json', 'assets/underworld_plains/home/generation_record.json', 'assets/underworld_plains/home/home_props.png', 'scripts/underworld_plains/underworld_player.gd', 'scripts/underworld_plains/underworld_actors.gd', 'scripts/ui/underworld_ui.gd', 'tests/underworld_plains/test_underworld_home.gd', 'tools/run_underworld_home_tests.py']
    before = {path: digest(ROOT / path) for path in tracked}
    arguments = ['--path', '.', '--audio-driver', 'Dummy']
    arguments += ['--rendering-method', 'gl_compatibility'] if args.capture else ['--headless']
    arguments += ['--script', 'tests/underworld_plains/test_underworld_home.gd']
    if args.capture:
        arguments += ['--', '--capture']
    mode = 'component_gpu' if args.capture else 'component_headless'
    log = run_dir / (mode + '.log')
    binding = {'schema': 'underworld-home-component-check-v2', 'head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(), 'scope': 'actual shared-worktree component; source drift rejects, not final whole-product acceptance', 'capture': args.capture, 'command': ['bash', str(ROOT/'tools/godot.sh'), *arguments], 'timeout_seconds': TIMEOUT, 'component_hashes_before': before, 'log': str(log.relative_to(ROOT)), 'status': 'running'}
    started = time.monotonic()
    fresh_since_ns = time.time_ns()
    error = None
    try:
        with log.open('w') as logfile, contextlib.redirect_stdout(Tee(sys.stdout, logfile)):
            output = run_engine(arguments, TIMEOUT)
        binding['exit_code'] = 0  # run_engine only returns after a real exit0.
        receipt = read_fresh_receipt(receipt_path, fresh_since_ns)
        saved_receipt = run_dir / 'receipt.json'
        shutil.copy2(receipt_path, saved_receipt)
        after = {path: digest(ROOT / path) for path in tracked}
        binding['component_hashes_after'] = after
        binding['changed_during_execution'] = [path for path in tracked if before[path] != after[path]]
        binding['receipt'] = str(saved_receipt.relative_to(ROOT))
        binding['receipt_sha256'] = digest(saved_receipt)
        binding['checks'] = verify_evidence(output, receipt, before, after, 101 if args.capture else 97, 0)
        binding['failures'] = 0
        binding['status'] = 'passed'
    except Exception as caught:
        error = caught
        binding['status'] = 'failed'
        binding['error'] = f'{type(caught).__name__}: {caught}'
        exit_match = re.fullmatch(r'Godot returned (-?\d+)', str(caught))
        binding.setdefault('exit_code', int(exit_match.group(1)) if exit_match else None)
        binding['timeout'] = isinstance(caught, subprocess.TimeoutExpired)
        after = {path: digest(ROOT/path) if (ROOT/path).exists() else None for path in tracked}
        binding['component_hashes_after'] = after
        binding['changed_during_execution'] = [path for path in tracked if before[path] != after[path]]
    finally:
        binding['elapsed_seconds'] = time.monotonic() - started
        if log.exists():
            binding['log_sha256'] = digest(log)
            shutil.copy2(log, out / (mode + '.log'))
        destination = run_dir / 'source_binding.json'
        destination.write_text(json.dumps(binding, ensure_ascii=False, indent=2) + '\n')
        shutil.copy2(destination, out / (mode + '_binding.json'))
    if error:
        raise error
    print(f"UNDERWORLD HOME CHECK: {binding['checks']} assertions,0 failures; actual consumer and source lineage checked")

if __name__ == '__main__':
    main()
