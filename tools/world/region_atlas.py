#!/usr/bin/env python3
"""Region-first spatial budget and touch review; deliberately contains no rooms."""
import html,json,hashlib,subprocess
from pathlib import Path
from collections import defaultdict,deque
from atlas_geometry import boundary, inside, overlap, signed_area, valid_polygon, shared_port, segment_inside
ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'config/world/region_atlas.json'


def validate(data):
    regions={r['id']:r for r in data['regions']}
    assert len(regions)==len(data['regions'])==16
    assert set(regions)==set('PFMSTYICKGNREAVZ')
    areas={rid:abs(signed_area(r['outline'])) for rid,r in regions.items()}
    for rid,r in regions.items():
        assert valid_polygon(r['outline']),f'Invalid polygon {rid}'
        assert inside(r['outline'],r['label']),f'Label outside {rid}'
        for other in regions:
            if other<=rid:continue
            assert not overlap(r['outline'],regions[other]['outline']),f'Overlap {rid}/{other}'
    assert areas['N']<min(areas[r] for r in regions if r!='N'),'Mine is a small junction'
    assert areas['G']==max(areas.values()),'City needs the largest exploration budget'
    graph=defaultdict(set)
    links={e['id']:e for e in data['interfaces']}
    assert len(links)==len(data['interfaces'])
    for e in links.values():
        assert e['a']!=e['b']
        a,b=regions[e['a']]['outline'],regions[e['b']]['outline']
        assert boundary(a,e['point']) and boundary(b,e['point']),e['id']
        assert shared_port(a,b,e['point']),f'Corner-only port {e["id"]}'
        graph[e['a']].add(e['b']);graph[e['b']].add(e['a'])
    for rid,r in regions.items():
        nodes={n['id']:n for n in r['districts']}
        assert len(nodes)==len(r['districts']),f'Duplicate district {rid}'
        local=defaultdict(set)
        for n in nodes.values():
            assert inside(r['outline'],n['position']),f'District outside {n["id"]}'
        for link in r['spines']:
            a,b=link['a'],link['b'];points=link['path']
            assert points[0]==nodes[a]['position'] and points[-1]==nodes[b]['position'],f'Spine anchor {rid}'
            assert all(segment_inside(r['outline'],x,y) for x,y in zip(points,points[1:])),f'Spine outside {rid}'
            local[a].add(b);local[b].add(a)
        reached={next(iter(nodes))};todo=list(reached)
        while todo:
            for node in local[todo.pop()]-reached:reached.add(node);todo.append(node)
        assert reached==set(nodes),f'Disconnected district {rid}'
    for e in links.values():
        for side in ('a','b'):
            r=regions[e[side]];nodes={n['id']:n for n in r['districts']};points=e['approaches'][side]
            assert points[0]==nodes[e['districts'][side]]['position'] and points[-1]==e['point'],f'Approach anchor {e["id"]}'
            assert all(segment_inside(r['outline'],x,y) for x,y in zip(points,points[1:])),f'Approach outside {e["id"]}'
    seen={'P'};queue=deque(seen)
    while queue:
        for nxt in graph[queue.popleft()]-seen:seen.add(nxt);queue.append(nxt)
    assert seen==set(regions),'Disconnected region'
    for route in data['routes']:
        assert set(route['interfaces'])<=set(links)
        assert all(b in graph[a] for a,b in zip(route['regions'],route['regions'][1:])),route['id']
    return {'regions':16,'interfaces':len(links),'overlaps':0,'districts':sum(len(r['districts']) for r in regions.values()),
            'city_neighbors':sorted(graph['G']),'mine_neighbors':sorted(graph['N']),
            'area_ratio_city_to_plains':round(areas['G']/areas['P'],2),
            'area_ratio_mine_to_city':round(areas['N']/areas['G'],2),
            'scope':'仅校验区域几何与邻接，不证明美感、房间通路或玩法成立'}


def region_bounds(region):
    xs,ys=zip(*region['outline'])
    return [min(xs),min(ys),max(xs)-min(xs),max(ys)-min(ys)]


def drawing(data,ports=True):
    scale=data['display_scale'];box=data['view_box']
    out=[f'<svg xmlns="http://www.w3.org/2000/svg" id="atlas" viewBox="{" ".join(map(str,box))}" role="img" aria-label="世界空间草图">',
      '<style>text{font-family:"Noto Sans CJK SC",sans-serif}.region{cursor:pointer}.region.selected .land{stroke:#ffe1a0;stroke-width:3}.dim{opacity:.16}.port{cursor:pointer}.port text,.region text,.spine,.approach,.node{pointer-events:none}.land{stroke-width:1.7;stroke-linejoin:round}.district-name{font-size:12px;fill:#bac7c4;paint-order:stroke;stroke:#101b21;stroke-width:3;stroke-linejoin:round}.hide-spines .development{display:none}</style>',
      '<rect width="2048" height="1536" fill="#0d171d"/>']
    # The same grid is used for all regions; an axis step is a planning budget.
    for x in range(0,2049,32):
        major=x%128==0;out.append(f'<path d="M{x} 0V1536" stroke="#6d8790" stroke-opacity="{.16 if major else .055}" stroke-width="1"/>')
    for y in range(0,1537,32):
        major=y%128==0;out.append(f'<path d="M0 {y}H2048" stroke="#6d8790" stroke-opacity="{.16 if major else .055}" stroke-width="1"/>')
    def path(points):return 'M'+'L'.join(f'{x/scale:g},{y/scale:g}' for x,y in points)
    for r in data['regions']:
        rid=r['id'];fill,stroke=r['color'],r['border_color']
        out.append(f'<g class="region" data-region="{rid}" tabindex="0" role="button" aria-label="{r["name"]}"><title>{html.escape(r["purpose"])}</title><path class="land" d="{path(r["outline"])}Z" fill="{fill}" fill-opacity=".78" stroke="{stroke}"/>')
        if ports:
            out.append('<g class="development">')
            for e in data['interfaces']:
                for side in ('a','b'):
                    if e[side]==rid:out.append(f'<path class="approach" d="{path(e["approaches"][side])}" fill="none" stroke="{stroke}" stroke-opacity=".6" stroke-width="1.2" stroke-dasharray="3 4"/>')
            for link in r['spines']:
                dash=' stroke-dasharray="6 4"' if link['gate'] else ''
                out.append(f'<path class="spine" d="{path(link["path"])}" fill="none" stroke="#b4c1b5" stroke-opacity=".48" stroke-width="1.7"{dash}/>')
            for n in r['districts']:
                nx,ny=[v/scale for v in n['position']]
                out.append(f'<circle class="node" cx="{nx:g}" cy="{ny:g}" r="5" fill="#17272b" stroke="#ddc69a" stroke-width="1.4"/><text class="district-name" x="{nx:g}" y="{ny+19:g}" text-anchor="middle">{html.escape(n["name"])}</text>')
            out.append('</g>')
        x,y=[v/scale for v in r['title_position']];size=23 if rid not in 'ZN' else 18
        out.append(f'<text x="{x}" y="{y}" text-anchor="middle" font-size="{size}" fill="#eae1c8" style="paint-order:stroke;stroke:#101b21;stroke-width:4;stroke-linejoin:round">{rid} · {r["name"]}</text></g>')
    if ports:
        for e in data['interfaces']:
            x,y=[v/scale for v in e['point']]
            out.append(f'<g class="port" data-port="{e["id"]}" tabindex="0" role="button" aria-label="{e["id"]} {e["name"]}"><title>{html.escape(e["name"]+"："+e["purpose"])}</title><circle cx="{x:g}" cy="{y:g}" r="8" fill="#101c22" stroke="#c9b181" stroke-width="1.2"/><text x="{x:g}" y="{y+2.6:g}" text-anchor="middle" font-size="7" fill="#eed7a7">{e["id"][1:]}</text></g>')
    out.append('</svg>')
    return ''.join(out)


def coordinate_sheet(data):
    grid=data['coordinate_system']['planning_grid_world_units'];w,h=3000,1920
    out=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}"><style>text{{font-family:"Noto Sans CJK SC",sans-serif}}</style><rect width="{w}" height="{h}" fill="#0b141a"/>',
      '<text x="85" y="85" font-size="43" fill="#e9e2cc">失序之钟 / 世界空间草图</text><text x="87" y="128" font-size="21" fill="#a8bab6">统一坐标与区域占地预算 · 16区域 · 少量功能分区与穿行意图 · 尚未划分房间</text>',
      '<path d="M85 158H2910" stroke="#34484f"/>']
    inner=drawing(data).replace('id="atlas"','id="sheet-map"',1).replace('viewBox="0 0 2048 1536"','x="110" y="230" width="2048" height="1536" viewBox="0 0 2048 1536"',1)
    out.append(inner)
    for x in range(0,65,4):out.append(f'<text x="{110+x*32}" y="211" text-anchor="middle" font-size="16" fill="#96aaa9">{x}</text>')
    for y in range(0,49,4):out.append(f'<text x="90" y="{236+y*32}" text-anchor="end" font-size="16" fill="#96aaa9">{y}</text>')
    out.append('<text x="2140" y="190" font-size="15" fill="#b9c7c2">X →</text><text x="42" y="260" font-size="15" fill="#b9c7c2">Y ↓</text><text x="110" y="1810" font-size="18" fill="#b9c7c2">格坐标：左上为 (0,0)　细线 1 格 / 主线 4 格　｜　1 格暂按 1024 世界单位 = 32 个地形格</text>')
    out.append('<g transform="translate(2250 235)"><text x="0" y="0" font-size="28" fill="#eadbb8">区域位置与尺寸</text><text x="0" y="34" font-size="17" fill="#9eb3b0">位置为占地外接框左上角；宽高不是面积。</text><text x="0" y="77" font-size="17" fill="#c5d1c7">区域</text><text x="305" y="77" font-size="17" fill="#c5d1c7">X, Y（格）</text><text x="500" y="77" font-size="17" fill="#c5d1c7">宽 × 高（格）</text>')
    order='PFCIYZKGVANSMTRE';lookup={r['id']:r for r in data['regions']}
    for i,rid in enumerate(order):
        r=lookup[rid];x,y,rw,rh=[v/grid for v in region_bounds(r)];yy=118+i*43
        out.append(f'<path d="M0 {yy+14}H650" stroke="#273b41"/><circle cx="9" cy="{yy-6}" r="5" fill="{r["border_color"]}"/><text x="26" y="{yy}" font-size="19" fill="#e0e1d2">{rid} · {r["name"]}</text><text x="305" y="{yy}" font-size="19" fill="#b4c9c6">{x:g}, {y:g}</text><text x="500" y="{yy}" font-size="19" fill="#e4d0a4">{rw:g} × {rh:g}</text>')
    out.append('<text x="0" y="875" font-size="24" fill="#eadbb8">怎样读这张图</text>')
    notes=['浅色占地：区域的空间预算，不是实心地形。','圆点及名称：功能分区，不是单个房间。','细线：内部通行意图；不代表实际长走廊。','编号口：两区接续位置，落在共同边界。','空白：为岩层、空域与空间间隔保留。','坐标换算：图上 (x,y) ×1024 → 世界坐标。']
    for i,line in enumerate(notes):out.append(f'<text x="0" y="{918+i*35}" font-size="18" fill="#aebfba">{line}</text>')
    out.append('<text x="0" y="1180" font-size="24" fill="#eadbb8">本轮审核重点</text>')
    notes=['工城：多层街区，从不同方向分阶段进入。','矿井：小型换层井簇，重在回城与分流。','冰川：登高层、低廊和侵蚀下缘有高差。','成长：牧风者 W → 森林 H / 地穴 D → 古堡 Q。','阶段门槛后续落实在房内地形，不加空口锁。']
    for i,line in enumerate(notes):out.append(f'<text x="0" y="{1223+i*35}" font-size="18" fill="#aebfba">{line}</text>')
    out.append('</g><path d="M85 1850H2910" stroke="#34484f"/><text x="87" y="1885" font-size="18" fill="#c8b78e">待审核草图：尺寸尚未按动作尺度与房间数量校准；保留内部留白，后续可调整边界。未改动正式游戏。</text></svg>')
    return ''.join(out)


def page(data,svg):
    template=(ROOT/'tools/world/region_atlas.html').read_text()
    return template.replace('<!-- ATLAS -->',svg).replace('/* DATA */',json.dumps(data,ensure_ascii=False).replace('</','<\\/'))

def main():
    data=json.loads(SOURCE.read_text());checks=validate(data);out=ROOT/'build/region-atlas';out.mkdir(parents=True,exist_ok=True)
    (out/'world-space-sketch.svg').write_text(coordinate_sheet(data));(out/'world-regions.svg').write_text(drawing(data));(out/'world-regions-outline.svg').write_text(drawing(data,False));(out/'world-regions.html').write_text(page(data,drawing(data)))
    (out/'region-atlas.json').write_text(SOURCE.read_text())
    (out/'manifest.json').write_text(json.dumps({'source':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'checks':checks,'scope':data['scope']},ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(checks,ensure_ascii=False))
if __name__=='__main__':main()
