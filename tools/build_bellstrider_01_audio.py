#!/usr/bin/env python3
"""Reproducible Bellstrider material SFX; only preserved CC0 recordings.

This processor creates no oscillators/noise and never reads or writes music.
Input source pages, licenses, original records and parent derivative recipes are
fingerprinted. --validate checks current output bytes without rebuilding them.
"""
import argparse
import array
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys
import wave

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/audio/bellstrider_01'
RATE = 48000
VERSION = 'bellstrider-material-01-v1'
# source, playback speed, highpass, lowpass, duration, offset, relative gain
RECIPES = {
 'armour_hit':(.095,.32,[['hit3',.86,100,1450,.09,0,1],['metal2',.72,200,1700,.08,0,.22]]),
 'weak_hit':(.26,.45,[['bell',1.32,520,9000,.25,0,1],['metal1',1.5,600,7000,.055,0,.25]]),
 'roll_warn':(.63,.66,[['metal1',.63,130,4800,.30,0,.65],['metal2',.78,250,5500,.16,.12,.40],['bell',.81,200,5600,.40,.04,1]]),
 'roll_warn_double':(.69,.66,[['metal1',.63,130,4800,.30,0,.65],['metal2',.78,250,5500,.16,.12,.40],['bell',.81,200,5600,.22,.04,1],['bell',.81,200,5600,.34,.28,1]]),
 'roll_start':(.25,.56,[['wood1',.60,55,1600,.20,0,1],['metal1',.67,170,4200,.22,.01,.58]]),
 'brake':(.31,.50,[['metal2',.57,190,4200,.28,0,1],['metal1',.74,330,4600,.12,.07,.45]]),
 'turn':(.24,.43,[['metal1',.81,150,3600,.21,0,1],['metal2',1.03,450,4400,.10,.075,.4]]),
 'ring_strike':(.63,.72,[['bell',.66,110,7600,.62,0,1],['metal1',.73,110,4200,.15,0,.56],['wood1',.72,50,1100,.13,0,.36]]),
 'lob_aim':(.34,.43,[['metal2',.73,300,5000,.16,0,.8],['metal1',1.05,500,5500,.18,.10,1]]),
 'lob_lock':(.24,.64,[['metal1',1.26,600,6500,.10,0,.8],['bell',1.15,900,8000,.20,.025,1]]),
 'lob_release':(.26,.52,[['metal2',1.23,400,6800,.16,0,1],['wood1',1.1,90,2200,.13,.015,.60]]),
 'lob_impact':(.44,.65,[['wood1',.63,50,1800,.17,0,.75],['metal2',.67,180,4600,.30,.01,.65],['bell',1.01,400,6800,.36,.015,1]]),
 'phase':(.66,.66,[['metal1',.58,150,5200,.28,0,.8],['metal2',.72,250,5900,.27,.14,.7],['bell',.70,250,6200,.49,.12,1]]),
 'death':(.39,.62,[['break1',.75,120,6500,.34,0,.6],['bell',.76,220,6500,.35,.015,1]]),
 'death_jam':(.34,.64,[['metal1',.56,120,4000,.14,0,1],['metal2',.66,250,4500,.10,.08,.70],['metal1',.50,150,3000,.12,.18,.7]]),
 'death_impact':(.58,.72,[['wood1',.53,45,1500,.23,0,1],['break3',.66,160,5800,.42,.018,.68],['metal1',.61,170,4800,.37,.05,.65]]),
 'death_final':(1.10,.58,[['bell',.64,130,7000,1.08,0,1],['metal2',1.3,750,6000,.12,.03,.11]]),
}


def sha(path):
 return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
 return json.loads((ROOT/path).read_text())


def source_records():
 parent='assets/audio/plains_feedback_02/provenance.json'
 plains=read(parent)
 result={}
 for key in ['hit3','metal1','metal2','wood1','break1','break3']:
  row=dict(plains['sources'][key])
  for pathkey,hashkey in [('path','sha256'),('source_page_path','source_page_sha256'),('license_path','license_sha256')]:
   assert sha(ROOT/row[pathkey])==row[hashkey],(key,pathkey)
  assert row['license']=='CC0-1.0'
  result[key]=row
 ambience=read('assets/audio/ambience_v1/manifest.json')
 render=next(r for r in ambience['point_events'] if r['id']=='plains_chime_a')
 original=read('config/audio_director/ambience/sources.json')['sources']['bell_1']
 path=render['path'].removeprefix('res://')
 assert sha(ROOT/path)==render['sha256']
 for pathkey,hashkey in [('source_page_path','source_page_sha256'),('license_path','license_sha256')]:
  assert sha(ROOT/original[pathkey])==original[hashkey]
 result['bell']={'path':path,'sha256':render['sha256'],'license':'CC0-1.0',
  'author':original['author'],'source_url':original['source_url'],
  'commercial_use':True,'attribution_required':False,'original_source':original,
  'parent_recipe_path':'config/audio_director/ambience/recipes.json',
  'parent_recipe_sha256':sha(ROOT/'config/audio_director/ambience/recipes.json'),
  'parent_manifest_path':'assets/audio/ambience_v1/manifest.json',
  'parent_manifest_sha256':sha(ROOT/'assets/audio/ambience_v1/manifest.json'),
  'description':'Existing quiet-02 bell derivative; exact parent bytes reused, not regenerated.'}
 return result


def layer(source, speed, high, low, duration):
 filters=f'asetrate={RATE}*{speed},aresample={RATE},highpass=f={high},lowpass=f={low}'
 data=subprocess.check_output(['ffmpeg','-v','error','-i',str(ROOT/source['path']),'-ac','1','-ar',str(RATE),'-af',filters,'-f','f32le','pipe:1'],timeout=30)
 samples=array.array('f');samples.frombytes(data)
 if sys.byteorder!='little':samples.byteswap()
 peak=max(abs(x) for x in samples)
 assert peak>1e-5
 onset=max(0,next(i for i,x in enumerate(samples) if abs(x)>peak*.015)-24)
 body=list(samples[onset:onset+round(duration*RATE)])
 peak=max(abs(x) for x in body)
 for i in range(len(body)):
  body[i]=body[i]/peak*min(1,(len(body)-i-1)/576)*min(1,i/24)
 return body,{'filter':filters,'onset_frame':onset,'duration':duration}


def build():
 OUT.mkdir(parents=True,exist_ok=True)
 sources=source_records();outputs=[]
 for name,(duration,target,layers) in RECIPES.items():
  mix=[0.] * round(duration*RATE);processed=[]
  for key,speed,high,low,length,offset,gain in layers:
   samples,trace=layer(sources[key],speed,high,low,length)
   start=round(offset*RATE)
   for i,x in enumerate(samples[:len(mix)-start]):mix[start+i]+=x*gain
   processed.append(dict(source=key,offset=offset,gain=gain,**trace))
  scale=target/max(abs(x) for x in mix)
  pcm=array.array('h',[round(x*scale*32767) for x in mix])
  if sys.byteorder!='little':pcm.byteswap()
  path=OUT/(name+'.wav')
  with wave.open(str(path),'wb') as wav:
   wav.setnchannels(1);wav.setsampwidth(2);wav.setframerate(RATE);wav.writeframes(pcm.tobytes())
  outputs.append({'id':name,'path':str(path.relative_to(ROOT)),'sha256':sha(path),
   'duration':duration,'frames':len(mix),'rate':RATE,'channels':1,'bits':16,
   'peak':target,'rms':math.sqrt(sum((x*scale)**2 for x in mix)/len(mix)),
   'post_mix_gain':scale,'layers':processed})
 files={'sources.json':{'version':VERSION,'sources':sources},
  'recipes.json':{'version':VERSION,'rate':RATE,'layer_fields':['source','speed','highpass_hz','lowpass_hz','duration','offset','gain'],'recipes':RECIPES},
  'manifest.json':{'version':VERSION,'task':'BELLSTRIDER-REWORK-01','assets':outputs,
   'producer':'tools/build_bellstrider_01_audio.py','producer_sha256':sha(__file__),
   'ffmpeg_version':subprocess.check_output(['ffmpeg','-version'],text=True).splitlines()[0],
   'license':'CC0-1.0','source_recordings_only':True,'oscillator_or_noise_layers':False,
   'subjective_status':'unverified','device_status':'unverified','engine_mix_status':'pending root capture'}}
 for filename,value in files.items():(OUT/filename).write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n')
 (OUT/'CC0-1.0.txt').write_bytes((ROOT/'assets/audio/ambience_v1/_sources/CC0-1.0.txt').read_bytes())
 print(f'Built {len(outputs)} Bellstrider cues from verified CC0 source bytes.')


def validate():
 manifest=read('assets/audio/bellstrider_01/manifest.json')
 assert manifest['producer_sha256']==sha(__file__),'producer changed'
 source_records()
 for row in manifest['assets']:
  path=ROOT/row['path'];assert sha(path)==row['sha256'],row['id']
  with wave.open(str(path),'rb') as wav:
   assert wav.getnchannels()==1 and wav.getsampwidth()==2 and wav.getframerate()==RATE
   pcm=array.array('h',wav.readframes(wav.getnframes()))
   if sys.byteorder!='little':pcm.byteswap()
   assert wav.getnframes()==row['frames']
   assert max(abs(x) for x in pcm)<32767
   assert sum(x*x for x in pcm)>0
 print(f'Validated {len(manifest["assets"])} source/output fingerprints, PCM format, nonzero energy and headroom. Listening/engine mix remain unverified.')


if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--validate',action='store_true');args=parser.parse_args()
 validate() if args.validate else build()
