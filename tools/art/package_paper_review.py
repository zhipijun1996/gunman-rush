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
    for name in ['A.mp4','B.mp4','capture-manifest.json','clip-A.json','clip-B.json','performance.json']:
        shutil.copyfile(EVIDENCE/name,media/name)
    cards = ''
    for pose,label in [('bridge','断桥与钟架'),('ascent','上层跳台'),('underbridge','桥下凹室')]:
        cards += '<section><h2>'+label+' · 相同机位</h2><div class="grid">'
        for mode,title in [('0','当前像素'),('A','A · 轻剪纸水彩'),('B','B · 抽象拼贴')]:
            name=f'{mode}-{pose}.png'
            cards+=f'<figure><a href="media/{name}" target="_blank"><img src="media/{name}" alt="{title} / {label}" loading="lazy"></a><figcaption>{title} · <a href="media/{name}" download>原图</a></figcaption></figure>'
        cards+='</div></section>'
    videos=''
    for mode,title in [('A','轻剪纸水彩'),('B','抽象拼贴')]:
        videos+=f'<figure><video controls playsinline preload="metadata" poster="media/{mode}-bridge.png" src="media/{mode}.mp4"></video><figcaption>{mode} · {title} / 正常速度 · <a href="media/{mode}.mp4" download>下载视频</a></figcaption></figure>'
    page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>失序之钟 · P04 纸艺剧场</title>
<style>*{box-sizing:border-box}body{margin:0;background:#eee7d6;color:#294f4f;font:16px/1.8 system-ui,sans-serif}main{max-width:1440px;margin:auto;padding:40px 24px 64px}header{max-width:820px;margin-bottom:38px}.eyebrow{letter-spacing:.16em;font-size:12px;color:#91604c}h1{font-size:clamp(30px,4vw,55px);font-weight:550;line-height:1.2;letter-spacing:-.04em;margin:20px 0}h2{font-size:21px;font-weight:550;margin-top:32px}p{color:#61746a}nav{display:flex;gap:12px;flex-wrap:wrap;margin:24px 0}nav a{background:#315e59;color:#f6e8cc;padding:12px 24px;text-decoration:none;border-radius:3px}nav a:nth-child(2){background:#a86448}nav a:nth-child(3){background:#d9cfb6;color:#294f4f}.grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:14px}.videos{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:20px}figure{margin:0}img,video{display:block;width:100%;border:1px solid #cabfa4}figcaption{font-size:13px;color:#64766c;margin:8px 0}a{color:inherit}.note{max-width:900px;border-left:2px solid #a86448;padding-left:18px;margin-top:32px}footer{font-size:12px;color:#708077;margin-top:40px}@media(max-width:800px){main{padding:24px 16px}.grid,.videos{grid-template-columns:1fr}nav a{flex:1;text-align:center;padding:12px}.grid figure{margin-bottom:12px}}</style>
<main><header><div class="eyebrow">GODOT 4.7.2 / GL COMPATIBILITY / P04</div><h1>失序之钟<br>纸艺剧场实验</h1><p>同一间倒钟田垄、同一控制器与镜头，比较当前像素、轻剪纸水彩与抽象拼贴。下方图片与影片均来自真实 Godot 渲染。风格尚未替换正式游戏。</p><nav><a href="play/index.html?paper=A">试玩 A</a><a href="play/index.html?paper=B">试玩 B</a><a href="play/index.html?paper=0">当前美术</a></nav><p>建议手机横屏。首次下载共享运行包约 142 MB，之后缓存复用。键盘 A/D 移动，空格跳跃；鼠标按住瞄准、松开射击。手机使用游戏原触控。试玩内可随时切换三种表现与重置 P04。</p></header>
'''+cards+'''<section><h2>连续操作 · 正常速度</h2><p>相同目标与真实输入，覆盖断桥反冲、登高、镜头移动和附着前景。录像使用现有隔离无敌审核模式；未设置玩家位置或镜头路径。Godot 以 60 个物理 tick 对应 1 秒输出，离线编码后保持该速度。</p><div class="videos">'''+videos+'''</div></section><div class="note"><strong>本次判断</strong><p>纸艺能够消除本房的规则贴图接缝，并把角色、危险与地形收进同一语言。A 更安静易读，B 的裁切色块与钟架更有辨识度。纸偶动作与各物种差异仍较简化；大钟架的局部构图以及手机性能还需打磨。当前证据不能证明已经适合16区量产。</p><p>没有使用完整场景插画或 AI 概念图。地形轮廓、色层、纸厚、接触影、视差、纸偶和有限动态光均在 Godot 运行时组成。</p><a href="media/performance.json">性能原始记录</a> · <a href="media/capture-manifest.json">机位与图片哈希</a></div><footer>源码与渲染结构：<a href="https://github.com/zhipijun1996/gunman-rush/tree/experiment/p04-paper-watercolor">独立实验分支</a> · 无正式存档写入 · 实体手机帧率未验收<br>Build: '''+info['build_id']+' · Source: '+info['source_commit']+'''</footer></main></html>'''
    (target/'index.html').write_text(page)
    (target/'build-info.json').write_text(json.dumps(info,indent=2)+'\n')
    oversized=[str(p) for p in target.rglob('*') if p.is_file() and p.stat().st_size>25*1024*1024]
    if oversized:raise ValueError('Static host oversized files: '+str(oversized))
    print(json.dumps({'target':str(target),'build_id':info['build_id'],'files':sum(p.is_file() for p in target.rglob('*'))}))


if __name__=='__main__':main()
