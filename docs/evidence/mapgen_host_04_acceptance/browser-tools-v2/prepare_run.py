"""Reuse exact recovered finite staging; change only CLI driver and extra producers."""
import hashlib
import json
from pathlib import Path
import shlex
import subprocess
import sys

sys.dont_write_bytecode=True
BASE=Path(__file__).resolve().parent
ORIGINAL_PREPARE=BASE.parent/'browser-tools/prepare_gears.py'
ORIGINAL_PREPARE_SHA='9f392153c515e488dcd787ca287741148c7b1de1ace89624cb7a5e992c1d07b6'

def main():
    assert hashlib.sha256(ORIGINAL_PREPARE.read_bytes()).hexdigest()==ORIGINAL_PREPARE_SHA
    if '--help' in sys.argv:
        subprocess.run([sys.executable,'-B',str(ORIGINAL_PREPARE),'--help'],check=True);return
    arguments=sys.argv[1:];output=Path(arguments[arguments.index('--output')+1]).resolve()
    proc=subprocess.run([sys.executable,'-B',str(ORIGINAL_PREPARE),*arguments],capture_output=True,text=True)
    if proc.returncode:
        print(proc.stdout,end='');print(proc.stderr,end='',file=sys.stderr);raise SystemExit(proc.returncode)
    (output/'original-prepare.stdout.json').write_text(proc.stdout)
    original=json.loads((output/'run-argv.json').read_text());argv=list(original)
    assert Path(argv[2]).name=='gears_run.py'
    argv[2]=str(BASE/'automated_driver.py')
    root=Path(argv[argv.index('--source-root')+1])
    producers=[BASE/name for name in ['original_driver.py','build_driver.py','offline_review.py','test_tools.py','prepare_run.py','freeze.json']]
    producers.append(root/'experiments/generation/runtime_map_verified_library_cache.gd')
    for path in producers:
        assert path.is_file();argv.extend(['--producer-file',str(path)])
    (output/'run-argv-original-manual.json').write_text(json.dumps(original,indent=2)+'\n')
    (output/'run-argv.json').write_text(json.dumps(argv,indent=2)+'\n')
    (output/'run.sh').write_text('#!/bin/sh\nset -eu\nexec '+shlex.join(argv)+'\n')
    transition=dict(status='STAGED_ONLY_NOT_RUN',original_driver_sha256=hashlib.sha256((BASE/'original_driver.py').read_bytes()).hexdigest(),automated_driver_sha256=hashlib.sha256((BASE/'automated_driver.py').read_bytes()).hexdigest(),scope='Only authorized checkpoint/status/real-capture batch migration; original source/PCK/native data unchanged; no browser/server launch',argv_original=original,argv_automatic=argv)
    (output/'driver-transition.json').write_text(json.dumps(transition,indent=2)+'\n')
    print(json.dumps(dict(status='STAGED_ONLY_NOT_RUN',output=str(output),transition=str(output/'driver-transition.json')),indent=2))

if __name__=='__main__':main()
