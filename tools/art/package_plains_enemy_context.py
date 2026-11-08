"""Package six actual PR142 captures of the fresh static candidates."""
from pathlib import Path
import base64
import hashlib
import json
import zipfile
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'build/plains_enemies_pr142/restart/context'
ART=ROOT/'art/reviews/plains_enemies_pr142_restart'
cases=[('01-meadow','室外草坡'),('02-junction','风铃岔路'),('03-interior','风车室内'),('04-bellstrider','鸣铃巡游机'),('05-keeper-one','牧风者一阶段'),('06-keeper-two','牧风者二阶段')]
shots=json.loads((OUT/'capture.json').read_text())['shots']
assert len(shots)==6
assert {s['id'] for shot in shots for s in shot['sprites']}==set(json.loads((ART/'manifest.json').read_text())['assets'])
rows=[]
for key,title in cases:
    path=OUT/f'{key}.png'
    assert Image.open(path).size==(1280,720)
    shot=next(s for s in shots if s['case']==key)
    assert all(s['inside_viewport'] for s in shot['sprites'])
    rows.append({'key':key,'title':title,'image':'data:image/png;base64,'+base64.b64encode(path.read_bytes()).decode()})
overview=Image.new('RGB',(2560,1440))
for i,key in enumerate(['01-meadow','03-interior','04-bellstrider','06-keeper-two']):overview.paste(Image.open(OUT/f'{key}.png'),(i%2*1280,i//2*720))
overview.save(OUT/'overview.png')
html='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>PR142 全新怪物静态稿</title><style>
*{box-sizing:border-box}body{margin:0;background:#182124;color:#eee1c7;font:16px/1.6 system-ui,sans-serif}main{max-width:1328px;margin:auto;padding:24px}h1{font-size:24px;margin:0}p{color:#bdc2b5}nav{display:flex;gap:8px;flex-wrap:wrap;margin:18px 0}button{background:#304044;color:#eee1c7;border:1px solid #637171;border-radius:6px;padding:8px 13px;font:inherit;cursor:pointer}button[aria-pressed=true]{background:#d7c29a;color:#182124}#scroll{overflow:auto}#shot{display:block;width:100%;height:auto;image-rendering:pixelated}#shot.full{width:1280px;max-width:none}.controls{display:flex;gap:18px;align-items:center;flex-wrap:wrap;margin-top:16px}a{color:#e8c78e}.hint{font-size:13px}button:focus-visible{outline:3px solid #e8c78e}</style>
<main><h1>PR142 · 全新怪物静态稿</h1><p>七类普通怪、两位 Boss，含牧风者头顶风车二阶段。原主角、正式 TileSet、原镜头和光照下试摆。</p><nav id="tabs" aria-label="选择场景"></nav><div id="scroll"><img id="shot" alt="实际关卡静态试摆"></div><div class="controls"><button id="zoom" aria-pressed="false">原图 1:1</button><a id="download" download>下载当前截图</a></div><p class="hint">全部重新设计，生成参考仅来自原游戏素材。画面是冻结的静态试摆，尚未审批或制作动画，也不代表战斗、碰撞和两阶段动作已验证。</p></main><script>
const data=DATA;const $=id=>document.getElementById(id);function select(i){const row=data[i];$('shot').src=row.image;$('shot').alt=row.title+'：实际关卡静态试摆';$('download').href=row.image;$('download').download=row.key+'.png';[...$('tabs').children].forEach((b,j)=>b.setAttribute('aria-pressed',i===j))}data.forEach((r,i)=>{const b=document.createElement('button');b.textContent=r.title;b.onclick=()=>select(i);$('tabs').append(b)});$('zoom').onclick=()=>{const on=$('shot').classList.toggle('full');$('zoom').setAttribute('aria-pressed',on);$('zoom').textContent=on?'适应窗口':'原图 1:1'};select(0);
</script></html>'''.replace('DATA',json.dumps(rows,ensure_ascii=False))
(OUT/'review.html').write_text(html)
evidence={'scope':'Six actual PR142 scenes, unchanged production camera and lighting, frozen static fixtures only','baseline':'PR142 cc62d369','hashes':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in OUT.glob('*.png') if p.name!='viewer-check.png'}}
(OUT/'evidence.json').write_text(json.dumps(evidence,indent=2)+'\n')
with zipfile.ZipFile(OUT.parent/'fresh-static-review.zip','w',zipfile.ZIP_DEFLATED) as archive:
    for folder,prefix in [(ART,'art'),(OUT,'context')]:
        for p in folder.rglob('*'):
            if p.is_file() and p.name!='viewer-check.png':archive.write(p,Path(prefix)/p.relative_to(folder))
print('PASS: six scenes, ten unique sprites inside viewport; standalone viewer, overview and ZIP created')
