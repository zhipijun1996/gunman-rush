from pathlib import Path
import subprocess,json,hashlib,sys
r=Path('/tmp/gunman-rush-mapgen-04');p=Path('/tmp/mapgen-v4-audit/upgrade-check');t=p/'old-install';a=Path('/tmp/mapgen-v4-audit/mapgen-godot-candidate-0.4.0.zip');tool=r/'tools/install_mapgen_candidate.py';rows=[]
def snapshot():return {x.relative_to(t).as_posix():hashlib.sha256(x.read_bytes()).hexdigest()for x in t.rglob('*')if x.is_file()}
def run(label,command,expected=2,archive=a):
 before=snapshot();q=subprocess.run([sys.executable,'-B',str(tool),command,'--archive',str(archive),'--target',str(t)],capture_output=True,text=True);(p/(label+'-r3.stdout.json')).write_text(q.stdout);(p/(label+'-r3.stderr.log')).write_text(q.stderr);assert q.returncode==expected,(label,q.stdout,q.stderr)
 if expected:assert snapshot()==before,label+' unexpectedly mutated target'
 rows.append({'case':label,'exit_code':q.returncode,'expected_rejection':bool(expected),'target_unchanged_on_rejection':snapshot()==before if expected else None,'error':q.stderr.strip()});print(label,q.returncode,q.stderr.strip())
run('01-install-refuses-old','install')
for label,name,action in [('02-old-code-tamper','addons/mapgen/solver.gd','change'),('03-old-lock-tamper','config/mapgen_candidate.json','change'),('04-old-input-missing','resources/mapgen/generator_config.json','delete')]:
 f=t/name;original=f.read_bytes();f.write_bytes(original+b'changed')if action=='change'else f.unlink()
 run(label,'upgrade');f.write_bytes(original)
f=t/'addons/mapgen/new_unapproved.gd';f.write_text('extends RefCounted\n');run('05-extra-gd','upgrade');f.unlink()
bad=p/'tampered-candidate.zip';data=bytearray(a.read_bytes());data[-1]^=1;bad.write_bytes(data);run('06-archive-tamper','upgrade',archive=bad);bad.unlink()
f=t/'config/mapgen_candidate.json';original=f.read_bytes();v=json.loads(original);v['version']='0.3.1';f.write_text(json.dumps(v));run('06b-unsupported-version','upgrade');f.write_bytes(original)
run('07-real-old-to-new','upgrade',expected=0);run('08-repeated-upgrade-nochange','upgrade',expected=0);run('09-repeat-install','install',expected=0);run('10-verify-archive','verify',expected=0)
(p/'real-upgrade-results-r3.json').write_text(json.dumps(rows,indent=2)+'\n')
