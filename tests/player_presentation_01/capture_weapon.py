"""Task-only real Godot on/off movies; immutable attempts and exact gameplay diff."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import selectors
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
import harness


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, value):
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + '\n')


def capture(folder, samples=998):
    if folder.exists() or not folder.is_relative_to(ROOT / 'build'):
        raise ValueError('Use a NEW build/ attempt directory')
    metadata = harness.git_metadata()
    if metadata['git_status'] or metadata['working_files']:
        raise ValueError('Commit source before capture')
    before = harness.source_inventory()
    folder.mkdir(parents=True)
    report = dict(task='PLAYER-PRESENTATION-01', status='running', source_metadata=metadata,
                  source_before=before, captures=[], errors=[],
                  conditions=dict(seed='player-presentation-01/motion-01', fps=60, resolution=[1280, 720], requested_samples=samples),
                  baseline='Same hero/movement/targets;weapon feedback OFF delegates original shot/contact and original projectile presentation',
                  scope='Actual original Home hero and geometry plus explicit added stationary training targets;real Router walk/fire/context,9 normal weapon modes. Movement candidate unchanged. No actor placement,resource/HP/tuning/grant changes;not formal weapon grants/encounter/user/device acceptance.',
                  comparison_differences=['Only task weapon projectile leaf/accepted contact and thin beam/mine/blast accents/owned weapon sound layers toggle;original Runtime phase sounds remain in both. Same movement/body/camera/targets/physics.'],
                  user_acceptance='unverified', device_acceptance='unverified')
    receipt = folder / 'report.json'
    write(receipt, report)
    env = dict(os.environ, LIBGL_ALWAYS_SOFTWARE='1', LP_NUM_THREADS='2')
    display = None
    try:
        if not env.get('DISPLAY'):
            with (folder / 'display.log').open('wb') as log:
                display = subprocess.Popen([str(ROOT.parent / 'toolchains/xvfb/usr/bin/Xvfb'), '-displayfd', '1', '-screen', '0', '1280x720x24', '-nolisten', 'tcp', '-ac'], stdout=subprocess.PIPE, stderr=log)
            with selectors.DefaultSelector() as selector:
                selector.register(display.stdout, selectors.EVENT_READ)
                if not selector.select(20): raise RuntimeError('Xvfb readiness timeout')
                number = display.stdout.readline().decode().strip()
                if not number.isdigit(): raise RuntimeError('Invalid display')
            env['DISPLAY'] = ':' + number
        for variant, flag in [('before', '--candidate=off'), ('after', '--candidate=on')]:
            avi = folder / (variant + '.avi')
            trace = folder / (variant + '.json')
            movie = folder / (variant + '.mp4')
            command = ['bash', 'tools/godot.sh', '--path', '.', '--audio-driver', 'Dummy', '--rendering-method', 'gl_compatibility', '--disable-vsync', '--fixed-fps', '60', '--write-movie', str(avi), '--script', 'tests/player_presentation_01/weapon_trace.gd', '--', '--capture', flag, '--output=' + str(trace)]
            record = dict(variant=variant, command=command)
            report['captures'].append(record)
            record['execution'] = harness.run_check(dict(argv=command, timeout_seconds=300, success_pattern=r'^WEAPON TRACE: samples=998 checks=3026 errors=0$'), folder / (variant + '.log'), ROOT, env)
            write(receipt, report)
            if record['execution']['status'] != 'passed': raise RuntimeError(variant + ' engine execution failed')
            with (folder / (variant + '-encode.log')).open('w') as log:
                subprocess.run(['ffmpeg', '-n', '-i', str(avi), '-c:v', 'libx264', '-crf', '21', '-pix_fmt', 'yuv420p', '-c:a', 'aac', str(movie)], stdout=log, stderr=subprocess.STDOUT, timeout=120, check=True)
            record.update(mp4_sha256=sha(movie), trace_sha256=sha(trace), original_avi_sha256=sha(avi))
            record['media'] = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-show_streams', '-show_format', '-of', 'json', str(movie)], timeout=30))
            write(receipt, report)
        a, b = [json.loads((folder / (v + '.json')).read_text()) for v in ('before', 'after')]
        fields = ['sample','tick','position','velocity','normal','recoil','motion_steps','hp','stamina','combat','charges','used_jumps','muzzle','aim','camera','camera_offset','body','weapon','epoch','packet','rounds','cooldown','phase','runtime_age','beam','projectiles','entities','targets']
        differences = [{'sample':i, 'fields':[key for key in fields if left[key] != right[key]]} for i, (left, right) in enumerate(zip(a['rows'], b['rows'])) if any(left[key] != right[key] for key in fields)]
        events = [trace['events'] for trace in (a,b)]
        report['gameplay_comparison'] = dict(fields=fields, differences=differences, samples=[len(a['rows']),len(b['rows'])], accepted_events_equal=events[0] == events[1], event_comparison_exclusion='none; every accepted event field must match')
        if differences or len(a['rows']) != samples or len(b['rows']) != samples or events[0] != events[1]:
            raise RuntimeError('On/off gameplay or accepted event mismatch')
        concat = folder / 'concat.txt'
        concat.write_text("file 'before.mp4'\nfile 'after.mp4'\n")
        with (folder / 'comparison-encode.log').open('w') as log:
            subprocess.run(['ffmpeg', '-n', '-f', 'concat', '-safe', '0', '-i', str(concat), '-c', 'copy', str(folder / 'comparison.mp4')], stdout=log, stderr=subprocess.STDOUT, timeout=120, check=True)
        report['comparison_sha256'] = sha(folder / 'comparison.mp4')
        report['source_after'] = harness.source_inventory()
        report['source_stable'] = before == report['source_after'] and metadata == harness.git_metadata()
        if not report['source_stable']: raise RuntimeError('Source changed during capture')
        from cloud_delivery import validate_capture
        report['status'] = 'passed'
        write(receipt, report)
        validate_capture(folder, report['task'])
        # Keep failed originals; release raw AVI only after full success validation.
        for variant in ('before', 'after'): (folder / (variant + '.avi')).unlink()
    except Exception as error:
        report['status'] = 'failed'
        report['errors'].append(type(error).__name__ + ': ' + str(error))
        report['source_after'] = harness.source_inventory()
        report['source_stable'] = before == report['source_after'] and metadata == harness.git_metadata()
    finally:
        if display is not None:
            display.terminate()
            display.wait(timeout=10)
        write(receipt, report)
    print(json.dumps(dict(status=report['status'], errors=report['errors'], receipt=str(receipt))))
    return 0 if report['status'] == 'passed' else 1


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--samples', type=int, choices=(998,), default=998, help='fixed9-mode actual Home hero route with stationary practice targets')
    args = parser.parse_args()
    raise SystemExit(capture(args.output.resolve(),args.samples))
