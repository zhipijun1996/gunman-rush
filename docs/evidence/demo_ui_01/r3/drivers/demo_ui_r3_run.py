import sys,os,json
from pathlib import Path
root=Path('/workspace/ui-workline');sys.path.insert(0,str(root/'tools'));import harness
out=root/'build/verification/demo-ui-r3'/sys.argv[1];out.mkdir(exist_ok=False,parents=True)
checks=sys.argv[2:];results=[]
for script in checks:
 name=Path(script).stem
 result=harness.run_check({'argv':['bash','tools/godot.sh','--headless','--path','.','--audio-driver','Dummy','--script',script],'timeout_seconds':180,'success_pattern':r'(?m)^(?:DEMO UI R3 ENERGY: [1-9]\d* checks, 0 failures|PLAINS EXPERIENCE ENERGY: [1-9]\d* assertions, 0 failures|GRAPPLE FOCUS HUD: [1-9]\d* checks / 0 failures)$'},out/(name+'.log'),root,dict(os.environ))
 result['id']=script;results.append(result);print(name,result['status'],flush=True)
(out/'report.json').write_text(json.dumps(results,indent=2)+'\n')
raise SystemExit(0 if all(r['status']=='passed' for r in results) else 1)
