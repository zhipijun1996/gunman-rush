import subprocess,json,hashlib
from pathlib import Path
from PIL import Image,ImageDraw
out=Path(__file__).parent/'media';out.mkdir(exist_ok=True)
ranges={'charger-hurt':(54,114),'charger-death':(178,229),'diver-hurt':(834,894),'diver-death':(962,1025)}
wanted=sorted({n for a,b in ranges.values() for n in range(a,b+1)}|{775,1555})
sel='+'.join(f'between(n,{a},{b})' for a,b in ranges.values())+'+eq(n,775)+eq(n,1555)';manifest={}
for case in ['movie','movie-legacy']:
 base=Path('/workspace/gunman-rush-work/build/enemy_feedback_01/v8')/case
 movie=base/'after.mp4';trace=json.loads((base/'after.json').read_text())['frames']
 cmd=['ffmpeg','-v','error','-i',str(movie),'-vf',"select='"+sel+"'",'-fps_mode','passthrough','-f','rawvideo','-pix_fmt','rgb24','pipe:1']
 p=subprocess.Popen(cmd,stdout=subprocess.PIPE);sheets={k:Image.new('RGB',(8*156,8*150),'#202027') for k in ranges};draws={k:ImageDraw.Draw(v) for k,v in sheets.items()};rows=[]
 for n in wanted:
  data=p.stdout.read(1280*720*3)
  if len(data)!=1280*720*3:raise RuntimeError((case,n,len(data)))
  im=Image.frombytes('RGB',(1280,720),data);r=trace[max(0,n-4)];body=r['remains'][0]
  pos=body['position'] if body['visible'] else [r['enemy_position'][0],r['enemy_position'][1]+16]
  cx=640+(pos[0]-575)*2.5;foot=360+(pos[1]-440)*2.5
  crop=(round(cx-98),round(foot-120),round(cx+98),round(foot+42))
  for key,(a,b) in ranges.items():
   if a<=n<=b:
    q=n-a;x=(q%8)*156;y=(q//8)*150;sheets[key].paste(im.crop(crop).resize((156,129)),(x,y+20));draws[key].text((x+3,y+2),str(n),fill='white')
  if n in [775,1555]:im.save(out/f'{case}-full-{n}.png')
  rows.append({'frame':n,'crop':crop})
 assert p.wait()==0
 for key,sheet in sheets.items():sheet.save(out/f'{case}-{key}-neighbors.png')
 manifest[case]={'movie_sha256':hashlib.sha256(movie.read_bytes()).hexdigest(),'frames':rows,'command':cmd,'method':'Every adjacent decoded MP4 frame in listed ranges; tracking crop approximate trace offset4; not normal playback/listening.'}
manifest['observer_sha256']=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
(out/'inspection-manifest.json').write_text(json.dumps(manifest,indent=2))
print('decoded',len(wanted),'frames per chain')
