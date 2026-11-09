#!/usr/bin/env python3
"""Package reproducible native atlases and an on-demand animation inspector."""
from pathlib import Path
import hashlib, json, shutil, zipfile
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / 'assets/plains_actors_142'
OUT = ROOT / 'build/plains_actors_142'
LABELS = {'patrol':'巡逻怪','charger':'冲锋怪','hopper':'跳跃怪','sentry':'哨兵','fan_sentry':'扇射哨兵','root_bell':'根铃','diver':'俯冲怪','bellstrider':'鸣铃巡游机','windkeeper_phase1':'牧风者 · 一阶段','windkeeper_phase2':'牧风者 · 二阶段'}

def review_asset(path):
    relative = Path('review-assets') / path.parent.name / path.name
    target = OUT / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(path, target)
    return relative.as_posix()


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    shutil.rmtree(OUT/'review-assets', ignore_errors=True)
    sheets, sources = {}, []
    poses = 0
    reused = 0
    for meta_path in sorted((ART/'atlases').glob('*.json')):
        name = meta_path.stem
        meta = json.loads(meta_path.read_text())
        atlas = ART/'atlases'/f'{name}.png'
        source = ART/'source'/f'{name}.png'
        im = Image.open(atlas)
        columns = meta['columns']
        assert im.size == (meta['frame_size'][0]*columns, meta['frame_size'][1]*len(meta['states']))
        frames = []
        for row in range(len(meta['states'])):
            hashes = []
            for col in range(columns):
                w,h = meta['frame_size']; f = im.crop((col*w,row*h,(col+1)*w,(row+1)*h))
                box = f.getbbox()
                assert box and box[0]>=2 and box[1]>=2 and box[2]<=w-2 and box[3]<=h-2, (name,row,col,'gutter')
                hashes.append(hashlib.sha256(f.tobytes()).hexdigest())
            assert len(set(hashes)) >= 3, (name,row,'duplicated poses')
            frames.extend(hashes)
        poses += len(frames)
        reused += meta.get("reused_pose_count",0)
        spec = json.loads((ART/"source"/f"{name}.json").read_text())
        if spec.get("interleave_from"):
            reused += len(frames)//2
            original = Image.open(ART/'atlases'/f'{spec["interleave_from"]}.png')
            for row in range(len(meta['states'])):
                for col in range(columns//2):
                    old = original.crop((col*w,row*h,(col+1)*w,(row+1)*h))
                    new = im.crop((col*2*w,row*h,(col*2+1)*w,(row+1)*h))
                    assert old.tobytes() == new.tobytes(), (name,row,col,'changed approved key')
        sheets[name] = {k: meta[k] for k in ('frame_size', 'pivot', 'columns', 'states')}
        sheets[name]['image'] = review_asset(atlas)
        sources.append({'id':name, 'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(), 'atlas_sha256':hashlib.sha256(atlas.read_bytes()).hexdigest(), 'states':meta['states'],'frames':len(frames),'frame_sha256':frames})
    manifest = {'generator':'image_gen','approved_static_commit':'a5668a4','world_sampling':'1 native pixel / world unit, nearest','baking':'alpha threshold, fixed body scale, fixed registration, nearest sampling; no painted Python pixels','pose_count':poses,'unique_authored_pose_count':poses-reused,'static_count':10,'sheets':sources}
    (ART/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    payload = json.dumps({'sheets':sheets,'labels':{n:label for n,label in LABELS.items() if n in sheets},'static':{n:review_asset(ART/'static'/f'{n}.png') for n in LABELS}},ensure_ascii=False)
    template = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>平原怪物 · 动作检视</title><style>
    *{box-sizing:border-box}body{margin:0;background:#172324;color:#e9e4d4;font:16px system-ui,sans-serif}main{max-width:1180px;margin:auto;padding:24px}h1{font-size:25px;margin:0 0 8px}p{color:#b8c7c2;line-height:1.6}nav,.controls{display:flex;gap:10px;flex-wrap:wrap;margin:20px 0}button,select,input{font:inherit}button,select{padding:10px 13px;border:1px solid #647770;border-radius:7px;background:#263b3a;color:inherit;cursor:pointer}button.active{background:#4a6860;border-color:#dacb97}.viewport{overflow:auto;background:#263b3a;border:1px solid #52635d;border-radius:10px;min-height:420px;display:flex;justify-content:center;align-items:center}canvas{image-rendering:pixelated;max-width:100%;height:auto}label{display:flex;align-items:center;gap:8px}.info{font-variant-numeric:tabular-nums;color:#d2c4a1}a{color:#c5dba7}video{width:100%;border-radius:8px}details{margin:24px 0}summary{cursor:pointer;padding:12px;background:#263b3a;border-radius:7px}@media(max-width:600px){main{padding:16px}.viewport{min-height:300px}}
    </style><main><h1>平原怪物 · 全动作检视</h1><p>B/C 造型 · 七类普通怪、两位 Boss 与牧风者头顶风车。每次只加载当前动作页。这里逐张查看已认可的小怪素材；Boss 已改用固定分层素材和骨骼，动作见下方实战录像，可编辑骨骼场景随工程提供。</p><nav id="actors"></nav><div class="controls"><label>招式 <select id="attack"></select></label><label>动作 <select id="clip"></select></label><button id="play">暂停</button><label>速度 <select id="speed"><option value=".5">0.5×</option><option value="1" selected>1×</option><option value="2">2×</option></select></label><label>放大 <select id="zoom"><option value="1">1×</option><option value="2" selected>2×</option><option value="3">3×</option></select></label></div><div class="viewport"><canvas id="view" width="900" height="540"></canvas></div><div class="controls"><label>逐帧 <input id="frame" type="range" min="0" max="3" value="0"></label><span class="info" id="info"></span><a id="download" download>下载当前动作页 PNG</a></div><p>静态图保留批准稿；待机、移动、前摇、攻击、后摇、受伤、死亡使用独立姿势。定点怪的移动素材用于完整动作库，游戏中的定点行为保持原规则。</p><details open><summary>实际战斗 · 正常速度 · 独立短片</summary><p>正式 TileSet、角色、AI、移动、攻击、伤害与尸体落地。普通怪为单怪布置；Boss 设置开场位置，二阶段另设置生命阈值，并使用标注的审查宽镜头保留双方与地面。自动操作片段不代表自然通关。</p><div id="movies"></div></details></main><script>
    const movies=MOVIES;for(const [src,title] of movies){const d=document.createElement('details');const label=document.createElement('summary');label.textContent=title;const v=document.createElement('video');v.controls=true;v.playsInline=true;v.preload='none';v.src=src;d.append(label,v);document.getElementById('movies').append(d);}const data=PAYLOAD; const $=id=>document.getElementById(id);let actor='charger', sheetName='charger', clip='idle', elapsed=0, paused=false,last=performance.now(); let loadedURL="", loadedImage=null;
    function imageFor(url){if(loadedURL!==url){if(loadedImage)loadedImage.removeAttribute('src');loadedURL=url;loadedImage=new Image();loadedImage.decoding='async';loadedImage.src=url;}return loadedImage;}
    const names={idle:'待机',move:'移动',anticipation:'攻击前摇',attack:'攻击',recovery:'后摇',hurt:'受伤',death:'死亡',transition_start:'风车生长',transition_finish:'风帆展开',static:'批准静态',turn:'转向'};
    const attacks={base:'基础动作',roll:'滚轮冲锋',ring:'地面铃波',lob:'高抛铜铃',stomp:'踏击',lunge:'扑击',sweep:'横扫',gust:'风压',seeds:'种子弹',platform:'平台踏击',transition:'头顶风车转换',turn:'回身转向'};
    function option(select,value,label){const o=document.createElement('option');o.value=value;o.textContent=label;select.append(o);}
    for(const [key,label] of Object.entries(data.labels)){const b=document.createElement('button');b.textContent=label;b.onclick=()=>{actor=key;setup();};b.dataset.actor=key;$('actors').append(b);}
    function setup(){document.querySelectorAll('nav button').forEach(b=>b.classList.toggle('active',b.dataset.actor===actor));$('attack').replaceChildren();option($('attack'),'base',attacks.base);for(const key of Object.keys(data.sheets)){if(key.startsWith(actor+'_')&&!key.endsWith('_motion')&&!key.endsWith('_flow')){const suffix=key.slice(actor.length+1);option($('attack'),suffix,attacks[suffix]||suffix);}}if(actor==='windkeeper_phase2')option($('attack'),'transition',attacks.transition);changeAttack();}
    function changeAttack(){const a=$('attack').value;sheetName=a==='base'?actor:a==='transition'?'windkeeper_transition':actor+'_'+a;$('clip').replaceChildren();if(a==='base')option($('clip'),'static',names.static);data.sheets[sheetName].states.forEach(c=>option($('clip'),c,names[c]||c));$('clip').value=a==='base'?'idle':a==='transition'?'transition_start':a==='turn'?'turn':'anticipation';changeClip();}
    function activeSheet(){if(sheetName===actor&&['idle','move'].includes(clip))return actor+'_motion';const f=sheetName+'_flow';return data.sheets[f]?.states.includes(clip)?f:sheetName;}function changeClip(){clip=$('clip').value;elapsed=0;$('frame').value=0;const n=activeSheet();$('frame').max=data.sheets[n].columns-1;$('download').href=data.sheets[n].image;$('download').download=n+'.png';}
    $('attack').onchange=changeAttack;$('clip').onchange=changeClip;$('play').onclick=()=>{paused=!paused;$('play').textContent=paused?'播放':'暂停';};$('frame').oninput=()=>{paused=true;$('play').textContent='播放';elapsed=Number($('frame').value)/data.sheets[activeSheet()].columns;};
    function draw(now){const dt=Math.min(.1,(now-last)/1000);last=now;const durations={idle:.84,move:.64,anticipation:.65,attack:.45,recovery:.7,hurt:.24,death:1.1,transition_start:.65,transition_finish:.65,turn:.36,static:1};if(!paused&&!document.hidden)elapsed=(elapsed+dt*Number($('speed').value)/durations[clip])%(clip==='turn'?2:1);const selected=activeSheet(),count=data.sheets[selected].columns;const index=Math.min(count-1,Math.floor((clip==='turn'&&elapsed>1?2-elapsed:elapsed)*count));$('frame').value=index;const meta=data.sheets[selected],ctx=$('view').getContext('2d'),z=Number($('zoom').value);const image=imageFor(clip==='static'?data.static[actor]:data.sheets[selected].image);const w=clip==='static'?image.width:meta.frame_size[0],h=clip==='static'?image.height:meta.frame_size[1];const cw=Math.max(600,w*z+60),ch=Math.max(350,h*z+55);if($('view').width!==cw)$('view').width=cw;if($('view').height!==ch)$('view').height=ch;ctx.imageSmoothingEnabled=false;ctx.fillStyle='#263b3a';ctx.fillRect(0,0,$('view').width,$('view').height);const baseline=$('view').height-26;ctx.fillStyle='#475650';ctx.fillRect(20,baseline,$('view').width-40,1);if(image.complete&&image.naturalWidth>0){const pivot=clip==='static'?[w/2,h]:meta.pivot;const x=$('view').width/2-pivot[0]*z,y=baseline-pivot[1]*z;if(clip==='static')ctx.drawImage(image,x,y,w*z,h*z);else ctx.drawImage(image,index*w,meta.states.indexOf(clip)*h,w,h,x,y,w*z,h*z);} $('info').textContent=names[clip]+' · '+(index+1)+'/'+count+' · '+w+' × '+h;requestAnimationFrame(draw);}setup();requestAnimationFrame(draw);
    </script></html>'''
    movie_ids = {'bellstrider':'bell','windkeeper_phase1':'keeper','windkeeper_phase2':'windmill'}
    movies = [[f"mobile-combat/{movie_ids.get(name,name)}.mp4",label] for name,label in LABELS.items()]
    if (OUT/'mobile-combat/bell_wave.mp4').exists():movies.insert(8,['mobile-combat/bell_wave.mp4','鸣铃巡游机 · 地波与抛铃'])
    if (OUT/'mobile-combat/pounce.mp4').exists():movies.append(['mobile-combat/pounce.mp4','牧风者扑击 · 穿身与停留对照'])
    (OUT/'review.html').write_text(template.replace('PAYLOAD',payload).replace('MOVIES',json.dumps(movies,ensure_ascii=False)))
    with zipfile.ZipFile(OUT/'plains-animations-pr142.zip','w',zipfile.ZIP_DEFLATED) as archive:
        for p in ART.rglob('*'):
            if p.is_file() and not p.name.endswith('.import'):
                archive.write(p,p.relative_to(ROOT))
        for p in (ROOT/'assets/plains_boss_fx_142').rglob('*'):
            if p.is_file() and not p.name.endswith('.import'): archive.write(p,p.relative_to(ROOT))
        archive.write(ROOT/'tools/art/build_plains_boss_fx.py','tools/art/build_plains_boss_fx.py')
        archive.write(ROOT/'tools/art/build_plains_boss_rigs.py','tools/art/build_plains_boss_rigs.py')
        archive.write(ROOT/'tools/requirements_art.txt','tools/requirements_art.txt')
        for p in (ROOT/'assets/plains_boss_rigs_142').rglob('*'):
            if p.is_file():archive.write(p,p.relative_to(ROOT))
        for p in (ROOT/'game/presentation/actors/art').glob('*'):
            archive.write(p,p.relative_to(ROOT))
        for folder in ('bellstrider','windkeeper'):
            for p in (ROOT/'game/bosses'/folder).glob('*.gd*'): archive.write(p,p.relative_to(ROOT))
        p=ROOT/'game/bosses/encounter/plains_boss_view_pose.gd';archive.write(p,p.relative_to(ROOT))
        archive.write(__file__, 'tools/art/package_plains_actor_animations.py')
        archive.write(ROOT/'tools/art/build_plains_actor_animations.py','tools/art/build_plains_actor_animations.py')
    with zipfile.ZipFile(OUT/'animation-review.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
        archive.write(OUT/'review.html', 'review.html')
        for p in (OUT/'review-assets').rglob('*.png'):
            archive.write(p, p.relative_to(OUT))
        for folder in ('mobile-combat',):
            for p in (OUT/folder).glob('*.mp4'):
                if p.name != 'motion.mp4':
                    archive.write(p, p.relative_to(OUT))
    print(f'{len(sheets)} sheets; {poses} source atlas frames ({poses-reused} authored poses); 10 approved static images; gutters and distinct-pose checks passed')

if __name__=='__main__': main()
