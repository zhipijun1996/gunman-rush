"""Mocked Python orchestration only; never launches Godot/Xvfb/FFmpeg.
Failed rendered_report files in mock_* folders are fixtures, not game captures.
"""
import json,sys,hashlib,os
from pathlib import Path
from unittest.mock import patch
R=Path.cwd();O=R/'build/plains_redesign/review_root_revisions';sys.path.insert(0,str(R/'tools'));import level_visual_capture as v
sha=hashlib.sha256(Path(v.__file__).read_bytes()).hexdigest();results=[]
for name,explicit,drift in [('default_lp1',None,False),('explicit_lp7','7',False),('producer_drift',None,True)]:
 env={'DISPLAY':':review-fixture'}
 if explicit is not None:env['LP_NUM_THREADS']=explicit
 folder=O/('mock_orchestration_'+name);observed={};calls=[0];original_read=Path.read_bytes
 def readbytes(path):
  if Path(path).resolve()==Path(v.__file__).resolve():
   calls[0]+=1
   if drift and calls[0]>1:return b'independent simulated changed producer'
  return original_read(path)
 def fake_run(check,log,cwd,env):
  observed.update(environment={k:env[k] for k in ['LIBGL_ALWAYS_SOFTWARE','LP_NUM_THREADS']},argv=check['argv']);return {'status':'passed' if drift else 'failed','exit_code':0 if drift else 1}
 with patch.dict(os.environ,env,clear=True),patch.object(v.level_formal,'source_files',return_value={'explicit-mock-source':'a'*64}),patch.object(v.subprocess,'check_output',return_value='0f868c290ac3e250cd09375450399f4da4dc0e23'),patch.object(v.harness,'run_check',side_effect=fake_run),patch.object(Path,'read_bytes',readbytes):
  try:v.capture('explicit-orchestration-fixture',1,'return',folder,encounter_policy='kill_from_bank_v1')
  except RuntimeError as error:observed['error']=str(error)
  else:raise AssertionError('mocked failing producer unexpectedly accepted')
 report=json.loads((folder/'rendered_report.json').read_text());assert report['status']=='failed';assert report['producer']['sha256']==sha;assert report['render_environment']==observed['environment'];assert report['render_environment']['LP_NUM_THREADS']==('7' if explicit else '1');assert report['request']['encounter_policy']=='kill_from_bank_v1';assert '--encounter-policy=kill_from_bank_v1' in observed['argv'];results.append(dict(case=name,actual_subprocesses=0,mocked=True,expected_rejected=True,producer_sha256=report['producer']['sha256'],render_environment=report['render_environment'],error=report['error']))
(O/'visual_orchestration_results.json').write_text(json.dumps(results,indent=2));print('VISUAL PYTHON ORCHESTRATION',len(results),'explicitly mocked controls; no subprocess')
