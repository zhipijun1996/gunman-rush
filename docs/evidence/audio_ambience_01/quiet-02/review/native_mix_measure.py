"""Read-only native waveform amplitude audit; no Godot or listening claim."""
from pathlib import Path
import hashlib
import json
import subprocess
import tempfile
import numpy as np
from scipy.signal import fftconvolve

ROOT=Path(__file__).resolve().parents[5]
OUT=Path(__file__).resolve().parent
OLD=ROOT/'build/audio_ambience_01/capture-05'
NEW=ROOT/'build/audio_ambience_01/capture-06'
RATE=8000

def read(path):return json.loads(path.read_text())
def decode(path):return np.frombuffer(subprocess.check_output(['ffmpeg','-v','error','-i',str(path),'-vn','-f','f32le','-ac','1','-ar',str(RATE),'pipe:1'],timeout=60),dtype='<f4').astype('float64')
def rms(x):return float(np.sqrt(np.mean(x*x)))
def db(x):return float(20*np.log10(x)) if x>0 else None
def align(reference,search):
 n=len(reference);dots=fftconvolve(search,reference[::-1],mode='valid');power=fftconvolve(search*search,np.ones(n),mode='valid');norms=np.sqrt(np.maximum(power,0)*float(np.dot(reference,reference)));corr=np.divide(dots,norms,out=np.zeros_like(dots),where=norms>1e-15);at=int(np.argmax(corr));aligned=search[at:at+n];return at,aligned,float(np.dot(reference,aligned)/(np.linalg.norm(reference)*np.linalg.norm(aligned)))

def run():
 reports={name:read(folder/'report.json') for name,folder in [('old',OLD),('new',NEW)]};traces={name:read(folder/'trace.json') for name,folder in [('old',OLD),('new',NEW)]};audio={name:decode(folder/'native.avi') for name,folder in [('old',OLD),('new',NEW)]};oldmanifest=json.loads(subprocess.check_output(['git','show','a14cd04c:assets/audio/ambience_v1/manifest.json'],cwd=ROOT,text=True));newmanifest=read(ROOT/'assets/audio/ambience_v1/manifest.json');manifest={'old':oldmanifest,'new':newmanifest};fits=[]
 with tempfile.TemporaryDirectory(prefix='native-sources-',dir=OUT) as temp:
  for label in ['old','new']:
   for segment in traces[label]['segments']:
    if segment['profile']=='original':continue
    source_path=manifest[label]['regions'][segment['region']]['profiles'][segment['profile']]['bed'].removeprefix('res://');source_file=ROOT/source_path
    if label=='old':
     source_file=Path(temp)/Path(source_path).name;source_file.write_bytes(subprocess.check_output(['git','show','a14cd04c:'+source_path],cwd=ROOT))
    source=decode(source_file);source=np.tile(source,2);start=segment['end_frame']/60-2.5;clip=audio[label][round(start*RATE):round((start+2)*RATE)];at,aligned,direct=align(clip,source);gain=float(np.dot(aligned,clip)/np.dot(aligned,aligned));residual=clip-gain*aligned
    fits.append({'capture':label,'region':segment['region'],'profile':segment['profile'],'window_start':start,'seconds':2,'direct_normalized_dot':direct,'aligned_source_seconds':at/RATE,'least_squares_native_gain':gain,'expected_session_gain':.7,'gain_error_db_from_0_7':db(gain/.7),'native_window_rms':rms(clip),'aligned_source_rms':rms(aligned),'residual_rms':rms(residual),'scope':'Fitted actual native amplitude; residual includes retained original forest sound, codec differences and other scene sound'})
 music=[]
 for region in ['plains','forest']:
  oldseg=next(s for s in traces['old']['segments'] if s['region']==region and s['profile']=='original');newseg=next(s for s in traces['new']['segments'] if s['region']==region and s['profile']=='original');oldstart=oldseg['start_frame']/60+3;newstart=newseg['start_frame']/60+2.5;reference=audio['old'][round(oldstart*RATE):round((oldstart+1.8)*RATE)];search=audio['new'][round(newstart*RATE):round((newseg['start_frame']/60+5)*RATE)];at,aligned,direct=align(reference,search);gain=float(np.dot(reference,aligned)/np.dot(reference,reference));music.append({'region':region,'old_original_window_relative_seconds':[3,4.8],'new_original_search_relative_seconds':[2.5,5],'transport_alignment_offset_seconds':newstart+at/RATE-newseg['start_frame']/60-3,'direct_normalized_dot':direct,'new_over_old_fitted_gain':gain,'gain_change_db':db(gain),'old_rms':rms(reference),'new_aligned_rms':rms(aligned),'scope':'Original profile stationary BGM-on window before first movement at5s; not subjective masking approval'})
 result={'old_producer':reports['old']['commit'],'new_producer':reports['new']['commit'],'new_mix_revision':reports['new'].get('mix_revision'),'new_movie_sha256':reports['new']['movie_sha256'],'native_source_hashes':{k:r['native_sha256'] for k,r in reports.items()},'fits':fits,'original_bgm_windows':music,'scope':'Independent numerical analysis of actual retained native AVI audio. No human listening/device/user approval, no production changes.'};(OUT/'native-amplitude-and-bgm-check.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
if __name__=='__main__':run()
