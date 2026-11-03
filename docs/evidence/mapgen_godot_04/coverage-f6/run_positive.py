from pathlib import Path
import hashlib,json,subprocess,time
E=Path('/tmp/mapgen-v4-actual-coverage-8ms');I=Path('/tmp/mapgen-v4-actual-inputs-8ms');W=Path('/tmp/map-edit-runtime-audit-v04');O=Path('/tmp/mapgen-v4-actual-coverage');H=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
oldfreeze=json.loads((O/'freeze.json').read_text()); oldfiles={p:H(O/p)for p in oldfreeze['files']};assert oldfiles==oldfreeze['files'];oldfiles['freeze.json']=H(O/'freeze.json')
inputs={str(p.relative_to(I)):H(p)for p in I.rglob('*')if p.is_file()};runs=[]
assert H(W/'tools/runtime_audit/check_930001.py')=='52e36a13386fb67c99ecd535ab529d8aee463d778f9498419b0b08047b49e2ea'
for name in ['default','gears']:
 out=E/(name+'-output');assert not out.exists()
 argv=['python3','-B','tools/runtime_audit/check_930001.py','--actual-profile',str(I/(name+'-profile.json')),'--inputs',str(I),'--zip110','/tmp/gunman-rush-mapgen-04/resources/mapgen/module-pack-1.1.0.zip','--out',str(out)]
 start=time.monotonic();r=subprocess.run(argv,cwd=W,capture_output=True,text=True,timeout=30);elapsed=time.monotonic()-start
 log=E/(name+'-positive.log');log.write_text(r.stdout+r.stderr)
 row={'profile':name,'argv':argv,'cwd':str(W),'exit_code':r.returncode,'elapsed_seconds':elapsed,'log_sha256':H(log),'profile_sha256':H(I/(name+'-profile.json')),'producer_sha256':H(W/'tools/runtime_audit/check_930001.py')}
 if (out/'mechanism-coverage.json').exists():row['output_sha256']=H(out/'mechanism-coverage.json')
 (E/(name+'-positive-receipt.json')).write_text(json.dumps(row,indent=2)+'\n');runs.append(row);assert r.returncode==0,row
assert inputs=={str(p.relative_to(I)):H(p)for p in I.rglob('*')if p.is_file()}
assert oldfiles=={p:H(O/p)for p in oldfiles}
(E/'positive-summary.json').write_text(json.dumps({'runs':runs,'input_files':inputs,'old_d4e_files':oldfiles,'inputs_unchanged':True,'old_d4e_unchanged':True},indent=2)+'\n');print('2 actual positives passed; old d4e untouched')
