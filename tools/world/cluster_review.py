#!/usr/bin/env python3
"""Deliver the neighboring underground draft and its same-scale world context."""
import base64,html,json
from pathlib import Path
from regional_review import compile_plan,ROOT
from forest_review import build as forest_build
from preview_catalog import preview_catalog

def markers(r):
    m=[]
    if r.get('rest'):m.append('休息')
    if r.get('rift'):m.append('裂缝')
    m += ['Boss '+b for b in r.get('bosses',[])]
    m += r.get('rewards',[])
    for a in r.get('actions',[]):
        if a['id']=='get_D':m.append('获得D')
        elif a['id']=='get_lamp':m.append('照明')
        elif a['id']=='get_filter':m.append('滤芯')
        elif a['id'].startswith('repair_'):m.append('修钟')
    return ' · '.join(m)

def drawing(plan,context=()):
    rooms=plan['rooms'];pts=[p for r in [*rooms,*context] for p in r['outline']]
    x=min(a for a,b in pts)-640;y=min(b for a,b in pts)-900;w=max(a for a,b in pts)-x+640;h=max(b for a,b in pts)-y+640
    colors={'P':('#514e35','#b8ae78'),'F':('#283e34','#84ad94'),'M':('#3d344d','#b9a3d2'),'S':('#294840','#8fc5b5'),'T':('#42472c','#b8c58a')}
    out=[f'<svg id="map" xmlns="http://www.w3.org/2000/svg" viewBox="{x} {y} {w} {h}" role="img" aria-label="地下三地区连续地图初稿"><style>text{{font-family:"Noto Sans CJK SC",sans-serif}}.room{{cursor:pointer}}.room.selected path{{stroke:#ffe5a8;stroke-width:20}}.room.dim{{opacity:.24}}.route{{pointer-events:none}}</style><rect x="{x}" y="{y}" width="{w}" height="{h}" fill="#101b21"/><text x="{x+240}" y="{y+330}" fill="#e5d9b4" font-size="180">{html.escape(plan.get("title","地穴 · 沼泽 · 圣殿 / 地图初稿"))}</text><text x="{x+240}" y="{y+600}" fill="#a7b7b5" font-size="95">同一世界坐标 · 实宽通道归房间 · 金色口为邻区预留 · 电梯两端同号 · 尚未施工玩法</text>']
    for r in [*context,*rooms]:
        rid=r['room_id'];a,b=r['label'];fill,stroke=colors[rid[0]];d='M'+'L'.join(f'{x},{y}' for x,y in r['outline'])+'Z';is_context=r in context
        r['marker']=markers(r)
        purpose=r['purpose'] if not is_context or len(r['purpose'])<=22 else r['purpose'][:21]+'…'
        out.append(f'<g class="{"context" if is_context else "room"}" data-room="{rid}" tabindex="0" role="button"><title>{rid} {html.escape(r["name"])} · {html.escape(r["purpose"])}</title><path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="9"/><text x="{a}" y="{b-64}" fill="#f1e7cd" text-anchor="middle" font-size="54">{rid} {html.escape(r["name"])}</text><text x="{a}" y="{b}" fill="#c6d2cb" text-anchor="middle" font-size="44">{html.escape(purpose)}</text><text x="{a}" y="{b+62}" fill="#f3cd8e" text-anchor="middle" font-size="34">{html.escape(r["marker"])}</text>')
        gates=sorted({'+'.join(g) for rt in r.get('gates',[]) for g in rt['requires'] if g})
        if gates:out.append(f'<text x="{a}" y="{b+110}" fill="#cdb8ef" font-size="32" text-anchor="middle">房内：{html.escape(" / ".join(gates))}</text>')
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
        a,b=c['path'][0];out.append(f'<circle cx="{a}" cy="{b}" r="28" fill="#f4c77d"/><text x="{a+60}" y="{b-70}" fill="#f4c77d" font-size="48">{c["id"]} 森林接缝</text>')
    for t in plan['transitions']:
        for side in ['a','b']:
            if t[side]['room'] not in {r['room_id'] for r in rooms}:continue
            a,b=t[side]['point'];out.append(f'<rect x="{a-45}" y="{b-45}" width="90" height="90" fill="#edc17b"/><text x="{a+70}" y="{b-60}" fill="#edc17b" font-size="42">L22 ⇅ 井内升降</text>')
    out.append('</svg>');return ''.join(out)

def main():
    from export_editor_project import export
    out=ROOT/'build/underground-review';out.mkdir(parents=True,exist_ok=True)
    plan=compile_plan();p=export(spatial_draft=True)
    (out/'project.json').write_text(json.dumps(p,ensure_ascii=False,separators=(',',':'))+'\n')
    whole=drawing(plan);(out/'underground.svg').write_text(whole)
    for code,name in [('M','mushroom'),('S','marsh'),('T','temple')]:
        sub={**plan,'rooms':[r for r in plan['rooms'] if r['room_id'][0]==code],'connections':[c for c in plan['connections'] if c['a'][0]==c['b'][0]==code],'routes':[r for r in plan['routes'] if r['rooms'][0][0]==code],'external_ports':[r for r in plan['external_ports'] if r['room'][0]==code],'attachments':[r for r in plan['attachments'] if r['room'][0]==code],'transitions':[],'title':{'M':'蕈灯地穴 · 18房','S':'萤雾沼泽 · 16房','T':'根脉圣殿 · 16房'}[code]}
        for c in plan['connections']:
            if (c['a'][0]==code)==(c['b'][0]==code):continue
            host=c['a'] if c['a'][0]==code else c['b'];other=c['b'] if host==c['a'] else c['a']
            sub['external_ports'].append({'id':c['id'],'point':c['seam'],'room':host,'direction':'right' if host==c['a'] else 'left','region_name':{'M':'蕈灯地穴','S':'萤雾沼泽','T':'根脉圣殿'}[other[0]]})
        if code=='M':
            sub['rooms']=[r for r in sub['rooms'] if r['room_id']!='M-R02']
            sub['external_ports']=[r for r in sub['external_ports'] if r['room']!='M-R02']
            sub['transitions']=plan['transitions'];sub['title']='蕈灯地穴 · 17房主体；M02井室见局部图 / L22升降转场'
        (out/f'{name}.svg').write_text(drawing(sub))
    preview=preview_catalog(ROOT);forest=forest_build(ROOT,preview);context=forest['rooms']
    for row in preview['map_rooms']:
        if row['id'][0]!='P':continue
        r=p['rooms'][row['id']];box=max(r['spaces'],key=lambda a:a[2]*a[3]);context.append(dict(room_id=r['id'],outline=row['polygon'],label=[r['origin'][0]+box[0]+box[2]/2,r['origin'][1]+box[1]+box[3]/2],name=r['name'],purpose=r['purpose']))
    well={**plan,'title':'M02封井局部 / P03钩索入口与井内升降','rooms':[r for r in plan['rooms'] if r['room_id']=='M-R02'],'connections':[],'routes':[],'attachments':[],'external_ports':[p for p in plan['external_ports'] if p['id']=='C03']}
    (out/'well.svg').write_text(drawing(well,[r for r in context if r['room_id']=='P-R03']))
    (out/'joined.svg').write_text(drawing({**plan,'title':'平原—森林—地下三地区 / 109房同尺度拼接'},context))
    page=(ROOT/'tools/world/forest_review.html').read_text()
    page=page.replace('荆棘森林','地下三地区').replace('24 房 · 30 条区内连接 · 5 个跨区接口','50 房 · 地穴18 / 沼泽16 / 圣殿16').replace("selected='F-R01'","selected='M-R03'").replace('forest-review-notes','underground-review-notes').replace('F-Rxx','M/S/T-Rxx')
    page=page.replace('<a class="link" href="/">返回工坊</a>','<span class="muted">世界初稿 · 第二片</span>').replace('一棵主树连接林下、树腹与根井。主路使用 H 深入并取得 W；游侠武器支路可先去，也可回来挑战；取得 W 后在已见过的岔路展开另一半森林。','菌灯先于黑暗门，D展开后庭；沼泽先走干岸，再选择滤芯深池；圣殿主钟与技能双卫分别安排。M02与M01使用同号井内升降口，不画穿房线。').replace('首访、武器支路、W后回环分别查看，比较连续几房的节奏。','选择首访、能力回访、主目标或收藏路线，比较各房职责与节奏。').replace('较长的根道','较长的通路')
    page=page.replace('r.room_id.slice(2)','r.room_id').replace('id.slice(2)','id').replace('e.room.slice(2)','e.room')
    page=page.replace('href="forest.svg" download','href="data:image/svg+xml;base64,'+base64.b64encode(whole.encode()).decode()+'" download="underground.svg"')
    page=page.replace('<select id="route"', '<select id="region-view" aria-label="选择区域"><option value="all">地下三地区总览</option><option value="M">蕈灯地穴主体</option><option value="S">萤雾沼泽</option><option value="T">根脉圣殿</option></select><select id="route"')
    page=page.replace('</script>', "$('#region-view').onchange=e=>{ $('#route').value='all';$('#route').dispatchEvent(new Event('change'));const rs=plan.rooms.filter(r=>e.target.value==='all'||r.room_id[0]===e.target.value&&r.room_id!=='M-R02');const x=Math.min(...rs.map(r=>r.bounds[0])),y=Math.min(...rs.map(r=>r.bounds[1])),xx=Math.max(...rs.map(r=>r.bounds[0]+r.bounds[2])),yy=Math.max(...rs.map(r=>r.bounds[1]+r.bounds[3]));view=[x-300,y-300,xx-x+600,yy-y+600];renderView()};</script>")
    page=page.replace('<!-- MAP -->',whole).replace('/* PLAN */',json.dumps(plan,ensure_ascii=False).replace('</','<\\/'))
    page=page.replace("$('#route-summary').textContent=rt?", "if(rt){const rs=rt.rooms.map(id=>rooms.get(id).bounds);const x=Math.min(...rs.map(b=>b[0])),y=Math.min(...rs.map(b=>b[1])),xx=Math.max(...rs.map(b=>b[0]+b[2])),yy=Math.max(...rs.map(b=>b[1]+b[3]));view=[x-300,y-300,xx-x+600,yy-y+600];renderView()}$('#route-summary').textContent=rt?")
    (out/'review.html').write_text(page)
    print(f"{len(plan['rooms'])} rooms; {len(plan['connections'])} continuous seams; {len(plan['transitions'])} explicit lift; 109-room joined map")
if __name__=='__main__':main()
