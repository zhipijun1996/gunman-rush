"""Actual terrain family consumers and deliberately broken live-node checks.
Cold import precedes source freeze. GPU fixtures do not claim route traversal.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import selectors
import shutil
import subprocess
import tempfile
import time

import production_loop

ROOT = Path(__file__).resolve().parents[1]
WRAPPER = '/workspace/gunman-rush/build/region_production_v3/godot_locked.sh'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--gpu', action='store_true')
    parser.add_argument('--all-maps', action='store_true')
    args = parser.parse_args()
    if os.environ.get('GODOT_BIN') != WRAPPER:
        raise SystemExit('Explicit GODOT_BIN shared wrapper is required')
    folder = Path(tempfile.mkdtemp(prefix='terrain-family-', dir=ROOT / 'build'))
    env = os.environ.copy()
    env.update(LP_NUM_THREADS='1', OMP_NUM_THREADS='1', LIBGL_ALWAYS_SOFTWARE='1')
    report = {'status':'failed','environment':{k:env[k] for k in ('GODOT_BIN','LP_NUM_THREADS','OMP_NUM_THREADS','LIBGL_ALWAYS_SOFTWARE')},'runs':[]}
    display = None
    display_log = None
    started = time.monotonic()
    try:
        # Import is real and intentionally before the source-before checkpoint.
        command = ['bash','tools/godot.sh','--headless','--editor','--path','.','--import']
        result = subprocess.run(command,cwd=ROOT,env=env,capture_output=True,text=True,timeout=180)
        (folder/'cold_import.log').write_text(result.stdout+result.stderr)
        report['cold_import']={'command':command,'exit_code':result.returncode,'log':str((folder/'cold_import.log').relative_to(ROOT))}
        if result.returncode or re.search(r'SCRIPT ERROR:|Parse Error:|SHADER ERROR:',result.stdout+result.stderr):
            raise RuntimeError('Cold import rejected')
        source_before = production_loop.snapshot()
        report['source_before']=source_before
        if args.gpu and not env.get('DISPLAY'):
            binary = shutil.which('Xvfb') or str(ROOT.parent/'toolchains/xvfb/usr/bin/Xvfb')
            display_log=(folder/'display.log').open('wb')
            display=subprocess.Popen([binary,'-displayfd','1','-screen','0','1280x720x24','-nolisten','tcp','-ac'],stdout=subprocess.PIPE,stderr=display_log)
            with selectors.DefaultSelector() as selector:
                selector.register(display.stdout,selectors.EVENT_READ)
                if not selector.select(20):raise RuntimeError('GPU display timeout')
                number=display.stdout.readline().decode().strip()
                if not number.isdigit():raise RuntimeError('Invalid GPU display')
            env['DISPLAY']=':'+number
            report['environment']['DISPLAY']=env['DISPLAY']
        for negative in (False,True):
            label='negative' if negative else 'positive'
            capture=folder/(label+'.json')
            command=['bash','tools/godot.sh']
            if args.gpu and not negative:command+=['--rendering-method','gl_compatibility','--audio-driver','Dummy']
            else:command+=['--headless','--max-fps','60']
            command+=['--path','.','--script','tests/plains_terrain_family_runner.gd','--','--output='+str(capture)]
            if negative:command+=['--prove-failure']
            elif args.gpu:command+=['--gpu']
            elif args.all_maps:command+=['--all-maps']
            result=subprocess.run(command,cwd=ROOT,env=env,capture_output=True,text=True,timeout=240)
            log=folder/(label+'.log');log.write_text(result.stdout+result.stderr)
            data=json.loads(capture.read_text()) if capture.exists() else {}
            passed=(result.returncode==(1 if negative else 0) and data.get('assertions',0)>=20 and data.get('failures')==(1 if negative else 0) and re.search(r'^TERRAIN FAMILY: [1-9]\d* assertions, [01] failures$',log.read_text(),re.M) and not re.search(r'(?m)SCRIPT ERROR:|Parse Error:|SHADER ERROR:|^ERROR:',log.read_text()))
            report['runs'].append({'command':command,'exit_code':result.returncode,'negative':negative,'passed':bool(passed),'assertions':data.get('assertions'),'failures':data.get('failures'),'capture':str(capture.relative_to(ROOT)),'log':str(log.relative_to(ROOT)),'log_sha256':hashlib.sha256(log.read_bytes()).hexdigest()})
            if not passed:raise RuntimeError('Actual '+label+' consumer rejected')
        report['source_after']=production_loop.snapshot()
        report['source_stable']=report['source_before']==report['source_after']
        if not report['source_stable']:raise RuntimeError('Source changed after cold import checkpoint')
        report['status']='passed'
    except Exception as exc:
        report['error']=repr(exc)
    finally:
        if display:
            display.terminate()
            try:display.wait(timeout=5)
            except subprocess.TimeoutExpired:display.kill();display.wait(timeout=5)
        if display_log:display_log.close()
        report['seconds']=time.monotonic()-started
        report['scope']='Actual source consumers/negative diagnoses; static GPU fixture is not traversal or aesthetics/device acceptance'
        (folder/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print('TERRAIN FAMILY SUITE:',report['status'],folder.relative_to(ROOT))
    return 0 if report['status']=='passed' else 1


if __name__=='__main__':
    raise SystemExit(main())
