"""Actual formal cosmetic-space consumer plus deliberate real Node counterexamples."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile
import time
import os
import selectors
import shutil
import argparse

import level_formal

ROOT = Path(__file__).resolve().parents[1]


def run_painted():
    """Short actual new-consumer preflight; the legacy suite remains separate."""
    from run_tests import run_engine
    dependencies = ('tests/painted_formal_terrain_tests.gd',
                    'tools/run_visual_director_space_tests.py')
    before = level_formal.source_files(extra_paths=dependencies)
    try:
        imported = run_engine(['--headless', '--path', '.', '--editor', '--quit'], 120)
        if 'ERROR:' in imported:
            raise RuntimeError('Native import error before painted-terrain preflight')
        output = run_engine(['--headless', '--path', '.', '--script',
                             'tests/painted_formal_terrain_tests.gd'], 45)
        if 'ERROR:' in output or not re.search(r'^PASS: painted formal ', output, re.M):
            raise RuntimeError('Actual painted-terrain completion missing or native error')
        if before != level_formal.source_files(extra_paths=dependencies):
            raise RuntimeError('Painted-terrain source changed during preflight')
        print('VISUAL TERRAIN MESH: passed; actual runtime/mesh/refusal checks only, not art or full-route approval')
        return 0
    except Exception as exc:
        print('VISUAL TERRAIN MESH: failed; ' + str(exc))
        return 1


def run(output=None):
    base = ROOT / 'build/visual_director/space_tests'
    base.mkdir(parents=True, exist_ok=True)
    folder = Path(output).resolve() if output else Path(tempfile.mkdtemp(prefix='run_', dir=base))
    if output:
        if folder.exists() or not folder.is_relative_to(ROOT/'build'):
            raise ValueError('Use a new build evidence folder')
        folder.mkdir(parents=True)
    before = level_formal.source_files()
    producer_sha256 = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    report = {'consumer_mode':'explicit_legacy_waterworks_diagnostic_not_default', 'source_before':before, 'producer_sha256':producer_sha256, 'status':'failed', 'runs':[], 'scope':'Actual cosmetic integration and real bad Node mutations, not gameplay traversal or visual acceptance'}
    try:
        for mutation in ('', 'detached_root', 'channel_intrusion', 'wrong_attachment', 'far_wrong_scale', 'far_wrong_depth', 'far_detached_root', 'far_clipped_boundary', 'translated_parent', 'bank_scope_escape', 'bank_disabled', 'ferry_graded'):
            label = mutation or 'positive'
            capture = folder / (label+'.json')
            command = ['bash','tools/godot.sh','--headless','--path','.', '--script','tests/visual_director_space_runner.gd','--','--legacy-waterworks-contract','--output='+str(capture)]
            if mutation: command.append('--mutation='+mutation)
            started = time.monotonic()
            result = subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=90)
            log = folder/(label+'.log'); log.write_text(result.stdout+result.stderr)
            text = log.read_text()
            data = json.loads(capture.read_text()) if capture.exists() else {}
            expected = ['abutment_cap_detached_from_actual_bank'] if mutation=='detached_root' else ['abutment_intrudes_into_open_channel'] if mutation=='channel_intrusion' else ['actual_attachment_differs_from_real_dock'] if mutation=='wrong_attachment' else ['actual_recess_scale_differs_from_contract'] if mutation=='far_wrong_scale' else ['distant_recess_not_behind_gameplay'] if mutation=='far_wrong_depth' else ['actual_recess_anchor_differs_from_real_bank'] if mutation=='far_detached_root' else ['actual_recess_texture_extent_differs_from_source'] if mutation=='far_clipped_boundary' else ['actual_bank_material_scope_differs_from_real_bank'] if mutation=='bank_scope_escape' else ['actual_selected_bank_material_not_enabled'] if mutation=='bank_disabled' else ['moving_ferry_material_incorrectly_graded_as_bank'] if mutation=='ferry_graded' else []
            negative = mutation not in ('', 'translated_parent')
            passed = (result.returncode == (1 if negative else 0) and data.get('assertions',0)>=11 and data.get('failures')==(1 if negative else 0)
                      and (set(expected)<=set(data.get('issues',[]))) and bool(re.search(r'^VISUAL SPACE: [1-9]\d* assertions, [01] failures$',text,re.M))
                      and not re.search(r'SCRIPT ERROR:|Parse Error:|SHADER ERROR:|ERROR: Failed to load script|ObjectDB.*leaked|resources? still in use at exit',text))
            report['runs'].append({'mutation':mutation,'passed':passed,'exit_code':result.returncode,'command':command,'seconds':time.monotonic()-started,
                                   'log':str(log.relative_to(ROOT)),'log_sha256':hashlib.sha256(log.read_bytes()).hexdigest(),'capture':str(capture.relative_to(ROOT)),
                                   'capture_sha256':hashlib.sha256(capture.read_bytes()).hexdigest() if capture.exists() else None,'assertions':data.get('assertions'),'failures':data.get('failures'),'issues':data.get('issues')})
            if not passed: raise RuntimeError('Actual consumer case failed: '+label)
        display = None
        display_log = None
        env = os.environ.copy(); env.update(LIBGL_ALWAYS_SOFTWARE='1', LP_NUM_THREADS='1')
        try:
            if not env.get('DISPLAY'):
                binary = shutil.which('Xvfb') or str(ROOT.parent/'toolchains/xvfb/usr/bin/Xvfb')
                display_log = (folder/'gpu_display.log').open('wb')
                display = subprocess.Popen([binary,'-displayfd','1','-screen','0','1280x720x24','-nolisten','tcp','-ac'],stdout=subprocess.PIPE,stderr=display_log)
                with selectors.DefaultSelector() as selector:
                    selector.register(display.stdout,selectors.EVENT_READ)
                    if not selector.select(20): raise RuntimeError('Actual GPU display readiness timeout')
                    number=display.stdout.readline().decode().strip()
                    if not number.isdigit(): raise RuntimeError('Invalid actual GPU display')
                env['DISPLAY']=':'+number
            capture=folder/'gpu_probe.json'
            command=['bash','tools/godot.sh','--rendering-method','gl_compatibility','--path','.', '--script','tests/visual_director_space_runner.gd','--','--legacy-waterworks-contract','--gpu-probe','--output='+str(capture)]
            started=time.monotonic()
            result=subprocess.run(command,cwd=ROOT,env=env,capture_output=True,text=True,timeout=90)
            log=folder/'gpu_probe.log';log.write_text(result.stdout+result.stderr)
            data=json.loads(capture.read_text()) if capture.exists() else {}
            passed=(result.returncode==0 and data.get('assertions',0)>=5 and data.get('failures')==0
                    and data.get('alpha_equal') is True and data.get('far_alpha_equal') is True and data.get('grass_equal') is True
                    and re.search(r'^VISUAL SPACE GPU: [1-9]\d* assertions, 0 failures$',log.read_text(),re.M)
                    and not re.search(r'SCRIPT ERROR:|Parse Error:|SHADER ERROR:|ERROR: Failed to load script|ObjectDB.*leaked|resources? still in use at exit',log.read_text()))
            report['gpu_probe']={'passed':bool(passed),'exit_code':result.returncode,'command':command,'seconds':time.monotonic()-started,
                'capture':str(capture.relative_to(ROOT)),'capture_sha256':hashlib.sha256(capture.read_bytes()).hexdigest() if capture.exists() else None,
                'log':str(log.relative_to(ROOT)),'log_sha256':hashlib.sha256(log.read_bytes()).hexdigest(),'device_scope':'Software GPU isolated shader fixture, not physical-device or beauty approval'}
            if not passed: raise RuntimeError('Actual GPU default/selected shader probe failed')
        finally:
            if display:
                display.terminate()
                try: display.wait(timeout=5)
                except subprocess.TimeoutExpired: display.kill(); display.wait(timeout=5)
            if display_log: display_log.close()
        report['source_after']=level_formal.source_files()
        if report['source_after']!=before or hashlib.sha256(Path(__file__).read_bytes()).hexdigest()!=producer_sha256:
            raise RuntimeError('Source/producer drift during actual consumer tests')
        report['status']='passed'
    except Exception as exc:
        report['error']=str(exc)
    finally:
        (folder/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print('VISUAL SPACE SUITE:',report['status'],str(folder.relative_to(ROOT)))
    return 0 if report['status']=='passed' else 1

if __name__=='__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--painted-terrain', action='store_true',
                        help='Run only the actual painted-terrain mesh preflight')
    args = parser.parse_args()
    raise SystemExit(run_painted() if args.painted_terrain else run())
