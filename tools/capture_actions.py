"""Record normal-speed accepted-input animation with audio; never certify device performance."""
import hashlib
import json
import os
from pathlib import Path
import selectors
import shutil
import subprocess
import sys
import harness

ROOT = Path(__file__).resolve().parents[1]


def main():
    folder = ROOT / 'build/verification/actions-movie'
    folder.mkdir(parents=True, exist_ok=True)
    avi, movie = folder / 'actions.avi', folder / 'actions.mp4'
    for path in (avi, movie): path.unlink(missing_ok=True)
    env = os.environ.copy(); env['LIBGL_ALWAYS_SOFTWARE'] = '1'
    display = None
    try:
        if not env.get('DISPLAY'):
            candidate = Path(os.environ.get('GUNMAN_TOOLCHAIN_ROOT', str(ROOT.parent / 'toolchains'))) / 'xvfb/usr/bin/Xvfb'
            binary = shutil.which('Xvfb') or (str(candidate) if candidate.is_file() else None)
            if not binary: raise RuntimeError('Xvfb is required for real rendered animation capture')
            display = subprocess.Popen([binary, '-displayfd', '1', '-screen', '0', '1280x720x24', '-nolisten', 'tcp', '-ac'], stdout=subprocess.PIPE, stderr=(folder/'display.log').open('wb'))
            with selectors.DefaultSelector() as selector:
                selector.register(display.stdout, selectors.EVENT_READ)
                if not selector.select(30): raise RuntimeError('Xvfb did not become ready')
                number = display.stdout.readline().decode().strip()
                if not number.isdigit(): raise RuntimeError('Invalid Xvfb display')
            env['DISPLAY'] = ':' + number
        check = {'argv': ['bash', 'tools/godot.sh', '--path', '.', '--rendering-method', 'gl_compatibility', '--write-movie', str(avi), '--fixed-fps', '60', '--script', 'tools/action_movie_capture.gd'],
                 'timeout_seconds': 600, 'success_pattern': r'^ACTION BUDGET MOVIE: [1-9]\d* frames$'}
        result = harness.run_check(check, folder/'capture.log', ROOT, env)
        if result['status'] != 'passed': raise RuntimeError('Animation recording failed: ' + result['status'])
        subprocess.run(['ffmpeg', '-y', '-i', str(avi), '-c:v', 'libx264', '-crf', '20', '-pix_fmt', 'yuv420p', '-c:a', 'aac', str(movie)], check=True, stdout=subprocess.DEVNULL, stderr=(folder/'encode.log').open('wb'), timeout=180)
        media = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-show_streams', '-show_format', '-of', 'json', str(movie)], timeout=30))
        video = next(v for v in media['streams'] if v['codec_type']=='video')
        audio = next(v for v in media['streams'] if v['codec_type']=='audio')
        trace = json.loads((ROOT/'build/action_budget/movie_trace.json').read_text())
        demos = {sample['demo'] for sample in trace['trace']}
        if video['avg_frame_rate'] != '60/1' or int(audio['sample_rate']) != 48000 or audio['channels'] != 2 or len(demos) != 10 or len(trace['trace']) < 2000:
            raise RuntimeError('Missing movie coverage, continuous frames or audio')
        report = {'status':'passed', 'commit': subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(), 'scope':'Normal-speed software-GPU accepted-input animation; independent/player/device acceptance unverified',
                  'demos':sorted(demos), 'frames':len(trace['trace']), 'duration_seconds':float(media['format']['duration']), 'media_sha256':hashlib.sha256(movie.read_bytes()).hexdigest(), 'capture':result}
        (folder/'report.json').write_text(json.dumps(report,indent=2)+'\n')
        print('PASS: continuous actions movie, 60 FPS and stereo 48k audio')
        return 0
    finally:
        if display:
            display.terminate()
            try: display.wait(timeout=5)
            except subprocess.TimeoutExpired: display.kill(); display.wait()


if __name__ == '__main__':
    sys.exit(main())
