"""Actual formal cosmetic-space consumer plus deliberate real Node counterexamples."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile
import time

import level_formal

ROOT = Path(__file__).resolve().parents[1]


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
    report = {'source_before':before, 'producer_sha256':producer_sha256, 'status':'failed', 'runs':[], 'scope':'Actual cosmetic integration and real bad Node mutations, not gameplay traversal or visual acceptance'}
    try:
        for mutation in ('', 'detached_root', 'channel_intrusion', 'wrong_attachment', 'far_wrong_scale', 'far_wrong_depth', 'far_detached_root', 'far_clipped_boundary', 'translated_parent'):
            label = mutation or 'positive'
            capture = folder / (label+'.json')
            command = ['bash','tools/godot.sh','--headless','--path','.', '--script','tests/visual_director_space_runner.gd','--','--output='+str(capture)]
            if mutation: command.append('--mutation='+mutation)
            started = time.monotonic()
            result = subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=90)
            log = folder/(label+'.log'); log.write_text(result.stdout+result.stderr)
            text = log.read_text()
            data = json.loads(capture.read_text()) if capture.exists() else {}
            expected = ['abutment_cap_detached_from_actual_bank'] if mutation=='detached_root' else ['abutment_intrudes_into_open_channel'] if mutation=='channel_intrusion' else ['actual_attachment_differs_from_real_dock'] if mutation=='wrong_attachment' else ['actual_recess_scale_differs_from_contract'] if mutation=='far_wrong_scale' else ['distant_recess_not_behind_gameplay'] if mutation=='far_wrong_depth' else ['actual_recess_anchor_differs_from_real_bank'] if mutation=='far_detached_root' else ['actual_recess_texture_extent_differs_from_source'] if mutation=='far_clipped_boundary' else []
            negative = mutation not in ('', 'translated_parent')
            passed = (result.returncode == (1 if negative else 0) and data.get('assertions',0)>=11 and data.get('failures')==(1 if negative else 0)
                      and (set(expected)<=set(data.get('issues',[]))) and bool(re.search(r'^VISUAL SPACE: [1-9]\d* assertions, [01] failures$',text,re.M))
                      and not re.search(r'SCRIPT ERROR:|Parse Error:|SHADER ERROR:|ERROR: Failed to load script',text))
            report['runs'].append({'mutation':mutation,'passed':passed,'exit_code':result.returncode,'command':command,'seconds':time.monotonic()-started,
                                   'log':str(log.relative_to(ROOT)),'log_sha256':hashlib.sha256(log.read_bytes()).hexdigest(),'capture':str(capture.relative_to(ROOT)),
                                   'capture_sha256':hashlib.sha256(capture.read_bytes()).hexdigest() if capture.exists() else None,'assertions':data.get('assertions'),'failures':data.get('failures'),'issues':data.get('issues')})
            if not passed: raise RuntimeError('Actual consumer case failed: '+label)
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
    raise SystemExit(run())
