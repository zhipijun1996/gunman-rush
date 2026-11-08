"""Build the current plains spatial REVIEW proposal; never writes runtime inputs.

Requires Shapely 2.1.2 for draft polygon/route checks. World identities, rewards,
rests, bosses and current door graph are read from config/world. The constants
below are the single spatial review design, not a second runtime world source.
After approval, migrate adopted geometry to construction/scenes and retire them.
"""
from pathlib import Path
import argparse, hashlib, heapq, html, json, math
from shapely.geometry import Polygon, LineString, Point, box
from shapely.ops import unary_union, nearest_points
from plains_layout import build_layout, ANCHORS

ROOT = Path(__file__).resolve().parents[2]
PROPOSAL = 'plains-map-review-04'
# The user approved A/B/C; coordinated runtime geometry migration follows contour review.
CHANGES = [
 dict(id='A', status='approved', remove='HUB-P31-P08', title='收敛小站旁三角回路',
      before='01—08、01—31、31—08构成很短的重复环。',
      after='取消31—08，保留小站东门01→08；铃场专注桥面与集市分流。',
      tradeoff='减少重复出口；08回站须经过01，失去一条很短的旁路。'),
 dict(id='B', status='approved', remove='HUB-P35-P12', title='让地窖成为真正的支路',
      before='汇口35可直达12，也可经18或19进入12，分支目的接近。',
      after='取消35—12；地窖仍由18与19接入，保留下层水路回环。',
      tradeoff='汇口少一个出口；地窖需要多走一房，奖励入口更有铺垫。'),
 dict(id='C', status='approved', remove='APPROACH-P05-P14', add=['P-R27','P-R14'], title='休息后直接接首Boss',
      before='背风棚27→慢风平台05→牧风者14，重试需穿过收集房。',
      after='改为27→14；27→05保留作TG02挑战支路，05→06开桥回环保留。',
      tradeoff='Boss重试少过一房；TG02须在27出口预告，并校准05墓园接口与14封场。'),
]
# One-line diagram captions. Full, current responsibilities remain room_design.json.
CAPTIONS = {
1:'整备辨路，进井再西行',2:'东部整备，分流风车与旧田',3:'走跳初练，控制两种落点',4:'断田反冲，桥下寻找铜齿',5:'移动落点挑战，取得铜齿',6:'循铃西行，分辨回环捷径',7:'登高辨路，掩体间接近',8:'乘笼升井，登西侧高地',9:'矿口地标，预览外区通路',10:'钩索穿风车，寻找暗栈',11:'可选Boss，取得三联机芯',12:'空中射铃，领奖后开折板',13:'石崖折返，挑战生命片',14:'首Boss与钩索首次试用',15:'钩索抵台，修钟开升降机',16:'Boss前休息，观察机匣',17:'藏栈取装备，放梯返回',18:'旧田战斗，分流崖道与井',19:'根井通行，预览双能力齿轮',20:'曲折渠岸，钩索回访行装',21:'掩体试枪，遇敌后撤换位',22:'反冲初练→变式→综合实践',23:'遇见阿栖，安静叙事停顿',24:'看见站灯，缓坡引向小站',25:'上下树台，越敌或地面战',26:'双吊台换乘与反冲接续',27:'Boss前整备，侧看铜齿支路',28:'地面遭遇，反冲登谷仓',29:'错层穿梁，换射线与落点',30:'低檐水洞，钩索取铜齿',31:'三向大庭，观路再选出口',32:'初见索环，得钩索再探桥',33:'钟心地标，舒缓与回望',34:'屋顶货运与摊间低路',35:'东行枢纽，田路与井道分流'}
ZONES = {
 'start':dict(name='初风草坡',rooms=[3,21,22,23,24],fill='#2c4034',edge='#a9c1a3'),
 'west':dict(name='牧风高地',rooms=[4,5,6,8,13,14,15,25,26,27],fill='#423e30',edge='#c8bb92'),
 'town':dict(name='钟庭旧街',rooms=[1,31,32,33,34,35],fill='#34434b',edge='#a8c5ce'),
 'water':dict(name='根井水路',rooms=[12,19,20],fill='#254149',edge='#8abec4'),
 'east':dict(name='东田与风车',rooms=[2,7,9,10,11,16,17,18,28,29,30],fill='#343f35',edge='#b5c4a8')}
WIDTH,HEIGHT=4500,2500
LABEL_ANCHORS={}
def read(p):return json.loads((ROOT/p).read_text())
def rid(n):return f'P-R{n:02}'
def esc(s):return html.escape(str(s),quote=True)
def zone(n):return next(z for z in ZONES.values() if n in z['rooms'])
def path_poly(poly):
    if poly.is_empty:return ''
    if poly.geom_type in ('MultiPolygon','GeometryCollection'):return ' '.join(path_poly(g) for g in poly.geoms if g.geom_type in ('Polygon','MultiPolygon'))
    return ' '.join('M '+' L '.join(f'{x:.2f} {y:.2f}' for x,y in ring.coords)+' Z' for ring in [poly.exterior,*poly.interiors])
def path_line(ps):return 'M '+' L '.join(f'{x:.2f} {y:.2f}' for x,y in ps)

def sources():
    world=read('config/world/world.json')
    rooms={r['id']:r for r in world['rooms'] if r['region']=='P'}
    edges=[dict(e) for e in world['connections'] if e['a'] in rooms and e['b'] in rooms and e['id'] not in {c['remove'] for c in CHANGES}]
    edges.append(dict(id='APPROACH-P27-P14',a=rid(27),b=rid(14),requires=[[]],a_section='main',b_section='main'))
    return world,rooms,edges

def inside_path(poly,start,end):
    """Visibility path through this draft footprint, not a playable motor proof."""
    if Point(start).distance(poly)>1:start=nearest_points(poly,Point(start))[0].coords[0]
    if Point(end).distance(poly)>1:end=nearest_points(poly,Point(end))[0].coords[0]
    pts=[start,end,*list(poly.exterior.coords)[:-1],*[p for ring in poly.interiors for p in list(ring.coords)[:-1]]]
    expanded=poly.buffer(.1)
    adj={i:[] for i in range(len(pts))}
    for i,a in enumerate(pts):
        for j in range(i):
            b=pts[j]
            if expanded.covers(LineString([a,b])):
                d=math.dist(a,b);adj[i].append((j,d));adj[j].append((i,d))
    q=[(0,0,[])];seen=set()
    while q:
        cost,i,path=heapq.heappop(q)
        if i in seen:continue
        seen.add(i);path=path+[i]
        if i==1:return [pts[j] for j in path]
        for j,d in adj[i]:heapq.heappush(q,(cost+d,j,path))
    raise ValueError('Disconnected internal draft path')

ROUTES=[
 dict(id='main',name='① 首访主线 · 基础动作 / 反冲',color='#e4b36e',rooms=[3,21,22,23,24,1,8,6,13,4,25,26,27,14],note='先在22完成综合实践再进站；01东门进井，06转西。26双吊台必经，27直达Boss。'),
 dict(id='return',name='② 钩索与修钟归途',color='#79c9c5',rooms=[14,15,32,31,1],note='14领H → 15校时开S1 → 重见32铜环；31可回站、往东探桥，或下集入水路。'),
 dict(id='east',name='③ 钩索东行与可选Boss',color='#9cb7e2',rooms=[32,35,18,7,2,10,16,11],note='得H后试32高桥直达35；基础阶段仍可走31→34→35。02→10房内需H，16整备后挑战11。'),
 dict(id='water',name='④ 下层探索回环',color='#b2c994',rooms=[31,34,20,19,12,18,35,34,31],note='主通路可探索；20奖励需H、19铜齿需H+D；12为独立射铃挑战。'),
 dict(id='preview',name='⑤ 初期可选 · 看见未来的路',color='#d3a7d6',rooms=[1,31,32],note='初到站可选步入铃场，在32近桥头看见真实H断桥；下层路开放、预览可退，不代记探索。')]


def validate(rooms,edges,geometry,corridors):
    assert len(rooms)==35 and len(edges)==43
    seen={rid(3)}
    while True:
        newer=seen|{e['b'] for e in edges if e['a'] in seen}|{e['a'] for e in edges if e['b'] in seen}
        if newer==seen:break
        seen=newer
    assert seen==set(rooms)
    assert all(p.is_valid and p.geom_type=='Polygon' for p in geometry.values())
    errors=[]
    for i,(a,p) in enumerate(geometry.items()):
        for b,q in list(geometry.items())[:i]:
            if p.intersection(q).area>1:errors.append('Room overlap '+a+' '+b)
    for e in edges:
        poly=corridors[e['id']]
        assert all(poly.intersection(geometry[r]).area>0 for r in (e['a'],e['b'])),('Disconnected corridor',e['id'])
        for r,p in geometry.items():
            if r not in (e['a'],e['b']) and poly.intersection(p).area>1:errors.append('Corridor crosses unrelated room '+e['id']+' '+r)
    for i,e in enumerate(edges):
        for f in edges[:i]:
            shared={e['a'],e['b']}&{f['a'],f['b']}
            overlap=corridors[e['id']].intersection(corridors[f['id']])
            allowed=unary_union([geometry[r] for r in shared]) if shared else Polygon()
            if overlap.difference(allowed).area>1:errors.append('Unowned corridor crossing '+e['id']+' '+f['id'])
    for route in ROUTES:
        for a,b in zip(route['rooms'],route['rooms'][1:]):assert any({rid(a),rid(b)}=={e['a'],e['b']} for e in edges),(route['id'],a,b)
    assert not errors,errors
    mass=unary_union([*geometry.values(),*corridors.values()])
    assert mass.geom_type=='Polygon', 'The full region silhouette must be physically joined'
    source_edges={e['id']:e for e in read('config/world/world.json')['connections']}
    for e in edges:
        if e['id'] in source_edges:
            assert all(e.get(k)==source_edges[e['id']].get(k) for k in ['a','b','requires','a_section','b_section'])
    return dict(rooms=35,current_internal_connections=45,proposed_internal_connections=43,connected=True,room_overlaps=0,unrelated_corridor_crossings=0,route_sequences_checked=len(ROUTES),scope='Draft geometry and graph only; no runtime or motor acceptance.')


def room_info(w,rooms):
    designs={r['room_id']:r for r in read('game/world/regions/P/room_design.json')['rooms']}
    acqs=read('config/world/collection_design.json')['acquisition_contracts']
    bosses={b['room_id']:b for b in w['boss_plan']['bosses'] if b.get('region')=='P'}
    result={}
    for r,row in rooms.items():
        n=int(r[-2:]);acq=[a for a in acqs if isinstance(a,dict) and a.get('room_id')==r]
        result[r]=dict(id=r,name=row['name'],caption=CAPTIONS[n],current_purpose=designs[r]['purpose'],spatial_intent=designs[r].get('spatial_intent',''),learning_sequence=designs[r].get('learning_sequence',[]),rest=bool(row.get('rest_point')),npcs=row.get('npc_ids',[]),reward_ids=row.get('reward_ids',[]),collections=[dict(id=a['reward_id'],experience=a.get('primary_experience',''),section=a.get('section_id','main'),requires=a.get('canonical_requires',a.get('requires')),return_path=a.get('return_path','')) for a in acq],boss=bosses.get(r),clock=row.get('clock_actions',[]),zone=zone(n)['name'])
    assert sum(r['rest'] for r in result.values())==4
    assert sum(bool(r['boss']) for r in result.values())==2
    return result

BADGES={1:['休 · NPC · 服务×14'],2:['休'],4:['TG01 · 探索'],5:['TG02 · 挑战返程'],6:['试制任务件'],10:['房内H路线'],11:['B2 · 三联机芯'],12:['装备P01 · 挑战返程'],13:['HP01 · 挑战返程'],14:['B1 · 获得H'],15:['H · 修钟'],16:['休'],17:['装备P03 · 隐藏/H返程'],19:['TG04 · H+D返程'],20:['装备P02 · H返程'],23:['阿栖'],27:['休'],30:['TG03 · H返程'],32:['H预览 · 战后重见'],33:['世界钟方向']}

def fit_labels(rooms,geometry):
    layouts={}
    for r,row in rooms.items():
        n=int(r[-2:]);px,py=ANCHORS[n];poly=geometry[r]
        width=max(len(CAPTIONS[n])*11+10,len(row['name'])*16+28,150)
        width=max(width,max([len(s)*10+8 for s in BADGES.get(n,[])]+[0]))
        best=None
        for step in range(9):
            scale=1-step*.05
            for dx in range(-100,101,10):
                for dy in range(-90,91,10):
                    score=scale*200-math.hypot(dx,dy)
                    if best and score<=best[0]:continue
                    x,y=px+dx,py+dy
                    if poly.covers(box(x-width*scale/2,y-25*scale,x+width*scale/2,y+32*scale)):
                        best=(score,x,y,scale,width)
        assert best is not None,('Room label needs an authored chamber',r)
        _,x,y,scale,width=best
        LABEL_ANCHORS[n]=(x,y);layouts[n]=(x,y,scale,width)
    return layouts


def svg_map(rooms,edges,geometry,corridors,ends,paths,labels,outline=False):
    mass=unary_union([*geometry.values(),*corridors.values()])
    mode=' silhouette' if outline else ''
    out=[f'<svg xmlns="http://www.w3.org/2000/svg" id="region-map" class="atlas{mode}" viewBox="0 0 {WIDTH} {HEIGHT}" role="img" aria-label="风铃平原，连续地域与35房职责审核图">',
    '''<defs><style>
    text{font-family:'Noto Sans CJK SC','Microsoft YaHei',sans-serif;fill:#d6dfd8} .room{cursor:pointer}.room:focus{outline:none}.room .roomshape{stroke:transparent;stroke-width:2}.room:hover .roomshape,.room:focus .roomshape,.room.selected .roomshape{stroke:#e8c985;stroke-width:3;fill:#596158}.route,.room-label,.zone-label,.map-notes,.seams,.outer-shore{pointer-events:none}.route-muted{opacity:.10}.no-routes .route{display:none}.poi-off .poi{display:none}.labels-off .room-label{display:none}.change{display:none}.show-changes .change{display:inline}.silhouette .route,.silhouette .room-label,.silhouette .poi,.silhouette .zone-label,.silhouette .map-notes,.silhouette .change,.silhouette .legend,.silhouette .seams{display:none}.silhouette .room .roomshape{fill:#849b92}.silhouette .corridor-body{fill:#849b92}
    </style>''']
    for r in ROUTES:out.append(f'<marker id="arrow-{r["id"]}" markerWidth="5" markerHeight="5" refX="4" refY="2.5" orient="auto"><path d="M0 0L5 2.5L0 5" fill="{r["color"]}"/></marker>')
    out.append('</defs>')
    out.append(f'<rect width="{WIDTH}" height="{HEIGHT}" fill="#101b20"/>')
    out.append('<text x="160" y="83" font-size="18" letter-spacing="7" style="fill:#8eaaa5">GUNMAN RUSH  /  REGION P</text><text x="157" y="151" font-size="48" font-weight="600">风铃平原</text><text x="435" y="148" font-size="23" style="fill:#a8bcb5">地域轮廓与探索路线</text><text x="4340" y="101" text-anchor="end" font-size="22" style="fill:#cbb992">轮廓收敛 / 04</text><text x="4340" y="146" text-anchor="end" font-size="17" style="fill:#8eaaa5">35房 · 43条已确认连接 · 空间设计稿，尚未应用到游戏</text>')
    # The outside shore is drawn once around connected land, not around room cards.
    out.append(f'<path d="{path_poly(mass)}" fill="#34434b" fill-rule="evenodd"/>')
    out.append('<g id="corridor-bodies">')
    for e in edges:
        color=zone(int(e['a'][-2:]))['fill']
        out.append(f'<path class="corridor-body" d="{path_poly(corridors[e["id"]])}" fill="{color}"/>')
    out.append('</g>')
    for r,p in geometry.items():
        n=int(r[-2:]);z=zone(n)
        out.append(f'<g class="room" data-room="{r}" tabindex="0" role="button" aria-label="{r} {esc(rooms[r]["name"])} {esc(CAPTIONS[n])}"><title>{r} {esc(rooms[r]["name"])}</title><path class="roomshape" d="{path_poly(p)}" fill="{z["fill"]}"/></g>')
    out.append(f'<path class="outer-shore" d="{path_poly(mass)}" fill="none" stroke="#a5b6ad" stroke-width="1.7" stroke-linejoin="round"/><path class="outer-shore" d="{path_poly(mass.buffer(-5))}" fill="none" stroke="#8a9e92" stroke-width=".55" opacity=".27"/>')
    # Retain shared solid walls outside the actual doorway width.
    openings=unary_union(list(corridors.values()))
    out.append('<g class="seams" fill="none" stroke="#a5b6ad" stroke-width="1.2">')
    items=list(geometry.items())
    for i,(ar,ap) in enumerate(items):
        for br,bp in items[:i]:
            wall=ap.boundary.intersection(bp.boundary).difference(openings)
            parts=list(wall.geoms) if hasattr(wall,'geoms') else [wall]
            for part in parts:
                if part.geom_type=='LineString' and not part.is_empty:out.append(f'<path d="{path_line(part.coords)}"/>')
    out.append('</g>')
    # Threshold ticks, not enclosing boxes, identify the real ownership transitions.
    out.append('<g class="seams" stroke="#a7b9b0" stroke-width="1.3" opacity=".7">')
    for e in edges:
        a,b=ends[e['id']];mid=((a[0]+b[0])/2,(a[1]+b[1])/2)
        dx,dy=b[0]-a[0],b[1]-a[1]
        if math.hypot(dx,dy)<1:
            ca=geometry[e['a']].centroid;cb=geometry[e['b']].centroid;dx,dy=cb.x-ca.x,cb.y-ca.y
        length=math.hypot(dx,dy);nx,ny=-dy/length*19,dx/length*19
        out.append(f'<path d="M{mid[0]-nx:.1f} {mid[1]-ny:.1f}L{mid[0]+nx:.1f} {mid[1]+ny:.1f}"/>')
    out.append('</g>')
    for name,sub,x,y in [('牧风高地','石崖 / 果园 / 双吊台',540,550),('初风草坡','学习之后，望见站灯',400,1750),('钟庭旧街','循钟归来，再选一条路',2430,830),('根井水路','窄颈之下，连通的旧水道',2160,2160),('东田与风车','田路向东，风车向上',3260,940)]:
        out.append(f'<g class="zone-label"><text x="{x}" y="{y}" font-size="31" letter-spacing="5" style="fill:#a1b2a5">{name}</text><text x="{x}" y="{y+34}" font-size="15" letter-spacing="2" style="fill:#667e76">{sub}</text></g>')
    for route in ROUTES:
        out.append(f'<g class="route" data-route="{route["id"]}">')
        for a,b in zip(route['rooms'],route['rooms'][1:]):
            ar,br=rid(a),rid(b);e=next(e for e in edges if {ar,br}=={e['a'],e['b']})
            ps=paths[e['id']]
            if e['a']!=ar:ps=ps[::-1]
            route_points=inside_path(geometry[ar],LABEL_ANCHORS[a],ps[0])+ps[1:]+inside_path(geometry[br],ps[-1],LABEL_ANCHORS[b])[1:]
            out.append(f'<path d="{path_line(route_points)}" fill="none" stroke="{route["color"]}" stroke-width="2" opacity=".62" stroke-linejoin="round" marker-end="url(#arrow-{route["id"]})"/>')
        out.append('</g>')
    for eid,label in [('room-link-144','S2 · 05侧放桥'),('L02','S3 · 胜利侧开闸'),('SC-P01','S1 · 修钟后开启')]:
        a,b=ends[eid];x,y=(a[0]+b[0])/2,(a[1]+b[1])/2
        out.append(f'<g class="poi"><circle cx="{x}" cy="{y}" r="7" fill="#101b20" stroke="#81bfb3" stroke-width="1.5"/><text x="{x+13}" y="{y-13}" font-size="12" paint-order="stroke" stroke="#101b20" stroke-width="3" style="fill:#95c4b8">{label}</text></g>')
    for letter,(x,y) in {'A':(1690,1320),'B':(2790,1640),'C':(1140,465)}.items():
        out.append(f'<g class="change"><circle cx="{x}" cy="{y}" r="16" fill="#794e67"/><text x="{x}" y="{y+5}" text-anchor="middle" font-size="17">{letter}</text></g>')
    # No opaque cards behind text; all labels fit inside their authored place.
    for r,row in rooms.items():
        n=int(r[-2:]);x,y,scale,width=labels[n];bg=zone(n)['fill']
        out.append(f'<g class="room-label" data-label="{r}" data-width="{width}" transform="translate({x} {y}) scale({scale:.3f})" paint-order="stroke" stroke="{bg}" stroke-width="3" stroke-linejoin="round"><text y="-9" text-anchor="middle" font-size="16" font-weight="500"><tspan font-size="11" style="fill:#9db3a7">{n:02} </tspan>{esc(row["name"])}</text><text y="9" text-anchor="middle" font-size="10.5" style="fill:#aebeb4">{CAPTIONS[n]}</text><g class="poi">')
        if n in BADGES:
            color='#d7b58b' if n in [11,14] else '#a7cbbf'
            out.append(f'<text y="28" text-anchor="middle" font-size="10" style="fill:{color}">{esc(" · ".join(BADGES[n]))}</text>')
        out.append('</g></g>')
    for label,p,q in [('森林',(160,1130),(65,1130)),('蘑菇 / 下水道',(340,1540),(225,1640)),('墓园接口',(1430,680),(1430,750)),('矿井侧开通',(4000,2110),(4120,2110)),('古堡 / 工城',(3050,1310),(3050,1210)),('世界钟心',(2620,1070),(2620,970))]:
        out.append(f'<g class="poi"><path d="{path_line([p,q])}" fill="none" stroke="#6c8a80" stroke-width="1.3" stroke-dasharray="4 5"/><text x="{q[0]}" y="{q[1]-13}" font-size="13" text-anchor="middle" style="fill:#809c8f">{label}</text></g>')
    # Stage cues are confined to empty landscape, never pasted over the landform.
    for title,detail,x,y in [('先学会，再独立实践','03走跳 → 21试枪 → 22三湾实践 → 23/24喘息抵站',1050,2070),('从熟悉的地方，走向新路','初期在32预览H；14取得H、15修钟后重回桥头',2300,650)]:
        out.append(f'<g class="map-notes"><text x="{x}" y="{y}" font-size="18" style="fill:#8da99b">{title}</text><text x="{x}" y="{y+27}" font-size="12" style="fill:#638276">{detail}</text></g>')
    out.append('<g class="legend"><path d="M160 2260H4340" stroke="#324950"/><text x="160" y="2305" font-size="20" style="fill:#a6bdb1">探索顺序</text>')
    for i,r in enumerate(ROUTES[:4]):
        x=160+(i%2)*2100;y=2350+(i//2)*65;seq=' → '.join(f'{n:02}' for n in r['rooms'])
        out.append(f'<circle cx="{x+5}" cy="{y-5}" r="4" fill="{r["color"]}"/><text x="{x+20}" y="{y}" font-size="16">{r["name"]}</text><text x="{x+20}" y="{y+24}" font-size="12" style="fill:#7f9b8d">{seq}</text>')
    out.append('<text x="4340" y="2480" text-anchor="end" font-size="13" style="fill:#789387">H 钩索 · D 二段跳 · 返程 领奖侧返回 · 外区虚线仅示方向 · 绘图单位不是碰撞参数</text></g></svg>')
    return '\n'.join(out)


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--out',type=Path,default=ROOT/'build/plains-map-review');args=parser.parse_args();args.out.mkdir(parents=True,exist_ok=True)
    w,rooms,edges=sources();geometry,corridors,ends,paths=build_layout(edges)
    checks=validate(rooms,edges,geometry,corridors);labels=fit_labels(rooms,geometry);info=room_info(w,rooms)
    checks.update(connected_silhouette=True,room_labels_inside=35,geometry_source='Authored regional landforms; no clipping to runtime bounding boxes')
    svg=svg_map(rooms,edges,geometry,corridors,ends,paths,labels)
    data=dict(id=PROPOSAL,runtime_build='f9e92d4a30ab',baseline_commit='00a8beb7',runtime_source_commit='1acefe0315ab51d1f280e2c5a3e56b5c2a65fb55',status='topology_approved_contours_in_review_not_runtime',changes=CHANGES,routes=ROUTES,rooms=info,edges=[{k:e[k] for k in ['id','a','b','requires','a_section','b_section'] if k in e} for e in edges],checks=checks,source_hashes={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in ['config/world/world.json','config/world/construction.json','game/world/regions/P/room_design.json','config/world/collection_design.json','tools/world_review/plains_map.py','tools/world_review/plains_layout.py','tools/world_review/review.html']})
    (args.out/'map.svg').write_text(svg)
    (args.out/'outline.svg').write_text(svg_map(rooms,edges,geometry,corridors,ends,paths,labels,outline=True))
    (args.out/'review.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    template=Path(__file__).with_name('review.html').read_text()
    (args.out/'index.html').write_text(template.replace('__SVG__',svg).replace('__DATA__',json.dumps(data,ensure_ascii=False).replace('</','<\\/')))
    print(json.dumps(checks,ensure_ascii=False))
if __name__=='__main__':main()
