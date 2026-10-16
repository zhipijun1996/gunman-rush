from pathlib import Path
import sys,json,os,time,subprocess
root=Path('/workspace/gunman-rush');sys.path.insert(0,str(root/'tools'));import level_formal,level_visual_capture
os.environ.update(LP_NUM_THREADS='1',LIBGL_ALWAYS_SOFTWARE='1')
folder=root/'build/plains_redesign/q6_rework/golden2';folder.mkdir(exist_ok=True)
source=level_formal.source_files();r={'source':source,'commands':[],'scope':'same API controlled before/after bounded prefixes, not full routes'}
try:
 for name,m,s,b in [('clock_return',1,'return',1100),('creek_growth',2,'growth',2600)]:
  args=dict(seed='level-design-v2-baseline',map_index=m,strategy=s,folder=str(folder/name),max_ticks=b,timeout=600,encounter_policy='kill_from_bank_v1')
  r['commands'].append({'api':'level_visual_capture.capture','arguments':args,'started':time.time()});(folder/'execution.json').write_text(json.dumps(r,indent=2)+'\n')
  result=level_visual_capture.capture(**args);r['commands'][-1].update(status=result['status'],outcome=result['outcome'],ticks=result['tick_count'],finished=time.time())
  assert source==level_formal.source_files()
 r['status']='captured'
finally:(folder/'execution.json').write_text(json.dumps(r,indent=2)+'\n')
