"""Postprocess an immutable failed-wrapper/native-PASS take; never reruns Godot."""
from pathlib import Path
import hashlib,json,subprocess,time
root=Path(__file__).resolve().parents[3]
out=Path(__file__).resolve().parent
original=root/'build/item_art_01/world-plains-dev-04'
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
inputs={p.name:sha(p) for p in [original/'raw.avi',original/'trace.json',original/'receipt.json',original/'capture.log']}
receipt=json.loads((original/'receipt.json').read_text());trace=json.loads((original/'trace.json').read_text())
assert receipt['status']=='failed' and receipt['error']=='RuntimeError: Actual derivative is not H264 normal60fps1280x720'
assert receipt['engine_exit_code']==0 and receipt['source_stable'] and receipt['source_before']==receipt['source_after']
assert trace['checks']==19 and not trace['failures']
start,end=trace['world_begin_drawn'],trace['world_end_drawn'];assert end-start==720
observations=[r for r in trace['frames'] if start<r['drawn_frame']<=end]
assert len({(r['session'],r['actor_epoch'],r['stage_epoch']) for r in observations})==1
assert all(r['fixture_note']=='美术验证：道具/共鸣/站位为测试初始化' and not r['paused'] for r in observations)
for origin in ['P24','P14']:
 assert any(r['derived'] and r['damage']>0 and '/'+origin+'/' in r['event'] for r in trace['damage_receipts'])
command=['ffmpeg','-y','-i',str(original/'raw.avi'),'-vf',f'trim=start_frame={start}:end_frame={end},setpts=N/(60*TB)','-af',f'atrim=start={start/60}:end={end/60},asetpts=PTS-STARTPTS','-r','60','-fps_mode','cfr','-c:v','libx264','-crf','20','-pix_fmt','yuv420p','-c:a','aac','-ar','48000','-ac','2','-movflags','+faststart',str(out/'world.mp4')]
started=time.monotonic()
with (out/'encode.log').open('w') as log:subprocess.run(command,check=True,stdout=subprocess.DEVNULL,stderr=log,timeout=150)
media=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(out/'world.mp4')],timeout=30))
v=next(s for s in media['streams'] if s['codec_type']=='video');a=[s for s in media['streams'] if s['codec_type']=='audio']
assert v['codec_name']=='h264' and v['avg_frame_rate']=='60/1' and int(v['nb_frames'])==720 and (v['width'],v['height'])==(1280,720)
assert len(a)==1 and a[0]['codec_name']=='aac' and a[0]['sample_rate']=='48000' and a[0]['channels']==2
assert float(v['duration'])==12 and 12<=float(media['format']['duration'])<=12.1
images=[]
for name,frame in [('active',35),('patrol',100),('jump',155),('observe',660)]:
 p=out/(name+'.png');subprocess.run(['ffmpeg','-y','-i',str(out/'world.mp4'),'-vf',f'select=eq(n\\,{frame})','-frames:v','1',str(p)],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=30)
 assert p.exists();images.append({'path':p.name,'sha256':sha(p),'world_video_frame':frame,'original_video_frame':start+frame,'original_completed_drawn_frame':start+frame+1})
assert inputs=={p.name:sha(p) for p in [original/'raw.avi',original/'trace.json',original/'receipt.json',original/'capture.log']}
report={'schema':'item-art-real-world-explicit-postprocess-v1','status':'development_derived_media_pass','development':True,'engine_rerun':False,'original_failed_wrapper_preserved':True,'original_directory':str(original.relative_to(root)),'original_inputs_before':inputs,'original_inputs_after':inputs,'original_source_commit':receipt['source_commit'],'original_source_before':receipt['source_before'],'original_source_after':receipt['source_after'],'original_source_stable':True,'original_native_checks':trace['checks'],'original_native_failures':trace['failures'],'original_wrapper_error':receipt['error'],'processor':str(Path(__file__).resolve().relative_to(root)),'processor_sha256':sha(Path(__file__)),'command':command,'original_segment_start_frame':start,'original_segment_end_exclusive':end,'frames':720,'media':media,'images':images,'world_mp4_sha256':sha(out/'world.mp4'),'wall_seconds':time.monotonic()-started,'scope':'Separate corrected constant60fps media derived from immutable Plains04 nativePASS19/0. Original wrapper failed trimming-duration validation and remains failed. No Godot rerun, no fresh frozen-source claim; dirty development producer identities are retained in original full inventory. R/patrol actual EnemyActor HP, original AI/hazard/collision and one pose retained. Actual pixel/motion review and device/listening acceptance remain separate.'}
(out/'receipt.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print('PASS: explicit development postprocess720frames60fps12s original48k stereo; no engine rerun')
