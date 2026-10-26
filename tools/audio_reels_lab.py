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
EVENTS = {
 'coin':['coin'], 'heal':['heal'], 'chest_open':['chest_open'], 'item_get':['item_get'],
 'ui':['click','confirm','denied'], 'enemy_hit':['enemy_hit'], 'enemy_hurt':['enemy_hurt'], 'hurt':['hurt'],
 'weapons':['shot_pulse','shot_shuriken','shot_bomb','bomb_explode'], 'mix':['coin','heal','enemy_hit','hurt'],
}
TITLES = {'coin':'金币 · 清脆收集','heal':'生命 · 液体回复','chest_open':'宝箱 · 锁扣与开盖','item_get':'道具 · 较长获得乐句','ui':'界面 · 点击、确认、拒绝','enemy_hit':'战斗 · 武器命中','enemy_hurt':'战斗 · 敌人受伤','hurt':'战斗 · 主角受伤','weapons':'武器 · 脉冲枪、手里剑、炸弹','mix':'连续场景 · 原家园BGM混音'}
EVENT_LABELS = {'coin':'金币收集','heal':'生命恢复','chest_open':'宝箱开启','item_get':'道具获得','click':'UI点击','confirm':'UI确认','denied':'UI拒绝','enemy_hit':'武器命中','enemy_hurt':'敌人受伤','hurt':'主角受伤','shot_pulse':'脉冲枪开火','shot_shuriken':'手里剑离手','shot_bomb':'炸弹弹出','bomb_explode':'炸弹爆炸'}
ORIGINAL_CUES = {'coin':'coin','heal':'heal','chest_open':'confirm','item_get':'note','click':'click','confirm':'confirm','denied':'denied','enemy_hurt':'hurt','hurt':'hurt'}
WEAPON_CUES = {'enemy_hit':'hit','shot_pulse':'pulse','shot_shuriken':'blade','bomb_explode':'blast'}

def read(p):return json.loads(Path(p).read_text())
def write(p,j):Path(p).write_text(json.dumps(j,ensure_ascii=False,indent=2)+'\n')
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def head():return subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()

def original_sources():
 records={};old=read(ROOT/'assets/audio/kenney/sources.json')
 for event,cue in ORIGINAL_CUES.items():
  p=ROOT/f'assets/audio/kenney/{cue}.ogg';s=old[cue]
  records['original/'+event]={'author':'Kenney','license':s['license'],'source_url':s['source'],'original_filename':s['original'],'commercial_use':True,'attribution_required':False,'path':str(p.relative_to(ROOT)),'sha256':sha(p),'download_date':'原项目来源记录，见assets/audio/kenney/sources.json'}
 for event,cue in WEAPON_CUES.items():
  paths=list((ROOT/'assets/player_presentation_01/weapon_audio_v2').glob(cue+'_*.wav'))
  records['original/'+event]={'author':'Freedoom contributors','license':'BSD-3-Clause','source_url':'https://freedoom.github.io/','original_filename':cue+'_0/1/2.wav (existing processed bank)','commercial_use':True,'attribution_required':True,'download_date':'原项目已存，见weapon-audio-v2-provenance.json','original_files':{str(p.relative_to(ROOT)):sha(p) for p in paths},'commercial_conditions':'Retain complete Freedoom COPYING.adoc with redistributed recordings/comparisons.'}
 p=ROOT/'assets/audio/bgm/the_kindred_hearth.mp3'
 records['original/home_bgm']={'author':'用户提供；作者以原provenance为准','license':'User-provided for this game/audition; no general reuse grant','source_url':'https://github.com/zhipijun1996/gunman-rush/blob/main/assets/audio/bgm/provenance.json','original_filename':p.name,'commercial_use':'Only as authorized for this project, not a third-party sample library','attribution_required':None,'commercial_conditions':'Only this game and its audition; third-party reuse/attribution terms have not been granted or independently verified.','path':str(p.relative_to(ROOT)),'sha256':sha(p),'download_date':'用户原提供，见assets/audio/bgm/provenance.json'}
 return records

def build(capture:Path,output:Path,interactive_url:str):
 if output.exists():raise ValueError('Use fresh --output; do not overwrite retained delivery evidence')
 from audio_candidates_v3 import validate
 from capture_audio_reels import validate_trace, sources
 validate()
 manifest=read(ROOT/'assets/audio/director_v3/manifest.json')
 choices={c['id']:c for e in manifest['events'] for c in e['candidates']}
 current=sources();validated=[];commits=set();engines=set()
 # Reject missing/changed captures before creating any deliverable directory.
 for reel in EVENTS:
  folder=capture/reel;report=read(folder/'report.json');trace=read(folder/'trace.json');movie=folder/(reel+'.mp4')
  if report.get('status')!='passed' or report.get('source_stable') is not True:raise ValueError('Capture not passed: '+reel)
  if report.get('source_before')!=current or report.get('source_after')!=current:raise ValueError('Capture runtime source differs: '+reel)
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
  commits.add(report['commit']);validated.append((reel,folder,report,segments,duration))
 if len(commits)!=1 or len(engines)!=1:raise ValueError('Recordings must share one frozen producer commit and engine')
 source=commits.pop()
 # Only documentation/evidence may change after the recorded implementation.
 tree={}
 for entry in subprocess.check_output(['git','ls-tree','-r','-z',source],cwd=ROOT).split(b'\0'):
  if not entry:continue
  meta,name=entry.split(b'\t',1);mode,kind,blob=meta.split();tree[name.decode()]=(mode.decode(),kind.decode(),blob.decode())
 for name in current:
  entry=tree.get(name)
  if not entry or entry[1]!='blob' or entry[0] not in ['100644','100755']:raise ValueError('Capture input not a regular producer file: '+name)
  p=ROOT/name;fingerprint=hashlib.sha1();fingerprint.update(('blob '+str(p.stat().st_size)+'\0').encode())
  with p.open('rb') as f:
   for chunk in iter(lambda:f.read(1024*1024),b''):fingerprint.update(chunk)
  if fingerprint.hexdigest()!=entry[2]:raise ValueError('Capture runtime input differs from producer commit: '+name)
 output.mkdir(parents=True);(output/'media').mkdir();(output/'posters').mkdir();(output/'audio').mkdir();(output/'licenses').mkdir()
 all_sources=copy.deepcopy(manifest['sources']);all_sources.update(original_sources())
 data={'schema_version':1,'task':TASK,'version':manifest['version'],'source_commit':source,'site_builder_commit':head(),'interactive_url':interactive_url,'interactive_label':'上一版互动工坊（V2） ↗','event_labels':EVENT_LABELS,'sources':all_sources,'clips':[],'subjective_status':'awaiting-user'}
 for reel,folder,report,segments,duration in validated:
  movie=folder/(reel+'.mp4');shutil.copyfile(movie,output/'media'/movie.name)
  poster=output/'posters'/(reel+'.jpg');poster_at=(segments[0]['start_frame']+min(70,segments[0]['end_frame']-segments[0]['start_frame']-1))/60
  subprocess.run(['ffmpeg','-v','error','-nostdin','-y','-ss',str(poster_at),'-i',str(movie),'-frames:v','1','-q:v','3',str(poster)],check=True,timeout=30)
  clip={'id':reel,'title':TITLES[reel],'category':'pickup' if reel in ['coin','heal','chest_open','item_get'] else 'ui' if reel=='ui' else 'combat' if reel in ['enemy_hit','enemy_hurt','hurt'] else 'weapons' if reel=='weapons' else 'mix','video':'media/'+movie.name,'poster':'posters/'+poster.name,'duration':duration,'audio_mode':'with_bgm' if reel=='mix' else 'sfx_only','audio_label':'Godot原录屏音轨 · 原家园BGM+SFX' if reel=='mix' else 'Godot原录屏音轨 · SFX，无BGM','notes':['明确开发fixture；原角色、真实接受事件与原生音轨。','原版为现有实际音色/增益，ABC待用户选择。'],'candidates':[],'movie_sha256':sha(movie),'trace_sha256':report['trace_sha256']}
  if reel in ['chest_open','item_get']:clip['notes'].append('原版无专用事件音，保留旧通用confirm/note映射并在画面标注；ABC为新设计。')
  if reel=='weapons':clip['notes'].append('按脉冲枪→手里剑→炸弹展示；原版炸弹弹出无专用声音，爆炸仍有原声。')
  for segment in segments:
   profile=segment['profile'];event_ids=EVENTS[reel];ids={e:e+'_'+profile.lower() for e in event_ids};source_ids=[]
   if profile=='original':
    ids={e:e+'_original' for e in event_ids};source_ids=['original/'+e for e in event_ids if 'original/'+e in all_sources]
   else:
    for cid in ids.values():source_ids+=choices[cid]['source_ids']
   if reel=='mix':source_ids+=['original/home_bgm']
   clip['candidates'].append({'id':reel+'_'+profile.lower(),'profile':profile,'label':'原版' if profile=='original' else manifest['profiles'][profile],'start':segment['start_frame']/60,'end':segment['end_frame']/60,'event_ids':event_ids,'event_candidate_ids':ids,'source_ids':list(dict.fromkeys(source_ids))})
  data['clips'].append(clip)
 for option in choices.values():
  for path in option['variants']:
   p=ROOT/path.removeprefix('res://');shutil.copyfile(p,output/'audio'/p.name)
 # Preserve terms and page snapshots; selected raw materials stay in source cache.
 license_inputs=[ROOT/'assets/player_presentation_01/weapon_audio_v2/sources/COPYING.adoc',ROOT/'assets/audio/bgm/provenance.json',*ROOT.glob('assets/audio/kenney/*LICENSE*')]
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
 write(output/'delivery.json',{'task':TASK,'version':data['version'],'source_commit':source,'site_builder_commit':data['site_builder_commit'],'clips':len(data['clips']),'candidate_segments':sum(len(c['candidates']) for c in data['clips']),'files':{p.relative_to(output).as_posix():{'bytes':p.stat().st_size,'sha256':sha(p)} for p in sorted(output.rglob('*')) if p.is_file()},'subjective_status':'awaiting-user'})
 print('AUDIO_REELS_LAB_OK',len(data['clips']),'clips',source,output)

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--capture-root',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--interactive-url',default='../');a=p.parse_args();build(a.capture_root,a.output,a.interactive_url)
if __name__=='__main__':main()
