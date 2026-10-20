"""Prepared independent FFmpeg phase. No native/browser invocation. New outputs only."""
import argparse,datetime,json,shlex,subprocess,time
from pathlib import Path
from fractions import Fraction
from common import ROOT,state,fresh,write,sha,bound
commands=[]
OUT=None

def run(argv,timeout=120):
 record={'argv':argv,'shell_display':shlex.join(argv),'timeout_seconds':timeout,'status':'running'};commands.append(record);write(OUT/'commands.json',commands)
 start=time.monotonic()
 try:
  result=subprocess.run(argv,cwd=ROOT,capture_output=True,text=True,timeout=timeout)
  record.update(exit_code=result.returncode,seconds=time.monotonic()-start,stdout=result.stdout,stderr=result.stderr,status='passed' if result.returncode==0 else 'failed');write(OUT/'commands.json',commands)
  if result.returncode:raise RuntimeError('Derivative tool failed; preserve source/AVI/log/partial output, do not overwrite')
  return result.stdout
 except subprocess.TimeoutExpired as e:
  record.update(status='timeout',seconds=time.monotonic()-start,stdout=str(e.stdout),stderr=str(e.stderr));write(OUT/'commands.json',commands);raise

def probe(path,save):
 result=json.loads(run(['ffprobe','-v','error','-count_frames','-show_streams','-show_format','-of','json',str(path)]));write(save,result)
 video=next(s for s in result['streams'] if s['codec_type']=='video')
 assert (video['width'],video['height'])==(1280,720)
 assert Fraction(video['r_frame_rate'])==60 and Fraction(video['avg_frame_rate'])==60
 assert int(video['nb_read_frames'])>0
 return result,video

def select_events(data):
    events=data['events'];selected=[]
    def add(predicate,offset=0,last=False):
        candidates=[(i,e) for i,e in enumerate(events) if predicate(e)]
        if not candidates:return False
        i,e=candidates[-1] if last else candidates[0]
        n=int(e['presentation_frame'])+offset
        if any(s['avi_frame_index_zero_based']==n for s in selected):return False
        fields={k:e[k] for k in ('kind','leg','target','mapped_target','anchor') if k in e}
        selected.append({'event_index':i,'event_fields':fields,'event':e,'event_presentation_frame':int(e['presentation_frame']),'avi_frame_offset_from_event':offset,'avi_frame_index_zero_based':n,'caption':json.dumps(fields,ensure_ascii=False,separators=(',',':'))})
        return True
    for offset in (-1,0,8):add(lambda e:e['kind']=='jumped',offset)
    add(lambda e:e['kind']=='hook_hang')
    for target in ['broken_arch__crown_ring','upper_spiral__spiral_lower','upper_spiral__spiral_middle','upper_spiral__spiral_crown','canopy_fork__relay_a']:
        add(lambda e,t=target:e['kind']=='hook_kick' and e.get('target')==t)
    add(lambda e:e['kind']=='hook_kick' and e.get('target')=='canopy_fork__relay_a',12)
    add(lambda e:e['kind']=='air_chain_arrival' and int(e.get('leg',-1))==13)
    if not add(lambda e:e['kind']=='forest_encounter_start'):
        if not add(lambda e:e['kind']=='interwoven_crown_combat_start'):add(lambda e:e['kind']=='committed_damage')
    hollow=[e for e in events if e['kind']=='hook_kick' and str(e.get('target','')).startswith('hollow__')]
    if hollow:
        add(lambda e:e['kind']=='hook_kick' and e.get('target')==hollow[0]['target'])
        add(lambda e:e['kind']=='hook_kick' and e.get('target')==hollow[-1]['target'],last=True)
    else:
        add(lambda e:e['kind']=='hook_kick' and e.get('target')=='north_court_ring')
        add(lambda e:e['kind']=='hook_kick' and e.get('target')=='forest_crossbranch')
    add(lambda e:e['kind']=='committed_damage',last=True)
    add(lambda e:e['kind']=='phase',last=True)
    for e in events:
        if len(selected)>=16:break
        if e['kind']=='hook_kick':add(lambda x,frame=e['presentation_frame']:x['kind']=='hook_kick' and x['presentation_frame']==frame)
    assert len(selected)==16,len(selected)
    return sorted(selected,key=lambda x:x['avi_frame_index_zero_based'])

def main():
 global OUT
 p=argparse.ArgumentParser();p.add_argument('--expected-commit',required=True);p.add_argument('--movies',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 before=state(a.expected_commit);source=a.movies.resolve();original=json.loads((source/'receipt.json').read_text())
 assert original['execution_head']==a.expected_commit and original['status']=='passed' and original['source_stable'] and len(original['maps'])==2
 OUT=fresh(a.output);summary={'status':'running','execution_head':a.expected_commit,'source_before':before,'native_wrapper_receipt':str(source/'receipt.json'),'native_wrapper_receipt_sha256':sha(source/'receipt.json'),'driver_sha256':sha(Path(__file__)),'common_sha256':sha(Path(__file__).with_name('common.py')),'maps':[],'scope':'Fresh actual final-main original AVI direct PNG decoding and lossy MP4 viewing derivatives. No resize/crop/recolor/overlay; no historical H/K rebind; no full film playback/audio/device/whole-region aesthetic admission.'};write(OUT/'summary.json',summary)
 try:
  versions={n:run([n,'-version']).splitlines()[0] for n in ['ffmpeg','ffprobe']};write(OUT/'toolchain.json',versions)
  bound(ROOT/'tools/run_forest_depth_region.py',a.expected_commit)
  for index in [1,2]:
   rp=source/f'map{index}/receipt.json';receipt=json.loads(rp.read_text());assert receipt['source_head']==a.expected_commit and receipt['source_stable'] and receipt['status']=='passed'
   assert len(receipt['runs'])==1;row=receipt['runs'][0];assert row['exit_code']==0 and row['status']=='passed' and row['errors']==[]
   native=source/f'map{index}/00-map{index}-high_return';avi=native/'gameplay.avi';cp=native/'capture.json';capture=json.loads(cp.read_text())
   assert sha(avi)==row['movie']['sha256'] and sha(cp)==row['capture_sha256']
   assert capture['map_index']==index and capture['seed']=='forest-depth-hollow-00' and capture['route']=='high_return' and not capture['failures'] and len(capture['completed_legs'])==len(capture['itinerary'])
   dest=OUT/f'map{index}';dest.mkdir();avi_probe,v=probe(avi,dest/'avi-ffprobe.json');count=int(v['nb_read_frames']);assert count==row['movie']['frames']
   mp4=dest/'gameplay-viewing.mp4'
   encode=['ffmpeg','-hide_banner','-loglevel','error','-threads','1','-filter_threads','1','-i',str(avi),'-map','0:v:0','-map','0:a:0?','-c:v','libx264','-preset','veryfast','-crf','18','-pix_fmt','yuv420p','-threads','1','-fps_mode','passthrough','-c:a','aac','-b:a','128k','-movflags','+faststart',str(mp4)]
   run(encode);_,mv=probe(mp4,dest/'mp4-ffprobe.json');assert int(mv['nb_read_frames'])==count
   selected=select_events(capture);assert all(0<=s['avi_frame_index_zero_based']<count for s in selected)
   frames=dest/'event-frames';frames.mkdir();expression='+'.join('eq(n\\,%d)'%s['avi_frame_index_zero_based'] for s in selected)
   decode=['ffmpeg','-hide_banner','-loglevel','error','-threads','1','-filter_threads','1','-i',str(avi),'-map','0:v:0','-vf','select='+expression,'-fps_mode','vfr','-c:v','png','-threads','1',str(frames/'%03d.png')]
   run(decode);pngs=sorted(frames.glob('*.png'));assert len(pngs)==16
   for s,png in zip(selected,pngs):s.update(png=str(png.relative_to(ROOT)),sha256=sha(png),bytes=png.stat().st_size,movie_time_seconds=s['avi_frame_index_zero_based']/60)
   record={'execution_head':a.expected_commit,'map':index,'seed':capture['seed'],'route':capture['route'],'completed_legs':len(capture['completed_legs']),'physics_frames':len(capture['frames']),'native_receipt':str(rp.relative_to(ROOT)),'native_receipt_sha256':sha(rp),'capture':str(cp.relative_to(ROOT)),'capture_sha256':sha(cp),'avi':str(avi.relative_to(ROOT)),'avi_sha256':sha(avi),'avi_bytes':avi.stat().st_size,'video_frames':count,'fps':'60/1','width':1280,'height':720,'video_seconds':count/60,'mp4':str(mp4.relative_to(ROOT)),'mp4_sha256':sha(mp4),'mp4_bytes':mp4.stat().st_size,'encode_command':encode,'direct_avi_decode_command':decode,'timeline_scope':'Event.presentation_frame selects zero-based AVI index with explicit offset. Never derive movie time from physics tick; first jump offsets -1,0,+8 are not three consecutive frames. Caption only actual event kind/leg/target/mapped_target/anchor fields.','duration_scope':'Native240 is original subprocess timeout. Original row.seconds includes display/ffprobe/AVI postprocessing and must never be reported as standalone native duration.','frames':selected,'pixel_status':'pending_independent_review'}
   write(dest/'event-frame-index.json',record);summary['maps'].append({k:v for k,v in record.items() if k!='frames'});write(OUT/'summary.json',summary)
  summary['source_after']=state(a.expected_commit);summary['source_stable']=summary['source_after']==before;assert summary['source_stable'];summary['status']='derived_pixels_pending_independent_review'
 except BaseException as e:summary.update(status='failed',error=type(e).__name__+': '+str(e));raise
 finally:write(OUT/'summary.json',summary)
 print(json.dumps({'status':summary['status'],'execution_head':a.expected_commit}))
if __name__=='__main__':main()
