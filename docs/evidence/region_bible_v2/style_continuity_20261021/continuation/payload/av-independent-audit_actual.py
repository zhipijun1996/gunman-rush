import sys,json,struct,hashlib,subprocess,wave,math,copy,re
from pathlib import Path
from collections import Counter
from array import array
from PIL import Image
root=Path.cwd();sys.path.insert(0,str(root/'tools'));import capture_forest_bible_route as av
src=Path(sys.argv[1]);challenge=sys.argv[2];out=Path(sys.argv[3]);out.mkdir(parents=True,exist_ok=True)
r=json.loads((src/'receipt.json').read_text());d=json.loads((src/'trace.json').read_text());rawcopy=copy.deepcopy(d)
assert r['exit_code']==0 and r['source_stable'] is True and r['source_after_import']==r['source_after']
source_before=r['source_after_import'];assert source_before==av.inventory()
assert r['provenance_before']['head']==r['provenance_after']['head']
artifacts=[]
for name,row in r['artifacts'].items():
 p=src/name;actual=av.sha(p);assert p.stat().st_size==row['bytes'] and actual==row['sha256'],name;artifacts.append({'path':name,'sha256':actual,'bytes':p.stat().st_size})
probe=[]
for name in ['original.avi','playback.mp4']:
 cmd=['ffprobe','-v','error','-count_packets','-show_entries','stream=index,codec_name,codec_type,width,height,avg_frame_rate,nb_frames,nb_read_packets,duration,sample_rate,channels,bits_per_sample','-of','json',str(src/name)]
 result=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=60,check=True);data=json.loads(result.stdout);(out/(name+'.independent.ffprobe.json')).write_bytes(result.stdout)
 video=[x for x in data['streams'] if x['codec_type']=='video'];audio=[x for x in data['streams'] if x['codec_type']=='audio'];assert len(video)==len(audio)==1
 v,a=video[0],audio[0];assert (v['width'],v['height'],v['avg_frame_rate'])==(1280,720,'60/1');assert a['sample_rate']=='48000' and a['channels']==2
 probe.append({'path':name,'argv':cmd,'video':v,'audio':a})
count=int(probe[0]['video']['nb_read_packets']);assert count==int(probe[1]['video']['nb_read_packets'])==r['checks']['raw_media']['frames']==r['checks']['mp4_media']['frames']
assert probe[0]['audio']['codec_name']=='pcm_s16le' and probe[1]['audio']['codec_name']=='aac'
route=av.verify_trace(d,challenge,r['map']);timeline=av.verify_movie_timeline(d,count,challenge);keys=av.keyframes(d,count,challenge)
assert [{k:row[k] for k in ['frame','events']} for row in r['keyframes']]==keys and len(keys)<=6
# Independently bind every physical frame to its actual unique drawn frame and
# every physics event/request to a real Engine counter. No tick-derived movie times.
frames=d['frames'];assert [x['tick'] for x in frames]==list(range(1,len(frames)+1));byengine={x['engine_physics_frame']:x for x in frames};assert len(byengine)==len(frames)
assert all(x['health']==5 and x['motor_steps']==1 and x['observation_phase']=='physics' for x in frames)
assert all(a['presentation_frame']<b['presentation_frame'] for a,b in zip(frames,frames[1:]))
for group in ['events','requests']:
 for row in d[group]:
  assert 0<=row['presentation_frame']<count
  if row['observation_phase']=='physics':
   frame=byengine[row['engine_physics_frame']];assert row['tick'] in [frame['tick']-1,frame['tick']];assert (row['presentation_frame'],row['process_frame'])==(frame['presentation_frame'],frame['process_frame'])
# Parse original MovieWriter AVI chunks without decoding/re-encoding full movie.
# Read only six actual JPEG packets; stream original PCM chunks for hash custody.
selected={x['frame']:x for x in r['keyframes']};packets={};audiohash=hashlib.sha256();audio_bytes=0;video_packets=0;audio_packets=0
with (src/'original.avi').open('rb') as f:
 header=f.read(12);assert header[:4]==b'RIFF' and header[8:]==b'AVI ';declared_riff_extent=struct.unpack('<I',header[4:8])[0]+8;limit=(src/'original.avi').stat().st_size
 def chunks(start,end):
  global video_packets,audio_packets,audio_bytes
  offset=start
  while offset+8<=end:
   f.seek(offset);tag,n=struct.unpack('<4sI',f.read(8));payload=offset+8;assert payload+n<=end
   if tag==b'LIST':
    listtype=f.read(4)
    if listtype in (b'movi',b'rec '):chunks(payload+4,payload+n)
   elif tag in (b'00dc',b'00db'):
    if video_packets in selected:
     f.seek(payload);data=f.read(n);assert data[:2]==b'\xff\xd8';packets[video_packets]=(payload,data)
    video_packets+=1
   elif tag==b'01wb':
    f.seek(payload);data=f.read(n);audiohash.update(data);audio_bytes+=n;audio_packets+=1
   offset=payload+n+(n&1)
 chunks(12,limit)
assert video_packets==count and len(packets)==len(selected)
with wave.open(str(src/'original.wav'),'rb') as f:
 assert (f.getnchannels(),f.getsampwidth(),f.getframerate())==(2,2,48000)
 wavframes=f.getnframes();wavhash=hashlib.sha256();squared=nonzero=peak=nums=0
 while block:=f.readframes(48000):
  wavhash.update(block);vals=array('h',block)
  if sys.byteorder!='little':vals.byteswap()
  squared+=sum(v*v for v in vals);nonzero+=sum(v!=0 for v in vals);peak=max(peak,max(abs(v) for v in vals));nums+=len(vals)
assert audiohash.hexdigest()==wavhash.hexdigest() and audio_bytes==wavframes*4 and wavframes==count*800 and peak>0
pixel=[]
for n,row in selected.items():
 pos,jpeg=packets[n]
 cmd=['ffmpeg','-nostdin','-v','error','-threads','1','-f','mjpeg','-i','pipe:0','-frames:v','1','-threads','1','-pix_fmt','rgb24','-f','rawvideo','pipe:1']
 p=subprocess.run(cmd,input=jpeg,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=20,check=True)
 with Image.open(src/row['path']) as image:png=image.convert('RGB').tobytes();assert image.size==(1280,720)
 equal=p.stdout==png
 pixel.append({'frame':n,'events':row['events'],'source_png':row['path'],'original_jpeg_byte_offset':pos,'original_jpeg_bytes':len(jpeg),'isolated_actual_packet_decode_argv':cmd,'decoded_rgb_bytes':len(p.stdout),'png_rgb_sha256':hashlib.sha256(png).hexdigest(),'isolated_actual_jpeg_rgb_sha256':hashlib.sha256(p.stdout).hexdigest(),'all_RGB_pixels_exactly_equal':equal,'stderr':p.stderr.decode()})
 assert equal,(n,'actual PNG differs from same original AVI packet')
assert d==rawcopy and source_before==av.inventory()
report={'verdict':'SCOPED_ACCEPT_actual_F05_AV' if challenge=='F05' else 'SCOPED_ACCEPT_actual_F08_AV','scope':'Independent full actual trace/timeline audit, original PCM custody, video packet/frame metadata, and at most6 original-frame pixel+visual samples; not full continuous visual watching or perceptual listening','source':str(src),'head':r['provenance_before']['head'],'source_before_after_and_current_full_inventory_equal':True,'source_files':len(source_before),'artifacts_verified':artifacts,'native_budget_seconds':240,'native_log_recorded_seconds':180 if challenge=='F05' else None,'wrapper_total_seconds':r['elapsed_seconds'],'route':route,'complete_timeline':timeline,'independent_media_probe':probe,'video_frame_count':count,'movie_seconds':count/60,'original_AVI_RIFF_declared_bytes':declared_riff_extent,'original_AVI_file_bytes':limit,'original_AVI_RIFF_header_short_by_bytes':limit-declared_riff_extent,'original_AVI_video_chunks':video_packets,'original_AVI_audio_chunks':audio_packets,'original_PCM':{'sample_frames':wavframes,'seconds':wavframes/48000,'channels':2,'bits':16,'sample_rate':48000,'AVI_PCM_bytes':audio_bytes,'AVI_PCM_sha256':audiohash.hexdigest(),'WAV_PCM_sha256':wavhash.hexdigest(),'AVI_WAV_PCM_byte_identical':True,'peak_pcm16':peak,'rms_pcm16':math.sqrt(squared/nums),'nonzero_samples':nonzero,'perceptual_listening_acceptance':False,'physical_device_playback_acceptance':False},'six_or_fewer_original_frame_pixel_replays':pixel,'visual_review':{'actual_images_viewed':len(pixel),'continuous_movie_watched':False,'findings_pending':True},'raw_trace_unmodified':d==rawcopy,'engine_executed_by_reviewer':False,'full_movie_reencoding_by_reviewer':False,'reviewer_decodes':'Only the selected original JPEG packets decoded independently; AVI/MP4 separately ffprobed. No gameplay/engine run.'}
(out/'review.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'verdict':report['verdict'],'source_files':report['source_files'],'physics_samples':route['physics_samples'],'video_frames':count,'PCM_sample_frames':wavframes,'PCM_bytes_equal':True,'selected_frames_RGB_exact':len(pixel),'raw_preserved':d==rawcopy},indent=2))
