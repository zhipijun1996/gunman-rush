"""Local-only preflight: unchanged original three consumers against exact U export.
Not a CI artifact, public deployment, or native movie claim.
"""
import functools,json,pathlib,subprocess,sys,threading,time
from http.server import ThreadingHTTPServer,SimpleHTTPRequestHandler
ROOT=pathlib.Path(__file__).resolve().parents[3]
sys.path[:0]=[str(ROOT/'tools'),str(ROOT/'build/forest_revision04/main-delivery-prepared')]
import harness
from common import state,sha,fresh,write,bound
U='e4b2132dd30bf8ca176a28eb79d1b32a65bb59e3'
def main():
 before=state(U);out=fresh(ROOT/'build/forest_revision04/menu-width-U-e4b2/local-three');web=ROOT/'build/web';info=json.loads((web/'build-info.json').read_text());assert info['source_commit']==U
 inventory=lambda:{str(p.relative_to(web)):sha(p)for p in sorted(web.rglob('*'))if p.is_file()}
 web_before=inventory();report={'status':'running','execution_head':U,'source_before':before,'build_info':info,'pack_sha256':sha(web/info['pack']),'web_inventory_before':web_before,'original_cap_seconds_each':300,'combined_cap':None,'results':[],'scope':'Exact U local export and original action-budget/studio-click/all-weapon browser consumers only; not CI artifact/public/native/device approval.'};server=None;start=time.monotonic()
 try:
  class Quiet(SimpleHTTPRequestHandler):
   def log_message(self,*args):pass
  server=ThreadingHTTPServer(('127.0.0.1',0),functools.partial(Quiet,directory=str(web)));threading.Thread(target=server.serve_forever,daemon=True).start();url=f'http://127.0.0.1:{server.server_port}/';report['url']=url;cwd=out/'browser-cwd';cwd.mkdir();write(out/'receipt.json',report)
  for name in ['verify_action_budget_browser','verify_studio_click_browser','verify_all_weapon_browser']:
   script=ROOT/'tools'/(name+'.py');cmd=[sys.executable,str(script),url];pattern='"failed": \\[\\]'if name=='verify_action_budget_browser'else'"failed": 0'
   result=harness.run_check({'argv':cmd,'timeout_seconds':300,'success_pattern':pattern},out/(name+'.log'),root=cwd)
   report['results'].append({'name':name,'command':cmd,'script':bound(script,U),**result});write(out/'receipt.json',report);assert result['status']=='passed',name+' original failure preserved'
  report['source_after']=state(U);report['web_inventory_after']=inventory();assert report['source_after']==before and report['web_inventory_after']==web_before;report['status']='passed'
 except BaseException as e:report.update(status='failed',error=type(e).__name__+': '+str(e));raise
 finally:
  if server:server.shutdown();server.server_close()
  report['seconds']=time.monotonic()-start;write(out/'receipt.json',report);print(json.dumps({k:report.get(k)for k in ['status','seconds','error']}))
if __name__=='__main__':main()
