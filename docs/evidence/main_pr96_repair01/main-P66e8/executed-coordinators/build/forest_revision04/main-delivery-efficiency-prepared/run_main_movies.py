"""Prepared only. Original per-map import90/native240, no combined outer timer."""
import argparse,datetime,json,os,subprocess,sys,time
from pathlib import Path
from common import ROOT,state,fresh,write,sha,bound

def main():
 p=argparse.ArgumentParser();p.add_argument('--expected-commit',required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 before=state(a.expected_commit);out=fresh(a.output)
 r={'status':'running','execution_head':a.expected_commit,'source_before':before,'source_cli':bound(ROOT/'tools/run_forest_depth_region.py',a.expected_commit),'driver_sha256':sha(Path(__file__)),'driver_common_sha256':sha(Path(__file__).with_name('common.py')),'started_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'maps':[],'scope':'Fresh actual final-main native GL60fps original high_return two-map routes only; no historical H/K movie rebound, public/browser/device/full Boss/whole forest approval.','caps':{'import_per_map_seconds':90,'native_per_map_seconds':240,'extra_combined_outer_timer':None}}
 write(out/'receipt.json',r)
 try:
  for index in [1,2]:
   if state(a.expected_commit)!=before:raise AssertionError('Source inventory changed before movie')
   cmd=[sys.executable,'tools/run_forest_depth_region.py','--output',str(out/f'map{index}'),'--seed','forest-depth-hollow-00','--map',str(index),'--route','high_return','--movie']
   row={'argv':cmd,'status':'running','source_before':state(a.expected_commit),'started_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'import_cap_seconds':90,'native_cap_seconds':240,'combined_outer_cap_seconds':None,'seconds_scope':'Outer includes original import/display/recording and original inspect_movie postprocessing. Original run_region_case row.seconds also includes setup/postprocessing; neither is standalone native time.'}
   r['maps'].append(row);write(out/'receipt.json',r);start=time.monotonic()
   env={**os.environ,'LIBGL_ALWAYS_SOFTWARE':'1','LP_NUM_THREADS':'4','OMP_NUM_THREADS':'1'}
   with (out/f'map{index}-outer.log').open('w') as log:
    result=subprocess.run(cmd,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT) # Intentionally no additional total timer.
   row.update(exit_code=result.returncode,seconds=time.monotonic()-start,log_sha256=sha(out/f'map{index}-outer.log'));write(out/f'map{index}-outer.json',row);write(out/'receipt.json',r)
   row['source_after']=state(a.expected_commit)
   row['source_stable']=row['source_before']==row['source_after']==before;row['status']='passed' if result.returncode==0 and row['source_stable'] else 'failed';write(out/f'map{index}-outer.json',row);write(out/'receipt.json',r)
   if row['status']!='passed':raise RuntimeError('Original map movie failed; preserve it and stop without increasing caps/retry')
   native=json.loads((out/f'map{index}/receipt.json').read_text());assert native['source_head']==a.expected_commit and native['status']=='passed' and native['source_stable']
   assert native['import']['timeout_seconds']==90 and native['import']['exit_code']==0 and not native['import']['errors']
   assert len(native['runs'])==1 and native['requested_cases']==[{'seed':'forest-depth-hollow-00','map':index,'route':'high_return'}]
   actual=native['runs'][0];assert actual['exit_code']==0 and actual['status']=='passed' and actual['errors']==[] and actual['movie']['errors']==[]
   assert actual['software_render_threads']==min(4,os.cpu_count() or 1)
   assert not any('--layout' in arg for arg in actual['argv'])
   row['native_receipt_sha256']=sha(out/f'map{index}/receipt.json');write(out/f'map{index}-outer.json',row)
  r['source_after']=state(a.expected_commit);r['source_stable']=r['source_after']==before;r['status']='passed' if r['source_stable'] else 'failed'
 except BaseException as e:r.update(status='failed',error=type(e).__name__+': '+str(e));raise
 finally:
  r['ended_utc']=datetime.datetime.now(datetime.timezone.utc).isoformat();r['not_executed_maps']=[i for i in [1,2] if len(r['maps'])<i];write(out/'receipt.json',r)
 print(json.dumps({'status':r['status'],'execution_head':a.expected_commit,'source_stable':r['source_stable']}))
if __name__=='__main__':main()
