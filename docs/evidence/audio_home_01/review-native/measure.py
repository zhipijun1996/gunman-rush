"""Independent read-only PCM review; no engine, playback or production edits."""
from pathlib import Path
import sys,json,math,hashlib
import numpy as np
from scipy.signal import resample_poly

ROOT=Path(__file__).resolve().parents[4]
sys.path.insert(0,str(ROOT/'tools'))
import capture_audio_home as c
OUT=Path(__file__).resolve().parent
CAP=ROOT/'build/audio_home_01/capture-01'

def rms(x):return float(np.sqrt(np.mean(x*x)))
def db(x):return float(20*np.log10(x)) if x>0 else None
def fit(actual,source):
 gain=float(np.dot(actual,source)/np.dot(source,source));residual=actual-gain*source
 return {'least_squares_gain':gain,'gain_db':db(gain),'normalized_dot':float(np.dot(actual,source)/(np.linalg.norm(actual)*np.linalg.norm(source))),'actual_rms':rms(actual),'source_rms':rms(source),'residual_rms':rms(residual)}

def main():
 report=c.read(CAP/'report.json');trace=c.read(CAP/'trace.json');manifest=c.read(c.MANIFEST)
 assert report['status']=='passed' and report['source_stable']
 assert c.sha(CAP/'native.avi')==report['native_sha256']
 assert c.sha(CAP/'home.mp4')==report['movie_sha256']
 assert c.sha(CAP/'trace.json')==report['trace_sha256']
 assert c.sha(c.MANIFEST)==report['manifest_sha256']
 c.validate_capture_override(report,CAP)
 segments=c.validate_trace(trace,report['frame_count'],manifest)
 assert c.read(CAP/'chapters.json')==c.chapters_from_segments(segments)
 assert report['source_before']==report['source_after']==c.frozen_sources()
 raw=c.decode_native(CAP/'native.avi')
 clips={s['mode']:raw[round(s['start_frame']/60*48000):round(s['end_frame']/60*48000)] for s in segments}
 delta,alignment=c.differential(clips['original'],clips['bed'])
 source=c.decode_native(ROOT/manifest['regions']['home']['profiles']['A']['bed'].removeprefix('res://'),8000)
 window=delta[24000:40000];proof=c.match_template(np.tile(source,2),window)
 bedsource=np.tile(source,2)[proof['offset_samples']:proof['offset_samples']+len(window)]
 bedfit=fit(window,bedsource);expected=.7*10**(-2/20)
 bedfit.update(expected_runtime_gain=expected,gain_error_db=db(bedfit['least_squares_gain']/expected),window_relative_seconds=[3,5],source_offset_seconds=proof['offset_samples']/8000)
 # Align the raw unchanged Home music at its actual integer native transport offset.
 lag=alignment['native_lag_samples'];idx=np.arange(len(clips['bed']))-lag
 aligned=np.zeros_like(clips['bed']);valid=(idx>=0)&(idx<len(clips['original']));aligned[valid]=clips['original'][idx[valid]]
 music=resample_poly(aligned,1,6)[24000:40000];mixed=resample_poly(clips['bed'],1,6)[24000:40000]
 coef=np.linalg.lstsq(np.column_stack([music,bedsource]),mixed,rcond=None)[0]
 bgm={'window_relative_seconds':[3,5],'native_alignment_samples':lag,'common_bgm_coefficient':float(coef[0]),'common_bgm_gain_change_db':db(float(coef[0])),'bed_coefficient':float(coef[1]),'original_pcm_rms':rms(music),'isolated_added_bed_rms':rms(window),'bed_to_original_rms_db':db(rms(window)/rms(music)),'total_mix_rms_change_db':db(rms(mixed)/rms(music)),'fitted_residual_rms':rms(mixed-coef[0]*music-coef[1]*bedsource),'note':'Joint regression of actual PCM mix on aligned original Home soundtrack and decoded bed; a numerical unchanged-music check. Window RMS ratios are not perceptual masking/listening approval.'}
 ld,la=c.differential(clips['bed'],clips['life']);life=[];points={p['id']:p for p in manifest['point_events']};ls=segments[2]
 for event in ls['final']['audition']['events']:
  template=c.decode_native(ROOT/points[event['event_id']]['path'].removeprefix('res://'),8000)[:8000]
  offset=(event['physics_tick']-ls['first_physics_tick'])/60;start=max(0,round((offset-.15)*8000));end=min(len(ld),round((offset+.20)*8000)+len(template));p=c.match_template(ld[start:end],template)
  observed=ld[start+p['offset_samples']:start+p['offset_samples']+len(template)];f=fit(observed,template);eg=10**(event['volume_db']/20)
  life.append({'event_id':event['event_id'],'slot':event['slot'],'expected_runtime_gain':eg,'gain_error_db':db(f['least_squares_gain']/eg),'actual_start_seconds':(start+p['offset_samples'])/8000,'trace_expected_seconds':offset,**f})
 # Both bed/life share the same bed/music. Before the naturally scheduled cue,
 # their aligned native PCM should match closely, independently of source fitting.
 life_pre={'alignment':la,'relative_window_seconds':[3,5],'residual_rms':rms(ld[24000:40000]),'scope':'No life cue yet; compares the actual common Home soundtrack between bed and life.'}
 rng=np.random.default_rng(481521);negative=[]
 for label,sig,temp in [('silence',np.zeros(40000),window),('fixed_seed_noise',rng.normal(size=40000),window),('wrong_actual_home_page',c.decode_native(ROOT/'assets/audio/ambience_v1/home/home_page_1.wav',8000),window)]:
  # Repeat the real short page only to give the same valid search bounds.
  if len(sig)<len(temp):sig=np.tile(sig,math.ceil((len(temp)+800)/len(sig)))
  try:p=c.match_template(sig,temp);negative.append({'id':label,'rejected':False,'proof':p})
  except ValueError as e:negative.append({'id':label,'rejected':True,'reason':str(e)})
 assert all(v['rejected'] for v in negative)
 result={'producer':report['commit'],'mp4_sha256':report['movie_sha256'],'native_sha256':report['native_sha256'],'trace_sha256':report['trace_sha256'],'source_closure_count':len(report['source_before']),'source_before_after_current_equal':True,'trace_chapters_override_hashes_revalidated':True,'bed_alignment':alignment,'bed_amplitude_fit':bedfit,'bgm_joint_fit':bgm,'life_amplitude_fits':life,'life_before_cue':life_pre,'template_negative_controls':negative,'scope':'Independent analysis of actual retained native PCM; downsample/phase/source-fit residuals retained. No listening, user taste, physical-device or commercial-quality certification.'}
 (OUT/'result.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print(json.dumps(result,ensure_ascii=False,indent=2))

if __name__=='__main__':main()
