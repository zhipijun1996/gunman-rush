#!/usr/bin/env python3
"""Build the forest planning review from authored design + canonical identities.

Candidate footprints are deliberately not installed into construction/runtime.
No geometry dependency: reuse the game's orthogonal room-space compiler.
"""
import argparse, html, json, math
from pathlib import Path
from spatial import room_space
ROOT = Path(__file__).resolve().parents[2]

def rectangles(poly):
    xs=sorted({p[0] for p in poly}); ys=sorted({p[1] for p in poly}); result=[]
    for x,xx in zip(xs,xs[1:]):
        for y,yy in zip(ys,ys[1:]):
            px,py=(x+xx)/2,(y+yy)/2
            crossings=sum(1 for a,b in zip(poly,poly[1:]+poly[:1]) if a[0]==b[0] and a[0]>px and min(a[1],b[1])<=py<max(a[1],b[1]))
            if crossings%2:result.append([x,y,xx-x,yy-y])
    return result

def split_path(points,width=256):
    lengths=[math.dist(a,b) for a,b in zip(points,points[1:])];half=sum(lengths)/2
    candidates=[];offset=0
    for i,length in enumerate(lengths):
        margin=min(width/2+32,length/2)
        at=max(margin,min(length-margin,half-offset))
        candidates.append((abs(offset+at-half),i,at/length))
        offset+=length
    _,i,f=min(candidates)
    a,b=points[i:i+2];mid=[a[k]+(b[k]-a[k])*f for k in (0,1)]
    return points[:i+1]+[mid],[mid]+points[i+1:]

def passage(points,width):
    result=[];h=width/2
    for a,b in zip(points,points[1:]):
        if a==b:continue
        assert a[0]==b[0] or a[1]==b[1], 'Passages must be orthogonal'
        result.append([min(a[0],b[0]),a[1]-h,abs(a[0]-b[0]),width] if a[1]==b[1] else [a[0]-h,min(a[1],b[1]),width,abs(a[1]-b[1])])
    for p in points[1:-1]:result.append([p[0]-h,p[1]-h,width,width])
    return result

def overlap(a,b):
    return min(a[0]+a[2],b[0]+b[2])-max(a[0],b[0])>0.001 and min(a[1]+a[3],b[1]+b[3])-max(a[1],b[1])>0.001

def build(root=ROOT, preview=None):
    plan=json.loads((root/'game/world/regions/F/room_design.json').read_text()); world=json.loads((root/'config/world/world.json').read_text())
    identities={r['id']:r for r in world['rooms']}; connections={e['id']:e for e in world['connections']}
    rooms={r['room_id']:dict(r) for r in plan['rooms']}
    assert set(rooms)=={r for r in identities if r.startswith('F-')},'Forest room set changed'
    assert {e['id'] for e in plan['connections']}=={e['id'] for e in connections.values() if e['a'] in rooms and e['b'] in rooms},'Internal connection identity mismatch'
    expected={e['id'] for e in connections.values() if (e['a'] in rooms)!=(e['b'] in rooms)}
    assert {p['id'] for p in plan['external_ports']}==expected,'Cross-region interfaces changed'
    rects={rid:rectangles(r['outline']) for rid,r in rooms.items()}
    for c in plan['connections']:
        e=connections[c['id']];a,b=split_path(c['path'],c['width']);c.update(a=e['a'],b=e['b'],requires=e.get('requires',[[]]),seam=a[-1])
        rects[e['a']]+=passage(a,c['width']);rects[e['b']]+=passage(b,c['width'])
    for rid,r in rooms.items():
        own=rects[rid];x=min(a[0] for a in own);y=min(a[1] for a in own);xx=max(a[0]+a[2] for a in own);yy=max(a[1]+a[3] for a in own)
        try:shape=room_space([[a-x,b-y,c,d] for a,b,c,d in own],[xx-x,yy-y])
        except ValueError as error:raise ValueError(f'{rid}: {error}') from error
        r['outline']=[[a+x,b+y] for a,b in shape['outline']];r['bounds']=[x,y,xx-x,yy-y]
        source=identities[rid];r.update(name=source['name'],rewards=source['reward_ids'],rest=source['rest_point'],rift=source.get('rift_machine',False),neighbors=[])
        for e in connections.values():
            if rid in [e['a'],e['b']]:r['neighbors'].append({'id':e['id'],'room':e['b'] if e['a']==rid else e['a'],'condition':e.get('condition_text','基础通行')})
    keys=list(rooms)
    for i,a in enumerate(keys):
        for b in keys[i+1:]:
            assert not any(overlap(s,t) for s in rects[a] for t in rects[b]),f'Overlapping room/passage {a} {b}'
    if preview is None:
        preview_path=root/'build/preview/preview-world.json'
        if not preview_path.exists():raise ValueError('Run python tools/export_runtime.py --plan-only before reviewing the world seam')
        preview=json.loads(preview_path.read_text())
    plains={m['id']:m for m in preview['map_rooms'] if m['id'].startswith('P-')}
    source=plains[plan['anchor']['source_room']];local=plan['anchor']['source_door_local']
    assert plan['anchor']['world_point']==[source['origin'][i]+local[i] for i in (0,1)],'C01 world anchor drift'
    for rid,own in rects.items():
        for pid,m in plains.items():
            assert not any(overlap(a,b) for a in own for b in rectangles(m['polygon'])),f'Forest overlaps existing plains: {rid} {pid}'
    for route in plan['routes']:
        route['rooms']=[f'F-R{n:02}' for n in route['rooms']]
        for a,b in zip(route['rooms'],route['rooms'][1:]):assert any({e['a'],e['b']}=={a,b} for e in connections.values()),f'Invalid route {a} {b}'
    for port in plan['external_ports']:
        e=connections[port['id']];target=e['b'] if e['a']==port['room'] else e['a'];port['target']=target;port['target_name']=identities[target]['name'];port['region_name']=next(r['name'] for r in world['regions'] if r['code']==target[0])
    plan['rooms']=list(rooms.values());return plan

def marker(r):
    ids=r['rewards'];m=[]
    if r['rest']:m.append('休')
    if r['rift']:m.append('裂缝')
    for x in ids:m.append(('生命碎片 ' if x.startswith('HP') else '铜齿 ' if x.startswith('TG') else '装备 ' if x.startswith('EQ') else '散华部件 ')+x)
    if r['room_id']=='F-R08':m.append('BOSS · 手里剑')
    if r['room_id']=='F-R10':m.append('能力 W')
    if r['room_id']=='F-R11':m.append('BOSS · 修钟')
    return ' · '.join(m)

def svg(plan):
    rooms=plan['rooms'];points=[p for r in rooms for p in r['outline']];x=min(p[0] for p in points)-480;y=min(p[1] for p in points)-480;w=max(p[0] for p in points)-x+480;h=max(p[1] for p in points)-y+480
    colors={'edge':'#273e38','crown':'#405547','root':'#203c3b','queen':'#344152','ranger':'#483b3b'}
    out=[f'<svg id="map" xmlns="http://www.w3.org/2000/svg" viewBox="{x} {y} {w} {h}" role="img" aria-label="荆棘森林24房候选空间总图"><style>text{{font-family:"Noto Sans CJK SC",sans-serif}}.room{{cursor:pointer}}.room:focus{{outline:none}}.room path{{transition:fill .15s}}.room.selected path,.room:focus path{{fill:#5b6951;stroke:#f2d28c;stroke-width:12}}.route{{pointer-events:none}}.room.dim{{opacity:.28}}</style><rect x="{x}" y="{y}" width="{w}" height="{h}" fill="#111e20"/>']
    for r in rooms:
        pts=r['outline'];d='M'+'L'.join(f'{a},{b}' for a,b in pts)+'Z';rid=r['room_id'];cx,cy=r['label'];m=marker(r);r['marker']=m
        out.append(f'<g class="room" data-room="{rid}" tabindex="0" role="button" aria-label="{rid} {html.escape(r["name"])}"><title>{rid} {html.escape(r["purpose"])}</title><path d="{d}" fill="{colors[r["zone"]]}" stroke="#8caa95" stroke-width="7"/><text x="{cx}" y="{cy-56}" text-anchor="middle" fill="#f2e5bd" font-size="53" font-weight="600">{rid[2:]} {html.escape(r["name"])}</text><text x="{cx}" y="{cy+8}" text-anchor="middle" fill="#cedbd3" font-size="37">{html.escape(r["purpose"])}</text><text x="{cx}" y="{cy+66}" text-anchor="middle" fill="#f1c982" font-size="35">{html.escape(m)}</text></g>')
    for c in plan['connections']:
        a,b=split_path(c['path'],c['width']);mid=a[-1];out.append(f'<circle cx="{mid[0]}" cy="{mid[1]}" r="19" fill="#c3cdb9" opacity=".8"><title>{c["id"]}: {c["a"]} ↔ {c["b"]}</title></circle>')
    lookup={r['room_id']:r for r in rooms}
    for rt in plan['routes']:
        for a,b in zip(rt['rooms'],rt['rooms'][1:]):
            c=next(e for e in plan['connections'] if {e['a'],e['b']}=={a,b});p=c['path'] if c['a']==a else list(reversed(c['path']));d='M'+'L'.join(f'{x},{y}' for x,y in p)
            out.append(f'<path class="route" data-route="{rt["id"]}" d="{d}" fill="none" stroke="{rt["color"]}" stroke-width="20" opacity=".95" style="display:none"/>')
        for n,rid in enumerate(rt['rooms']):
            cx,cy=lookup[rid]['label'];out.append(f'<text class="route" data-route="{rt["id"]}" x="{cx}" y="{cy-120}" text-anchor="middle" fill="{rt["color"]}" font-size="58" font-weight="700" style="display:none">{n+1}</text>')
    for p in plan['external_ports']:
        cx,cy=p['point'];dx,dy={'up':(0,-1),'down':(0,1),'left':(-1,0),'right':(1,0)}[p['direction']];ex,ey=cx+dx*220,cy+dy*220
        out.append(f'<path d="M{cx},{cy}L{ex},{ey}" stroke="#e4c782" stroke-width="14"/><circle cx="{cx}" cy="{cy}" r="25" fill="#e4c782"/><text x="{ex+dx*70}" y="{ey+dy*70}" text-anchor="{ "end" if dx<0 else "start" if dx>0 else "middle"}" fill="#e4c782" font-size="40">{p["id"]} → {p["region_name"]}</text>')
    out.append('</svg>');return ''.join(out)

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--output',type=Path,default=ROOT/'build/forest-review');args=ap.parse_args();p=build();drawing=svg(p);args.output.mkdir(parents=True,exist_ok=True)
    (args.output/'forest.svg').write_text(drawing);(args.output/'forest.json').write_text(json.dumps(p,ensure_ascii=False,indent=2)+'\n')
    template=(ROOT/'tools/world/forest_review.html').read_text();(args.output/'index.html').write_text(template.replace('<!-- MAP -->',drawing).replace('/* PLAN */',json.dumps(p,ensure_ascii=False).replace('</','<\\/')))
    print(f'Forest review: {len(p["rooms"])} rooms, {len(p["connections"])} internal seams, {len(p["external_ports"])} external ports; identity/routes/non-overlap and P04 world seam passed')
if __name__=='__main__':main()
