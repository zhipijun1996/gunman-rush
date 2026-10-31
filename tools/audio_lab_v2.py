#!/usr/bin/env python3
"""Build the scene-first Audio Director V2 room from licensed, frozen candidates."""
from __future__ import annotations
import argparse
import hashlib
import json
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
MANIFEST=ROOT/'assets/audio/director_v2/manifest.json'
CONTEXTS={'click':'ui','confirm':'ui','denied':'ui','coin':'pickup','heal':'pickup','reward':'pickup','enemy_hit':'combat','enemy_hurt':'combat','hurt':'combat'}
ORIGINALS={
 'click':('assets/audio/kenney/click.ogg',10,'原版通用按钮点击'),
 'confirm':('assets/audio/kenney/confirm.ogg',7,'原版已接受确认'),
 'denied':('assets/audio/kenney/denied.ogg',7,'原版拒绝'),
 'coin':('assets/audio/kenney/coin.ogg',7,'原版金币'),
 'heal':('assets/audio/kenney/heal.ogg',7,'原版生命恢复'),
 'reward':('assets/audio/kenney/note.ogg',7,'原版普通奖励参考note'),
 'enemy_hit':('assets/player_presentation_01/weapon_audio_v2/hit_0.wav',10,'原版V2武器已接受敌伤反馈层；情境内单事件焦点不叠另一层'),
 'enemy_hurt':('assets/audio/kenney/hurt.ogg',7,'原版敌人受伤层；情境内与武器命中层分开比较'),
 'hurt':('assets/audio/kenney/hurt.ogg',7,'原版主角受伤'),
}
MUSIC={'the_kindred_hearth':'家园','where_the_path_bends':'风铃平原','across_the_wooden_sails':'平原Boss','vines_beneath_the_canopy':'荆棘森林','beyond_the_knotted_vines':'森林Boss'}

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text())
def write(p,j):Path(p).write_text(json.dumps(j,ensure_ascii=False,indent=2)+'\n')
def head():return subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()

def build(output:Path,game_url='game/'):
 if output.exists():raise ValueError('Use a fresh output directory; immutable deliveries must not be overwritten')
 from audio_candidates_v2 import validate
 validate() # Fail closed before copying any runtime playback path.
 manifest=read(MANIFEST);sources=read(ROOT/'config/audio_director/v2/sources.json')['sources'];rules=read(ROOT/'config/audio_director/v2/runtime.json')['events']
 profiles=manifest['profiles'];profiles=[{'id':k,'label':v} for k,v in profiles.items()] if isinstance(profiles,dict) else profiles
 if [p['id'] for p in profiles]!=['A','B','C']:raise ValueError('Expected three explicit V2 profiles')
 output.mkdir(parents=True);media=output/'audio';media.mkdir();music=output/'music';music.mkdir();licenses=output/'licenses';licenses.mkdir()
 data={'schema_version':2,'task':'AUDIO-DIRECTOR-02','version':manifest['version'],'source_commit':head(),'profiles':profiles,'game_url':game_url,'sources':dict(sources),'events':[],'music':[],'comparison_url':'audio-comparison.zip','preserved_events':['jump','land','shot','enemy_death','hook_release','hook_connect','hook_pull'],'subjective_status':'awaiting-user'}
 from audio_director import metrics
 legacy=read(ROOT/'assets/audio/kenney/sources.json')
 for event in manifest['events']:
  eid=event['id'];entry={k:event[k] for k in ('id','label','category')};entry['context']=CONTEXTS[eid];entry['candidates']=[]
  for candidate in event['candidates']:
   c={k:candidate[k] for k in ('id','label','design','version','profile','source_ids','duration','peak_dbfs','rms_dbfs') if k in candidate};c['profile']=c.get('profile',c['id'].rsplit('_',1)[-1].upper());c['version']=data['version'];c['attenuation_db']=float(rules[eid].get('attenuation_db',8));c['variants']=[]
   for resource in candidate['variants']:
    source=ROOT/resource.removeprefix('res://');target=media/source.name;shutil.copyfile(source,target);c['variants'].append('audio/'+target.name)
   c['path']=c['variants'][0];entry['candidates'].append(c)
  relative,attenuation,note=ORIGINALS[eid];source=ROOT/relative;target=media/(eid+'_original.wav')
  subprocess.run(['ffmpeg','-nostdin','-v','error','-y','-i',str(source),'-ac','1','-ar','44100','-c:a','pcm_s16le',str(target)],check=True)
  sourceid='original/'+eid
  if eid=='enemy_hit':record={'author':'Freedoom contributors','license':'BSD-3-Clause','source_url':'https://freedoom.github.io/','original_filename':'weapon_audio_v2/hit_0.wav (加工记录见原项目来源)','attribution_required':True,'download_date':'原项目已存；详见原provenance','commercial_use':True}
  else:
   old=legacy[source.stem];record={'author':'Kenney','license':old['license'],'source_url':old['source'],'original_filename':old['original'],'attribution_required':False,'download_date':'2026-10-11（项目原来源记录）','commercial_use':True}
  record.update(path=relative,sha256=sha(source));data['sources'][sourceid]=record
  entry['original']={'id':eid+'_original','profile':'original','label':'原版','path':'audio/'+target.name,'variants':['audio/'+target.name],'version':'original-main-26e7f2a','source_ids':[sourceid],'attenuation_db':attenuation,'design':note,'original_path':relative,'original_sha256':sha(source),**metrics(target)}
  data['events'].append(entry)
 for stem,label in MUSIC.items():
  source=ROOT/'assets/audio/bgm'/(stem+'.mp3');shutil.copyfile(source,music/source.name);data['music'].append({'label':label,'path':'music/'+source.name,'sha256':sha(source),'original_bytes':True})
 # External terms remain visible even when a Godot package omits source caches.
 index=[]
 inputs=[*ROOT.glob('assets/audio/kenney/*LICENSE*'),ROOT/'assets/player_presentation_01/weapon_audio_v2/sources/COPYING.adoc',ROOT/'assets/audio/bgm/provenance.json']
 for p in (ROOT/'assets/audio/director_v2/_sources').rglob('*'):
  if p.is_file() and (p.suffix.lower() in ['.txt','.md','.html','.adoc'] or 'license' in p.name.lower()):inputs.append(p)
 for i,p in enumerate(inputs):
  if p.is_file():
   name=f'{i:02d}-{p.name}';shutil.copyfile(p,licenses/name);index.append(f'{name}: {p.relative_to(ROOT)} SHA256 {sha(p)}')
 (licenses/'README.txt').write_text('V2 candidate inputs CC0. Original enemy-hit comparison is Freedoom BSD-3-Clause; retain COPYING. Five original MP3 files are user-provided for this game and audition; no general reuse permission.\n'+'\n'.join(index)+'\n')
 write(output/'lab.json',data);write(output/'sources.json',{'sources':data['sources']});shutil.copyfile(MANIFEST,output/'manifest.json');shutil.copyfile(ROOT/'tools/sound_lab/v2_index.html',output/'index.html')
 (output/'README.txt').write_text('失序之钟 Sound Lab V2\nHTTP服务器打开index.html。9事件原版+3套少加工CC0候选，保原起跳/落地。选择记录仅存当前浏览器。\n包内包括五首原BGM，仅供本项目试听。真实Godot场景需网站中的game/目录或在线站点；比较ZIP不包含185MB游戏包。\n真实情境为development fixture，复用正式角色/敌人/受付服务；单事件焦点区分武器命中与敌人受伤，避免叠双瞬态。\n')
 # The comparison archive is self-contained for single sounds/BGM and explicitly
 # disables the separately hosted game, rather than shipping a broken game link.
 with zipfile.ZipFile(output/'audio-comparison.zip','w',zipfile.ZIP_DEFLATED) as z:
  for p in sorted(output.rglob('*')):
   if not p.is_file() or p.suffix=='.zip':continue
   name=p.relative_to(output).as_posix()
   if name=='lab.json':
    offline=dict(data);offline['game_url']='';offline['offline_comparison']=True;z.writestr(name,json.dumps(offline,ensure_ascii=False,indent=2)+'\n')
   else:z.write(p,name)
 write(output/'listening-delivery.json',{'task':data['task'],'version':data['version'],'source_commit':data['source_commit'],'files':{p.relative_to(output).as_posix():{'sha256':sha(p),'bytes':p.stat().st_size} for p in sorted(output.rglob('*')) if p.is_file()},'aesthetic_status':'awaiting-user'})
 print(f'AUDIO_LAB_V2_OK events={len(data["events"])} profiles=3 output={output}')

def stage(bundle:Path,output:Path):
 from cloud_delivery import validate_bundle,inject_entry
 info,receipt=validate_bundle(bundle,ROOT,'res://experiments/audio/entries/audio_director_lab_v2.tscn');build(output,'game/')
 game=output/'game';shutil.copytree(bundle,game);page=(game/'index.html').read_text();original=sha(game/'index.html');page=inject_entry(page,'AUDIO-DIRECTOR-02','audio-director-v2/context-01','scene','res://experiments/audio/entries/audio_director_lab_v2.tscn')
 old='window.PLAYTEST_CACHE_READY.then(() => engine.startGame({'
 new="window.PLAYTEST_CACHE_READY.then(ready => { if (!ready || typeof DecompressionStream === 'undefined') throw new Error('真实场景需要支持 Service Worker 与 DecompressionStream 的现代浏览器；可先用单声试听。'); return engine.startGame({"
 if page.count(old)!=1:raise ValueError('Original loader changed; refuse unverified patch')
 page=page.replace(old,new).replace('})).then(() => {','}); }).then(() => {');(game/'index.html').write_text(page)
 removed=[]
 for p in list(game.iterdir()):
  if p.suffix=='.pck' or p.name.endswith('.wasm') or p.name.endswith('.wasm.gz'):
   removed.append({'path':p.name,'bytes':p.stat().st_size,'sha256':sha(p)});p.unlink()
 shutil.copyfile(ROOT/'config/audio_director/v2/sources.json',game/'Audio-Director-v2-sources.json')
 write(game/'hosting-adaptation.json',{'task':'AUDIO-DIRECTOR-02','source_commit':info['source_commit'],'build_id':info['build_id'],'original_pack_verification':receipt,'mode':'Original exact hash-verified chunks; explicitly requires ServiceWorker and DecompressionStream. Raw fallback unavailable.','virtual_resources':removed,'original_html_sha256':original})
 files=[p for p in output.rglob('*') if p.is_file()]
 if any(p.stat().st_size>25*1024*1024 for p in files):raise ValueError('Static file over25MiB')
 write(output/'site-delivery.json',{'task':'AUDIO-DIRECTOR-02','version':'audio-director-v2','source_commit':info['source_commit'],'build_id':info['build_id'],'files':{p.relative_to(output).as_posix():{'bytes':p.stat().st_size,'sha256':sha(p)} for p in sorted(files)},'aesthetic_status':'awaiting-user'})
 print('AUDIO_SCENE_SITE_V2_STAGED',info['build_id'],len(files))

def main():
 p=argparse.ArgumentParser(description=__doc__);s=p.add_subparsers(dest='cmd',required=True)
 b=s.add_parser('build');b.add_argument('--output',type=Path,required=True);b.add_argument('--game-url',default='game/')
 t=s.add_parser('stage');t.add_argument('--bundle',type=Path,default=ROOT/'build/web');t.add_argument('--output',type=Path,required=True)
 a=p.parse_args();build(a.output,a.game_url) if a.cmd=='build' else stage(a.bundle,a.output)
if __name__=='__main__':main()
