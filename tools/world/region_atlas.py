#!/usr/bin/env python3
"""Region-first spatial budget and touch review; deliberately contains no rooms."""
import html,json,hashlib,subprocess
from pathlib import Path
from collections import defaultdict,deque
from forest_review import rectangles,overlap
ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'config/world/region_atlas.json'

def boundary(poly,p):
    return any(a[0]==b[0]==p[0] and min(a[1],b[1])<=p[1]<=max(a[1],b[1]) or a[1]==b[1]==p[1] and min(a[0],b[0])<=p[0]<=max(a[0],b[0]) for a,b in zip(poly,poly[1:]+poly[:1]))

def validate(data):
    regions={r['id']:r for r in data['regions']};assert len(regions)==len(data['regions'])==16
    assert set(regions)==set('PFMSTYICKGNREAVZ')
    cells={rid:rectangles(r['outline']) for rid,r in regions.items()}
    areas={rid:sum(w*h for x,y,w,h in rs) for rid,rs in cells.items()}
    for rid,r in regions.items():
        poly=r['outline'];assert len({tuple(p) for p in poly})==len(poly),rid
        assert all(a!=b and (a[0]==b[0] or a[1]==b[1]) for a,b in zip(poly,poly[1:]+poly[:1])),rid
        area=abs(sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(poly,poly[1:]+poly[:1])))/2
        assert area==areas[rid],f'Invalid polygon {rid}'
        assert any(x<r['label'][0]<x+w and y<r['label'][1]<y+h for x,y,w,h in cells[rid]),rid
        for other in regions:
            if other<=rid:continue
            assert not any(overlap(a,b) for a in cells[rid] for b in cells[other]),f'Overlap {rid}/{other}'
    assert areas['G']==max(areas.values()),'City must have largest planned area'
    edges={e['id']:e for e in data['interfaces']};assert len(edges)==len(data['interfaces'])
    graph=defaultdict(set)
    for e in edges.values():
        assert e['a']!=e['b']
        for side in ('a','b'):assert boundary(regions[e[side]]['outline'],e['point']),e['id']
        x,y=e['point'];delta=1
        inside=lambda rid,dx,dy:any(a<=x+dx<a+w and b<=y+dy<b+h for a,b,w,h in cells[rid])
        assert any(all(inside(e['a'],dx+t*dy,dy+t*dx) and inside(e['b'],-dx+t*dy,-dy+t*dx) for t in (-1,1)) for dx,dy in [(delta,0),(-delta,0),(0,delta),(0,-delta)]),f'Corner-only port {e["id"]}'
        graph[e['a']].add(e['b']);graph[e['b']].add(e['a'])
    seen={'P'};queue=deque(seen)
    while queue:
        for nxt in graph[queue.popleft()]-seen:seen.add(nxt);queue.append(nxt)
    assert seen==set(regions),'Disconnected region'
    for route in data['routes']:
        assert set(route['interfaces'])<=set(edges)
        assert all(b in graph[a] for a,b in zip(route['regions'],route['regions'][1:])),route['id']
    return {'regions':16,'interfaces':len(edges),'overlaps':0,'city_neighbors':sorted(graph['G']),'mine_neighbors':sorted(graph['N']),'area_ratio_city_to_plains':round(areas['G']/areas['P'],2),'scope':'宏观空间与邻接；不验证房间路径、能力可达或玩法'}

def drawing(data,ports=True):
    s=data['display_scale'];out=['<svg xmlns="http://www.w3.org/2000/svg" id="atlas" viewBox="40 0 2040 1510" role="img" aria-label="失序之钟世界区域图"><style>text{font-family:\'Noto Sans CJK SC\',sans-serif}.region{cursor:pointer}.region path{stroke:#b6c3bd;stroke-width:2}.region.selected path{stroke:#ffe1a0;stroke-width:5}.dim{opacity:.22}.port{cursor:pointer}.port text{pointer-events:none}.region text{pointer-events:none}</style><rect x="40" y="0" width="2040" height="1510" fill="#111b21"/>']
    for r in data['regions']:
        path='M'+'L'.join(f'{x/s},{y/s}' for x,y in r['outline'])+'Z';x,y=[v/s for v in r['label']]
        role_lines = r['role'].split('与') if r['id']=='S' else [r['role']]
        landmark_lines = ['初访调查·核心安装', '最终战场'] if r['id']=='Z' else [r['landmark']]
        subtitle_size = 14 if r['id']=='Z' else 17
        out.append(f'<g class="region" data-region="{r["id"]}" tabindex="0" role="button" aria-label="{r["name"]}"><title>{html.escape(r["purpose"])}</title><path d="{path}" fill="{r["color"]}"/><text x="{x}" y="{y-17}" text-anchor="middle" font-size="{34 if r["id"] in "GN" else 25}" fill="#fff1d5">{r["name"]}</text>')
        for i,line in enumerate(role_lines):
            out.append(f'<text x="{x}" y="{y+16+i*22}" text-anchor="middle" font-size="{subtitle_size}" fill="#e5e5d8">{html.escape(line)}</text>')
        for i,line in enumerate(landmark_lines):
            out.append(f'<text x="{x}" y="{y+44+(len(role_lines)-1)*22+i*21}" text-anchor="middle" font-size="14" fill="#e8d4a6">{html.escape(line)}</text>')
        out.append('</g>')
    out.append('<text x="935" y="900" text-anchor="middle" fill="#e7dfc6" font-size="19">浅矿／转运</text><text x="935" y="927" text-anchor="middle" fill="#cdc7ad" font-size="14">下接主矿层</text>')
    if ports:
        for e in data['interfaces']:
            x,y=[v/s for v in e['point']];out.append(f'<g class="port" data-port="{e["id"]}" tabindex="0" role="button" aria-label="{e["id"]} {e["name"]}"><title>{html.escape(e["name"]+"："+e["purpose"])}</title><circle cx="{x}" cy="{y}" r="16" fill="#15232a" stroke="#f4d09a" stroke-width="2"/><text x="{x}" y="{y+4}" text-anchor="middle" font-size="11" fill="#ffe2ac">{e["id"]}</text></g>')
    out.append('<text x="130" y="1475" fill="#b6c6c8" font-size="17">区域占地初稿 · 无房间划分 · 编号表示计划接口；共用边界不代表处处互通 · W墙面 / H钩索 / D二跳 / Q反冲保护</text></svg>')
    return ''.join(out)

def page(data,svg):
    template=(ROOT/'tools/world/region_atlas.html').read_text()
    return template.replace('<!-- ATLAS -->',svg).replace('/* DATA */',json.dumps(data,ensure_ascii=False).replace('</','<\\/'))

def main():
    data=json.loads(SOURCE.read_text());checks=validate(data);out=ROOT/'build/region-atlas';out.mkdir(parents=True,exist_ok=True)
    (out/'world-regions.svg').write_text(drawing(data));(out/'world-regions-outline.svg').write_text(drawing(data,False));(out/'world-regions.html').write_text(page(data,drawing(data)))
    (out/'region-atlas.json').write_text(SOURCE.read_text())
    (out/'manifest.json').write_text(json.dumps({'source':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'checks':checks,'scope':data['scope']},ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(checks,ensure_ascii=False))
if __name__=='__main__':main()
