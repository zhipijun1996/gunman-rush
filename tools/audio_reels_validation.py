"""Bounded, numerically stable checks of actual captured audio; no aesthetic rating."""
from __future__ import annotations
import hashlib
import json
from pathlib import Path
import subprocess
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
RATE=48000

def pcm(path):
 return np.frombuffer(subprocess.check_output(['ffmpeg','-v','error','-i',str(path),'-f','f32le','-ac','1','-ar',str(RATE),'pipe:1']),dtype='<f4').astype('float64')

def stable_match(window,reference):
 """FFT search, energy mask and direct-dot verification of actual peak windows."""
 m=len(reference);n=len(window);power=float(np.dot(reference,reference))
 if not m or n<m or not np.isfinite(window).all() or not np.isfinite(reference).all() or power<=1e-20:raise ValueError('Invalid audio reference/window')
 size=1<<(m+n-1).bit_length()
 corr=np.fft.irfft(np.fft.rfft(window,size)*np.fft.rfft(reference[::-1],size),size)[m-1:n]
 cumulative=np.r_[0.,np.cumsum(window*window)]
 energy=np.maximum(0.,cumulative[m:]-cumulative[:-m])
 floor=max(1e-20,float(np.max(energy))*1e-8)
 valid=energy>floor
 if not valid.any():raise ValueError('No meaningful signal energy; numerical FFT residue is not a match')
 score=np.zeros_like(energy);score[valid]=np.abs(corr[valid])/np.sqrt(energy[valid]*power)
 best=(-1.,-1)
 # The direct calculation, not an ill-conditioned cumulative denominator,
 # owns the reported acceptance. Empty tails never enter this shortlist.
 for index in np.argsort(score)[-min(8,len(score)):]:
  index=int(index)
  if not valid[index]:continue
  actual=window[index:index+m];observed=float(np.dot(actual,actual))
  if observed<=floor:continue
  exact=float(abs(np.dot(actual,reference))/np.sqrt(observed*power))
  if not np.isfinite(exact) or exact>1.00000001:raise ValueError('Correlation violates its mathematical bound')
  if exact>best[0]:best=(min(exact,1.),index)
 if best[1]<0:raise ValueError('No valid audio peak')
 return best

def joint_fit(design,observed):
 if design.ndim!=2 or design.shape[1]!=2 or len(observed)!=len(design):raise ValueError('Invalid two-layer recording')
 energy=float(np.dot(observed,observed))
 if energy<=1e-20:raise ValueError('Silent combined recording')
 coefficients=np.linalg.lstsq(design,observed,rcond=None)[0]
 residual=observed-design@coefficients;r2=1-float(np.dot(residual,residual))/energy
 single=[float(np.dot(observed,column)**2/(np.dot(column,column)*energy)) for column in design.T]
 gains=[r2-v for v in single]
 # Positive machine epsilon is not evidence that an audible layer survived.
 # Require both independent components to explain additional observed energy.
 if not np.isfinite(r2) or r2<.90 or np.any(coefficients<=0) or min(gains)<.01:raise ValueError('Combined recording does not independently support both components')
 return {'joint_r2':r2,'positive_coefficients':coefficients.tolist(),'r2_gain_over_single_components':gains}

def validate_audio_windows(movie,trace,reel,manifest=None):
 if manifest is None:manifest=json.loads((ROOT/'assets/audio/director_v3/manifest.json').read_text())
 candidates={c['id']:c for e in manifest['events'] for c in e['candidates']};audio=pcm(movie);references={};rows=[]
 def reference(cid):
  if cid not in references:
   p=ROOT/candidates[cid]['path'].removeprefix('res://')
   if hashlib.sha256(p.read_bytes()).hexdigest()!=candidates[cid]['sha256']:raise ValueError('Frozen candidate waveform hash mismatch')
   references[cid]=pcm(p)
  return references[cid]
 for segment in trace['segments']:
  a=int(segment['start_frame'])*800;b=min(len(audio),int(segment['end_frame'])*800)
  if b<=a or float(np.sqrt(np.mean(audio[a:b]**2)))<1e-6:raise ValueError('Captured profile is silent')
  matches=[];events=segment['director_events'];grouped=set()
  for event in events:
   cid=event['candidate'];frame=int(event['movie_frame'])
   if cid in grouped:continue
   pair=[e for e in events if int(e['movie_frame'])==frame and e['id'] in ['shot_bomb','bomb_explode']]
   if len(pair)==2:
    # Current recoil bomb is an instantaneous combined action. It cannot
    # prove separate launch timing; verify both components in one real mix.
    blast=next(e for e in pair if e['id']=='bomb_explode');ref=reference(blast['candidate'])
    first=max(a,(frame-8)*800);last=min(b,(frame+8)*800+len(ref))
    correlation,index=stable_match(audio[first:last],ref);start=first+index
    refs=[reference(e['candidate']) for e in pair];length=max(map(len,refs))
    if start+length>b:raise ValueError('Combined bomb tail truncated')
    design=np.column_stack([np.pad(r,(0,length-len(r))) for r in refs]);observed=audio[start:start+length]
    fit=joint_fit(design,observed)
    matches.append({'candidate_ids':[e['candidate'] for e in pair],'status':'joint_mix_verified','individual_launch_timing':'unverified; simultaneous logical signals','common_offset_ms':(start-frame*800)/48,'anchor_correlation':correlation,**fit})
    grouped.update(e['candidate'] for e in pair)
   else:
    ref=reference(cid);first=max(a,(frame-8)*800);last=min(b,(frame+8)*800+len(ref))
    correlation,index=stable_match(audio[first:last],ref)
    if correlation<.12:raise ValueError('Frozen candidate waveform not supported in actual captured audio: '+cid)
    matches.append({'candidate_id':cid,'status':'waveform_verified','correlation':correlation,'offset_ms':(first+index-frame*800)/48})
  rows.append({'profile':segment['profile'],'rms':float(np.sqrt(np.mean(audio[a:b]**2))),'candidate_matches':matches})
 return {'reel':reel,'method':'FFT search with meaningful energy mask; direct-dot bounded correlation. Shared-tick bomb verified by positive joint fit, no isolated launch onset claim.','tool_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'scope':'Technical source-waveform evidence only; not a sound-quality, physical-device or perceptual-sync approval','profiles':rows}
