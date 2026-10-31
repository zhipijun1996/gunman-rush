from pathlib import Path
import json,subprocess,hashlib,os,re,time,signal
root=Path('/workspace/gunman-rush-refactor');out=Path('/workspace/refactor-evidence/entry-startup-diagnostic-C-01');data=json.loads((out/'plan.json').read_text());results=[]
assert subprocess.check_output(['git','status','--porcelain'],cwd=root,text=True)==''
head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()
for index,(scene,mode) in enumerate(data['cases'],1):
 env=os.environ.copy();env.update(XDG_DATA_HOME=str(out/'user-data'/str(index)),XDG_CONFIG_HOME=str(out/'user-config'/str(index)),XDG_CACHE_HOME=str(out/'cache'))
 argv=[data['engine'],'--headless','--audio-driver','Dummy','--fixed-fps','60','--path',str(root),'--script',data['probe'],'--','--audit-scene=res://'+scene,'--audit-mode='+mode]
 log=out/f'{index:02d}.log';start=time.monotonic()
 with log.open('wb') as stream:
  process=subprocess.Popen(argv,cwd=root,env=env,stdout=stream,stderr=subprocess.STDOUT,start_new_session=True)
  try:code=process.wait(timeout=45)
  except subprocess.TimeoutExpired:
   os.killpg(process.pid,signal.SIGKILL);process.wait();code=124
 text=log.read_text(errors='replace');errors=[]
 if code:errors.append('exit='+str(code))
 if re.search(r'SCRIPT ERROR:|Parse Error:|SHADER ERROR:|(?m:^ERROR:)|ObjectDB.*leaked|resources still in use|RID.*leaked',text):errors.append('engine/script/resource/exit error')
 if 'AUDIT_ENTRY_DONE true' not in text:errors.append('audio teardown completion missing')
 snapshots=re.findall(r'^AUDIT_ENTRY_SNAPSHOT (.+)$',text,re.M)
 if len(snapshots)!=1:errors.append('one startup snapshot required')
 row={'scene':scene,'mode':mode,'exit_code':code,'seconds':time.monotonic()-start,'log':log.name,'errors':errors,'status':'failed' if errors else 'startup_probe_passed','argv':argv,'snapshot':json.loads(snapshots[0]) if len(snapshots)==1 else None}
 results.append(row);(out/'results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n');print(json.dumps({k:row[k] for k in ['scene','mode','status','errors','seconds']},ensure_ascii=False),flush=True)
final={'source_commit':head,'source_unchanged':head==subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip() and subprocess.check_output(['git','status','--porcelain'],cwd=root,text=True)=='','engine_sha256':data['engine_sha256'],'probe_sha256':data['probe_sha256'],'scope':'Diagnostic O0 engine C only; exact entry startup plus original audio drain. No optimized toolchain, ready-for-play, input interaction, GUI, completion or device claim. Foundry requires final selected engine/source-basis rebuild for meaningful play readiness.','results':results}
(out/'report.json').write_text(json.dumps(final,ensure_ascii=False,indent=2)+'\n')
raise SystemExit(1 if any(r['errors'] for r in results) or not final['source_unchanged'] else 0)
