#!/usr/bin/env python3
"""Shared SVG rendering for authored regions and the assembled world review."""
import html

def markers(r):
    m=[]
    if r.get('rest'):m.append('休息')
    if r.get('rift'):m.append('裂缝')
    m += ['Boss '+b for b in r.get('bosses',[])]
    m += r.get('rewards',[])
    for a in r.get('actions',[]):
        if a.get('type')=='ability':m.append('获得'+' / '.join(a['grants']))
        elif a['id']=='get_lamp':m.append('照明')
        elif a['id']=='get_filter':m.append('滤芯')
        elif a['id'].startswith('repair_'):m.append('修钟')
    return ' · '.join(m)

def drawing(plan,context=()):
    rooms=plan['rooms'];pts=[p for r in [*rooms,*context] for p in r['outline']]
    x=min(a for a,b in pts)-640;y=min(b for a,b in pts)-900;w=max(a for a,b in pts)-x+640;h=max(b for a,b in pts)-y+640
    colors={'P':('#514e35','#b8ae78'),'F':('#283e34','#84ad94'),'M':('#3d344d','#b9a3d2'),'S':('#294840','#8fc5b5'),'T':('#42472c','#b8c58a'),'Y':('#4c3b2e','#b89772'),'I':('#2d4653','#8eb4c5'),'C':('#3e3d51','#aaa6c4')}
    out=[f'<svg id="map" xmlns="http://www.w3.org/2000/svg" viewBox="{x} {y} {w} {h}" role="img" aria-label="连续地区地图初稿"><style>text{{font-family:"Noto Sans CJK SC",sans-serif}}.room{{cursor:pointer}}.room.selected path{{stroke:#ffe5a8;stroke-width:20}}.room.dim{{opacity:.24}}.route{{pointer-events:none}}</style><rect x="{x}" y="{y}" width="{w}" height="{h}" fill="#101b21"/><text x="{x+240}" y="{y+330}" fill="#e5d9b4" font-size="{min(180,(w-480)/max(1,len(plan.get("title","地穴 · 沼泽 · 圣殿 / 地图初稿"))))}">{html.escape(plan.get("title","地穴 · 沼泽 · 圣殿 / 地图初稿"))}</text><text x="{x+240}" y="{y+600}" fill="#a7b7b5" font-size="{min(95,(w-480)/68)}">同一世界坐标 · 实宽通道归房间 · 金色口为邻区预留 · 电梯两端同号 · 尚未施工玩法</text>']
    for r in [*context,*rooms]:
        rid=r['room_id'];a,b=r['label'];fill,stroke=colors[rid[0]];d='M'+'L'.join(f'{x},{y}' for x,y in r['outline'])+'Z';is_context=r in context
        r['marker']=markers(r)
        purpose=r['purpose'] if len(r['purpose'])<=22 else r['purpose'][:21]+'…'
        cuts=sorted(p[0] for p,q in zip(r['outline'],r['outline'][1:]+r['outline'][:1]) if p[0]==q[0] and min(p[1],q[1])<=b<max(p[1],q[1]))
        width=next((right-left for left,right in zip(cuts[::2],cuts[1::2]) if left<=a<=right),1000)-96
        title_size=min(88,width/max(1,len(rid+' '+r['name'])))
        purpose_size=min(64,width/max(1,len(purpose)))
        marker_size=min(48,width/max(1,len(r['marker'])))
        out.append(f'<g class="{"context" if is_context else "room"}" data-room="{rid}" tabindex="0" role="button"><title>{rid} {html.escape(r["name"])} · {html.escape(r["purpose"])}</title><path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="9"/><text x="{a}" y="{b-104}" fill="#f1e7cd" text-anchor="middle" font-size="{title_size}">{rid} {html.escape(r["name"])}</text><text x="{a}" y="{b}" fill="#c6d2cb" text-anchor="middle" font-size="{purpose_size}">{html.escape(purpose)}</text><text x="{a}" y="{b+88}" fill="#f3cd8e" text-anchor="middle" font-size="{marker_size}">{html.escape(r["marker"])}</text>')
        gates=sorted({'+'.join(g) for rt in r.get('gates',[]) for g in rt['requires'] if g})
        if gates:out.append(f'<text x="{a}" y="{b+150}" fill="#cdb8ef" font-size="42" text-anchor="middle">房内：{html.escape(" / ".join(gates))}</text>')
        out.append('</g>')
    for c in plan['connections']:
        a,b=c['seam'];out.append(f'<circle cx="{a}" cy="{b}" r="17" fill="#d9d5bb"><title>{c["id"]} · {html.escape(c["space_role"])}</title></circle>')
    for rt in plan['routes']:
        for a,b in zip(rt['rooms'],rt['rooms'][1:]):
            c=next(e for e in plan['connections'] if {e['a'],e['b']}=={a,b});pts=c['path'] if c['a']==a else list(reversed(c['path']));path='M'+'L'.join(f'{x},{y}' for x,y in pts)
            out.append(f'<path class="route" data-route="{rt["id"]}" d="{path}" stroke="{rt["color"]}" stroke-width="28" fill="none" style="display:none"/>')
        for n,rid in enumerate(rt['rooms']):
            r=next(r for r in rooms if r['room_id']==rid);a,b=r['label'];out.append(f'<text class="route" data-route="{rt["id"]}" x="{a}" y="{b-135}" text-anchor="middle" fill="{rt["color"]}" font-size="60" style="display:none">{n+1}</text>')
    for p in plan['external_ports']:
        a,b=p['point'];dx,dy={'up':(0,-1),'down':(0,1),'left':(-1,0),'right':(1,0)}[p['direction']]
        out.append(f'<path d="M{a},{b}l{dx*180},{dy*180}" stroke="#edc17b" stroke-width="18"/><text x="{a+dx*220}" y="{b+dy*220}" fill="#edc17b" font-size="44">{p["id"]} → {html.escape(p["region_name"])}</text>')
    for c in plan['attachments']:
        a,b=c['path'][0];out.append(f'<circle cx="{a}" cy="{b}" r="28" fill="#f4c77d"/><text x="{a+60}" y="{b-70}" fill="#f4c77d" font-size="48">{c["id"]} {html.escape(c.get("label","跨区接缝"))}</text>')
    for t in plan['transitions']:
        for side in ['a','b']:
            if t[side]['room'] not in {r['room_id'] for r in rooms}:continue
            a,b=t[side]['point'];out.append(f'<rect x="{a-45}" y="{b-45}" width="90" height="90" fill="#edc17b"/><text x="{a+70}" y="{b-60}" fill="#edc17b" font-size="42">L22 ⇅ 井内升降</text>')
    out.append('</svg>');return ''.join(out)
