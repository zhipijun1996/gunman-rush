"""Prepared only: unique, actual final-Web GUI/three-contact probes, serial with every engine."""
from pathlib import Path
from functools import partial
from http.server import ThreadingHTTPServer,SimpleHTTPRequestHandler
from threading import Thread
import json,subprocess,sys,hashlib,time,os
R=Path('/workspace/gunman-rush');sys.path.insert(0,str(R/'tools'));import harness
report_path=R/sys.argv[1];d=json.loads(report_path.read_text());assert d['status']=='passed'
assert json.loads((R/'build/verification/plains-redesign-q6-cliff-asset/state.json').read_text())['status']=='blocked'
rollback=json.loads((R/'build/plains_redesign/q6_rollback/execution.json').read_text());assert rollback['status'] in {'restored_pending_actual_tests','revalidated'}
for row in rollback['rows']: assert hashlib.sha256((R/row['path']).read_bytes()).hexdigest()==row['restored_sha256']
bridge=json.loads((R/'build/plains_redesign/gui_locator_diagnosis/c3_to_current_bridge.json').read_text());assert bridge['original_source_digest']==d['source_digest']
assert bridge['runtime_changed_paths']==[]
assert bridge['current_source_digest']==harness.input_digest({'argv':[]},harness.source_files(),harness.toolchain_identity()),'Unreviewed drift after explicit test-only bridge'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();assert sha(R/'build/web/build-info.json')==d['build_info_sha256']
engines=[s for s in subprocess.check_output(['ps','-eo','args'],text=True).splitlines() if 'Godot_v4.7.2-stable_linux.x86_64' in s and 'ps -eo' not in s];assert not engines,engines
B=R/'build/plains_redesign/final_gui_v2';assert not B.exists();B.mkdir(parents=True)
server=ThreadingHTTPServer(('127.0.0.1',0),partial(SimpleHTTPRequestHandler,directory=str(R/'build/web')));thread=Thread(target=server.serve_forever,daemon=True);thread.start();url=f'http://127.0.0.1:{server.server_port}/'
env=os.environ.copy();env['GUNMAN_RECORD_GUI']='1';env['LP_NUM_THREADS']='1'
record={'scope':'Actual final Web GUI Home purchase/reload/formal region, real fog map focus/zoom/drag/close, held-jump/aim-release and independent three-touch contacts. Seeded9notes is fixture, not earned. Emulated Chromium is not physical mobile/gamepad/human fun. WebM normal browser render, no audio-track claim.','delivery_report':str(report_path.relative_to(R)),'delivery_report_sha256':sha(report_path),'test_only_source_bridge':'build/plains_redesign/gui_locator_diagnosis/c3_to_current_bridge.json','test_only_source_bridge_sha256':sha(R/'build/plains_redesign/gui_locator_diagnosis/c3_to_current_bridge.json'),'build_info':d['build_info'],'commands':[],'started_utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime())};frozen_digest=bridge['current_source_digest']
try:
 for name,probe in [('region','region'),('floating_touch','floating')]:
  folder=B/name
  module='verify_plains_region_browser' if probe=='region' else 'verify_floating_touch_browser'
  timeout=260 if probe=='region' else 240
  code="import sys,asyncio;from pathlib import Path;sys.path.insert(0,'tools');import verify_plains_polish_browser as base;import "+module+" as actual;base.FOLDER=Path(sys.argv[1]);base.h.FOLDER=base.FOLDER;asyncio.run(asyncio.wait_for(base.main(sys.argv[2],actual.probe),timeout="+str(timeout)+"))"
  argv=['python3','-c',code,str(folder.relative_to(R)),url];entry={'name':name,'argv':argv};record['commands'].append(entry)
  with (B/(name+'.log')).open('w') as log:r=subprocess.run(argv,cwd=R,env=env,stdout=log,stderr=subprocess.STDOUT)
  entry['exit_code']=r.returncode
  p=folder/'browser-report.json'
  if p.exists():entry.update(report_sha256=sha(p),actual=json.loads(p.read_text()))
  (B/'execution.json').write_text(json.dumps(record,indent=2)+'\n');assert harness.input_digest({'argv':[]},harness.source_files(),harness.toolchain_identity())==frozen_digest,'Source drift'
  if r.returncode:raise SystemExit(r.returncode)
 record['status']='passed';record['finished_utc']=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime());(B/'execution.json').write_text(json.dumps(record,indent=2)+'\n')
finally:server.shutdown();server.server_close()
