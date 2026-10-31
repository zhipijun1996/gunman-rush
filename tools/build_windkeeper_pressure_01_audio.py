"""Deterministic short Boss SFX from retained licensed recordings, no generated tone/noise.

Only WINDKEEPER-PRESSURE-01 files are written. No player/BGM/global profile edits.
"""
from pathlib import Path
from array import array
import hashlib,json,math,subprocess,sys,wave
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'assets/audio/windkeeper_pressure_01';RATE=44100
SOURCES=json.loads((OUT/'sources.json').read_text())['sources']
# Each layer: source, source-start seconds, playback-rate, offset seconds, gain,
# reverse flag, lowpass cutoff. Warn/release phases are separate accepted events.
def L(source,start=0,rate=1,offset=0,gain=1,reverse=False,cutoff=6000):
 return dict(source=source,start=start,rate=rate,offset=offset,gain=gain,reverse=reverse,lowpass_hz=cutoff)
RECIPES={
 'stomp_warning':(.48,[L('chain',rate=.72,gain=.50),L('bell',rate=.58,offset=.06,gain=.36,cutoff=2200)]),
 'stomp_warning_double':(.58,[L('chain',rate=.72,gain=.42),L('bell',rate=.58,offset=.03,gain=.36,cutoff=2200),L('bell',rate=.68,offset=.25,gain=.30,cutoff=2400)]),
 'lunge_warning':(.48,[L('cloth',start=.4,rate=.82,gain=.42),L('spring',rate=.60,offset=.08,gain=.48,cutoff=2200),L('bell',rate=.48,offset=.18,gain=.23,cutoff=1600)]),
 'sweep_warning':(.52,[L('chain',rate=.85,gain=.48),L('blade',rate=.65,offset=.12,gain=.40),L('bell',rate=.72,offset=.03,gain=.25,cutoff=2500)]),
 'gust_warning':(.52,[L('wind',start=2.1,rate=.85,gain=.62,reverse=True,cutoff=4200),L('cloth',start=1.1,rate=.9,offset=.12,gain=.33)]),
 'seeds_warning':(.46,[L('spring',rate=.92,gain=.42),L('bell',rate=.84,offset=.12,gain=.43,cutoff=3300)]),
 'platform_warning':(.60,[L('wood',rate=.70,gain=.42),L('chain',rate=.65,offset=.11,gain=.40),L('bell',rate=.54,offset=.28,gain=.32,cutoff=2200)]),
 'stomp_strike':(.38,[L('stone',rate=.75,gain=.70),L('wood',rate=.62,gain=.42),L('bell',rate=.63,offset=.025,gain=.25,cutoff=3000)]),
 'lunge_start':(.29,[L('cloth',start=.3,rate=1.25,gain=.70),L('spring',rate=.82,gain=.38)]),
 'lunge_land':(.36,[L('wood',rate=.55,gain=.65),L('stone',rate=.84,offset=.025,gain=.38),L('chain',rate=.85,offset=.09,gain=.26)]),
 'sweep_release':(.40,[L('blade',rate=.80,gain=.63),L('leaves',start=.08,rate=1.45,gain=.48),L('metal',rate=.75,offset=.07,gain=.22)]),
 'gust_release':(.60,[L('wind',start=5.8,rate=1.65,gain=.80,cutoff=4500),L('cloth',start=.8,rate=1.2,gain=.45)]),
 'seeds_release':(.28,[L('spring',rate=1.18,gain=.55),L('core',rate=1.18,offset=.02,gain=.22),L('blade',rate=1.35,offset=.045,gain=.32)]),
 'platform_impact':(.48,[L('stone',rate=.68,gain=.67),L('wood',rate=.58,offset=.02,gain=.55),L('metal',rate=.58,offset=.075,gain=.32)]),
 'link':(.16,[L('chain',rate=1.05,gain=.36),L('cloth',start=.3,rate=1.5,offset=.025,gain=.24)]),
 'recover':(.36,[L('cloth',start=1.6,rate=.82,gain=.42),L('chain',rate=.68,offset=.045,gain=.35)]),
 'phase':(.82,[L('cloth',start=.7,rate=.7,gain=.5),L('spring',rate=.62,offset=.1,gain=.36),L('bell',rate=.54,offset=.34,gain=.38,cutoff=2400)]),
 'hit':(.17,[L('metal',rate=.92,gain=.68),L('core',rate=.88,offset=.015,gain=.20)]),
 'death':(.46,[L('spring',rate=.48,gain=.62),L('metal',rate=.46,offset=.08,gain=.40),L('bell',rate=.45,offset=.02,gain=.23,cutoff=1700)]),
 'death_impact':(.58,[L('wood',rate=.45,gain=.62),L('stone',rate=.58,gain=.51),L('leaves',rate=.72,offset=.15,gain=.28)]),
 'death_final':(.90,[L('bell',rate=.69,gain=.43,cutoff=2700),L('bell',rate=.56,offset=.22,gain=.28,cutoff=2300),L('bell',rate=.43,offset=.43,gain=.16,cutoff=1800)]),
}
# Announce a frozen two/three-attack group only at its first warning. The
# additional bell onsets are embedded in the same stream, not extra voices.
for warning in ['stomp_warning','lunge_warning','sweep_warning','gust_warning','seeds_warning','platform_warning']:
 for count in [2,3]:
  if warning=='stomp_warning' and count==2:continue # existing double-foot cue
  duration,layers=RECIPES[warning]
  marker=[]
  for index in range(count):
   layer=L('bell',rate=.58-.04*index,offset=.035+index*.145,gain=.20 if index==0 else .16,cutoff=2200)
   layer['length_seconds']=.12;marker.append(layer)
  RECIPES[warning+'_combo'+str(count)]=(duration,layers+marker)


def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def decode(path):
 data=subprocess.check_output(['ffmpeg','-v','error','-i',str(path),'-f','f32le','-ac','1','-ar',str(RATE),'-'])
 result=array('f');result.frombytes(data)
 if sys.byteorder!='little':result.byteswap()
 return result

def build():
 samples={}
 for name,s in SOURCES.items():
  path=ROOT/s['path'];assert digest(path)==s['sha256'],name;samples[name]=decode(path)
 rows={}
 for name,(duration,layers) in RECIPES.items():
  count=round(duration*RATE);mix=[0.0]*count
  for layer in layers:
   raw=samples[layer['source']];available=max(0,len(raw)-round(layer['start']*RATE));length=min(count,round(available/layer['rate']),round(layer.get('length_seconds',duration)*RATE));start=round(layer['start']*RATE);offset=round(layer['offset']*RATE)
   local=[];previous=0.0;alpha=1-math.exp(-2*math.pi*layer['lowpass_hz']/RATE)
   for i in range(length):
    index=start+i*layer['rate'];lo=min(int(index),len(raw)-1);hi=min(lo+1,len(raw)-1);fraction=index-lo;v=raw[lo]*(1-fraction)+raw[hi]*fraction;previous+=alpha*(v-previous);local.append(previous)
   if layer['reverse']:local.reverse()
   # Per-recording RMS normalization is only processing gain, not synthesized sound.
   rms=math.sqrt(sum(v*v for v in local)/max(1,len(local)));gain=.14/max(.002,rms)*layer['gain']
   for i,v in enumerate(local):
    target=i+offset
    if target>=count:break
    env=min(1,i/(RATE*.004),(count-target)/(RATE*.06),(len(local)-i)/(RATE*.025))
    if name.endswith('warning'):env*=.48+.52*min(1,target/max(1,count-1))
    mix[target]+=v*gain*max(0,env)
  peak=max(abs(v) for v in mix);gain=min(1,(10**(-6/20))/max(peak,.001));pcm=array('h',(round(max(-1,min(1,v*gain))*32767) for v in mix))
  if sys.byteorder!='little':pcm.byteswap()
  path=OUT/(name+'.wav')
  with wave.open(str(path),'wb') as f:f.setnchannels(1);f.setsampwidth(2);f.setframerate(RATE);f.writeframes(pcm.tobytes())
  rows[name]={'path':'res://'+str(path.relative_to(ROOT)),'duration_seconds':duration,'layers':layers,'peak_normalized':peak*gain,'rms_normalized':math.sqrt(sum((v*gain)**2 for v in mix)/count),'sha256':digest(path),'bytes':path.stat().st_size}
 manifest={'schema_version':1,'task':'WINDKEEPER-PRESSURE-01','version':'windkeeper-pressure-audio-01','status':'candidate-awaiting-listening','sample_rate':RATE,'channels':1,'bits':16,'peak_ceiling_dbfs':-6,'processor_sha256':digest(Path(__file__)),'sources_sha256':digest(OUT/'sources.json'),'cues':rows,'runtime':'Existing GameAudio12voice pool; accepted encounter events only; no BGM/player/default bank edits.'}
 (OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
 print('WINDKEEPER PRESSURE AUDIO: '+str(len(rows))+' recorded-material cues built; no oscillator/noise synthesis')

if __name__=='__main__':build()
