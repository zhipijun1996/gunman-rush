"""Replay frozen preregistered native startup consumers; no route/art admission."""
from contextlib import redirect_stdout
import fcntl
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from run_tests import run_engine
from run_root_bell_ecology import godot_lock_path
import visual_director as visual

folder = ROOT / 'build/plains_joint/consumer_startups_01'
folder.mkdir(parents=True, exist_ok=False)
checkpoint = json.loads((ROOT / 'docs/evidence/plains_joint/checkpoint.json').read_text())
expected = json.loads((ROOT / 'build/plains_joint/full_02/visual_capture.json').read_text())
started = time.monotonic()
report = {'scope': 'Actual headless single startup snapshot per preregistered Seed; not route, visible art, audio listening or device acceptance', 'status': 'running', 'source_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(), 'seeds': checkpoint['structural_seeds'], 'runs': []}
try:
    before = visual.sources(visual.PLACES_CAPTURE)
    assert before == expected['source_before'] == expected['source_after'], 'Frozen runtime differs from primary native capture'
    report['source_before'] = before
    with godot_lock_path(ROOT).open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        for seed in report['seeds']:
            item = {'seed': seed, 'status': 'running', 'snapshot_count': 1}
            report['runs'].append(item)
            run_started = time.monotonic()
            argv = ['--headless', '--path', '.', '--script', 'tools/plains_places_preview.gd', '--', '--seed=' + seed, '--smoke-close']
            item['argv'] = ['bash', 'tools/godot.sh', *argv]
            try:
                log = folder / (seed + '.log')
                with log.open('w') as native_log, redirect_stdout(native_log):
                    output = run_engine(argv, 90)
                item['log'] = str(log.relative_to(ROOT))
                item['log_sha256'] = hashlib.sha256(log.read_bytes()).hexdigest()
                rows = re.findall(r'^PLAINS PLACES REVIEW READY: (.*)$', output, re.M)
                assert len(rows) == 1, 'Missing/duplicated actual startup snapshot'
                snapshot = json.loads(rows[0])
                item['actual'] = snapshot
                assert not re.search(r'(^|\n)ERROR:', output), 'Actual native ERROR'
                # This is ONE startup observation. The shared full-capture predicate
                # expects two fields, so both refer to the same single observation.
                # No second observation, movement or final-state claim is inferred.
                errors = visual._validate_place_art_consumers({'environment_initial_physics': snapshot, 'environment_final_physics': snapshot}, snapshot['environment_plan'])
                item['consumer_errors'] = errors
                assert not errors, '; '.join(errors)
                assert snapshot['environment_plan']['seed'] == seed and snapshot['production_pool'] is False
                assert visual.sources(visual.PLACES_CAPTURE) == before, 'Source drift during native startup'
                item['status'] = 'passed'
            except BaseException as error:
                item['status'] = 'failed'
                item['error'] = type(error).__name__ + ': ' + str(error)
                raise
            finally:
                if 'log' in locals() and log.is_file():
                    item['log'] = str(log.relative_to(ROOT))
                    item['log_sha256'] = hashlib.sha256(log.read_bytes()).hexdigest()
                item['elapsed_seconds'] = time.monotonic() - run_started
                (folder / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    report['source_after'] = visual.sources(visual.PLACES_CAPTURE)
    assert report['source_after'] == before
    report['status'] = 'passed'
except BaseException as error:
    report['status'] = 'failed'
    report['error'] = type(error).__name__ + ': ' + str(error)
finally:
    report['elapsed_seconds'] = time.monotonic() - started
    (folder / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
print('JOINT ACTUAL STARTUP CONSUMERS:', report['status'], len(report['runs']), report['elapsed_seconds'])
raise SystemExit(0 if report['status'] == 'passed' else 1)
