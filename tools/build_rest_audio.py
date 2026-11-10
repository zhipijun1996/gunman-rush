import math,random,struct,wave
from pathlib import Path
D=Path(__file__).resolve().parents[1]/'assets/player_presentation_01/charging/audio';D.mkdir(exist_ok=True)
rate=22050
# Original deterministic synthesis. No third-party recordings or samples.
def render(name,duration,kind):
 rng=random.Random(721);samples=[];previous=0
 for i in range(round(duration*rate)):
  t=i/rate;fade=min(1,t/.035)*min(1,(duration-t)/.16)
  previous=.93*previous+.07*rng.uniform(-1,1)
  if kind=='contact':
   value=(math.sin(math.tau*580*t)*math.exp(-t*18)+.4*math.sin(math.tau*1173*t)*math.exp(-t*29))*.24*fade
  elif kind=='current':
   ramp=min(1,t/.25);envelope=(.8+.2*math.sin(math.tau*3*t))*fade
   value=(.16*math.sin(math.tau*(92*t+10*t*t))+.045*math.sin(math.tau*287*t)+previous*.14)*envelope*ramp
  else:
   value=0
   for delay,freq in [(0,523.25),(.09,659.25),(.18,783.99)]:
    a=t-delay
    if a>=0:value+=(math.sin(math.tau*freq*a)+.14*math.sin(math.tau*freq*2.01*a))*min(1,a/.025)*math.exp(-a*3.8)*.16
   value*=min(1,(duration-t)/.16)
  samples.append(int(max(-.85,min(.85,value))*32767))
 with wave.open(str(D/(name+'.wav')),'wb') as w:
  w.setnchannels(1);w.setsampwidth(2);w.setframerate(rate);w.writeframes(struct.pack('<'+'h'*len(samples),*samples))
 print(name,len(samples)/rate,max(abs(s) for s in samples)/32767)
render('contact',.24,'contact');render('current',1.65,'current');render('restore',.92,'restore')
