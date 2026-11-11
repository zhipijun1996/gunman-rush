"""Original pitched pickup chime. No game recordings or third-party samples."""
from pathlib import Path
import hashlib,json,math,struct,subprocess,wave
ROOT=Path(__file__).resolve().parents[1]
def build():
    out=ROOT/'build/game-feel-pass';out.mkdir(parents=True,exist_ok=True)
    rate=44100
    for name,upper in [('coin-clear',1760),('coin-soft',1568)]:
        phase=0.;samples=[];duration=.24
        for i in range(round(rate*duration)):
            t=i/rate;frequency=1320 if t<.045 else upper
            phase+=math.tau*frequency/rate
            envelope=min(1,t/.002)*math.exp(-max(0,t-.045)*17)*min(1,(duration-t)/.02)
            value=(math.sin(phase)*.50+math.sin(phase*2)*.13+math.sin(phase*3)*.045)*envelope
            samples.append(round(value*32767))
        with wave.open(str(out/(name+'.wav')),'wb') as f:
            f.setnchannels(1);f.setsampwidth(2);f.setframerate(rate);f.writeframes(struct.pack('<'+'h'*len(samples),*samples))
    target=ROOT/'assets/audio/kenney/coin.ogg'
    subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(out/'coin-clear.wav'),'-c:a','libvorbis','-q:a','6',str(target)],check=True)
    path=target.parent/'sources.json';data=json.loads(path.read_text())
    data['coin']={'pack':'original-player-feedback','original':'coin-clear.wav','source':'tools/audio_coin_chime.py','license':'project-original-synthesis','description':'Original short upward pitched ding; no sampled Mario audio','sha256':hashlib.sha256(target.read_bytes()).hexdigest()}
    path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
if __name__=='__main__':build()
