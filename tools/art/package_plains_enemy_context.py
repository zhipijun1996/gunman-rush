"""Package untouched Godot captures into an offline B/C viewer and ZIP."""
from pathlib import Path
import base64
import hashlib
import json
import zipfile
import subprocess
import sys
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'build/plains_enemies_pr142/color-c/context'
BASELINE_COMMIT = 'b4d4488'
if '--prepare-baseline' in sys.argv:
    target = ROOT/'build/plains_enemies_pr142/color-c/baseline'
    (target/'static').mkdir(parents=True,exist_ok=True)
    files = subprocess.check_output(['git','ls-tree','-r','--name-only',BASELINE_COMMIT,'art/reviews/plains_enemies_pr142/static'],cwd=ROOT,text=True).splitlines()
    for path in files:
        (target/'static'/Path(path).name).write_bytes(subprocess.check_output(['git','show',BASELINE_COMMIT+':'+path],cwd=ROOT))
    (target/'readability.gdshader').write_bytes(subprocess.check_output(['git','show',BASELINE_COMMIT+':tools/art/plains_enemy_readability.gdshader'],cwd=ROOT))
    print('Prepared rejected B baseline from',BASELINE_COMMIT)
    sys.exit(0)
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
    for variant in ['B','C']:
        path=OUT/f'{key}-{variant}.png'
        row[variant]='data:image/png;base64,'+base64.b64encode(path.read_bytes()).decode()
    rows.append(row)
overview=Image.new('RGB',(2560,1440))
for i,key in enumerate(['01-meadow','03-interior','04-bellstrider','06-keeper-two']):
    overview.paste(Image.open(OUT/f'{key}-C.png'),(i%2*1280,i//2*720))
overview.save(OUT/'overview.png')
html='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>PR142 怪物配色重绘 · B/C对照</title>
<style>
*{box-sizing:border-box}body{margin:0;background:#102528;color:#e9e2ca;font:16px/1.6 system-ui,sans-serif}main{max-width:1328px;margin:auto;padding:24px}h1{font-size:24px;margin:0}p{margin:8px 0 16px;color:#b9c9bf}nav{display:flex;gap:8px;flex-wrap:wrap;margin:18px 0}button{background:#234144;color:#e9e2ca;border:1px solid #496265;border-radius:6px;padding:9px 14px;font:inherit;cursor:pointer}button[aria-pressed=true]{background:#d9c59a;color:#102528}#viewer{position:relative;aspect-ratio:16/9;overflow:hidden;border:1px solid #496265;background:#081416}#viewer img{position:absolute;width:100%;height:100%;image-rendering:pixelated}#left{clip-path:inset(0 50% 0 0)}#line{position:absolute;top:0;bottom:0;left:50%;border-left:2px solid #e9ce8e;pointer-events:none}.badges{position:absolute;bottom:10px;left:10px;right:10px;display:flex;justify-content:space-between;pointer-events:none}.badges span{background:#102528e8;border:1px solid #56645b;border-radius:4px;padding:3px 9px;font-size:13px}.controls{display:flex;align-items:center;gap:12px;margin-top:14px;flex-wrap:wrap}input{flex:1;min-width:180px;accent-color:#dcc58a}a{color:#e9ce8e}.hint{font-size:13px}#viewer.full{width:1280px;max-width:none}#scroll{overflow:auto}button:focus-visible,input:focus-visible{outline:3px solid #e9ce8e;outline-offset:2px}
</style><main><h1>PR #142 · 怪物放进真实关卡看</h1><p>B旧配色与C主色块重绘，同机位对照。两版均使用正式地形、光照与主角。</p><nav id="tabs" aria-label="选择场景"></nav><p id="description"></p><div id="scroll"><div id="viewer"><img id="right" alt="C：孔雀蓝主色块与琥珀重点"><img id="left" alt="B：旧配色"><div id="line"></div><div class="badges"><span>B 旧配色</span><span>C 主色块重绘</span></div></div></div><div class="controls"><button id="a">只看 B</button><input id="split" type="range" min="0" max="100" value="50" aria-label="左右分割位置"><button id="b">只看 C</button><button id="zoom" aria-pressed="false">原图 1:1</button><a id="download" download>下载当前 C 截图</a></div><p class="hint">拖动滑杆或切换 B/C。截图来自 Godot 正式房间；怪物为静态试摆，还未制作动画或验证战斗。C为重新绘制的配色母版，未叠加调色材质，仍待审批。</p></main>
<script>const data=DATA;const $=id=>document.getElementById(id);let active=0;
function split(value){$('split').value=value;$('left').style.clipPath=`inset(0 ${100-value}% 0 0)`;$('line').style.left=value+'%'}
function select(i){active=i;const row=data[i];$('left').src=row.B;$('right').src=row.C;$('description').textContent=row.description;$('download').href=row.C;$('download').download=row.key+'-C.png';[...$('tabs').children].forEach((button,j)=>button.setAttribute('aria-pressed',i===j));}
data.forEach((row,i)=>{const button=document.createElement('button');button.textContent=row.title;button.onclick=()=>select(i);$('tabs').append(button)});$('split').oninput=e=>split(e.target.value);$('a').onclick=()=>split(100);$('b').onclick=()=>split(0);$('zoom').onclick=()=>{const on=$('viewer').classList.toggle('full');$('zoom').setAttribute('aria-pressed',on);$('zoom').textContent=on?'适应窗口':'原图 1:1'};document.addEventListener('keydown',e=>{if(e.target.tagName==='INPUT')return;if(e.key==='b'||e.key==='B')split(100);if(e.key==='c'||e.key==='C')split(0)});select(0);
</script></html>'''.replace('DATA',json.dumps(rows,ensure_ascii=False))
(OUT/'review.html').write_text(html)
report={'source_branch':'art/plains-enemy-static-pr142','room_baseline':'PR142@cc62d369d3cec2597db483f1137ff976e25863cf',
        'scope':'Godot actual scenes, production camera zoom1.6; rejected B old PNG/material versus C regenerated color masters without grading; same feet/camera, master widths may vary',
        'baseline_commit':BASELINE_COMMIT,
        'overview':'overview.png is an unscaled 2x2 assembly of four C captures',
        'hashes':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(OUT.glob('*.png')) if p.name!='viewer-check.png'}}
(OUT/'evidence.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
with zipfile.ZipFile(OUT/'level-static-review.zip','w',zipfile.ZIP_DEFLATED) as z:
    for path in sorted(OUT.iterdir()):
        if path.suffix in ['.png','.html','.json'] and path.name!='viewer-check.png':z.write(path,path.name)
print('Offline B/C viewer and screenshot ZIP written:',OUT)
