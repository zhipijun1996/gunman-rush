import sys,os,json
from pathlib import Path
root=Path('/workspace/ui-workline');sys.path.insert(0,str(root/'tools'));import harness
out=root/'build/verification/demo-ui-r3/frozen-ui';out.mkdir(exist_ok=False)
source=harness.git_metadata();assert source['git_status']==''
env={**os.environ,'DISPLAY':':99','LIBGL_ALWAYS_SOFTWARE':'1'}
base=['bash','tools/godot.sh','--path','.','--audio-driver','Dummy'];native=base+['--rendering-method','gl_compatibility']
checks=[
('contract',native+['--script','tests/demo_ui_01/contract_runner.gd','--','--capture','--output=res://build/verification/demo-ui-r3/frozen-ui/native'],r'^DEMO UI CONTRACT: [1-9]\d* checks, 0 failures$'),
('title-font',native+['--script','tests/demo_ui_01/r2_runner.gd','--','--capture','--output=res://build/verification/demo-ui-r3/frozen-ui/title-font'],r'^DEMO UI R2: [1-9]\d* checks, 0 failures$'),
('old-energy',base+['--headless','--script','tests/plains_experience_energy_runner.gd'],r'^PLAINS EXPERIENCE ENERGY: [1-9]\d* assertions, 0 failures$'),
('region-lifecycle',base+['--headless','--script','tests/plains_region_lifecycle_runner.gd'],r'^REGION LIFECYCLE: [1-9]\d* assertions, 0 failures$'),
('underworld-ui',['python3','tools/run_underworld_ui_tests.py'],r'^UNDERWORLD UI: [1-9]\d* checks, 0 failures$'),
('cloud-preview',base+['--headless','--script','tests/cloud_preview_runner.gd'],r'^CLOUD PREVIEW TESTS: [1-9]\d* assertions, 0 failures$')]
rows=[]
for name,args,pattern in checks:
 r=harness.run_check({'argv':args,'timeout_seconds':180,'success_pattern':pattern},out/(name+'.log'),root,env);r['id']=name;rows.append(r);print(name,r['status'],flush=True)
 if r['status']!='passed':break
report={'source':source,'source_stable':source==harness.git_metadata(),'results':rows,'scope':'Focused current native UI and original historical/system checks; real device and Integration/Release separate.'}
(out/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
raise SystemExit(0 if report['source_stable'] and len(rows)==len(checks) and all(r['status']=='passed' for r in rows) else 1)
