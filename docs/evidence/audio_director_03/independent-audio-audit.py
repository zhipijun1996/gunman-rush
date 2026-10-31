#!/usr/bin/env python3
"""Independent, read-only MP4 onset audit. No Godot or production writes."""
from pathlib import Path
import argparse,hashlib,json,subprocess
import numpy as np

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def pcm(p):
    return np.frombuffer(subprocess.check_output(['ffmpeg','-v','error','-i',str(p),'-f','f32le','-ac','1','-ar','48000','pipe:1']),dtype='<f4').astype('float64')
def analyze(repo,base):
    manifest_path=repo/'assets/audio/director_v3/manifest.json'
    manifest=json.loads(manifest_path.read_text())
    candidates={c['id']:c for e in manifest['events'] for c in e['candidates']}
    refs={};rows=[];audio_cache={};inputs=[];old_overshoots=[]
    for folder in sorted(base.iterdir()):
        if not (folder/'trace.json').exists(): continue
        report=json.loads((folder/'report.json').read_text())
        trace=json.loads((folder/'trace.json').read_text())
        movie=folder/(folder.name+'.mp4')
        assert sha(movie)==report['movie_sha256']
        assert sha(folder/'trace.json')==report['trace_sha256']
        audio=pcm(movie);audio_cache[folder.name]=audio
        inputs.append({'reel':folder.name,'producer_commit':report['commit'],'movie_sha256':sha(movie),'trace_sha256':sha(folder/'trace.json')})
        for segment in trace['segments']:
            if segment['profile']=='original': continue
            a=int(segment['start_frame'])*800;b=min(len(audio),int(segment['end_frame'])*800)
            for event in segment['director_events']:
                cid=event['candidate']
                if cid not in refs:
                    path=repo/candidates[cid]['path'].removeprefix('res://')
                    assert sha(path)==candidates[cid]['sha256']
                    refs[cid]=pcm(path)
                ref=refs[cid];frame=int(event['movie_frame'])
                first=max(a,(frame-8)*800);last=min(b,(frame+8)*800+len(ref))
                win=audio[first:last];m=len(ref);n=len(win)
                assert n>=m
                size=1<<(m+n-1).bit_length()
                corr=np.fft.irfft(np.fft.rfft(win,size)*np.fft.rfft(ref[::-1],size),size)[m-1:n]
                cumul=np.r_[0.,np.cumsum(win*win)]
                naive_energy=cumul[m:]-cumul[:-m]
                naive=np.abs(corr)/np.sqrt(np.maximum(1e-30,naive_energy*np.dot(ref,ref)))
                if float(np.max(naive))>1.000001:
                    old_overshoots.append({'reel':folder.name,'candidate':cid,'invalid_correlation':float(np.max(naive))})
                # Direct convolution avoids subtractive cancellation for short
                # cues. Long-cue subtraction excludes numerically empty windows.
                energy=np.convolve(win*win,np.ones(m),'valid') if m<8192 else np.maximum(0.,naive_energy)
                valid=energy>max(1e-20,float(np.max(energy))*1e-10)
                score=np.zeros_like(energy)
                score[valid]=np.abs(corr[valid])/np.sqrt(energy[valid]*np.dot(ref,ref))
                index=int(np.argmax(score));local=win[index:index+m]
                exact=float(abs(np.dot(local,ref))/np.sqrt(np.dot(local,local)*np.dot(ref,ref))) if np.dot(local,local)>0 else 0
                assert exact<=1.000000001
                rows.append({'reel':folder.name,'candidate':cid,'movie_frame':frame,'offset_ms':round((first+index-frame*800)/48,4),'correlation':round(exact,6),'individual_timing_unverified':cid.startswith('shot_bomb_')})
    fits=[]
    trace=json.loads((base/'weapons/trace.json').read_text());audio=audio_cache['weapons']
    for segment in trace['segments']:
        if segment['profile']=='original': continue
        profile=segment['profile'].lower();launch='shot_bomb_'+profile;blast='bomb_explode_'+profile
        row=next(r for r in rows if r['reel']=='weapons' and r['candidate']==blast)
        start=round((row['movie_frame']*1000/60+row['offset_ms'])*48)
        length=max(len(refs[launch]),len(refs[blast]))
        design=np.column_stack([np.pad(refs[k],(0,length-len(refs[k]))) for k in [launch,blast]])
        target=audio[start:start+length];coef=np.linalg.lstsq(design,target,rcond=None)[0]
        prediction=design@coef;energy=float(np.dot(target,target))
        joint=1-float(np.dot(target-prediction,target-prediction))/energy
        blast_only=float(np.dot(target,design[:,1])**2/(np.dot(design[:,1],design[:,1])*energy))
        fits.append({'profile':segment['profile'],'common_frame':row['movie_frame'],'onset_offset_ms':row['offset_ms'],'launch_coefficient':round(float(coef[0]),6),'blast_coefficient':round(float(coef[1]),6),'joint_R2':round(joint,6),'blast_only_R2':round(blast_only,6),'joint_gain_R2':round(joint-blast_only,6)})
    nonlaunch=[r for r in rows if not r['individual_timing_unverified']]
    return {'method':'Actual MP4 AAC decoded to mono48k. Match full frozen WAV in event-frame +-8 frames, stable local energy and direct-dot final verification. Shared-tick bomb launch/explosion fitted jointly; no isolated launch timing or subjective quality claim.','script_sha256':sha(Path(__file__)),'manifest_sha256':sha(manifest_path),'matches':len(rows),'unique_references':len(refs),'non_launch_count':len(nonlaunch),'non_launch_offset_ms_range':[min(r['offset_ms'] for r in nonlaunch),max(r['offset_ms'] for r in nonlaunch)],'inputs':inputs,'naive_numerical_overshoots':old_overshoots,'rows':rows,'bomb_shared_onset_fits':fits}
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--repo',type=Path,default=Path('/workspace/gunman-audio'));p.add_argument('--capture-root',type=Path);p.add_argument('--output',type=Path,required=True);a=p.parse_args();result=analyze(a.repo,a.capture_root or a.repo/'build/audio_director_v3/reels-final');a.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print(json.dumps({'matches':result['matches'],'references':result['unique_references'],'offset_ms':result['non_launch_offset_ms_range'],'naive_overshoots':len(result['naive_numerical_overshoots']),'bomb_shared_onset_fits':result['bomb_shared_onset_fits'],'output':str(a.output)},ensure_ascii=False))
