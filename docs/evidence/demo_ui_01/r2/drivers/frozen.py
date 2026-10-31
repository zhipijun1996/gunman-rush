import sys, os, json
from pathlib import Path
ROOT=Path('/workspace/ui-workline');sys.path.insert(0,str(ROOT/'tools'));import harness
folder=ROOT/'build/verification/demo-ui-r2/frozen-v3';folder.mkdir(exist_ok=False)
source=harness.git_metadata();assert source['git_status']==''
env={**os.environ,'DISPLAY':':99','LIBGL_ALWAYS_SOFTWARE':'1'}
base=['bash','tools/godot.sh','--path','.','--audio-driver','Dummy']
native=base+['--rendering-method','gl_compatibility']
checks=[
 ('ui-contract',native+['--script','tests/demo_ui_01/contract_runner.gd','--','--capture','--output=res://build/verification/demo-ui-r2/frozen-v3/native'],r'^DEMO UI CONTRACT: \d+ checks, 0 failures$'),
 ('r2',native+['--script','tests/demo_ui_01/r2_runner.gd','--','--capture','--output=res://build/verification/demo-ui-r2/frozen-v3/r2'],r'^DEMO UI R2: \d+ checks, 0 failures$'),
 ('underworld-ui',['python3','tools/run_underworld_ui_tests.py'],r'^UNDERWORLD UI: \d+ checks, 0 failures$'),
 ('preview',base+['--headless','--script','tests/cloud_preview_runner.gd'],r'^CLOUD PREVIEW TESTS: 25 assertions, 0 failures$'),
 ('legacy',base+['--headless','--script','tests/demo_ui_01/legacy_runner.gd'],r'^DEMO UI LEGACY: 101 checks, 0 failures$'),
 ('settings',base+['--headless','--script','tests/menu_settings_lifecycle_runner.gd'],r'^MENU SETTINGS LIFECYCLE: 14 assertions, 0 failures$'),
 ('focus',base+['--headless','--script','tests/grapple_focus_hud_runner.gd'],r'^GRAPPLE FOCUS HUD: 25 checks / 0 failures$'),
 ('menu-scroll',native+['--script','tests/menu_scroll_touch_tests.gd'],r'^MENU SCROLL TOUCH: 44 checks / 0 failures; native GUI lifecycle only, Web scrolling separate$'),
 ('art',['python3','tools/check_art.py'],r'^PASS: 222 assets, hashes, dimensions, pivots, self-contained SVGs. Device visuals not verified.$')]
results=[]
for name,argv,pattern in checks:
 result=harness.run_check({'argv':argv,'timeout_seconds':180,'success_pattern':pattern},folder/(name+'.log'),ROOT,env)
 result['id']=name;results.append(result)
 print(name,result['status'],flush=True)
report={'task':'DEMO-UI-01','content_version':'clockwork-ui-r2','source':source,'source_stable':source==harness.git_metadata(),'scope':'Focused UI Development checks only. Dynamic Control inventory affects observed assertion counts; original assertions and budgets remain. No Integration/Release/device approval.','results':results}
(folder/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
assert report['source_stable'] and all(r['status']=='passed' for r in results)
