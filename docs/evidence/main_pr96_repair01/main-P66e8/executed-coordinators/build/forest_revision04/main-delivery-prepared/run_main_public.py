"""Execute original full-public-bytes and original forest GUI, then finite selector supplement.
No combined timer or changed original consumer caps. New ignored evidence only.
"""
import argparse,json,os,subprocess,sys,time
from pathlib import Path
from common import ROOT,state,fresh,write,sha,bound

def main():
 p=argparse.ArgumentParser();p.add_argument('--expected-commit',required=True);p.add_argument('--ci-receipt',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 before=state(a.expected_commit);ci=json.loads(a.ci_receipt.read_text());assert ci['status']=='passed' and ci['source_commit']==a.expected_commit and len(ci['browser_results'])==3
 info=ci['build_info'];artifact=ci['artifact_receipt'];bundle=Path(ci['served_directory']);assert info['source_commit']==a.expected_commit
 out=fresh(a.output);url='https://zhipijun1996.github.io/gunman-rush/'
 selector=ROOT/'build/forest_revision04/selector-popup-M-prepared/capture_selector_popup.py'
 commands=[('full-public-bytes',[sys.executable,'tools/underworld_delivery.py','public-bytes','--source',a.expected_commit,'--bundle',str(bundle),'--url',url,'--output',str(out/'public-bytes.json')]),('original-forest-GUI',[sys.executable,'tools/verify_forest_browser.py',url,'--expected-commit',a.expected_commit,'--expected-build-id',info['build_id'],'--expected-forest-version','thorn-forest-region-v2','--expected-forest-layout','forest-fruit-routes-v14','--proxy-from-environment','--output-dir',str(out/'forest-GUI')]),('finite-selector-supplement',[sys.executable,str(selector),url,'--output-dir',str(out/'selector'),'--expected-commit',a.expected_commit,'--expected-build-id',info['build_id'],'--expected-pck-sha256',artifact['pack_sha256'],'--expected-pack-bytes',str(info['pack_bytes']),'--proxy-from-environment'])]
 report={'status':'running','execution_head':a.expected_commit,'source_before':before,'ci_receipt_sha256':sha(a.ci_receipt),'build_info':info,'expected_pack_sha256':artifact['pack_sha256'],'original_consumer_caps_seconds':{'forest_GUI':480,'selector_supplement':120,'combined':None},'commands':[],'bound_sources':[bound(ROOT/x,a.expected_commit) for x in ['tools/underworld_delivery.py','tools/verify_forest_browser.py']],'supplement_source_sha256':sha(selector),'scope':'Public complete PCK and licenses; original20/8 real mouse/CDP-touch forest GUI; finite CJK selector pixels await independent review. No human/device/FUN or whole-region visual acceptance.'}
 write(out/'outer.json',report)
 try:
  for name,cmd in commands:
   state(a.expected_commit);start=time.monotonic();log=out/(name+'.log');entry={'name':name,'command':cmd,'started_at_unix':time.time()};report['commands'].append(entry);write(out/'outer.json',report)
   with log.open('w') as stream:result=subprocess.run(cmd,cwd=ROOT,stdout=stream,stderr=subprocess.STDOUT,env=os.environ.copy())
   entry.update(exit_code=result.returncode,seconds=time.monotonic()-start,log_sha256=sha(log));write(out/'outer.json',report);assert result.returncode==0,name+' original failure preserved';entry['source_after']=state(a.expected_commit);assert entry['source_after']==before
  report.update(status='passed',source_after=state(a.expected_commit));assert report['source_after']==before
 except BaseException as e:report.update(status='failed',error=type(e).__name__+': '+str(e));raise
 finally:write(out/'outer.json',report)
if __name__=='__main__':main()
