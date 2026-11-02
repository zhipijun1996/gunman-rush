from pathlib import Path
import subprocess,json,hashlib,time,os,sys,re
R=Path('/workspace/gunman-rush-refactor');E=Path(__file__).parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
v=json.loads((E/'source-vector.json').read_text());pre={r['path']:sha(R/r['path']) for r in v['files']};assert all(pre[r['path']]==r['candidate_sha256'] for r in v['files']),'Candidate source changed; explicitly regenerate/bind source vector before run'
assert sha(E/'baseline_e42.gd')==v['baseline_generated_sha256']
argv=['bash','tools/godot.sh','--headless','--path',str(R),'--script',str(E/'bench.gd')]
sys.path.insert(0,str(R/'tools'))
import harness
started=time.monotonic()
check=dict(argv=argv,timeout_seconds=180,success_pattern='^COMBAT_E42_PAIRED ')
execution=harness.run_check(check,E/'native.log',root=R)
raw=(E/'native.log').read_bytes();code=execution['exit_code'];timed_out=execution['status']=='timeout'
strict_errors=[line for line in raw.decode(errors='replace').splitlines() if re.search(r'SCRIPT ERROR:|Parse Error:|SHADER ERROR:|ERROR:|ObjectDB.*leaked|resources? still in use at exit',line)]
(E/'native.log').write_bytes(raw);post={path:sha(R/path) for path in pre};result=None
for line in raw.decode(errors='replace').splitlines():
 if line.startswith('COMBAT_E42_PAIRED '):result=json.loads(line[len('COMBAT_E42_PAIRED '):])
receipt=dict(execution=execution,strict_errors=strict_errors,argv=argv,timeout_seconds=180,elapsed_seconds=time.monotonic()-started,returncode=code,timed_out=timed_out,source_vector_sha256=sha(E/'source-vector.json'),bench_sha256=sha(E/'bench.gd'),runner_sha256=sha(Path(__file__)),baseline_generated_sha256=sha(E/'baseline_e42.gd'),source_pre=pre,source_post=post,source_stable=pre==post,log_sha256=sha(E/'native.log'),result=result,scope='Native same-process synthetic cost, not browser/mobile FPS. Actual parsed success and errors retained.')
(E/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(dict(returncode=code,timed_out=timed_out,elapsed_seconds=receipt['elapsed_seconds'],source_stable=receipt['source_stable'],failures=None if result is None else result['failures'],receipt=str(E/'receipt.json'))));raise SystemExit(0 if execution['status']=='passed' and not strict_errors and code==0 and result is not None and result['failures']==0 and pre==post else 1)
