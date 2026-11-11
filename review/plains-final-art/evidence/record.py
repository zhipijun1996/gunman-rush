import subprocess,os,re,json
from pathlib import Path
base=Path('build/plains-final-art');(base/'movies').mkdir(exist_ok=True);(base/'clips').mkdir(exist_ok=True)
groups={'approved_draft_actions':[4,5,7,9,17,19,28,29,30,31],'approved_hub_actions':[2],'approved_clock_rooms':[11,16],'approved_exploration_rooms':[12,13,18,34],'approved_final_rooms':[10,20]}
summary={}
for test,rooms in groups.items():
 wrapper=base/'movies'/f'{test}.gd'
 wrapper.write_text(f'''extends "res://tests/world/{test}.gd"
func fixture(at:Vector2)->void:
 await ticks(30)
 print("SEGMENT_END ",Engine.get_frames_drawn())
 await super.fixture(at)
 print("SEGMENT_BEGIN ",Engine.get_frames_drawn()," ",at)
 await ticks(60)
func check(ok:bool,label:String)->void:
 super.check(ok,label)
 print("SEGMENT_CHECK ",Engine.get_frames_drawn()," ",ok," ",label)
''')
 for n in rooms:
  rid=f'P-R{n:02}';log=base/'movies'/f'{rid}.log';avi=base/'movies'/f'{rid}.avi'
  env=dict(os.environ,DISPLAY=':108',LIBGL_ALWAYS_SOFTWARE='1')
  with log.open('w') as f:code=subprocess.run(['bash','tools/godot.sh','--path','.','--script',str(wrapper),'--write-movie',str(avi),'--fixed-fps','30','--',rid],stdout=f,stderr=subprocess.STDOUT,env=env).returncode
  text=log.read_text();duration=float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','default=nw=1:nk=1',str(avi)]))
  segments=[];active=None
  for line in text.splitlines():
   if line.startswith('SEGMENT_END') and active:
    active['end']=int(line.split()[1]);segments.append(active);active=None
   if line.startswith('SEGMENT_BEGIN'):
    active=dict(start=int(line.split()[1]),labels=[])
   if line.startswith('SEGMENT_CHECK') and active:active['labels'].append(line)
  if active:active['end']=int(duration*30)-2;segments.append(active)
  usable=[s for s in segments if s['end']-s['start']>=30 and any(re.search('recoil|rides|hook|jump|shot|lands|grapple|through|cross|loop|climb|return',l,re.I) for l in s['labels'])]
  if not usable:usable=[s for s in segments if s['end']-s['start']>=30]
  selected=sorted(sorted(usable,key=lambda s:s['end']-s['start'],reverse=True)[:2],key=lambda s:s['start'])
  clips=[]
  for i,s in enumerate(selected):
   out=base/'clips'/f'{rid}-{i+1}.mp4';start=s['start']/30;length=min(12,(s['end']-s['start'])/30)
   subprocess.run(['ffmpeg','-v','error','-y','-ss',str(start),'-i',str(avi),'-t',str(length),'-vf','scale=960:540:flags=neighbor','-c:v','libx264','-preset','fast','-crf','25','-c:a','aac','-b:a','80k','-movflags','+faststart',str(out)],check=True)
   subprocess.run(['ffmpeg','-v','error','-i',str(out),'-f','null','-'],check=True)
   clips.append(dict(file=out.name,start=start,duration=length,labels=s['labels']))
  summary[rid]=dict(exit_code=code,raw_duration=duration,clips=clips,method='正式控制器局部动作夹具；多数隔离敌人，镜头与游戏时间正常；起点夹具间已拆段，不代表连续通关或完整战斗')
  (base/'movies'/'index.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
  avi.unlink();print(rid,code,len(clips),'clips',flush=True)
