"""One development-only native route probe; final visible movie remains required."""
import contextlib
import fcntl
import hashlib
import json
import re
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'tools'))
import visual_director as vd
from run_tests import run_engine
from run_root_bell_ecology import godot_lock_path

folder = Path(__file__).resolve().parent
native = folder / 'capture.json'
if native.exists() or (folder / 'development_probe.json').exists():
    raise SystemExit('Refuse to overwrite earlier probe')
base_commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
args = ['--headless', '--fixed-fps', '60', '--path', '.', '--script', vd.PLACES_CAPTURE, '--', '--source-commit=' + base_commit, '--seed=plains-places-first-01', '--map-index=1', '--strategy=fast', '--encounter-policy=blind_legacy', '--phase-wait-ticks=0', '--max-ticks=6000', '--environment-phase=full', '--environment-mutation=', '--output=' + str(native)]
report = {'status': 'failed', 'artifact_kind': 'development_headless_route_probe', 'sourcebound_final': False, 'base_commit': base_commit, 'scope': 'Actual original headless Router/Motor route only. Base HEAD is not a claim that dirty development sources match that commit. Full source snapshots are bound separately. No image/art/visible-postdraw/final frozen capture admission.', 'argv': ['bash', 'tools/godot.sh', *args], 'producer_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(), 'started_unix': time.time()}
try:
    with godot_lock_path(ROOT).open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        with (folder / 'import.log').open('w') as log, contextlib.redirect_stdout(log):
            imported = run_engine(['--headless', '--path', '.', '--editor', '--quit'], 120)
        if re.search(r'^\s*ERROR:', imported, re.M): raise RuntimeError('Import ERROR')
        report['git_status_before'] = subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT, text=True)
        report['source_before'] = vd.sources(vd.PLACES_CAPTURE)
        with (folder / 'capture.log').open('w') as log, contextlib.redirect_stdout(log):
            output = run_engine(args, 120)
        report['source_after'] = vd.sources(vd.PLACES_CAPTURE)
        if report['source_before'] != report['source_after']: raise RuntimeError('Source drift during actual probe')
        if re.search(r'^\s*ERROR:|SCRIPT ERROR:|Parse Error:|ObjectDB.*leaked|resources? still in use at exit', output, re.M): raise RuntimeError('Native error or unclean exit')
        data = json.loads(native.read_text())
        if data.get('capture_errors') != [] or data.get('outcome') != 'route_target_reached' or data.get('route_reached') is not True: raise RuntimeError('Actual route did not complete')
        plan = data['manifest']['environment_plan']
        expected = plan['route_forward'] + plan['route_return']
        cases = data['environment_cases']
        if [row['id'] for row in cases] != expected or not all(row.get('passed') is True and row.get('supported') is True for row in cases): raise RuntimeError('Actual grounded route cases incomplete')
        if not data.get('frames') or any(row['health'] != 5 or row['recovery_count'] != 0 for row in data['frames']): raise RuntimeError('Actual injury or recovery')
        if data.get('post_capture_cleanup', {}).get('audio_backend_released') is not True: raise RuntimeError('Audio not released')
        errors = vd.validate_places_observations(data, plan)
        if errors: raise RuntimeError('; '.join(errors))
        report.update(status='passed', engine_exit_code=0, tick_count=data['tick_count'], completed_cases=len(cases), actual_input_protocol=data['captured_scope']['input_transport_protocol'], native_sha256=hashlib.sha256(native.read_bytes()).hexdigest(), log_sha256=hashlib.sha256((folder/'capture.log').read_bytes()).hexdigest(), health_values=sorted(set(row['health'] for row in data['frames'])), max_recovery_count=max(row['recovery_count'] for row in data['frames']))
except Exception as error:
    report['error'] = type(error).__name__ + ': ' + str(error)
finally:
    report['ended_unix'] = time.time()
    (folder / 'development_probe.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({key: report.get(key) for key in ('status', 'error', 'base_commit', 'tick_count', 'completed_cases', 'actual_input_protocol')}, ensure_ascii=False))
raise SystemExit(0 if report['status'] == 'passed' else 1)
