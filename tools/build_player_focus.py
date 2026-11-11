"""Register generated focus poses at one scale; synthesize original short SFX."""
import hashlib,json,math,random,struct,wave
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
D=ROOT/'assets/player_presentation_01/focus'

def build():
    source=D/'generated/player.png';im=Image.open(source).convert('RGBA')
    scale=46/311 # neutral hood crown to planted boot; all frames share this scale
    atlas=Image.new('RGBA',(320,128));frames=[]
    for i in range(8):
        x,y=i%4,i//4;rect=(x*im.width//4,y*im.height//2,(x+1)*im.width//4,(y+1)*im.height//2)
        c=im.crop(rect);c.putalpha(c.getchannel('A').point(lambda a:a if a>=128 else 0))
        b=c.getbbox();boots=c.crop((0,b[3]-24,c.width,b[3])).getchannel('A').getbbox()
        pivot=(boots[0]+boots[2])/2
        c=c.resize((round(c.width*scale),round(c.height*scale)),Image.Resampling.NEAREST)
        dx=43-round(pivot*scale);dy=58-c.getbbox()[3]
        frame=Image.new('RGBA',(80,64));frame.paste(c,(dx,dy));atlas.paste(frame,(x*80,y*64))
        frames.append({'source_cell':rect,'translation':[dx,dy],'bbox':frame.getbbox(),'pixel_sha256':hashlib.sha256(frame.tobytes()).hexdigest()})
    atlas.save(D/'poses.png')
    (D/'build.json').write_text(json.dumps({'reference':'assets/player_presentation_01/motion_v1/motion_source.png','reference_pivot':[168,242],'reference_body_height':182,'display_height':44,'control_height':311,'uniform_scale':scale,'anchor':[40,58],'canvas':[80,64],'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'frames':frames,'processing':'alpha<128 cleanup; nearest ONE scale; boot registration; no repaint/per-frame resize'},indent=2)+'\n')
    build_audio()

def build_audio():
    audio=D/'audio';audio.mkdir(exist_ok=True);rate=22050
    for name,duration in [('gather',1.04),('release',.55)]:
        samples=[];rng=random.Random(914);noise=0
        for i in range(round(duration*rate)):
            t=i/rate;p=t/duration;noise=.92*noise+.08*rng.uniform(-1,1)
            fade=min(1,t/.045)*min(1,(duration-t)/.055)
            if name=='gather':
                phase=math.tau*(330*t+170*t*t)
                v=(math.sin(phase)*.38+math.sin(phase*2.01)*.12+math.sin(phase*3)*.06+noise*.13)*(.55+.45*p)*fade
            else:
                v=sum(math.sin(math.tau*f*t)*.24*math.exp(-t*5) for f in [523.25,659.25,783.99])*fade+noise*.2*math.exp(-t*12)*fade
            samples.append(round(max(-.85,min(.85,v))*32767))
        with wave.open(str(audio/(name+'.wav')),'wb') as w:
            w.setnchannels(1);w.setsampwidth(2);w.setframerate(rate);w.writeframes(struct.pack('<'+'h'*len(samples),*samples))
if __name__=='__main__':
    import sys
    build_audio() if '--audio-only' in sys.argv else build()
