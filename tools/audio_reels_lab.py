#!/usr/bin/env python3
"""Package immutable, validated native recordings for the existing mobile Sound Lab."""
from __future__ import annotations
import argparse
import copy
import hashlib
import json
import math
from pathlib import Path
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
TASK = 'AUDIO-DIRECTOR-03'
POST_VALIDATION_FILES={'tools/capture_audio_reels.py','tools/audio_reels_validation.py'}
EVENTS = {
 'coin':['coin'], 'heal':['heal'], 'chest_open':['chest_open'], 'item_get':['item_get'],
 'ui':['click','confirm','denied'], 'enemy_hit':['enemy_hit'], 'enemy_hurt':['enemy_hurt'], 'hurt':['hurt'],
 'weapons':['shot_pulse','shot_shuriken','shot_bomb','bomb_explode'], 'mix':['coin','heal','enemy_hit','hurt'],
}
TITLES = {'coin':'金币 · 清脆收集','heal':'生命 · 液体回复','chest_open':'宝箱 · 锁扣与开盖','item_get':'道具 · 较长获得乐句','ui':'界面 · 点击、确认、拒绝','enemy_hit':'战斗 · 武器命中','enemy_hurt':'战斗 · 敌人受伤','hurt':'战斗 · 主角受伤','weapons':'武器 · 脉冲枪、手里剑、炸弹','mix':'原BGM下 · 拾取与战斗片段'}
EVENT_LABELS = {'coin':'金币收集','heal':'生命恢复','chest_open':'宝箱开启','item_get':'道具获得','click':'UI点击','confirm':'UI确认','denied':'UI拒绝','enemy_hit':'武器命中','enemy_hurt':'敌人受伤','hurt':'主角受伤','shot_pulse':'脉冲枪开火','shot_shuriken':'手里剑离手','shot_bomb':'反冲炸弹发射','bomb_explode':'炸弹爆炸'}
ORIGINAL_CUES = {'coin':'coin','heal':'heal','chest_open':'confirm','item_get':'note','click':'click','confirm':'confirm','denied':'denied','enemy_hurt':'hurt','hurt':'hurt'}
WEAPON_CUES = {'enemy_hit':'hit','shot_pulse':'pulse','shot_shuriken':'blade','bomb_explode':'blast'}

def read(p):return json.loads(Path(p).read_text())
def write(p,j):Path(p).write_text(json.dumps(j,ensure_ascii=False,indent=2)+'\n')
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def head():return subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()

def original_sources():
 records={};old=read(ROOT/'assets/audio/kenney/sources.json')
 for cue,record in old.items():
  p=ROOT/f'assets/audio/kenney/{cue}.ogg'
  if not p.is_file():continue
  records['original/'+cue]={'author':'Kenney','license':record['license'],'source_url':record['source'],'original_filename':record['original'],'commercial_use':True,'attribution_required':False,'path':str(p.relative_to(ROOT)),'sha256':sha(p),'download_date':'原项目来源记录，见assets/audio/kenney/sources.json'}
 for event,cue in ORIGINAL_CUES.items():records['original/'+event]=copy.deepcopy(records['original/'+cue])
 bank=ROOT/'assets/player_presentation_01/weapon_audio_v2'
 for cue in sorted({p.stem.rsplit('_',1)[0] for p in bank.glob('*_0.wav')}):
  paths=sorted(bank.glob(cue+'_*.wav'))
  records['original_weapon/'+cue]={'author':'Freedoom contributors','license':'BSD-3-Clause','source_url':'https://freedoom.github.io/','original_filename':cue+'_0/1/2.wav (existing processed bank)','commercial_use':True,'attribution_required':True,'download_date':'原项目已存，见weapon-audio-v2-provenance.json','original_files':{str(p.relative_to(ROOT)):sha(p) for p in paths},'commercial_conditions':'Retain complete Freedoom COPYING.adoc with redistributed recordings/comparisons.'}
 for event,cue in WEAPON_CUES.items():records['original/'+event]=copy.deepcopy(records['original_weapon/'+cue])
 for cue in ['jump','land','heavy']:
  paths=sorted((ROOT/'assets/player_presentation_01/feel_audio_v1').glob(cue+'_*.wav'))
  records['original_motion/'+cue]={'author':'Kenney; existing project edits','license':'CC0-1.0','source_url':'https://kenney.nl/assets/impact-sounds','original_filename':cue+'_0/1/2.wav (retained feel-audio-v1)','commercial_use':True,'attribution_required':False,'download_date':'原项目已存，见feel-audio-provenance.json','original_files':{str(p.relative_to(ROOT)):sha(p) for p in paths},'processing_provenance':'docs/worklines/PLAYER-PRESENTATION-01/feel-audio-provenance.json'}
 p=ROOT/'assets/audio/bgm/the_kindred_hearth.mp3'
 records['original/home_bgm']={'author':'用户提供；作者以原provenance为准','license':'User-provided for this game/audition; no general reuse grant','source_url':'https://github.com/zhipijun1996/gunman-rush/blob/main/assets/audio/bgm/provenance.json','original_filename':p.name,'commercial_use':'Only as authorized for this project, not a third-party sample library','attribution_required':None,'commercial_conditions':'Only this game and its audition; third-party reuse/attribution terms have not been granted or independently verified.','path':str(p.relative_to(ROOT)),'sha256':sha(p),'download_date':'用户原提供，见assets/audio/bgm/provenance.json'}
 return records

def recorded_source_ids(segment, choices, all_sources):
 ids=[]
 for event in segment['director_events']:ids.extend(choices[event['candidate']]['source_ids'])
 for cue,count in segment['played_delta'].items():
  if not count or cue.startswith('director_'):continue
  key='original_weapon/'+cue[7:] if cue.startswith('weapon_') else 'original_motion/'+cue[7:] if cue.startswith('motion_') else 'original/'+cue
  if key not in all_sources:raise ValueError('Recorded companion sound has no source/license record: '+cue)
  ids.append(key)
 return list(dict.fromkeys(ids))

def build(capture:Path,output:Path,interactive_url:str):
 if output.exists():raise ValueError('Use fresh --output; do not overwrite retained delivery evidence')
 from audio_candidates_v3 import validate
 from capture_audio_reels import validate_trace, sources
 from audio_reels_validation import validate_audio_windows
 validate()
 manifest=read(ROOT/'assets/audio/director_v3/manifest.json')
 choices={c['id']:c for e in manifest['events'] for c in e['candidates']}
 current=sources();validated=[];commits=set();engines=set();producer_inputs=None;audio_audits={}
 # Reject missing/changed captures before creating any deliverable directory.
 for reel in EVENTS:
  folder=capture/reel;report=read(folder/'report.json');trace=read(folder/'trace.json');movie=folder/(reel+'.mp4')
  if report.get('status')!='passed' or report.get('source_stable') is not True:raise ValueError('Capture not passed: '+reel)
  before=report.get('source_before')
  if not isinstance(before,dict) or report.get('source_after')!=before:raise ValueError('Captured producer source was unstable: '+reel)
  if producer_inputs is None:producer_inputs=before
  if producer_inputs!=before:raise ValueError('Producer snapshots differ across recordings')
  if {k:v for k,v in before.items() if k not in POST_VALIDATION_FILES}!={k:v for k,v in current.items() if k not in POST_VALIDATION_FILES}:raise ValueError('Captured game/scene/engine inputs differ from current frozen runtime: '+reel)
  if report.get('trace_sha256')!=sha(folder/'trace.json'):raise ValueError('Trace hash mismatch: '+reel)
  if report.get('movie_sha256')!=sha(movie):raise ValueError('Movie hash mismatch: '+reel)
  count=report['frame_count']
  if not isinstance(count,(int,float)) or not math.isfinite(count) or count!=int(count):raise ValueError('Non-integral movie frame count')
  engine=report['engine']
  if not engine['version'].startswith('4.7.2') or len(engine['sha256'])!=64:raise ValueError('Unverified capture engine identity')
  engines.add((engine['version'],engine['sha256']))
  frame_count=int(count);segments=validate_trace(trace,reel,frame_count,manifest)
  if movie.stat().st_size>25*1024*1024:raise ValueError('Movie exceeds static per-file limit')
  media=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(movie)],timeout=30));video=next(s for s in media['streams'] if s['codec_type']=='video');audio=next(s for s in media['streams'] if s['codec_type']=='audio')
  if int(video.get('nb_frames',-1))!=frame_count:raise ValueError('Actual MP4 frame count differs from receipt')
  if video['avg_frame_rate']!='60/1' or int(audio['sample_rate'])!=48000 or int(audio['channels'])!=2:raise ValueError('Unexpected movie format')
  duration=float(media['format']['duration'])
  if abs(duration-frame_count/60)>.1:raise ValueError('Movie duration/frame count drift')
  audio_audits[reel]=validate_audio_windows(movie,trace,reel,manifest)
  commits.add(report['commit']);validated.append((reel,folder,report,segments,duration))
 if len(commits)!=1 or len(engines)!=1:raise ValueError('Recordings must share one frozen producer commit and engine')
 source=commits.pop()
 # Only documentation/evidence may change after the recorded implementation.
 tree={}
 for entry in subprocess.check_output(['git','ls-tree','-r','-z',source],cwd=ROOT).split(b'\0'):
  if not entry:continue
  meta,name=entry.split(b'\t',1);mode,kind,blob=meta.split();tree[name.decode()]=(mode.decode(),kind.decode(),blob.decode())
 for name in producer_inputs:
  entry=tree.get(name)
  if not entry or entry[1]!='blob' or entry[0] not in ['100644','100755']:raise ValueError('Capture input not a regular producer file: '+name)
  if name in POST_VALIDATION_FILES:
   blob=subprocess.check_output(['git','show',source+':'+name],cwd=ROOT)
   if hashlib.sha256(blob).hexdigest()!=producer_inputs[name]:raise ValueError('Historical producer tool differs from its actual recorded Git source')
   continue
  p=ROOT/name;fingerprint=hashlib.sha1();fingerprint.update(('blob '+str(p.stat().st_size)+'\0').encode())
  with p.open('rb') as f:
   for chunk in iter(lambda:f.read(1024*1024),b''):fingerprint.update(chunk)
  if fingerprint.hexdigest()!=entry[2]:raise ValueError('Capture runtime input differs from producer commit: '+name)
 output.mkdir(parents=True);(output/'media').mkdir();(output/'posters').mkdir();(output/'audio').mkdir();(output/'licenses').mkdir();(output/'verification').mkdir()
 for reel,audit in audio_audits.items():write(output/'verification'/(reel+'-audio.json'),audit)
 all_sources=copy.deepcopy(manifest['sources']);all_sources.update(original_sources())
 data={'schema_version':1,'task':TASK,'version':manifest['version'],'source_commit':source,'site_builder_commit':head(),'interactive_url':interactive_url,'interactive_label':'上一版互动工坊（V2） ↗','event_labels':EVENT_LABELS,'sources':all_sources,'clips':[],'subjective_status':'awaiting-user','post_validation_tool_sha256':sha(ROOT/'tools/audio_reels_validation.py'),'verification_upgrade':'Original 4d footage and producer snapshots retained. Only capture/post-validation Python tools upgraded after recording to reject numerical zero-energy FFT false peaks; all game/scene/assets/config inputs remain the original frozen bytes.'}
 for reel,folder,report,segments,duration in validated:
  movie=folder/(reel+'.mp4');shutil.copyfile(movie,output/'media'/movie.name)
  poster=output/'posters'/(reel+'.jpg');poster_at=(segments[0]['start_frame']+min(70,segments[0]['end_frame']-segments[0]['start_frame']-1))/60
  subprocess.run(['ffmpeg','-v','error','-nostdin','-y','-ss',str(poster_at),'-i',str(movie),'-frames:v','1','-q:v','3',str(poster)],check=True,timeout=30)
  clip={'id':reel,'title':TITLES[reel],'category':'pickup' if reel in ['coin','heal','chest_open','item_get'] else 'ui' if reel=='ui' else 'combat' if reel in ['enemy_hit','enemy_hurt','hurt'] else 'weapons' if reel=='weapons' else 'mix','video':'media/'+movie.name,'poster':'posters/'+poster.name,'duration':duration,'audio_mode':'with_bgm' if reel=='mix' else 'sfx_only','audio_label':'Godot原录屏音轨 · 原家园BGM+SFX' if reel=='mix' else 'Godot原录屏音轨 · SFX，无BGM','notes':['明确开发fixture；原角色、真实接受事件与原生音轨。','原版为现有实际音色/增益，ABC待用户选择。'],'candidates':[],'movie_sha256':sha(movie),'trace_sha256':report['trace_sha256']}
  if reel in ['chest_open','item_get']:clip['notes'].append('原版无专用事件音，保留旧通用confirm/note映射并在画面标注；ABC为新设计。')
  if reel=='mix':clip['notes'].append('原生连续录制中的样板片段切换：拾取后重建战斗fixture，BGM继续；不是自然无重置通关。')
  if reel in ['enemy_hit','enemy_hurt']:clip['notes'].append('场景也包含该方案的脉冲枪开火；此片重点比较对应命中/受伤层，选定后再验所选声音的组合。')
  if reel=='weapons':clip['notes'].append('按脉冲枪→手里剑→炸弹展示；原版炸弹弹出无专用声音，爆炸仍有原声。')
  for segment in segments:
   profile=segment['profile'];event_ids=EVENTS[reel];ids={e:e+'_'+profile.lower() for e in event_ids}
   if profile=='original':ids={e:e+'_original' for e in event_ids}
   source_ids=recorded_source_ids(segment,choices,all_sources)
   if reel=='mix':source_ids+=['original/home_bgm']
   clip['candidates'].append({'id':reel+'_'+profile.lower(),'profile':profile,'label':'原版' if profile=='original' else '方案 '+profile,'start':segment['start_frame']/60,'end':segment['end_frame']/60,'event_ids':event_ids,'event_candidate_ids':ids,'source_ids':list(dict.fromkeys(source_ids)),'audible_candidate_ids':[e['candidate'] for e in segment['director_events']]})
  if reel=='weapons':
   # Chapter views share the original unedited MP4. Absolute accepted-event
   # frames make each real weapon quick to compare without replaying the others.
   for child_id,title,target_events in [('shot_pulse','武器 · 脉冲枪发射',['shot_pulse']),('shot_shuriken','武器 · 手里剑离手',['shot_shuriken']),('bomb_weapon','武器 · 反冲炸弹发射与爆破',['shot_bomb','bomb_explode'])]:
    chapter=copy.deepcopy(clip);chapter.update(id=child_id,title=title,source_reel='weapons',candidates=[])
    for parent,segment in zip(clip['candidates'],segments):
     event_map={e['event_id']:e for e in segment['events']};event_frame=int(event_map[target_events[0]]['movie_frame'])
     following=[int(e['movie_frame']) for e in segment['events'] if e['event_id'] in ['shot_pulse','shot_shuriken','shot_bomb'] and int(e['movie_frame'])>event_frame]
     begin=max(int(segment['start_frame']),event_frame-18);end=min(following)-6 if following else int(segment['end_frame'])
     if begin>=end:raise ValueError('Invalid real weapon chapter')
     c=copy.deepcopy(parent);c.update(id=child_id+'_'+parent['profile'].lower(),start=begin/60,end=end/60,event_ids=target_events,event_candidate_ids={e:parent['event_candidate_ids'][e] for e in target_events})
     c['audible_candidate_ids']=[e['candidate'] for e in segment['director_events'] if begin<=e['movie_frame']<end]
     chapter['candidates'].append(c)
    chapter['notes']=['同一份真实三武器录屏的原音轨章节；候选按钮直接跳到此武器，无后配或重排音画。','当前基础反冲炸弹是即时爆破，这里比较整体声音；原版只有原爆破声。' if child_id=='bomb_weapon' else '每方案相同真实武器/输入；命中与受伤另有场景。']
    chapter_poster=output/'posters'/(child_id+'.jpg');at=min(chapter['candidates'][0]['end']-.05,chapter['candidates'][0]['start']+.5)
    subprocess.run(['ffmpeg','-v','error','-nostdin','-y','-ss',str(at),'-i',str(movie),'-frames:v','1','-q:v','3',str(chapter_poster)],check=True,timeout=30)
    chapter['poster']='posters/'+chapter_poster.name;data['clips'].append(chapter)
  else:data['clips'].append(clip)
 for option in choices.values():
  for path in option['variants']:
   p=ROOT/path.removeprefix('res://');shutil.copyfile(p,output/'audio'/p.name)
 # Preserve terms and page snapshots; selected raw materials stay in source cache.
 license_inputs=[ROOT/'docs/worklines/PLAYER-PRESENTATION-01/feel-audio-provenance.json',ROOT/'docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-v2-provenance.json',ROOT/'assets/player_presentation_01/weapon_audio_v2/sources/COPYING.adoc',ROOT/'assets/audio/bgm/provenance.json',*ROOT.glob('assets/audio/kenney/*LICENSE*')]
 for p in (ROOT/'assets/audio/director_v3/_sources').rglob('*'):
  if p.is_file() and p.suffix.lower() in ['.txt','.html','.md','.adoc']:license_inputs.append(p)
 for i,p in enumerate(license_inputs):
  if p.is_file():shutil.copyfile(p,output/'licenses'/f'{i:03d}-{p.name}')
 shutil.copyfile(ROOT/'assets/audio/director_v3/manifest.json',output/'sound-manifest.json')
 shutil.copyfile(ROOT/'config/audio_director/v3/recipes.json',output/'recipes.json')
 shutil.copyfile(ROOT/'tools/sound_lab/reels_index.html',output/'index.html')
 write(output/'sources.json',{'sources':all_sources})
 write(output/'reels.json',data)
 (output/'README.txt').write_text('失序之钟 · V3真实场景有声试听录屏\n直接打开media/*.mp4即可比较原版/A/B/C；网页用HTTP服务器打开index.html，首次点击声音播放。\n所有声音是实际Godot录屏原音轨，未后配替换。正常60Hz片段不是实体性能证明；审美待用户。\n新候选CC0；原游戏Freedoom-derived音色保留BSD3许可；混音片含用户提供原BGM，仅限本项目试听，不提供第三方素材再用授权。\n离线包不含185MB游戏，禁用不存在的互动入口。选择只存本浏览器，可导出JSON。\n')
 # Individual MP4s remain downloadable when the full bundle would exceed hosting limit.
 total=sum(p.stat().st_size for p in output.rglob('*') if p.is_file())
 if total<24*1024*1024:
  data['download_url']='audio-scene-reels.zip';write(output/'reels.json',data)
  with zipfile.ZipFile(output/'audio-scene-reels.zip','w',zipfile.ZIP_DEFLATED) as z:
   for p in sorted(output.rglob('*')):
    if not p.is_file() or p.suffix=='.zip':continue
    name=p.relative_to(output).as_posix()
    if name=='reels.json':
     offline=copy.deepcopy(data);offline['interactive_url']='';offline.pop('download_url',None);offline['offline_comparison']=True;z.writestr(name,json.dumps(offline,ensure_ascii=False,indent=2)+'\n')
    else:z.write(p,name)
  if (output/'audio-scene-reels.zip').stat().st_size>25*1024*1024:raise ValueError('Comparison bundle unexpectedly exceeds limit')
 write(output/'delivery.json',{'task':TASK,'version':data['version'],'source_commit':source,'site_builder_commit':data['site_builder_commit'],'movies':len(validated),'clips':len(data['clips']),'candidate_segments':sum(len(c['candidates']) for c in data['clips']),'files':{p.relative_to(output).as_posix():{'bytes':p.stat().st_size,'sha256':sha(p)} for p in sorted(output.rglob('*')) if p.is_file()},'subjective_status':'awaiting-user'})
 print('AUDIO_REELS_LAB_OK',len(data['clips']),'clips',source,output)

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--capture-root',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--interactive-url',default='../');a=p.parse_args();build(a.capture_root,a.output,a.interactive_url)
if __name__=='__main__':main()
