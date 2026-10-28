#!/usr/bin/env python3
"""Separately revalidate retained native media after a validator-only correction."""
import argparse,json,subprocess
from pathlib import Path
from capture_selected_audio import ROOT,sha,ERROR,frozen_sources,verified_selection,validate_selected_trace
from audio_reels_validation import validate_audio_windows

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--capture',type=Path,required=True);p.add_argument('--revision',type=int,default=1);a=p.parse_args();folder=a.capture.resolve();old_path=folder/'report.json';old=json.loads(old_path.read_text());output=folder/('post-validation.json' if a.revision==1 else 'post-validation-v%d.json'%a.revision)
 if output.exists():raise ValueError('Preserve prior post-validation; use explicit new version')
 if old.get('status')!='failed' or old.get('error') not in ['Selection receipt drift','Actual physics tick discontinuity']:raise ValueError('Only the known JSON roundtrip or explicit context reconstruction validator rejection may be corrected here')
 before=old['source_before'];current=frozen_sources();allowed='tools/capture_selected_audio.py'
 if before.keys()!=current.keys() or any(before[k]!=current[k] for k in before if k!=allowed):raise ValueError('Native runtime/input closure changed')
 captured_tool=subprocess.check_output(['git','show',old['commit']+':'+allowed],cwd=ROOT)
 import hashlib
 if hashlib.sha256(captured_tool).hexdigest()!=before[allowed]:raise ValueError('Recorded capture tool does not match producer Git source')
 if sha(Path(old['engine']['path']))!=old['engine']['sha256']:raise ValueError('Engine changed')
 native=(folder/'native.log').read_text()
 if ERROR.search(native) or 'AUDIO_REELS_CAPTURE reel=coin complete=true' not in native:raise ValueError('Original native capture did not complete cleanly')
 media=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(folder/'selected.mp4')]))
 video=next(s for s in media['streams'] if s['codec_type']=='video');audio=next(s for s in media['streams'] if s['codec_type']=='audio')
 if video['avg_frame_rate']!='60/1' or int(audio['sample_rate'])!=48000 or audio['channels']!=2:raise ValueError('Unexpected actual encoding')
 trace=json.loads((folder/'trace.json').read_text());selection=verified_selection();segments=validate_selected_trace(trace,int(video['nb_frames']),selection)
 windows=validate_audio_windows(folder/'selected.mp4',trace,'selected-user-20261028')
 cuts=[]
 for profile in ['original','selected']:
  s=next(s for s in segments if s['reel']=='mix' and s['profile']==profile)
  rows=[r for r in trace['trace'] if r.get('reel')=='mix' and r['profile']==profile and s['action_start_frame']<r['action_frame']<=s['action_end_frame']]
  cuts += [{'profile':profile,'before':b,'after':n} for b,n in zip(rows,rows[1:]) if n['physics_tick']-b['physics_tick']>1]
 chapters={'chapters':[{'id':s['reel'],'title':s['reel'],'profile':s['profile'],'start':s['start_frame']/60,'end':s['end_frame']/60} for s in segments]};(folder/'chapters.json').write_text(json.dumps(chapters,indent=2)+'\n')
 result={**old,'status':'passed','capture_attempt_status':old['status'],'capture_attempt_error':old['error'],'original_report_sha256':sha(old_path),'postvalidator_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'postvalidator_sha256':sha(Path(__file__)),'runtime_sources_unchanged':True,'allowed_validation_only_change':{'path':allowed,'recorded_sha256':before[allowed],'postvalidation_sha256':current[allowed]},'source_after_postvalidation':current,'explicit_context_cuts':cuts,'frame_count':int(video['nb_frames']),'media':media,'movie_sha256':sha(folder/'selected.mp4'),'native_avi_sha256':sha(folder/'native.avi'),'movie_bytes':(folder/'selected.mp4').stat().st_size,'trace_sha256':sha(folder/'trace.json'),'audio_windows':windows}
 result.pop('error',None);output.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'status':'passed','output':str(output),'chapters':len(segments),'explicit_context_cuts':len(cuts),'frames':result['frame_count']}))
if __name__=='__main__':main()
