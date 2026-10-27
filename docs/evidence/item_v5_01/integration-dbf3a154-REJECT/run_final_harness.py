from pathlib import Path
import hashlib,json,re,subprocess,sys,time
project=Path('/workspace/gunman-rush')
out=project/'build/item_v5/final-dbf3a154-review'
sys.path.insert(0,str(project/'tools'))
import harness
scope=json.loads((out/'selected_scope.json').read_text())
argv=['python3','tools/harness.py','--profile','item-v5','--jobs','1']
for check in scope['actual29_checks']: argv+=['--check',check]
before=harness.source_inventory()
metadata={'commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=project,text=True).strip(),'git_status':subprocess.check_output(['git','status','--porcelain'],cwd=project,text=True).strip()}
(out/'source_snapshot_before.json').write_text(json.dumps(before,indent=2)+'\n')
(out/'invocation.json').write_text(json.dumps({'reviewer':'/root/v5_review','argv':argv,'metadata':metadata,'selected_count':len(scope['actual29_checks']),'reuse':False,'release':False,'jobs':1},indent=2)+'\n')
start=time.time()
with (out/'harness.log').open('w') as stream:
 result=subprocess.run(argv,cwd=project,stdout=stream,stderr=subprocess.STDOUT)
after=harness.source_inventory()
(out/'source_snapshot_after.json').write_text(json.dumps(after,indent=2)+'\n')
log=(out/'harness.log').read_text()
paths=re.findall(r'^Evidence: (.+)$',log,re.M)
report_path=project/paths[-1] if paths else None
report=json.loads(report_path.read_text()) if report_path and report_path.exists() else {}
if report_path and report_path.exists(): (out/'harness_report.json').write_bytes(report_path.read_bytes())
manifest={'reviewer':'/root/v5_review','actual_command':argv,'wrapper_exit':result.returncode,'seconds':time.time()-start,'metadata':metadata,'source_stable':before==after,'source_count':len(before),'source_changes':[k for k in sorted(set(before)|set(after)) if before.get(k)!=after.get(k)],'original_harness_report':str(report_path) if report_path else None,'harness_status':report.get('status'),'actual_check_count':len(report.get('checks',[])),'expected_check_count':len(scope['actual29_checks']),'all_fresh':all(not c.get('reused',False) for c in report.get('checks',[])),'accepted':result.returncode==0 and before==after and report.get('status')=='passed' and len(report.get('checks',[]))==len(scope['actual29_checks']),'scope':'exact selected29 engineering checks, no full Release/CI/player/device endorsement'}
(out/'execution_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(manifest,ensure_ascii=False))
sys.exit(0 if manifest['accepted'] else 1)
