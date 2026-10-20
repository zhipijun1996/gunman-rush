"""New ignored local preflight; original three browser consumers/caps unchanged.
No CI artifact/public/native claims. Always records final source and bundle guard.
"""
import argparse,functools,json,pathlib,sys,threading,time
from http.server import ThreadingHTTPServer,SimpleHTTPRequestHandler
from common import ROOT,state,sha,fresh,write,bound
sys.path.insert(0,str(ROOT/'tools'))
import harness

def main():
 p=argparse.ArgumentParser();p.add_argument('--expected-commit',required=True);p.add_argument('--output',type=pathlib.Path,required=True);a=p.parse_args();before=state(a.expected_commit);out=fresh(a.output);web=ROOT/'build/web';info=json.loads((web/'build-info.json').read_text());assert info['source_commit']==a.expected_commit
 inventory=lambda:{str(p.relative_to(web)):sha(p)for p in sorted(web.rglob('*'))if p.is_file()}
 web_before=inventory();report={'status':'running','execution_head':a.expected_commit,'source_before':before,'build_info':info,'pack_sha256':sha(web/info['pack']),'web_inventory_before':web_before,'original_cap_seconds_each':300,'combined_cap':None,'shared_helper':bound(ROOT/'tools/studio_gui_pointer.py',a.expected_commit),'results':[],'scope':'Exact local export and original three browser consumers only; not CI artifact/public/native/device approval.'};server=None;start=time.monotonic();write(out/'receipt.json',report)
 try:
  class Quiet(SimpleHTTPRequestHandler):
   def log_message(self,*args):pass
  server=ThreadingHTTPServer(('127.0.0.1',0),functools.partial(Quiet,directory=str(web)));threading.Thread(target=server.serve_forever,daemon=True).start();url=f'http://127.0.0.1:{server.server_port}/';report['url']=url;cwd=out/'browser-cwd';cwd.mkdir();write(out/'receipt.json',report)
  for name in ['verify_action_budget_browser','verify_studio_click_browser','verify_all_weapon_browser']:
   script=ROOT/'tools'/(name+'.py');cmd=[sys.executable,str(script),url];pattern='"failed": \\[\\]'if name=='verify_action_budget_browser'else'"failed": 0'
   result=harness.run_check({'argv':cmd,'timeout_seconds':300,'success_pattern':pattern},out/(name+'.log'),root=cwd);report['results'].append({'name':name,'command':cmd,'script':bound(script,a.expected_commit),**result});write(out/'receipt.json',report);assert result['status']=='passed',name+' original failure preserved'
  report['status']='passed'
 except BaseException as e:report.update(status='failed',error=type(e).__name__+': '+str(e));raise
 finally:
  if server:server.shutdown();server.server_close()
  try:
   report['source_after']=state(a.expected_commit);report['source_stable']=report['source_after']==before;report['web_inventory_after']=inventory();report['bundle_stable']=report['web_inventory_after']==web_before
   assert report['source_stable'] and report['bundle_stable']
  except BaseException as e:report.update(status='failed',final_guard_error=type(e).__name__+': '+str(e))
  report['seconds']=time.monotonic()-start;write(out/'receipt.json',report);print(json.dumps({k:report.get(k)for k in ['status','seconds','error','source_stable','bundle_stable']}))
 if report['status']!='passed':raise SystemExit(1)
if __name__=='__main__':main()
