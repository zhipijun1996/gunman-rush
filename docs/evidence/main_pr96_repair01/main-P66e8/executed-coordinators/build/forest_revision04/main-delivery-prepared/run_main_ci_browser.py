"""Prepared API-bound CI ZIP -> unchanged three original browser consumers."""
import argparse,json,subprocess,sys,time
from pathlib import Path
from common import ROOT,state,fresh,write,sha,bound

def main():
 p=argparse.ArgumentParser();p.add_argument('--expected-commit',required=True);p.add_argument('--run-api',type=Path,required=True);p.add_argument('--artifact-api',type=Path,required=True);p.add_argument('--artifact-zip',type=Path,required=True);p.add_argument('--run-id',type=int,required=True);p.add_argument('--attempt',type=int,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 before=state(a.expected_commit);run=json.loads(a.run_api.read_text());api=json.loads(a.artifact_api.read_text())
 assert run['id']==a.run_id and run['head_sha']==a.expected_commit and run['run_attempt']==a.attempt and run['status']=='completed' and run['conclusion']=='success'
 assert api['name']=='gunman-rush-web-playtest' and not api.get('expired',False) and api['workflow_run']['id']==a.run_id and api['workflow_run']['head_sha']==a.expected_commit
 assert api['digest']=='sha256:'+sha(a.artifact_zip) and api['size_in_bytes']==a.artifact_zip.stat().st_size
 out=fresh(a.output);r={'status':'running','execution_head':a.expected_commit,'source_before':before,'input_hashes':{str(p):sha(p) for p in [a.run_api,a.artifact_api,a.artifact_zip]},'coordinator':bound(ROOT/'tools/verify_ci_artifact_browser.py',a.expected_commit),'original_consumer_caps_seconds_each':300,'extra_combined_timer':None,'scope':'Exact API-selected CI artifact gunman-rush-web-playtest. Original action budget/studio click/all weapon browser consumers; no public deployment/native film/device/fullforest claim.'}
 cmd=[sys.executable,'tools/verify_ci_artifact_browser.py','--run-api',str(a.run_api.resolve()),'--artifact-api',str(a.artifact_api.resolve()),'--artifact-zip',str(a.artifact_zip.resolve()),'--commit',a.expected_commit,'--run-id',str(a.run_id),'--attempt',str(a.attempt),'--output',str(out/'original')];r['argv']=cmd;write(out/'outer.json',r);start=time.monotonic()
 try:
  with (out/'outer.log').open('w') as log:result=subprocess.run(cmd,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
  r.update(exit_code=result.returncode,seconds=time.monotonic()-start,log_sha256=sha(out/'outer.log'));write(out/'outer.json',r);r['source_after']=state(a.expected_commit);r['source_stable']=before==r['source_after'];assert result.returncode==0 and r['source_stable']
  original=json.loads((out/'original/receipt.json').read_text());assert original['status']=='passed' and len(original['browser_results'])==3;r['status']='passed'
 except BaseException as e:r.update(status='failed',error=type(e).__name__+': '+str(e));raise
 finally:write(out/'outer.json',r)
if __name__=='__main__':main()
