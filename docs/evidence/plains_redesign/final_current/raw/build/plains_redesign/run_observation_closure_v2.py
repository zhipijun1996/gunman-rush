"""Independent remaining observation after original actual outer-route failure. No retry/quality pass."""
from pathlib import Path
import json,hashlib,subprocess,sys,time,os
R=Path('/workspace/gunman-rush');B=R/'build/plains_redesign';P=B/'observation_closure_v2.json';assert not P.exists()
sys.path.insert(0,str(R/'tools'));import level_formal
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
original=B/'remaining_after_gui_fix_execution.json';assert json.loads(original.read_text())['status']=='blocked_outer_circuit_movie'
assert json.loads((B/'worst_movie_execution.json').read_text())['status']=='blocked_original_queue'
assert json.loads((B/'map_execution.json').read_text())['status']=='blocked_movie_queue'
source=level_formal.source_files();env=os.environ.copy();env.update(LP_NUM_THREADS='1',LIBGL_ALWAYS_SOFTWARE='1',MPLBACKEND='Agg')
d={'status':'running','scope':'Collect independent remaining evidence after a real FAILED outer route; never retry or mark that route passed. Original queue/receipts stay blocked/failed. New step success means media collection/projection only, not play quality.','original_queue_sha256':sha(original),'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=R,text=True).strip(),'source_before':source,'stages':[]}
def save():P.write_text(json.dumps(d,indent=2)+'\n')
def run(name,argv,timeout):
 row={'name':name,'argv':argv,'started_utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),'log':f'build/plains_redesign/closure_v2_{name}.log'};d['stages'].append(row);save()
 with (R/row['log']).open('w') as f:r=subprocess.run(argv,cwd=R,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=timeout)
 row.update(exit_code=r.returncode,finished_utc=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()));assert source==level_formal.source_files(),'Source drift';save();assert r.returncode==0,(name,r.returncode)
save()
try:
 folder=B/'final_outer_movie';capture=folder/'capture.json';receipt=folder/'receipt.json';log=folder/'capture.log';avi=folder/'gameplay.avi';mp4=folder/'gameplay.mp4';meta=folder/'failed_media.json'
 assert not mp4.exists() and not meta.exists();raw=json.loads(capture.read_text());old=json.loads(receipt.read_text());case=raw['cases'][0]
 assert old['status']=='failed' and old['process']['exit_code']==1 and raw['failures']>0 and case['outcome']=='scene_custom_route_failed'
 assert old['source_files']==source
 originals={str(p.relative_to(R)):sha(p) for p in [capture,receipt,log,avi]}
 run('encode_failed_outer',['ffmpeg','-i',str(avi),'-c:v','libx264','-crf','21','-pix_fmt','yuv420p','-c:a','aac',str(mp4)],180)
 media=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(mp4)],timeout=30))
 video=next(s for s in media['streams'] if s['codec_type']=='video');audio=next(s for s in media['streams'] if s['codec_type']=='audio')
 assert video['width']==1280 and video['height']==720 and video['avg_frame_rate']=='60/1' and int(audio['sample_rate'])==48000 and audio['channels']==2
 assert all(sha(R/p)==v for p,v in originals.items())
 meta.write_text(json.dumps({'status':'failed_route_media_preserved','scope':'Full original FAILED attempt converted only; NOT a completed outer circuit. Original native7assert/1fail and original producerexit1 preserved. Original producer lacks source_after after its assertion; current source equality independently checked at encoding, not relabelled as original after receipt.','source_commit':d['source_commit'],'source_at_encoding':source,'original_artifact_sha256':originals,'movie_sha256':sha(mp4),'media':media,'outcome':case['outcome'],'ticks':case['ticks'],'original_assertions':raw['assertions'],'original_failures':raw['failures'],'actual_route_comparison':case['route_comparison']},indent=2)+'\n')
 d['outer_outcome']=case['outcome'];d['failed_media_sha256']=sha(meta);save()
 wp=B/'worst_movie_v2_execution.json';assert not wp.exists();worst={'status':'running','scope':'Independent worst seed observation; original blocked monitor remains unchanged. Capture integrity success never means target reached.','started_utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime())};wp.write_text(json.dumps(worst,indent=2)+'\n')
 code="import sys;sys.path.insert(0,'tools');from level_visual_capture import capture;capture('level-design-v2-baseline/03',2,'deep','build/plains_redesign/worst_movie',max_ticks=18000,timeout=900,encounter_policy='kill_from_bank_v1')"
 run('worst_capture',['python3','-c',code],960)
 wr=json.loads((B/'worst_movie/rendered_report.json').read_text());assert wr['status']=='captured';worst.update(status='recorded',exit_code=0,outcome=wr['outcome'],report_sha256=sha(B/'worst_movie/rendered_report.json'),finished_utc=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()));wp.write_text(json.dumps(worst,indent=2)+'\n')
 run('map_projection',['python3',str(B/'plot_controlled_maps.py'),'--before-project','/workspace/plains-redesign-baseline','--after-project',str(R),'--trajectories'],300)
 d.update(status='observations_collected_with_failed_outer_route',source_after=level_formal.source_files(),finished_utc=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()));save();print('Independent observations collected; original outer route stays FAILED, quality not accepted.')
except Exception as exc:
 d.update(status='blocked',error=str(exc),source_after=level_formal.source_files());save();raise
