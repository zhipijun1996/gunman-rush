"""Package untouched Godot captures into an offline A/B viewer and ZIP."""
from pathlib import Path
import base64
import hashlib
import json
import zipfile
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'build/plains_enemies_pr142/context'
cases = [
    ('01-meadow', '室外草坡', '巡逻、冲锋、跃击：看草沿附近的身体和浅色头部。'),
    ('02-junction', '风铃岔路', '哨兵、根铃、俯冲体：看与建筑、远景、草沿的区分。'),
    ('03-interior', '风车室内', '看深色木根、披布能否从木墙和传动架前分离。'),
    ('04-bellstrider', '鸣铃巡游机', '原有竞技场与镜头比例，检查钟体、轮组和主角大小关系。'),
    ('05-keeper-one', '牧风者一阶段', '看完整胸肩、粗壮四肢与地面的关系。'),
    ('06-keeper-two', '牧风者二阶段', '看头顶风车、HUD遮挡与战斗视野；地面贴底是当前正式镜头的表现。'),
]
rows=[]
for key,title,description in cases:
    row={'key':key,'title':title,'description':description}
    for variant in ['A','B']:
        path=OUT/f'{key}-{variant}.png'
        row[variant]='data:image/png;base64,'+base64.b64encode(path.read_bytes()).decode()
    rows.append(row)
overview=Image.new('RGB',(2560,1440))
for i,key in enumerate(['01-meadow','03-interior','04-bellstrider','06-keeper-two']):
    overview.paste(Image.open(OUT/f'{key}-B.png'),(i%2*1280,i//2*720))
overview.save(OUT/'overview.png')
html='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>PR142 怪物关卡试摆 · 静态辨识度对照</title>
<style>
*{box-sizing:border-box}body{margin:0;background:#102528;color:#e9e2ca;font:16px/1.6 system-ui,sans-serif}main{max-width:1328px;margin:auto;padding:24px}h1{font-size:24px;margin:0}p{margin:8px 0 16px;color:#b9c9bf}nav{display:flex;gap:8px;flex-wrap:wrap;margin:18px 0}button{background:#234144;color:#e9e2ca;border:1px solid #496265;border-radius:6px;padding:9px 14px;font:inherit;cursor:pointer}button[aria-pressed=true]{background:#d9c59a;color:#102528}#viewer{position:relative;aspect-ratio:16/9;overflow:hidden;border:1px solid #496265;background:#081416}#viewer img{position:absolute;width:100%;height:100%;image-rendering:pixelated}#left{clip-path:inset(0 50% 0 0)}#line{position:absolute;top:0;bottom:0;left:50%;border-left:2px solid #e9ce8e;pointer-events:none}.badges{position:absolute;bottom:10px;left:10px;right:10px;display:flex;justify-content:space-between;pointer-events:none}.badges span{background:#102528e8;border:1px solid #56645b;border-radius:4px;padding:3px 9px;font-size:13px}.controls{display:flex;align-items:center;gap:12px;margin-top:14px;flex-wrap:wrap}input{flex:1;min-width:180px;accent-color:#dcc58a}a{color:#e9ce8e}.hint{font-size:13px}#viewer.full{width:1280px;max-width:none}#scroll{overflow:auto}button:focus-visible,input:focus-visible{outline:3px solid #e9ce8e;outline-offset:2px}
</style><main><h1>PR #142 · 怪物放进真实关卡看</h1><p>原稿与轻量轮廓增强，同机位对照。两版都使用正式地形、前景、光照与主角。</p><nav id="tabs" aria-label="选择场景"></nav><p id="description"></p><div id="scroll"><div id="viewer"><img id="right" alt="B：轻量轮廓与明暗增强"><img id="left" alt="A：原静态稿"><div id="line"></div><div class="badges"><span>A 原稿</span><span>B 轮廓与明暗增强</span></div></div></div><div class="controls"><button id="a">只看 A</button><input id="split" type="range" min="0" max="100" value="50" aria-label="左右分割位置"><button id="b">只看 B</button><button id="zoom" aria-pressed="false">原图 1:1</button><a id="download" download>下载当前 B 截图</a></div><p class="hint">拖动滑杆或切换 A/B。截图来自 Godot 正式房间；怪物为静态试摆，还未制作动画或验证战斗。B 是临时材质方案，仍待审批。</p></main>
<script>const data=DATA;const $=id=>document.getElementById(id);let active=0;
function split(value){$('split').value=value;$('left').style.clipPath=`inset(0 ${100-value}% 0 0)`;$('line').style.left=value+'%'}
function select(i){active=i;const row=data[i];$('left').src=row.A;$('right').src=row.B;$('description').textContent=row.description;$('download').href=row.B;$('download').download=row.key+'-B.png';[...$('tabs').children].forEach((button,j)=>button.setAttribute('aria-pressed',i===j));}
data.forEach((row,i)=>{const button=document.createElement('button');button.textContent=row.title;button.onclick=()=>select(i);$('tabs').append(button)});$('split').oninput=e=>split(e.target.value);$('a').onclick=()=>split(100);$('b').onclick=()=>split(0);$('zoom').onclick=()=>{const on=$('viewer').classList.toggle('full');$('zoom').setAttribute('aria-pressed',on);$('zoom').textContent=on?'适应窗口':'原图 1:1'};document.addEventListener('keydown',e=>{if(e.target.tagName==='INPUT')return;if(e.key==='a'||e.key==='A')split(100);if(e.key==='b'||e.key==='B')split(0)});select(0);
</script></html>'''.replace('DATA',json.dumps(rows,ensure_ascii=False))
(OUT/'review.html').write_text(html)
report={'source_branch':'art/plains-enemy-static-pr142','room_baseline':'PR142@cc62d369d3cec2597db483f1137ff976e25863cf',
        'scope':'Godot actual scenes, production camera zoom 1.6, frozen statically placed proposed enemies; A/B material comparison only',
        'overview':'overview.png is an unscaled 2x2 assembly of four B captures',
        'hashes':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(OUT.glob('*.png')) if p.name!='viewer-check.png'}}
(OUT/'evidence.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
with zipfile.ZipFile(OUT/'level-static-review.zip','w',zipfile.ZIP_DEFLATED) as z:
    for path in sorted(OUT.iterdir()):
        if path.suffix in ['.png','.html','.json'] and path.name!='viewer-check.png':z.write(path,path.name)
print('Offline A/B viewer and screenshot ZIP written:',OUT)
