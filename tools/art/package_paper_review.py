"""Package real Godot evidence and the chunked Web export for an independent host.

Usage: python3 tools/art/package_paper_review.py /absolute/site/dist
The host's .openai/hosting.json and source publication are managed separately.
"""
from pathlib import Path
import argparse
import json
import re
import shutil

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / 'build/paper_theater'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('target', type=Path)
    args = parser.parse_args()
    target = args.target.resolve()
    target.mkdir(parents=True, exist_ok=True)
    source = EVIDENCE / 'web'
    info = json.loads((source/'build-info.json').read_text())
    if not info.get('paper_theater') or info['threads_enabled']:
        raise ValueError('Only the nonthreaded independent experiment is admitted')
    play = target / 'play'
    play.mkdir(exist_ok=True)
    names = ['index.html','index.png','index.cache-sw.js','build-info.json','paper-build.json']
    names += [p.name for p in source.glob('index.*.engine*.js')]
    for name in names:
        shutil.copyfile(source/name,play/name)
    # Retain only chunks used by this frozen export, never old build payloads.
    if (play/'chunks').is_dir():
        for old in (play/'chunks').glob('*.gz'):
            if re.fullmatch(r'[a-f0-9]{64}\.gz',old.name) and not (source/'chunks'/old.name).exists():
                old.unlink()
    shutil.copytree(source/'chunks',play/'chunks',dirs_exist_ok=True)
    html = (play/'index.html').read_text()
    # Raw >25MiB files intentionally remain local. Require the existing verified
    # chunk worker; show a real startup error if a browser cannot supply it.
    marker = '\tawait window.PLAYTEST_CACHE_READY;\n\tconst missing = Engine.getMissingFeatures({'
    gate = '''\tconst transportReady = await window.PLAYTEST_CACHE_READY;
\tif (!transportReady || typeof DecompressionStream === 'undefined') {
\t\tdisplayFailureNotice('浏览器未能启动分块加载。请使用新版 Chrome 并允许本站存储后重试。');
\t\treturn;
\t}
\tconst missing = Engine.getMissingFeatures({'''
    if html.count(marker)!=1:
        raise ValueError('Verified Godot loader marker changed')
    html = html.replace(marker,gate).replace('image-rendering: pixelated','image-rendering: auto')
    (play/'index.html').write_text(html)
    media = target/'media'
    media.mkdir(exist_ok=True)
    captures = json.loads((EVIDENCE/'capture-manifest.json').read_text())
    for row in captures:
        path = EVIDENCE/'captures'/Path(row['file']).name
        shutil.copyfile(path,media/path.name)
    rooms = [('P-R04','风铃平原','断桥与铜钟：开敞空间、斜切日轮与赭色薄台。'),('F-R01','荆棘森林','叠叶与裂根：非等距树冠、双层树干与林隙。'),('G-R02','齿轮工城','壁板与窗光：固定机械内墙、墙上铜钟与缓转齿轮。')]
    for name in ['capture-manifest.json','performance.json','modulation.json']:
        shutil.copyfile(EVIDENCE/name,media/name)
    for rid,_,_ in rooms:
        for name in [rid+'.mp4','clip-'+rid+'.json']:
            shutil.copyfile(EVIDENCE/name,media/name)
    # Old A and P04 A/B media belong to Git/earlier Site versions only.
    admitted={Path(row['file']).name for row in captures}
    admitted.update(['capture-manifest.json','performance.json','modulation.json'])
    admitted.update(rid+'.mp4' for rid,_,_ in rooms)
    admitted.update('clip-'+rid+'.json' for rid,_,_ in rooms)
    for path in media.iterdir():
        if path.is_file() and path.name not in admitted:path.unlink()
    triptych=''
    cards=''
    for rid,title,detail in rooms:
        image=rid+'-B-landmark.png'
        triptych+=f'<figure><a href="media/{image}" target="_blank"><img src="media/{image}" alt="B / {title}"></a><figcaption>{title} · {rid} · <a href="play/index.html?room={rid}&paper=B">试玩</a></figcaption></figure>'
        cards+=f'<section><h2>{title} / {rid}</h2><p>{detail}</p><div class="video-wrap"><video controls playsinline preload="metadata" poster="media/{image}" src="media/{rid}.mp4"></video><p><a href="media/{rid}.mp4" download>下载正常速度实机片段</a></p></div>'
        for pose,label in [('landmark','主机位'),('upper','第二机位'),('lower','第三机位')]:
            cards+=f'<h3>{label} · 当前美术 / B 同机位</h3><div class="compare">'
            for mode,name in [('0','当前像素'),('B','B 抽象拼贴')]:
                image=f'{rid}-{mode}-{pose}.png'
                cards+=f'<figure><a href="media/{image}" target="_blank"><img src="media/{image}" alt="{title} / {name} / {label}" loading="lazy"></a><figcaption>{name} · <a href="media/{image}" download>原图下载</a></figcaption></figure>'
            cards+='</div>'
        cards+='</section>'
    navigation=''.join(f'<a href="play/index.html?room={rid}&paper=B">{title}试玩</a>' for rid,title,_ in rooms)
    megabytes=round(info['download_bytes']/1000000)
    page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>失序之钟 · B 三域纸艺剧场</title>
<style>*{box-sizing:border-box}body{margin:0;background:#eee7d6;color:#294f4f;font:16px/1.8 system-ui,sans-serif}main{max-width:1440px;margin:auto;padding:40px 24px 64px}header{max-width:920px}.eyebrow{letter-spacing:.16em;font-size:12px;color:#91604c}h1{font-size:clamp(30px,4vw,55px);font-weight:550;line-height:1.2;margin:20px 0}h2{font-size:25px;font-weight:550;margin-top:44px}h3{font-size:16px;font-weight:500;color:#65786c}p{color:#61746a}nav{display:flex;gap:12px;flex-wrap:wrap;margin:24px 0}nav a{background:#315e59;color:#f6e8cc;padding:12px 24px;text-decoration:none;border-radius:3px}nav a:nth-child(2){background:#586c50}nav a:nth-child(3){background:#576a73}.grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:14px}.compare{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:14px}.video-wrap{max-width:960px}figure{margin:0}img,video{display:block;width:100%;border:1px solid #cabfa4}figcaption{font-size:13px;color:#64766c;margin:8px 0}a{color:inherit}.note{max-width:920px;border-left:2px solid #a86448;padding-left:18px;margin-top:32px}footer{font-size:12px;color:#708077;margin-top:40px}@media(max-width:800px){main{padding:24px 16px}.grid,.compare{grid-template-columns:1fr}nav a{flex:1;text-align:center;padding:12px}.grid figure{margin-bottom:12px}}</style>
<main><header><div class="eyebrow">GODOT 4.7.2 / B / THREE REGIONAL STUDIES</div><h1>失序之钟<br>B · 三域纸艺剧场</h1><p>只继续抽象拼贴 B。风铃平原、荆棘森林、齿轮工城，各一间现有真实样房：共用纸偶、连续地形、纸厚与水彩材质，分别探索开敞断桥、树冠根系和封闭机械建筑。A 已退出当前实验。</p><nav>'''+navigation+f'''</nav><p>建议手机横屏。首次共享运行包约 {megabytes} MB，之后缓存复用。试玩内直接切换三个区域，按 B / 0 对比纸艺与当前美术，按 1 / 2 / 3 切区域；A/D移动、空格跳跃，鼠标按住瞄准后松开射击，手机使用原触控。</p></header><h2>三域 B · 真实 Godot 合屏</h2><p>三域使用相同角色尺寸与正式镜头参数。以下三列来自各自真实房间；往下可看每房当前美术/B的同机位原图。</p><div class="grid">'''+triptych+'''</div><div class="note"><strong>本轮检查范围</strong><p>森林与工城使用当前正式入口示例，保持其现有地形和玩法；不是三个完整区域改造。所有画面由运行时几何、材质、层叠、纸偶和有限动态光组成，没有完整场景插画或AI概念图。</p><p>操作片段保持正常速度；使用画面明示的隔离无敌审核模式，不写正式存档，不设置片中玩家位置或镜头路径。P04约20秒，另两房约15秒。实体手机帧率与完整战斗仍未验收。</p></div>'''+cards+'''<div class="note"><strong>比较判断</strong><p>平原保留温暖留白与铜钟，森林用叶冠负形和树干深度建立包围感，工城用固定壁板、窗光与机械圆片建立室内秩序。三域在共同纸艺语言下已有不同空间性格；纸偶动作和物种细节仍是后续打磨项，三个样房不等于16区量产通过。</p><a href="media/performance.json">三域性能原始记录</a> · <a href="media/capture-manifest.json">机位与图片哈希</a></div><footer><a href="https://github.com/zhipijun1996/gunman-rush/pull/159">独立实验 PR159</a> · 正式游戏入口、地形碰撞与规范未修改<br>Build: '''+info['build_id']+' · Source: '+info['source_commit']+'''</footer></main></html>'''
    (target/'index.html').write_text(page)
    (target/'build-info.json').write_text(json.dumps(info,indent=2)+'\n')
    oversized=[str(p) for p in target.rglob('*') if p.is_file() and p.stat().st_size>25*1024*1024]
    if oversized:raise ValueError('Static host oversized files: '+str(oversized))
    print(json.dumps({'target':str(target),'build_id':info['build_id'],'files':sum(p.is_file() for p in target.rglob('*'))}))


if __name__=='__main__':main()
