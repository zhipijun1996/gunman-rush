#!/usr/bin/env python3
"""Assemble authored regions in place; validate shared seams before review export."""
import base64,copy,html,json
from pathlib import Path
from cluster_review import drawing
from export_editor_project import export
from forest_review import build as forest_build,rectangles,overlap
from preview_catalog import preview_catalog
from regional_review import compile_plan,ROOT

MANIFEST=ROOT/'config/world/spatial_layout.json'
OPPOSITE={'left':'right','right':'left','up':'down','down':'up'}

def on_boundary(poly,p):
    x,y=p
    return any(a[0]==b[0]==x and min(a[1],b[1])<=y<=max(a[1],b[1]) or a[1]==b[1]==y and min(a[0],b[0])<=x<=max(a[0],b[0]) for a,b in zip(poly,poly[1:]+poly[:1]))

def validate_assembly(plan,project):
    rooms={r['room_id']:r for r in plan['rooms']};issues=[]
    rects={rid:rectangles(r['outline']) for rid,r in rooms.items()}
    items=list(rects.items())
    for i,(rid,rs) in enumerate(items):
        for other,ss in items[i+1:]:
            if not overlap(rooms[rid]['bounds'],rooms[other]['bounds']):continue
            if any(overlap(a,b) for a in rs for b in ss):issues.append(f'Overlap {rid} / {other}')
    for seam in plan['seams']:
        e=project['connections'][seam['id']];points=[];dirs=[]
        for side in ['a','b']:
            ep=e[side];r=project['rooms'][ep['room']];port=r['ports'][ep['port']]
            p=[r['origin'][i]+port['position'][i] for i in (0,1)]
            points.append(p);dirs.append(port['direction'])
            if not on_boundary(rooms[r['id']]['outline'],p):issues.append(f"Boundary {e['id']} / {r['id']}")
        if points[0]!=points[1]:issues.append(f"Seam drift {e['id']}: {points}")
        if OPPOSITE[dirs[0]]!=dirs[1]:issues.append(f"Normals {e['id']}: {dirs}")
        seam.update(point=points[0],directions=dirs)
    for pending in plan.get('pending_connections',[]):
        for side in ('a','b'):
            ep=pending[side]
            if not on_boundary(rooms[ep['room']]['outline'],ep['point']):issues.append(f"Pending port off boundary: {pending['id']} / {ep['room']}")
    assert not issues,'\n'.join(issues)
    return {'rooms':len(rooms),'cross_region_seams':len(plan['seams']),'overlaps':0,'unresolved_connections':len(plan.get('pending_connections',[]))}

def build(project=None):
    from spatial_adjustments import preview as adjusted_preview
    p=project or export(spatial_draft=True);preview=adjusted_preview(ROOT,preview_catalog(ROOT))
    manifest=json.loads(MANIFEST.read_text());regions='P'+''.join(manifest['scope_regions'])
    cache={}
    plans=[forest_build(ROOT,preview),*[compile_plan(cluster=Path(source).stem,_cache=cache) for source in manifest['cluster_sources']]]
    world=json.loads((ROOT/'config/world/world.json').read_text());identities={r['id']:r for r in world['rooms']};names={r['code']:r['name'] for r in world['regions']}
    rooms=[copy.deepcopy(r) for plan in plans for r in plan['rooms']]
    for row in preview['map_rooms']:
        if row['id'][0]!='P':continue
        r=p['rooms'][row['id']];x,y=r['origin'];box=max(r['spaces'],key=lambda b:b[2]*b[3])
        design=dict(room_id=r['id'],name=r['name'],purpose=r['purpose'],outline=row['polygon'],label=[x+box[0]+box[2]/2,y+box[1]+box[3]/2],bounds=[x,y,*r['bounds'][2:]],stage='沿用已制作平原；本轮不重新验收玩法',play='玩法与对象保持正式房间配置。',failure='沿用现行安全岸和地形恢复规则；本轮仅检查世界拼接。',exploration='奖励、能力门与剧情沿正式数据。')
        if r['spatial_source']['kind']=='spatial_draft':
            design.update(r.get('design_contract',{}));design['stage']='已制作房的候选调整；尚未回写正式关卡'
            if 'review_label' in r:design['label']=[r['review_label'][i]+r['origin'][i] for i in (0,1)]
        rooms.append(design)
    from spatial_adjustments import connections as draft_connections
    ids={r['room_id'] for r in rooms};edges={e['id']:e for e in draft_connections(ROOT,world)}
    for r in rooms:
        rid=r['room_id'];src=identities[rid]
        r.update(rest=src['rest_point'],rift=src.get('rift_machine',False),rewards=src['reward_ids'],bosses=[b['working_name'] for b in world['boss_plan']['bosses'] if b['physical_room']==rid],actions=[a for a in world['actions'] if a.get('room_id')==rid],gates=[g for g in src['internal_routes'] if not g['id'].endswith(':return')])
        r['neighbors']=[{'id':e['id'],'room':e['b'] if e['a']==rid else e['a'],'condition':e.get('condition_text','基础通行')} for e in edges.values() if rid in [e['a'],e['b']]]
    connections=[copy.deepcopy(c) for plan in plans for c in plan['connections']];seen={c['id'] for c in connections}
    transitions=[t for plan in plans for t in plan.get('transitions',[])];pending=[t for plan in plans for t in plan.get('pending_connections',[])];transition_ids={t['id'] for t in [*transitions,*pending]}
    seams=[];external=[]
    for e in edges.values():
        inside=[e[side] in ids for side in ['a','b']]
        if not any(inside):continue
        cid=e['id'];edge=p['connections'][cid]
        if all(inside):
            if e['a'][0]!=e['b'][0] and cid not in transition_ids:seams.append({'id':cid,'a':e['a'],'b':e['b'],'condition':e.get('condition_text','基础通行')})
            if cid not in seen and cid not in transition_ids:
                ep=edge['a'];r=p['rooms'][ep['room']];port=r['ports'][ep['port']];pt=[port['position'][i]+r['origin'][i] for i in (0,1)]
                connections.append(dict(id=cid,a=e['a'],b=e['b'],seam=pt,path=[pt,pt],space_role=e.get('description','现行共享门口')))
        else:
            host=e['a'] if inside[0] else e['b'];target=e['b'] if inside[0] else e['a'];r=p['rooms'][host];port=next(v for v in r['ports'].values() if v['connection']==cid)
            external.append(dict(id=cid,room=host,target=target,point=[r['origin'][i]+port['position'][i] for i in (0,1)],direction=port['direction'],region_name=names[target[0]]+'（待编排）'))
    plan=dict(title=f'失序之钟 · {len(regions)}地区 / {len(rooms)}房世界空间初稿',rooms=sorted(rooms,key=lambda r:(regions.index(r['room_id'][0]),r['room_id'])),connections=connections,routes=[copy.deepcopy(r) for p1 in plans for r in p1['routes']],external_ports=external,transitions=transitions,pending_connections=pending,seams=seams,attachments=[],regions=[{'code':c,'name':names[c]} for c in regions],review_limits=manifest['review_limits']+[f'同坐标检查{len(rooms)}房无重叠、{len(seams)}对跨区接缝共点且门向相反；真实落点和动作待灰盒验证。','能力锁、奖励、NPC与审批状态不因排布升级；房内门槛位置仍需灰盒校准。'],summary=manifest['review_summary'],focus_regions=manifest['review_regions'])
    plan['checks']=validate_assembly(plan,p)
    plan['review_limits'] += [f"待接续 {t['id']}：{t['reason']}" for t in pending]
    plan['attachments']=[dict(id=s['id'],path=[s['point']],label=s['a'][0]+' ↔ '+s['b'][0]) for s in seams]
    return plan,p

def page(plan,svg):
    nr=len(plan['regions']);nc=len(plan['rooms']);ns=len(plan['seams'])
    text=(ROOT/'tools/world/forest_review.html').read_text()
    text=text.replace('荆棘森林','世界地图').replace('24 房 · 30 条区内连接 · 5 个跨区接口',f'{nr} 地区 · {nc} 房 · {ns} 对跨区接缝').replace("selected='F-R01'",f"selected='{plan['focus_regions'][0]}-R01'").replace('forest-review-notes','world-review-notes').replace('F-Rxx','区域-Rxx')
    text=text.replace('<a class="link" href="/">返回工坊</a>','<span class="muted">世界初稿 / 持续编排</span>')
    text=text.replace('一棵主树连接林下、树腹与根井。主路使用 H 深入并取得 W；游侠武器支路可先去，也可回来挑战；取得 W 后在已见过的岔路展开另一半森林。',plan['summary']).replace('较长的根道','较长的通道').replace('首访、武器支路、W后回环分别查看，比较连续几房的节奏。','选择一条首访、能力回访或奖励支路；也可按区域或跨区接缝逐处查看。')
    text=text.replace('r.room_id.slice(2)','r.room_id').replace('id.slice(2)','id').replace('e.room.slice(2)','e.room')
    text=text.replace('href="forest.svg" download','href="data:image/svg+xml;base64,'+base64.b64encode(svg.encode()).decode()+'" download="world-map.svg"')
    selectors=f'<select id="region-view" aria-label="选择区域"><option value="all">{nr}地区总览</option>'+''.join(f'<option value="{r["code"]}">{r["name"]}</option>' for r in plan['regions'])+f'</select><select id="seam-view" aria-label="选择跨区接缝"><option value="">跨区接缝 · {ns}对</option>'+''.join(f'<option value="{s["id"]}">{s["id"]} · {s["a"]} ↔ {s["b"]}</option>' for s in plan['seams'])+'</select>'
    text=text.replace('<select id="route"',selectors+'<select id="route"')
    text=text.replace("$('#route-summary').textContent=rt?","if(rt)fitRooms(rt.rooms.map(id=>rooms.get(id)));$('#route-summary').textContent=rt?")
    text=text.replace("const pointers=new Map();", "function fitRooms(rs){const bs=rs.map(r=>r.bounds),x=Math.min(...bs.map(b=>b[0])),y=Math.min(...bs.map(b=>b[1])),xx=Math.max(...bs.map(b=>b[0]+b[2])),yy=Math.max(...bs.map(b=>b[1]+b[3]));view=[x-300,y-300,xx-x+600,yy-y+600];renderView()}const pointers=new Map();")
    text=text.replace('<select id="route"', '<select id="pending-view" aria-label="待解决连接"><option value="">待解决连接 · '+str(len(plan.get('pending_connections',[])))+'</option>'+''.join('<option value="'+t['id']+'">'+t['id']+'</option>' for t in plan.get('pending_connections',[]))+'</select><select id="route"')
    handlers="""
$('#pending-view').onchange=e=>{const p=plan.pending_connections.find(p=>p.id===e.target.value);if(!p)return;select(p.a.room);fitRooms([rooms.get(p.a.room),rooms.get(p.b.room)]);$('#route-summary').textContent='待接续：'+p.reason;document.querySelectorAll('.room').forEach(n=>n.classList.toggle('dim',![p.a.room,p.b.room].includes(n.dataset.room)))};
$('#region-view').onchange=e=>{ $('#route').value='all';$('#route').dispatchEvent(new Event('change'));$('#seam-view').value='';fitRooms(plan.rooms.filter(r=>e.target.value==='all'||r.room_id[0]===e.target.value&&(e.target.value!=='M'||r.room_id!=='M-R02')))};
$('#seam-view').onchange=e=>{const s=plan.seams.find(s=>s.id===e.target.value);if(!s)return;$('#route').value='all';$('#route').dispatchEvent(new Event('change'));select(s.a);view=[s.point[0]-1800,s.point[1]-1500,3600,3000];renderView();$('#route-summary').textContent=`${s.id}：${s.a}（${s.directions[0]}） ↔ ${s.b}（${s.directions[1]}） · ${s.condition}`;document.querySelectorAll('.room').forEach(n=>n.classList.toggle('dim',![s.a,s.b].includes(n.dataset.room)))};
"""
    text=text.replace('</script>',handlers+'</script>')
    text=text.replace('<!-- MAP -->',svg).replace('/* PLAN */',json.dumps(plan,ensure_ascii=False).replace('</','<\\/'))
    return text

def seam_sheet(plan):
    """Actual same-coordinate neighborhoods, not a separate schematic graph."""
    height=((len(plan['seams'])+2)//3)*850
    out=[f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 3000 {height}"><rect width="3000" height="{height}" fill="#101b21"/><style>text{{font-family:"Noto Sans CJK SC",sans-serif}}</style>']
    for i,s in enumerate(plan['seams']):
        x=(i%3)*1000;y=(i//3)*850;px,py=s['point'];view=[px-1800,py-1300,3600,2600]
        out.append(f'<text x="{x+24}" y="{y+42}" fill="#f0dcac" font-size="24">{s["id"]} · {s["a"]} ↔ {s["b"]}</text><text x="{x+24}" y="{y+76}" fill="#b3c7c5" font-size="18">{html.escape(s["condition"])}</text><svg x="{x+12}" y="{y+100}" width="976" height="710" viewBox="{view[0]} {view[1]} {view[2]} {view[3]}">')
        for r in plan['rooms']:
            if not overlap(r['bounds'],view):continue
            active=r['room_id'] in [s['a'],s['b']];fill='#42554c' if r['room_id']==s['a'] else '#4b465c' if active else '#1c2a30'
            d='M'+'L'.join(f'{a},{b}' for a,b in r['outline'])+'Z'
            out.append(f'<path d="{d}" fill="{fill}" stroke="{"#d7c38e" if active else "#455454"}" stroke-width="8"/>')
            if active:
                # Place readable identifiers on each side of the shared mouth.
                direction=s['directions'][0 if r['room_id']==s['a'] else 1];dx,dy={'left':(1,0),'right':(-1,0),'up':(0,1),'down':(0,-1)}[direction]
                out.append(f'<text x="{px+dx*650}" y="{py+dy*400-100}" text-anchor="middle" font-size="68" fill="#ece4ce">{r["room_id"]}</text>')
        out.append(f'<circle cx="{px}" cy="{py}" r="32" fill="#ffe2a0"/></svg>')
    out.append('</svg>');return ''.join(out)

def main():
    out=ROOT/'build/world-review';out.mkdir(parents=True,exist_ok=True)
    plan,p=build();svg=drawing(plan)
    (out/'world-map.svg').write_text(svg);(out/'world-review.html').write_text(page(plan,svg))
    (out/'seams.svg').write_text(seam_sheet(plan))
    (out/'world-project.json').write_text(json.dumps(p,ensure_ascii=False,separators=(',',':'))+'\n')
    for code in plan['focus_regions']:
        filename=code.lower()
        sub={**plan,'rooms':[r for r in plan['rooms'] if r['room_id'][0]==code],'connections':[c for c in plan['connections'] if c['a'][0]==c['b'][0]==code],'routes':[r for r in plan['routes'] if all(x[0]==code for x in r['rooms'])],'attachments':[],'pending_connections':[t for t in plan.get('pending_connections',[]) if any(t[side]['room'][0]==code for side in 'ab')],'transitions':[t for t in plan['transitions'] if any(t[side]['room'][0]==code for side in 'ab')],'external_ports':[e for e in plan['external_ports'] if e['room'][0]==code],'title':next(r['name'] for r in plan['regions'] if r['code']==code)+' · 整区初稿'}
        for s in plan['seams']:
            if code not in [s['a'][0],s['b'][0]]:continue
            index=0 if s['a'][0]==code else 1;host=s['a'] if index==0 else s['b'];other=s['b'] if index==0 else s['a']
            sub['external_ports'].append(dict(id=s['id'],point=s['point'],direction=s['directions'][index],room=host,region_name=other))
        (out/f'{filename}.svg').write_text(drawing(sub))
    # Keep a compact, machine-readable validation/identity record with the delivery.
    (out/'manifest.json').write_text(json.dumps({'source':p['source'],'draft':p['metadata']['spatial_draft'],'checks':plan['checks'],'seams':plan['seams'],'regions':plan['regions'],'limits':plan['review_limits'],'pending_connections':plan.get('pending_connections',[])},ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(plan['checks']))
if __name__=='__main__':main()
