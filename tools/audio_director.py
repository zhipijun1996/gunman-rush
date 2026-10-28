#!/usr/bin/env python3
"""Audio Director entry: context brief, reproducible candidates, mobile listening lab."""
import argparse
import hashlib
import json
import shutil
import subprocess
import sys
import tempfile
import wave
import math
import array
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / 'assets/audio/director_candidates/manifest.json'

def read(path):
    return json.loads(path.read_text())

def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def run(*args):
    subprocess.run([sys.executable, *args], cwd=ROOT, check=True)

ORIGINALS = {
    'shot': ('assets/player_presentation_01/weapon_audio_v2/pulse_0.wav', 12, '正式V2基础枪pulse；包含原反冲听觉主体'),
    'recoil': ('assets/player_presentation_01/weapon_audio_v2/pulse_0.wav', 12, '原版反冲与枪声为一个事件，没有独立反冲音轨；此处重听同一pulse，不能叠放'),
    'enemy_hit': ('assets/player_presentation_01/weapon_audio_v2/hit_0.wav', 10, '正式V2 accepted damage hit层；非致命受伤另有hurt层'),
    'enemy_hurt': ('assets/audio/kenney/hurt.ogg', 7, '原版敌人与主角共用hurt；现在明确事件语义'),
    'enemy_death': ('assets/audio/kenney/enemy_defeat.ogg', 7, '正式默认敌人死亡；death_burst仅旧fixture，不冒充正式原版'),
    'jump': ('assets/player_presentation_01/feel_audio_v1/jump_0.wav', 12, '正式默认主角motion jump'),
    'land': ('assets/player_presentation_01/feel_audio_v1/land_0.wav', 13.5, '正式默认主角motion land；实际增益随落地强度变化，参考中等强度'),
    'hurt': ('assets/audio/kenney/hurt.ogg', 7, '正式主角hurt'),
    'coin': ('assets/audio/kenney/coin.ogg', 7, '正式金币cue'),
    'heal': ('assets/audio/kenney/heal.ogg', 7, '正式生命cue'),
    'reward': ('assets/audio/kenney/note.ogg', 7, '普通奖励参考note；并非所有奖励路径使用同一cue'),
    'confirm': ('assets/audio/kenney/confirm.ogg', 7, '正式confirm；按钮通用click与确认语义不同'),
    'denied': ('assets/audio/kenney/denied.ogg', 7, '正式拒绝cue'),
    'hook_release': ('assets/audio/kenney/focus_start.ogg', 7, '原钩索释放借用focus_start'),
    'hook_connect': ('assets/audio/kenney/bell.ogg', 7, '原钩索连接借用bell'),
    'hook_pull': ('assets/audio/kenney/impact.ogg', 7, '原钩索开始牵引一次impact；不是原版持续loop'),
}

def metrics(path):
    with wave.open(str(path)) as f:
        n, rate, channels = f.getnframes(), f.getframerate(), f.getnchannels()
        assert f.getsampwidth() == 2
        values = array.array('h', f.readframes(n))
    rms = math.sqrt(sum(float(v)*v for v in values)/max(1,len(values)))/32768
    peak = max(map(abs, values), default=0)/32768
    return {'rms_dbfs':20*math.log10(max(rms,1e-10)), 'peak_dbfs':20*math.log10(max(peak,1e-10)), 'duration':n/rate,'channels':channels}

def lab(output, game_url):
    output=output.resolve()
    if output.exists() and any(output.iterdir()):
        raise ValueError('Use a fresh empty output directory; existing deliveries are immutable')
    output.mkdir(parents=True, exist_ok=True)
    manifest=read(MANIFEST)
    sources=read(ROOT/'config/audio_director/sources.json')['sources']
    data={'version':manifest['version'],'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'game_url':game_url,'sources':sources,'events':[],'music':[]}
    media=output/'audio';media.mkdir()
    for event in manifest['events']:
        entry={k:event[k] for k in ('id','label','category')}
        entry['candidates']=[]
        for candidate in event['candidates']:
            c={k:candidate[k] for k in ('id','label','design','version','source_ids','duration','peak_dbfs','rms_dbfs') if k in candidate}
            c['variants']=[]
            for resource in candidate['variants']:
                source=ROOT/resource.removeprefix('res://')
                target=media/source.name
                shutil.copyfile(source,target)
                c['variants'].append('audio/'+target.name)
            c['path']=c['variants'][0]
            c['attenuation_db']=read(ROOT/'config/audio_director/runtime.json')['events'][event['id']]['attenuation_db']
            entry['candidates'].append(c)
        relative,attenuation,note=ORIGINALS[event['id']]
        source=ROOT/relative; target=media/(event['id']+'_original.wav')
        subprocess.run(['ffmpeg','-nostdin','-v','error','-y','-i',str(source),'-ac','1','-ar','44100','-c:a','pcm_s16le',str(target)],check=True)
        entry['original']={'id':event['id']+'_original','label':'C · 原版','path':'audio/'+target.name,'version':'main-26e7f2a','source_ids':[],'attenuation_db':attenuation,'legacy_note':note,'original_path':relative,'original_sha256':sha(source),**metrics(target)}
        if event['id']=='hook_pull':
            target.unlink()
            entry['original'].update(path=None, duration=0, legacy_note='原版没有专用持续牵引声；连接时只播放bell，接触踢另播放impact。')
            note='原版无持续牵引声；这里保留安静作对照，不能拿接触踢impact冒充。'
        entry['original_note']=note
        data['events'].append(entry)
    music_dir=output/'music';music_dir.mkdir()
    labels={'the_kindred_hearth':'家园','where_the_path_bends':'风铃平原','across_the_wooden_sails':'平原 Boss','vines_beneath_the_canopy':'荆棘森林','beyond_the_knotted_vines':'森林 Boss'}
    for stem,label in labels.items():
        source=ROOT/'assets/audio/bgm'/(stem+'.mp3');shutil.copyfile(source,music_dir/source.name)
        data['music'].append({'label':label,'path':'music/'+source.name,'sha256':sha(source),'original_bytes':True})
    license_dir=output/'licenses';license_dir.mkdir()
    licensed=[*ROOT.glob('assets/audio/kenney/*LICENSE*'),*ROOT.glob('assets/player_presentation_01/**/COPYING*'),*ROOT.glob('assets/player_presentation_01/**/*LICENSE*'),*ROOT.glob('assets/audio/director_candidates/_sources/licenses/*')]
    # Preserve complete upstream terms for Freedoom-derived original comparison.
    licensed += list(ROOT.glob('assets/player_presentation_01/**/freedoom*.txt'))
    index=[]
    for i,p in enumerate(licensed):
        if p.is_file():
            name=f'{i:02d}-{p.name}';shutil.copyfile(p,license_dir/name);index.append(f'{name}: {p.relative_to(ROOT)} sha256={sha(p)}')
    for p in [ROOT/'assets/audio/kenney/sources.json',ROOT/'assets/audio/bgm/provenance.json']:
        name=p.parent.name+'-'+p.name;shutil.copyfile(p,license_dir/name);index.append(name+': '+str(p.relative_to(ROOT)))
    (license_dir/'README.txt').write_text('Audio Director comparison license index\nCC0 candidate originals: sources.json. Original game samples retain their individual licenses, including BSD-3-Clause Freedoom. BGM: user-provided, game/listening only, no third-party reuse grant.\n'+'\n'.join(index)+'\n')
    write(output/'lab.json',data);shutil.copyfile(MANIFEST,output/'manifest.json');write(output/'sources.json',{'sources':sources})
    shutil.copyfile(ROOT/'tools/sound_lab/index.html',output/'index.html')
    (output/'README.txt').write_text('失序之钟 Sound Lab\n用HTTP服务器打开index.html；手机浏览器首次点击解锁音频；包内包含五首原BGM，仅限本项目试玩。\nA/B待用户试听；C是当前正式音色的PCM解码，不是原文件替换。\n原文件路径/SHA、增益与语义差异见lab.json，许可见licenses。\n选择只存在当前浏览器，导出JSON回传。\n')
    with zipfile.ZipFile(output/'audio-comparison.zip','w',zipfile.ZIP_DEFLATED) as z:
        for p in sorted(output.rglob('*')):
            if p.is_file() and p.suffix!='.zip' :z.write(p,p.relative_to(output))
    files={p.relative_to(output).as_posix():{'bytes':p.stat().st_size,'sha256':sha(p)} for p in sorted(output.rglob('*')) if p.is_file()}
    write(output/'delivery.json',{'task':'AUDIO-DIRECTOR-01','source_commit':data['source_commit'],'version':data['version'],'game_url':game_url,'files':files,'subjective_status':'awaiting-user','device_status':'unverified'})
    print(f'AUDIO_LAB_OK events={len(data["events"])} files={len(files)} output={output}')

def brief(request,output):
    active_version=3 if (ROOT/'assets/audio/director_v3/manifest.json').is_file() else 2 if (ROOT/'assets/audio/director_v2/manifest.json').is_file() else 1
    active_manifest=ROOT/f'assets/audio/director_v{active_version}/manifest.json' if active_version>1 else MANIFEST
    manifest=read(active_manifest); matches=[]
    families={'钩索':['hook_'],'敌人':['enemy_'],'命中':['enemy_hit','enemy_hurt'],'受伤':['hurt','enemy_hurt'],'拾取':['coin','heal','reward','item_get'],'金币':['coin'],'回血':['heal'],'血量':['heal'],'宝箱':['chest_open','item_get'],'道具':['item_get'],'界面':['click','confirm','denied'],'点击':['click'],'枪':['shot','recoil'],'射击':['shot','bomb_explode'],'武器':['shot','bomb_explode'],'跳':['jump','land'],'UI':['click','confirm','denied'],'奖励':['coin','heal','reward','item_get'],'环境':[],'区域':[]}
    for word,ids in families.items():
        if word in request:matches += [e['id'] for e in manifest['events'] if any(e['id'].startswith(i) for i in ids)]
    prefix=f'config/audio_director/v{active_version}/' if active_version>1 else 'config/audio_director/'
    inputs=['docs/audio_director/style_bible.md','docs/audio_director/event_catalog.json',prefix+'sources.json',prefix+'recipes.json',prefix+'runtime.json',str(active_manifest.relative_to(ROOT))]
    inputs+=['docs/audio_director/style_bible_v3.md','docs/audio_director/event_catalog_v3.md','docs/worklines/audio_director_03/scope.md'] if active_version==3 else ['docs/audio_director/listening_v2.md']
    selected_path='config/audio_director/selected/selected.json'
    if active_version==3 and (ROOT/selected_path).is_file(): inputs.append(selected_path)
    result={'task':f'AUDIO-DIRECTOR-0{active_version}','candidate_version':manifest['version'],'prior_v1_status':'user-rejected; preserve original jump/land' if active_version>1 else 'awaiting-user','request':request,'status':'production_brief','selected_events':list(dict.fromkeys(matches)),'inputs':[{'path':p,'sha256':sha(ROOT/p)} for p in inputs if (ROOT/p).exists()],'workflow':['Read current functional Audio Style Bible, Event Catalog and selected family; inspect actual accepted consumers','Review mature-game function/timing references, then select licensed source files with original SHA and terms','Build and validate explicit versioned recipes; preserve prior versions and failed aesthetic feedback','Verify event/phase semantics, pause/death/reload and shared voice lifecycle','Deliver short real Godot recordings or interactive lab as requested; user alone approves timbre'],'next_command':f'python3 tools/audio_candidates_v{active_version}.py build' if active_version>1 else 'python3 tools/audio_design.py build','limitation':'Brief routes context, not automatic creative completion. New enemies/areas need actual source selection and authored recipes. Commercial game references are not licensed production inputs.'}
    if selected_path in inputs:
        selection=read(ROOT/selected_path)
        result['user_selection']={'path':selected_path,'event_profiles':selection['event_profiles'],'provenance':selection['provenance'],'scope':'User selected individual event sounds on 2026-10-28; combined mix, formal rollout and device quality remain unapproved. Preserve original shuriken, bomb, jump and landing.'}
    write(output,result);print(json.dumps(result,ensure_ascii=False,indent=2))

def main():
    p=argparse.ArgumentParser(description=__doc__);s=p.add_subparsers(dest='cmd',required=True)
    b=s.add_parser('brief');b.add_argument('request');b.add_argument('--output',type=Path,default=ROOT/'build/audio_director/brief.json')
    s.add_parser('build');s.add_parser('validate');s.add_parser('audit')
    l=s.add_parser('lab');l.add_argument('--output',type=Path,required=True);l.add_argument('--game-url',default='')
    a=p.parse_args()
    if a.cmd=='brief':brief(a.request,a.output)
    elif a.cmd=='lab':lab(a.output,a.game_url)
    elif a.cmd=='audit':run('tools/audio_inventory.py')
    else:run('tools/audio_design.py',a.cmd)
if __name__=='__main__':main()
