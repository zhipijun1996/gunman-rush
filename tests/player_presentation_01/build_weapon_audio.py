from pathlib import Path
import sys,json,hashlib,array,wave,math,copy
r=Path(__file__).resolve().parents[2];sys.path.insert(0,str(r/'tests/player_presentation_01'))
from build_feel_audio import decode
out=r/'assets/player_presentation_01/weapon_audio_v1'
sources={};records=[]
for name in ['shot','armour','enemy_shot','impact','roar','enemy_defeat']:
 sources[name],record=decode(name);records.append(record)
recipes={'pulse':(.18,[('shot',.75),('armour',.13)]),'machine':(.115,[('shot',.45),('armour',.32)]),'blade':(.19,[('enemy_shot',.8),('armour',.12)]),'contact':(.14,[('impact',.55),('armour',.32)]),'blast':(.32,[('roar',.65),('enemy_defeat',.6),('impact',.25)]),'beam':(.8,[])}
files=[];preloads=[]
for cue,(duration,layers) in recipes.items():
 paths=[]
 for variant,rate in enumerate([.975,1,1.025]):
  values=[]
  for i in range(int(duration*48000)):
   t=i/48000;v=0
   for name,gain in layers:
    pos=i*rate*(1.22 if cue=='machine' else 1);j=int(pos);f=pos-j;a=sources[name]
    if j+1<len(a):v+=gain*(a[j]*(1-f)+a[j+1]*f)
   if cue=='beam':v=.35*math.sin(t*math.tau*135*rate)+.16*math.sin(t*math.tau*270*rate)+.07*math.sin(t*math.tau*540*rate)
   v*=min(1,t/(.02 if cue=='beam' else .0015))*min(1,(duration-t)/(.08 if cue=='beam' else .035))
   values.append(v)
  peak=max(map(abs,values)) or 1;gain=(.48 if cue=='beam' else .72)/peak*[1,.95,1.02][variant]
  pcm=array.array('h',[round(max(-.98,min(.98,v*gain))*32767) for v in values]);p=out/f'{cue}_{variant}.wav'
  with wave.open(str(p),'wb') as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(48000);w.writeframes(pcm.tobytes())
  item=dict(path=str(p.relative_to(r)),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),cue=cue,variant=variant,duration=duration,peak=max(map(abs,pcm))/32767);files.append(item);paths.append('preload("res://'+item['path']+'")')
 preloads.append('\t&"'+cue+'":['+','.join(paths)+'],')
(r/'game/combat/weapons/presentation/resources/weapon_sound_data.gd').write_text('extends RefCounted\nconst CLIPS := {\n'+'\n'.join(preloads)+'\n}\n')
pro=r/'assets/player_presentation_01/provenance/weapon-audio-provenance.json';pro.write_text(json.dumps(dict(task='PLAYER-PRESENTATION-01',version='weapon-audio-v1',sources=records,recipes=recipes,files=files,processing='Deterministic48k mono16;offline micro pitch/gain;1.5ms attack35ms tail,beam20ms/80ms;six familiesxthree variants;beam additive135/270/540Hz short0.8s state-gated cue,not music',license='Kenney CC0-1.0 originals retained;beam waveform authored mathematical sine synthesis;no third-party musical source',listening='unverified'),indent=2)+'\n')
print('Source recipes written beside audio; listening remains unverified')
