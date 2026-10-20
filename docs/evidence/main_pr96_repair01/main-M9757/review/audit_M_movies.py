from pathlib import Path
import json,hashlib,subprocess,sys,importlib.util,re,time
from PIL import Image
R=Path.cwd();sys.path.insert(0,str(R/'tools'));out=R/'build/forest_revision04/main-M-review';base=R/'build/forest_revision04/main-movie-derivatives-M9757';native=R/'build/forest_revision04/main-movies-M9757';M='9757ddf2ee20b5620c4a34ecc5d51186f018513b'
def sha(p):
 h=hashlib.sha256()
 with p.open('rb') as f:
  for b in iter(lambda:f.read(1048576),b''):h.update(b)
 return h.hexdigest()
def load(p):return json.loads(p.read_text())
s=load(base/'summary.json');r=load(native/'receipt.json');assert r['status']=='passed' and r['execution_head']==M and r['source_stable'] is True and r['source_before']==r['source_after'];assert s['execution_head']==M and s['source_stable'] and s['source_before']==s['source_after'];assert s['native_wrapper_receipt_sha256']==sha(native/'receipt.json')
assert r['caps']=={'import_per_map_seconds':90,'native_per_map_seconds':240,'extra_combined_outer_timer':None}
assert len(r['maps'])==2 and r['not_executed_maps']==[]
for path,decl in [('run_main_movies.py',r['driver_sha256']),('derive_main_movies.py',s['driver_sha256']),('common.py',s['common_sha256'])]:assert sha(R/'build/forest_revision04/main-delivery-prepared'/path)==decl
assert s['common_sha256']==r['driver_common_sha256']
for p in ['tools/run_forest_depth_region.py','tests/forest_depth_region_runner.gd','tests/forest_depth_region_trace.gd','scripts/generation/stage_camera_rig.gd','scripts/demo/demo_app.gd','scripts/world/forest_target_hosts.gd','scripts/world/forest_fruit_anchor.gd']:
 b=(R/p).read_bytes();assert b==subprocess.check_output(['git','show',M+':'+p]);assert hashlib.sha256(b).hexdigest()==r['source_before']['inventory'][p]
spec=importlib.util.spec_from_file_location('original_region_validator',R/'tools/run_forest_depth_region.py');v=importlib.util.module_from_spec(spec);spec.loader.exec_module(v)
commands=load(base/'commands.json');assert all(c['status']=='passed' and c['exit_code']==0 for c in commands)
results=[]
for index,count,bodies,legs in [(1,2290,2274,24),(2,2788,2772,29)]:
 a=load(base/f'map{index}/event-frame-index.json');nr=load(native/f'map{index}/receipt.json');row=nr['runs'][0];c=load(R/a['capture']);outer=r['maps'][index-1]
 assert outer['status']=='passed' and outer['exit_code']==0 and outer['source_stable'] and outer['source_before']==outer['source_after']==r['source_before'];assert outer['import_cap_seconds']==90 and outer['native_cap_seconds']==240 and outer['combined_outer_cap_seconds'] is None
 assert sha(native/f'map{index}-outer.log')==outer['log_sha256'];assert sha(native/f'map{index}/receipt.json')==a['native_receipt_sha256']==outer['native_receipt_sha256']
 assert nr['source_head']==M and nr['source_stable'] and nr['source_before']==nr['source_after'] and nr['status']=='passed'
 assert nr['import']['exit_code']==0 and nr['import']['errors']==[] and nr['import']['timeout_seconds']==90
 assert nr['requested_cases']==[{'seed':'forest-depth-hollow-00','map':index,'route':'high_return'}] and len(nr['runs'])==1 and nr['completed_case_indices']==[0] and nr['not_executed_case_indices']==[]
 assert row['exit_code']==0 and row['status']=='passed' and row['errors']==[] and row['movie']['errors']==[]
 assert '--headless' not in row['argv'] and '--disable-render-loop' not in row['argv'] and not any('--layout'in x for x in row['argv']);assert row['argv'][row['argv'].index('--fixed-fps')+1]=='60' and row['argv'][row['argv'].index('--rendering-method')+1]=='gl_compatibility'
 assert c['manifest']['layout_version']=='forest-fruit-routes-v14' and len(c['frames'])==bodies and len(c['completed_legs'])==len(c['itinerary'])==legs and c['manual_motor_step'] is False and c['position_or_resource_injection'] is False
 assert v.validate(c)==[] and v.validate_movie_timeline(c,count)==[]
 assert sha(R/a['capture'])==a['capture_sha256']==row['capture_sha256'];assert sha(R/a['avi'])==a['avi_sha256']==row['movie']['sha256'] and (R/a['avi']).stat().st_size==a['avi_bytes'];assert sha(R/a['mp4'])==a['mp4_sha256'] and (R/a['mp4']).stat().st_size==a['mp4_bytes']
 for name in ['avi','mp4']:
  pr=load(base/f'map{index}/{name}-ffprobe.json');video=next(x for x in pr['streams'] if x['codec_type']=='video');audio=next(x for x in pr['streams'] if x['codec_type']=='audio');assert (video['width'],video['height'])==(1280,720) and video['avg_frame_rate']==video['r_frame_rate']=='60/1' and int(video['nb_read_frames'])==count;assert audio['sample_rate']=='48000' and audio['channels']==2
 images=[]
 for f in a['frames']:
  assert c['events'][f['event_index']]==f['event'] and f['event_presentation_frame']==f['event']['presentation_frame'] and f['avi_frame_index_zero_based']==f['event_presentation_frame']+f['avi_frame_offset_from_event'];assert f['movie_time_seconds']==f['avi_frame_index_zero_based']/60
  assert json.loads(f['caption'])==f['event_fields']=={k:f['event'][k] for k in ['kind','leg','target','mapped_target','anchor'] if k in f['event']}
  assert sha(R/f['png'])==f['sha256'] and (R/f['png']).stat().st_size==f['bytes'];im=Image.open(R/f['png']);assert im.size==(1280,720);images.append(im.convert('RGB').tobytes())
 assert len(images)==16 and [x['avi_frame_offset_from_event'] for x in a['frames'][:3]]==[-1,0,8]
 # Independent decoder-only replay, no native, re-encoding or PNG mutation.
 expr='+'.join('eq(n\\,%d)'%f['avi_frame_index_zero_based'] for f in a['frames']);cmd=['ffmpeg','-hide_banner','-loglevel','error','-threads','1','-filter_threads','1','-i',str(R/a['avi']),'-map','0:v:0','-vf','select='+expr,'-fps_mode','vfr','-pix_fmt','rgb24','-f','rawvideo','-threads','1','pipe:1'];start=time.monotonic();actual=subprocess.run(cmd,capture_output=True,timeout=60);assert actual.returncode==0 and len(actual.stdout)==1280*720*3*16
 for n,expected in enumerate(images):assert actual.stdout[n*len(expected):(n+1)*len(expected)]==expected,('wrong original AVI pixels',index,n)
 log=(R/a['capture']).with_name('native.log');assert sha(log)==row['log_sha256'];txt=log.read_text();assert not any(x in txt for x in ['SCRIPT ERROR','ERROR:','resources still in use at exit','ObjectDB instances leaked at exit'])
 timing=next(x for x in txt.splitlines() if 'frames at 60 FPS'in x)
 results.append({'map':index,'actual_source':M,'actual_completed_legs':legs,'actual_physics_observations':bodies,'original_validator_replayed':True,'movie_timeline_validator_replayed':True,'AVI_sha256':a['avi_sha256'],'MP4_sha256':a['mp4_sha256'],'all_media_hashes_verified':True,'AVI_video_frames':count,'fps':60,'movie_seconds':count/60,'original_native_log_timing':timing,'original_native_cap_seconds':240,'original_import_cap_seconds':90,'outer_seconds_with_initialization_postprocess':outer['seconds'],'row_seconds_including_display_probe':row['seconds'],'selected_16_images_original_AVI_exact_RGB_equal':True,'independent_decode_seconds':time.monotonic()-start,'independent_decoder_command':cmd,'viewed_images':[{'path':f['png'],'SHA256':f['sha256'],'AVI_zero_based_frame':f['avi_frame_index_zero_based'],'event':f['event_fields'],'offset':f['avi_frame_offset_from_event']} for f in a['frames']],'benign_preserved_native_warning':'Low available disk warning; completed AVI/source/exit guards pass. Not converted to a failed native run.'})
(out/'M_movies_independent_audit.json').write_text(json.dumps({'source_commit':M,'decision':'SCOPED_ACCEPT','maps':results,'source_before_after_equal':True,'original_caps_preserved':True,'selected32_all_exact_AVI_pixel_replay':True,'no_native_or_transcode_launched':True},ensure_ascii=False,indent=2)+'\n');print(json.dumps({'status':'passed','maps':[{k:d[k] for k in ['map','actual_completed_legs','AVI_video_frames','selected_16_images_original_AVI_exact_RGB_equal','independent_decode_seconds']}for d in results]},ensure_ascii=False))
