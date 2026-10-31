#!/usr/bin/env python3
"""Build a standalone review document from actual analysis and native traces."""
import argparse
import html
import json
from pathlib import Path


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--analysis', required=True)
    p.add_argument('--pilot', action='append', default=[])
    p.add_argument('--output', required=True)
    args = p.parse_args()
    analysis = json.loads(Path(args.analysis).read_text())
    pilots = []
    for name in args.pilot:
        source = Path(name).resolve()
        runtime = source.parent
        while not (runtime / 'project.godot').exists() and runtime != runtime.parent:
            runtime = runtime.parent
        report = json.loads(source.read_text())
        for r in report['receipts']:
            if not r.get('raw_path'): continue
            raw = json.loads((runtime / r['raw_path']).read_text())
            pilots.append({'id': raw['candidate'], 'condition': raw['strategy'], 'variant': raw['variant'],
                           'source_commit': report['source_commit'], 'tuning': raw['tuning'],
                           'ok': r['technical_pass'], 'errors': raw['failures'],
                           'reward': raw['visited_reward_location'], 'return': raw['returned_after_reward'],
                           'geometry': raw['geometry'], 'anchors': raw['anchors'], 'routes': raw['routes'],
                           'frames': raw['frames'][::3] + [raw['frames'][-1]], 'raw_sha256': r['raw_sha256']})
    rows = [{'id': r['id'], 'title': r['title'], 'region': r['region'],
             'decision': r['ai_design'].get('decision', 'pending'),
             'role': r['ai_design'].get('role', ''), 'strengths': r['ai_design'].get('strengths', []),
             'problems': r['ai_design'].get('problems', []), 'improvement': r['ai_design'].get('improvement', []),
             'counterfactual': r['ai_design'].get('counterfactual', []),
             'capability_status': (r.get('capabilities') or {}).get('status', 'unspecified')}
            for r in analysis['modules']]
    data = json.dumps({'library': rows, 'pilots': pilots}, ensure_ascii=False).replace('<', '\\u003c')
    page = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>失序之钟 · AI 关卡设计 v1 实验报告</title>
<style>body{font:16px/1.7 system-ui,sans-serif;background:#101923;color:#e3edf4;max-width:1180px;margin:auto;padding:30px}h1,h2{line-height:1.3}a{color:#74d4e5}button,select,input{font:inherit;padding:8px;background:#243443;color:white;border:1px solid #597180;border-radius:5px}input[type=range]{width:95%}section{background:#182533;padding:22px;border-radius:12px;margin:22px 0}table{width:100%;border-collapse:collapse}td,th{text-align:left;vertical-align:top;padding:9px;border-bottom:1px solid #3a4b59}small,.note{color:#b9cad5}.pass{color:#95e6ac}.fail{color:#ffab9b}svg{width:100%;background:#0c1420;border-radius:10px}video{width:100%;max-width:1100px}.pill{display:inline-block;padding:2px 10px;border:1px solid #476577;border-radius:30px}#details{white-space:pre-wrap}summary{cursor:pointer}code{overflow-wrap:anywhere}</style>
<h1>失序之钟 · AI 关卡设计体系 v1</h1>
<p>小规模方法验证：来源审计 → 设计契约 → AI 初审 → 真实 Godot → 对照与失败回流。正式入口与既有有效关卡保留。</p>
<p class="pill">技术可行性、AI 设计判断、真人认可分别记录</p>
<section><h2>架构选择</h2><p>离线创造并验证玩法家族，在线生成受约束的组合和探索关系。Macro Module 是可选体验编排层：只有独立的跨模块资源、状态、节奏或分叉回程约束时使用。Map 可直接组合 Module / Cell；尺寸大、动作多或数量多都不构成新玩法。</p><p>本轮是离线有限关系基因实验；没有把实验规则加入正式随机池，没有证明一般算法可无限创造有趣关卡。</p></section>
<section><h2>真实 Godot 短片</h2><p class="note">原型几何，真实运行与连续录制；各段条件独立，不代表整张地图连续通关。奖励只验位置往返，没有正式领奖交易。真人趣味、设备与最终美术未验。</p><video controls preload="metadata" src="pilot-latest.mp4"></video><p><a href="pilot-latest.mp4" download>下载短片</a> · <a href="evidence.zip" download>下载完整原始证据与恢复索引</a></p></section>
<section><h2>物理对照与设计图</h2><p>绿色/粉色代表该策略的原生结果。直接取奖失败只否定本次有界策略，不证明不存在其他解法。静态设计路线与实际运动分开显示。</p><select id="case"></select><svg id="diagram" viewBox="-50 -200 950 620"></svg><input id="frame" type="range" min="0" value="0"><p id="state"></p><p class="note">上图为原始轨迹的每三帧采样遥测，可拖动核对；它不是录像。蓝线主路，黄线奖励/回程设计锚点，白线实际运动，青色框为实际身体。</p><pre id="details"></pre></section>
<section><h2>177 份参考的 AI 设计初审</h2><p>全部来源 hash 核对；9 份深入初审，168 份有限源码初审。retain 是保留取证意向，不能签优秀或正式准入。169 条仍需要证据。低交互休整不自动劣质，长动作链不自动优秀。</p><input id="query" placeholder="搜索 ID、区域或评价"><select id="decision"><option value="">全部判断</option><option>retain</option><option>improve</option><option>reconstruct</option><option>needs_evidence</option></select><p id="count"></p><table><thead><tr><th>内容 / 角色</th><th>AI 判断与反证</th></tr></thead><tbody id="library"></tbody></table></section>
<section><h2>仍需验证</h2><p>样本之间有可观察的行为差异，尚不能证明真人更喜欢哪一个；8wu几何变体也不应自动算新玩法。当前工厂有限，动态机关、完整跨模块资源链、真实邻接、多Seed整图与本作钩索机制仍需扩展证据。最新开发与 main 的一发/两发及能量规则分别绑定，不能混签。</p></section>
<script id="data" type="application/json">__DATA__</script><script>
const D=JSON.parse(document.getElementById('data').textContent),$=id=>document.getElementById(id),esc=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
D.pilots.forEach((p,i)=>{const o=document.createElement('option');o.value=i;o.textContent=`${p.source_commit.slice(0,7)} · ${p.id} / ${p.condition} / v${p.variant} · ${p.ok?'技术通过':'保留失败'}`;$('case').append(o)});
function diagram(){const p=D.pilots[+$('case').value];if(!p)return;let s=p.geometry.map(r=>`<rect x="${r[0]}" y="${r[1]}" width="${r[2]}" height="${r[3]}" fill="#47685c" stroke="#9cbd9e"/>`).join('');for(const [name,route]of Object.entries(p.routes)){const pts=route.map(i=>p.anchors[i].join(',')).join(' ');s+=`<polyline points="${pts}" fill="none" stroke="${name==='main'?'#76bfff':'#e4bf66'}" stroke-dasharray="8 6" stroke-width="2"/>`;}s+=`<polyline points="${p.frames.map(f=>f.position.join(',')).join(' ')}" fill="none" stroke="#f2f5fa" opacity=".7" stroke-width="1.8"/>`;s+='<rect id="body" width="24" height="36" fill="#5df1f5" opacity=".85"/>';$('diagram').innerHTML=s;$('frame').max=p.frames.length-1;$('frame').value=0;$('details').textContent=`${p.ok?'该策略技术通过':'该策略失败/未到达'} · 空中射击=${p.tuning.max_air_shots} · 实际奖励位置=${p.reward} · 返回标记=${p.return}\n错误=${JSON.stringify(p.errors)}\n原始收据 SHA256=${p.raw_sha256}\n本实验不签正式领奖、整图或真人趣味。`;state();}
function state(){const p=D.pilots[+$('case').value];if(!p)return;const f=p.frames[+$('frame').value],b=$('body');b.setAttribute('x',f.position[0]-12);b.setAttribute('y',f.position[1]-18);$('state').textContent=`原生帧 ${f.frame} · 位置 ${f.position.map(n=>n.toFixed(1))} · grounded=${f.grounded} · shots=${f.shots} · stamina=${f.stamina.toFixed(1)} · 实际事件 ${JSON.stringify(f.accepted_actions)}`;}
function library(){const q=$('query').value.toLowerCase(),kind=$('decision').value,rows=D.library.filter(r=>(!kind||r.decision===kind)&&JSON.stringify(r).toLowerCase().includes(q));$('count').textContent=`${rows.length} / ${D.library.length} 份 · 技术与真人认可不由此表赋值`;$('library').innerHTML=rows.map(r=>`<tr><td><b>${esc(r.title)}</b><br><code>${esc(r.id)}</code><br>${esc(r.region)} · 能力 ${esc(r.capability_status)}<br>${esc(r.role)}</td><td><b>${esc(r.decision)}</b><details><summary>查看依据与待验反例</summary><p>优势：${esc(r.strengths.join('；'))}</p><p>问题：${esc(r.problems.join('；'))}</p><p>改进：${esc(r.improvement.join('；'))}</p><p>反证：${esc(r.counterfactual.join('；'))}</p></details></td></tr>`).join('');}
$('case').onchange=diagram;$('frame').oninput=state;$('query').oninput=library;$('decision').onchange=library;diagram();library();</script></html>'''
    dest = Path(args.output)
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(page.replace('__DATA__', data))
    print('REPORT: standalone review document written to ' + str(dest))


if __name__ == '__main__':
    main()
