"""Original build.py web plus exact clean before/after source guard, no extra cap."""
import argparse,json,pathlib,subprocess,sys,time
from common import ROOT,state,fresh,write,sha,bound

def main():
 p=argparse.ArgumentParser();p.add_argument('--expected-commit',required=True);p.add_argument('--output',type=pathlib.Path,required=True);a=p.parse_args();before=state(a.expected_commit);out=fresh(a.output);cmd=[sys.executable,'tools/build.py','web'];r={'status':'running','execution_head':a.expected_commit,'source_before':before,'command':cmd,'build_source':bound(ROOT/'tools/build.py',a.expected_commit),'extra_outer_cap':None,'environment':{'platform':sys.platform,'python':sys.version},'scope':'Actual exact-source local export only; no CI/public/browser/native/device claim.'};write(out/'receipt.json',r);start=time.monotonic()
 try:
  with (out/'build-web.log').open('w') as log:result=subprocess.run(cmd,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
  r.update(exit_code=result.returncode,seconds=time.monotonic()-start,log_sha256=sha(out/'build-web.log'));assert result.returncode==0
  r['source_after']=state(a.expected_commit);r['source_stable']=before==r['source_after'];assert r['source_stable'];info=json.loads((ROOT/'build/web/build-info.json').read_text());assert info['source_commit']==a.expected_commit;r.update(build_info=info,pack_sha256=sha(ROOT/'build/web'/info['pack']),status='passed')
 except BaseException as e:r.update(status='failed',error=type(e).__name__+': '+str(e));raise
 finally:write(out/'receipt.json',r);print(json.dumps({k:r.get(k)for k in ['status','execution_head','exit_code','seconds','error']}))
if __name__=='__main__':main()
