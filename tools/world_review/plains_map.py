"""Build the current plains spatial REVIEW proposal; never writes runtime inputs.

Requires Shapely 2.1.2 for draft polygon/route checks. World identities, rewards,
rests, bosses and current door graph are read from config/world. The constants
below are the one pending spatial proposal, not a second runtime world source.
After approval, migrate adopted geometry to construction/scenes and retire them.
"""
from pathlib import Path
import argparse, hashlib, heapq, html, json, math
from shapely.geometry import Polygon, LineString, Point, box
from shapely.ops import unary_union, nearest_points

ROOT = Path(__file__).resolve().parents[2]
PROPOSAL = 'plains-map-review-01'
# The three explicit decisions awaiting the user's map review.
CHANGES = [
 dict(id='A', remove='HUB-P31-P08', title='收敛小站旁三角回路',
      before='01—08、01—31、31—08构成很短的重复环。',
      after='取消31—08，保留小站东门01→08；铃场专注桥面与集市分流。',
      tradeoff='减少重复出口；08回站须经过01，失去一条很短的旁路。'),
 dict(id='B', remove='HUB-P35-P12', title='让地窖成为真正的支路',
      before='汇口35可直达12，也可经18或19进入12，分支目的接近。',
      after='取消35—12；地窖仍由18与19接入，保留下层水路回环。',
      tradeoff='汇口少一个出口；地窖需要多走一房，奖励入口更有铺垫。'),
 dict(id='C', remove='APPROACH-P05-P14', add=['P-R27','P-R14'], title='休息后直接接首Boss',
      before='背风棚27→慢风平台05→牧风者14，重试需穿过收集房。',
      after='改为27→14；27→05保留作TG02挑战支路，05→06开桥回环保留。',
      tradeoff='Boss重试少过一房；TG02须在27出口预告，并校准05墓园接口与14封场。'),
]
# One-line diagram captions. Full, current responsibilities remain room_design.json.
CAPTIONS = {
1:'休息交易，辨认两条出站路',2:'东部整备，分流风车与旧田',3:'学习走跳，回望起点',4:'断田反冲，桥下寻找铜齿',5:'移动落点挑战，取得铜齿',6:'辨认主线、回环与捷径',7:'登高辨路，掩体间接近',8:'乘笼升井，登西侧高地',9:'矿口地标，预览外区通路',10:'钩索穿风车，寻找暗栈',11:'可选Boss，取得三联机芯',12:'空中射铃，领奖后开折板',13:'石崖折返，挑战生命片',14:'首Boss与钩索首次试用',15:'钩索抵台，修钟开升降机',16:'Boss前休息，观察机匣',17:'藏栈取装备，放梯返回',18:'旧田战斗，分流崖道与井',19:'根井通行，预览双能力齿轮',20:'曲折渠岸，钩索回访行装',21:'试枪命中，理解反向位移',22:'反冲越渠，失误可走回',23:'遇见阿栖，安静叙事停顿',24:'看见站灯，缓坡引向小站',25:'上下树台，越敌或地面战',26:'双吊台换乘与反冲接续',27:'Boss前整备，侧看铜齿支路',28:'地面遭遇，反冲登谷仓',29:'错层穿梁，换射线与落点',30:'低檐水洞，钩索取铜齿',31:'站外分流，选择桥或集市',32:'下桥通行，上桥钩索捷线',33:'钟心地标，舒缓与回望',34:'屋顶货运与摊间低路',35:'东行枢纽，田路与井道分流'}
ZONES = {
 'start':dict(name='初风草坡',sub='启程 · 教学 · 人物',rooms=[3,21,22,23,24],fill='#d6dfc1',edge='#718565'),
 'west':dict(name='牧风高地',sub='反冲主线 · 首Boss · 铜齿支路',rooms=[4,5,6,8,13,14,15,25,26,27],fill='#ddcfac',edge='#a28b5e'),
 'town':dict(name='钟庭旧街',sub='安全枢纽 · 地标 · 上下层回环',rooms=[1,31,32,33,34,35],fill='#dfd7c6',edge='#9b8b74'),
 'water':dict(name='根井水路',sub='收集挑战 · 能力回访 · 下层归途',rooms=[12,19,20],fill='#bdd7d2',edge='#5c9693'),
 'east':dict(name='东田与风车',sub='自由探索 · 钩索路线 · 可选Boss',rooms=[2,7,9,10,11,16,17,18,28,29,30],fill='#c6d4d5',edge='#738e99')}
LABEL_ANCHORS = { # Native planning coordinates, inside principal chambers.
 1:(8820,6768),2:(21790,7070),3:(4200,7580),4:(3750,6070),5:(8100,3584),6:(10570,3270),
 7:(20850,5310),8:(10300,5800),9:(23180,8920),10:(23150,4900),11:(25260,3530),
 12:(18120,6940),13:(5450,6075),14:(8000,2510),15:(11850,4930),16:(23230,3590),
 17:(23490,6450),18:(18400,5850),19:(16330,8650),20:(14150,8570),21:(5810,7410),
 22:(6560,8285),23:(8224,8256),24:(8390,7540),25:(4630,4980),26:(6670,4790),
 27:(6500,3760),28:(21600,7740),29:(23430,7720),30:(20670,6200),31:(10850,7150),
 32:(13140,6270),33:(15570,5690),34:(13030,7650),35:(15500,7220)}
SCALE=.235
OX,OY=2500,1500
MARGIN_X,MARGIN_Y=150,360
WIDTH,HEIGHT=6000,2650

def read(p): return json.loads((ROOT/p).read_text())
def rid(n): return f'P-R{n:02}'
def esc(s): return html.escape(str(s),quote=True)
def xy(p): return ((p[0]-OX)*SCALE+MARGIN_X,(p[1]-OY)*SCALE+MARGIN_Y)
def points(ps): return ' '.join(f'{x:.2f},{y:.2f}' for x,y in map(xy,ps))
def path_poly(p):
    rings=[p.exterior,*p.interiors]
    return ' '.join('M '+' L '.join(f'{x:.2f} {y:.2f}' for x,y in map(xy,r.coords))+' Z' for r in rings)
def path_line(ps):return 'M '+' L '.join(f'{x:.2f} {y:.2f}' for x,y in map(xy,ps))
def zone(n):return next(z for z in ZONES.values() if n in z['rooms'])

def sources():
    w=read('config/world/world.json');c=read('config/world/construction.json')
    rooms={r['id']:r for r in w['rooms'] if r['region']=='P'}
    con={r['room_id']:r for r in c['rooms'] if r['room_id'] in rooms}
    edges=[e for e in w['connections'] if e['a'] in rooms and e['b'] in rooms]
    doors={d['id']:d for r in con.values() for d in r['doors']}
    origins={rid(1):(8000,6400)}
    while len(origins)<35:
        before=len(origins)
        for e in edges:
            for a,b in [(e['a'],e['b']),(e['b'],e['a'])]:
                if a not in origins:continue
                pa=doors[e['id']+':'+a]['position_candidate']['local_world_units']
                pb=doors[e['id']+':'+b]['position_candidate']['local_world_units']
                origin=tuple(origins[a][i]+pa[i]-pb[i] for i in (0,1))
                if b in origins:assert origins[b]==origin
                else:origins[b]=origin
        assert len(origins)>before or len(origins)==35
    geometry={r:unary_union([box(x+origins[r][0],y+origins[r][1],x+origins[r][0]+ww,y+origins[r][1]+hh) for x,y,ww,hh in row['space_rects']]) for r,row in con.items()}
    ports={}
    for e in edges:
        a=e['a'];p=doors[e['id']+':'+a]['position_candidate']['local_world_units']
        ports[e['id']]=(p[0]+origins[a][0],p[1]+origins[a][1])
    return w,rooms,edges,geometry,ports


def candidate(current,edges,ports):
    raw=dict(current)
    # Bring the landmark onto its own upper terrace; the junction no longer wraps it.
    raw[rid(33)]=box(14432,5216,16736,6240)
    raw[rid(35)]=unary_union([box(14432,6656,16736,8032),box(16736,5904,17120,8032)])
    # The sheltered pre-boss approach rises on the outer cliff, separate from TG02.
    raw[rid(14)]=unary_union([raw[rid(14)],box(6400,2200,6976,3072)])
    raw[rid(27)]=unary_union([raw[rid(27)],box(6432,3072,6848,3456)])
    inset={r:p.buffer(-80 if r in [rid(13),rid(14),rid(27),rid(35)] else -96,join_style=2) for r,p in raw.items()}
    assert all(p.geom_type=='Polygon' and not p.is_empty for p in inset.values())
    proposed=[dict(e) for e in edges if e['id'] not in {x['remove'] for x in CHANGES}]
    proposed.append(dict(id='REVIEW-P27-P14',a=rid(27),b=rid(14),requires=[[]],a_section='main',b_section='main',proposal='C'))
    specials={
      'HUB-P32-P33':[(14000,6048),(14800,6048)],
      'HUB-P32-P35':[(14000,6816),(14800,6816)],
      'HUB-P33-P35':[(15584,6020),(15584,6950)],
      'HUB-P34-P35':[(13900,7680),(14800,7680)],
      'REVIEW-P27-P14':[(6640,3450),(6640,2750)]}
    pair_sides={p['edge_id']:p['construction_sides'] for p in read('config/world/construction.json')['door_pairs']}
    corridors={};ends={}
    for e in proposed:
        a,b=e['a'],e['b']
        if e['id'] in specials:
            ps=specials[e['id']]
        else:
            p=ports[e['id']]
            # Span both room insets at the existing paired doorway.
            side=pair_sides[e['id']][a]
            dx,dy={'right':(1,0),'left':(-1,0),'up':(0,-1),'down':(0,1)}[side]
            ps=[(p[0]-dx*240,p[1]-dy*240),(p[0]+dx*240,p[1]+dy*240)]
        line=LineString(ps)
        if not inset[a].buffer(1).covers(Point(ps[0])) and inset[a].buffer(1).covers(Point(ps[-1])):ps=ps[::-1]
        line=LineString(ps)
        assert line.intersects(inset[a]) and line.intersects(inset[b]),(e['id'],ps)
        corridors[e['id']]=line.buffer(80,cap_style=2,join_style=2)
        ends[e['id']]=(tuple(ps[0]),tuple(ps[-1]))
    # Natural shoulders step inward; building interiors retain deliberate straight walls.
    # Keep every doorway and annotation clear. This is authored terrain intent, not random noise.
    natural={3,4,5,7,13,14,18,19,20,21,22,24,25,28,30,32,33,34,35}
    for r,p in list(inset.items()):
        n=int(r[-2:])
        if n not in natural:continue
        x0,y0,x1,y1=p.bounds
        protected=unary_union([corridors[e['id']].buffer(64) for e in proposed if r in [e['a'],e['b']]]+[Point(LABEL_ANCHORS[n]).buffer(410)])
        size=min(224,(x1-x0)*.15,(y1-y0)*.23)
        for idx,(cx,cy,dx,dy) in enumerate([(x0,y0,1,1),(x1,y0,-1,1),(x1,y1,-1,-1),(x0,y1,1,-1)]):
            if idx not in [n%4,(n+2)%4]:continue
            steps=[(0,0),(size,0),(size,size/3),(size*2/3,size/3),(size*2/3,size*2/3),(size/3,size*2/3),(size/3,size),(0,size)]
            cut=Polygon([(cx+dx*x,cy+dy*y) for x,y in steps])
            if not cut.intersects(protected):
                candidate=p.difference(cut)
                if candidate.geom_type=='Polygon':p=candidate
        inset[r]=p
    return inset,proposed,corridors,ends


def inside_path(poly,start,end):
    """Visibility path through this draft footprint, not a playable motor proof."""
    if Point(start).distance(poly)>1:start=nearest_points(poly,Point(start))[0].coords[0]
    if Point(end).distance(poly)>1:end=nearest_points(poly,Point(end))[0].coords[0]
    pts=[start,end,*list(poly.exterior.coords)[:-1]]
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
 dict(id='main',name='① 首访主线 · 基础动作 / 反冲',color='#c46c2e',rooms=[3,21,22,23,24,1,8,6,13,4,25,26,27,14],note='首Boss前不要求H；26双吊台保持必经。27侧口可选05铜齿挑战。'),
 dict(id='return',name='② 钩索与修钟归途',color='#318a88',rooms=[14,15,32,31,1],note='14胜利领H → 15校时；从15侧开SC01，经32、31回小站。'),
 dict(id='east',name='③ 东行与可选Boss',color='#626ba1',rooms=[1,31,34,35,18,7,2,10,16,11],note='东田可首访探索；02→10的房内路线需要H；16整备后挑战11。'),
 dict(id='water',name='④ 下层探索回环',color='#358579',rooms=[31,34,20,19,12,18,35,34,31],note='主通路可探索；20奖励需H、19铜齿需H+D；12为独立射铃挑战。')]


def validate(rooms,edges,geometry,corridors):
    assert len(rooms)==35 and len(edges)==43
    seen={rid(3)}
    while True:
        newer=seen|{e['b'] for e in edges if e['a'] in seen}|{e['a'] for e in edges if e['b'] in seen}
        if newer==seen:break
        seen=newer
    assert seen==set(rooms)
    errors=[]
    for i,(a,p) in enumerate(geometry.items()):
        for b,q in list(geometry.items())[:i]:
            if p.intersection(q).area>1:errors.append('Room overlap '+a+' '+b)
    for e in edges:
        poly=corridors[e['id']]
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
    source_edges={e['id']:e for e in read('config/world/world.json')['connections']}
    for e in edges:
        if e['id'] in source_edges:
            assert all(e.get(k)==source_edges[e['id']].get(k) for k in ['a','b','requires','a_section','b_section'])
    return dict(rooms=35,current_internal_connections=45,proposed_internal_connections=43,connected=True,room_overlaps=0,unrelated_corridor_crossings=0,route_sequences_checked=4,scope='Draft geometry and graph only; no runtime or motor acceptance.')


def room_info(w,rooms):
    designs={r['room_id']:r for r in read('game/world/regions/P/room_design.json')['rooms']}
    acqs=read('config/world/collection_design.json')['acquisition_contracts']
    bosses={b['room_id']:b for b in w['boss_plan']['bosses'] if b.get('region')=='P'}
    result={}
    for r,row in rooms.items():
        n=int(r[-2:]);acq=[a for a in acqs if isinstance(a,dict) and a.get('room_id')==r]
        result[r]=dict(id=r,name=row['name'],caption=CAPTIONS[n],current_purpose=designs[r]['purpose'],rest=bool(row.get('rest_point')),npcs=row.get('npc_ids',[]),reward_ids=row.get('reward_ids',[]),collections=[dict(id=a['reward_id'],experience=a.get('primary_experience',''),section=a.get('section_id','main'),requires=a.get('canonical_requires',a.get('requires')),return_path=a.get('return_path','')) for a in acq],boss=bosses.get(r),clock=row.get('clock_actions',[]),zone=zone(n)['name'])
    assert sum(r['rest'] for r in result.values())==4
    assert sum(bool(r['boss']) for r in result.values())==2
    return result


def svg_map(rooms,edges,geometry,corridors,ends,current,ports,info):
    out=[f'<svg xmlns="http://www.w3.org/2000/svg" id="region-map" viewBox="0 0 {WIDTH} {HEIGHT}" role="img" aria-label="平原整区空间提案，35房职责、路线与收集要素">',
    '''<defs><pattern id="grid" width="48" height="48" patternUnits="userSpaceOnUse"><path d="M48 0H0V48" fill="none" stroke="#3b554d" stroke-width=".5" opacity=".06"/></pattern>
    <pattern id="hatch" width="12" height="12" patternUnits="userSpaceOnUse"><path d="M0 12L12 0" stroke="#344d42" stroke-width="1" opacity=".14"/></pattern>
    <filter id="shadow" x="-10%" y="-10%" width="120%" height="140%"><feDropShadow dx="0" dy="7" stdDeviation="4" flood-color="#46564c" flood-opacity=".18"/></filter>''']
    for route in ROUTES:out.append(f'<marker id="arrow-{route["id"]}" markerWidth="7" markerHeight="7" refX="5" refY="3.5" orient="auto"><path d="M0 0L7 3.5L0 7" fill="{route["color"]}"/></marker>')
    out.append('''</defs><style>
    text{font-family:'Noto Sans CJK SC','Microsoft YaHei',sans-serif;fill:#243e37} .room{cursor:pointer}.room:focus{outline:none}.room:focus .roomshape,.room:hover .roomshape,.room.selected .roomshape{stroke:#b24d72;stroke-width:5}.route{pointer-events:none}.room-label{pointer-events:none}.ghost{display:none} .show-changes .ghost{display:inline}.poi-off .poi{display:none}.no-routes .route{display:none}.route-muted{opacity:.12}.zone-label{font-weight:700;letter-spacing:5px}
    </style>''')
    out.append(f'<rect width="{WIDTH}" height="{HEIGHT}" fill="#f4f0e5"/><rect width="{WIDTH}" height="{HEIGHT}" fill="url(#grid)"/>')
    out.append('<text x="145" y="94" font-size="23" letter-spacing="8" fill="#777c65">GUNMAN RUSH  /  REGION P</text><text x="140" y="174" font-size="63" font-weight="700">风铃平原 · 整区空间审核图</text><text x="145" y="228" font-size="25">35间房 · 连续地貌与短窄通道 · 43条内部连接候选 · 设计提案，尚未写入试玩关卡</text>')
    out.append('<text x="5850" y="113" text-anchor="end" font-size="29" fill="#a15170">待审核 / 01</text><text x="5850" y="159" text-anchor="end" font-size="23">实线廊道＝实体通路意图；彩箭头＝推荐行进顺序</text><text x="5850" y="200" text-anchor="end" font-size="23">H＝钩索　D＝二段跳　灰虚线＝外区接口方向，未施工</text>')
    # Terrain contours belong to the landscape, not extra playable rooms.
    for z in ZONES.values():
        mass=unary_union([geometry[rid(n)] for n in z['rooms']])
        for distance,opacity in [(200,.28),(350,.16),(510,.1)]:
            contour=mass.buffer(distance,join_style=1)
            polys=list(contour.geoms) if contour.geom_type=='MultiPolygon' else [contour]
            for p in polys:out.append(f'<path d="{path_poly(p)}" fill="none" stroke="{z["edge"]}" stroke-width="1.3" opacity="{opacity}"/>')
    # Quiet landscape labels in unoccupied space establish geographic groups.
    for name,sub,p in [('牧风高地','双吊台 → 背风棚 → 牧风者',(3600,2700)),('初风草坡','从车厢到小站的启程路',(3100,8770)),('钟庭旧街','桥上见钟，桥下归途',(13500,3500)),('根井水路','暗渠 · 收集 · 回访',(11400,9000)),('东田与风车','两层农路与远处机械轮廓',(21300,2150))]:
        x,y=xy(p);out.append(f'<text class="zone-label" x="{x}" y="{y}" font-size="39">{name}</text><text x="{x}" y="{y+43}" font-size="23" fill="#748177">{sub}</text>')
    # Physical corridor bodies have width; they are not long topology connector lines.
    out.append('<g id="corridor-bodies">')
    for e in edges:
        p=corridors[e['id']];out.append(f'<path d="{path_poly(p)}" fill="#c7cbb8" stroke="#758675" stroke-width="2"><title>{esc(e["id"])}：{e["a"]} ↔ {e["b"]}</title></path>')
    out.append('</g>')
    # Footprint silhouette and masonry/earth bank edge.
    for r,p in geometry.items():
        z=zone(int(r[-2:]));out.append(f'<g class="room" data-room="{r}" tabindex="0" role="button" aria-label="{r} {esc(rooms[r]["name"])} {esc(CAPTIONS[int(r[-2:])])}"><title>{r} {esc(rooms[r]["name"])}</title><path class="roomshape" d="{path_poly(p)}" fill="{z["fill"]}" stroke="{z["edge"]}" stroke-width="2.5" filter="url(#shadow)"/><path d="{path_poly(p.difference(p.buffer(-25,join_style=2)))}" fill="url(#hatch)" fill-rule="evenodd"/></g>')
    # Unselected branch passage traces stay legible under the route overlays.
    for e in edges:
        a,b=ends[e['id']];out.append(f'<path d="{path_line([a,b])}" fill="none" stroke="#f4f0e5" stroke-width="3" opacity=".8"/>')
    for route in ROUTES:
        out.append(f'<g class="route" data-route="{route["id"]}">')
        seq=route['rooms']
        for i,(a,b) in enumerate(zip(seq,seq[1:])):
            ar,br=rid(a),rid(b);e=next(e for e in edges if {ar,br}=={e['a'],e['b']})
            ea,eb=ends[e['id']]
            if e['a']!=ar:ea,eb=eb,ea
            # Room-internal arrows show regional sequence only, never a motor replay.
            ap=inside_path(geometry[ar],LABEL_ANCHORS[a],ea)
            bp=inside_path(geometry[br],eb,LABEL_ANCHORS[b])
            ps=ap+[eb]+bp[1:]
            out.append(f'<path d="{path_line(ps)}" fill="none" stroke="{route["color"]}" stroke-width="4" stroke-linejoin="round" opacity=".8" marker-mid="url(#arrow-{route["id"]})" marker-end="url(#arrow-{route["id"]})"/>')
        out.append('</g>')
    # Three existing shortcuts, with actual opening sides and state conditions.
    shortcut_specs=[('room-link-144','S2 · 05侧放桥'),('L02','S3 · 14胜利侧开闸'),('SC-P01','S1 · 15修钟后开启')]
    for eid,label in shortcut_specs:
        a,b=ends[eid];x,y=xy(((a[0]+b[0])/2,(a[1]+b[1])/2))
        out.append(f'<g class="poi"><circle cx="{x}" cy="{y}" r="13" fill="#f4f0e5" stroke="#318a88" stroke-width="3"/><text x="{x+19}" y="{y-15}" font-size="18" fill="#266b69" paint-order="stroke" stroke="#f4f0e5" stroke-width="6">{label}</text></g>')
    # Candidate changes: magenta marker always visible; discarded seam only on comparison.
    change_pos={'A':ports['HUB-P31-P08'],'B':ports['HUB-P35-P12'],'C':(6640,3160)}
    for change in CHANGES:
        p=change_pos[change['id']];x,y=xy(p)
        out.append(f'<g class="change" data-change="{change["id"]}"><circle cx="{x}" cy="{y}" r="23" fill="#ab5779" stroke="#fff8ed" stroke-width="3"/><text x="{x}" y="{y+8}" text-anchor="middle" fill="white" style="fill:white" font-size="24" font-weight="700">{change["id"]}</text></g>')
        old=ports[change['remove']];ox,oy=xy(old)
        out.append(f'<g class="ghost"><path d="M{ox-33} {oy-33}L{ox+33} {oy+33}M{ox+33} {oy-33}L{ox-33} {oy+33}" stroke="#ab5779" stroke-width="5"/><text x="{ox+40}" y="{oy+5}" font-size="19" fill="#ab5779">拟取消旧口</text></g>')
    # Labels are drawn last; every room has its one-line responsibility inside it.
    badge_map={1:[('休','rest'),('NPC','npc'),('服务×14','service')],2:[('休','rest')],4:[('TG01 齿轮 · 探索','gear')],5:[('TG02 齿轮 · 挑战↩','gear')],6:[('试制任务件','trial')],11:[('B2 · 巡游机','boss'),('三联机芯','gear')],12:[('装备P01 · 挑战↩','gear')],13:[('HP01 生命片 · 挑战↩','gear')],14:[('B1 · 牧风者','boss'),('获得H','ability')],15:[('H · 修钟','clock')],10:[('房内H路线','ability')],16:[('休','rest')],17:[('装备P03 · 隐藏/H↩','gear')],19:[('TG04 · H+D↩','ability')],20:[('装备P02 · H↩','ability')],23:[('阿栖','npc')],27:[('休','rest')],30:[('TG03 · H↩','ability')],32:[('上层路线H','ability')],33:[('世界钟方向','clock')]}
    badge_colors={'rest':'#3f8371','npc':'#8d6a93','service':'#777452','gear':'#ad7733','boss':'#ae5451','ability':'#507d99','clock':'#8b7443','trial':'#79847b'}
    for r,row in rooms.items():
        n=int(r[-2:]);x,y=xy(LABEL_ANCHORS[n]);p=geometry[r]
        assert p.contains(Point(LABEL_ANCHORS[n])),r
        span=p.intersection(LineString([(p.bounds[0],LABEL_ANCHORS[n][1]),(p.bounds[2],LABEL_ANCHORS[n][1])]))
        label_w=min(max(len(CAPTIONS[n])*15,190),span.length*SCALE-12)
        name_size=min(28,(label_w-8)/(len(row['name'])+1.65));caption_size=min(19,(label_w-6)/len(CAPTIONS[n]))
        out.append(f'<g class="room-label" data-label="{r}"><rect x="{x-label_w/2-8}" y="{y-51}" width="{label_w+16}" height="111" rx="7" fill="{zone(n)["fill"]}" opacity=".97"/><text x="{x}" y="{y-25}" text-anchor="middle" font-size="{name_size:.1f}" font-weight="700"><tspan font-size="17" fill="#6e7c68">{n:02} </tspan>{esc(row["name"])}</text><text x="{x}" y="{y+4}" text-anchor="middle" font-size="{caption_size:.1f}">{CAPTIONS[n]}</text>')
        badges=badge_map.get(n,[]);widths=[len(s)*14+18 for s,t in badges];left=x-(sum(widths)+6*max(0,len(widths)-1))/2
        out.append('<g class="poi">')
        for (s,t),ww in zip(badges,widths):
            out.append(f'<rect x="{left}" y="{y+18}" width="{ww}" height="26" rx="5" fill="{badge_colors[t]}"/><text x="{left+ww/2}" y="{y+37}" text-anchor="middle" style="fill:white" font-size="14">{s}</text>');left+=ww+6
        out.append('</g></g>')
    # Exterior stubs are deliberately separated from the region's 43 internal passages.
    for n,label,p,q in [(3,'→ 蘑菇 / 下水道',(4200,7820),(4200,9200)),(4,'→ 森林',(3000,6100),(2300,6600)),(5,'墓园接口 ↙',(7250,3300),(6950,3300)),(9,'矿井侧开通 →',(23300,9160),(25200,9350)),(18,'→ 古堡 / 工城',(19500,5600),(20300,4300)),(33,'世界钟心 ←',(14700,5400),(14400,4500))]:
        x,y=xy(q);out.append(f'<g class="poi"><path d="{path_line([p,q])}" fill="none" stroke="#8d9c8b" stroke-width="2" stroke-dasharray="9 8"/><text x="{x}" y="{y-12}" font-size="20" fill="#7a8879">{label}</text></g>')
    # Printed reading key and full-route index remain in the downloadable image.
    out.append('<path d="M145 2225H5850" stroke="#c4c9b8" stroke-width="2"/><text x="145" y="2280" font-size="29" font-weight="700">路线与要素</text>')
    for i,route in enumerate(ROUTES):
        x=145+(i%2)*2800;y=2335+(i//2)*114
        seq=' → '.join(f'{n:02}' for n in route['rooms'])
        out.append(f'<circle cx="{x+10}" cy="{y-8}" r="9" fill="{route["color"]}"/><text x="{x+35}" y="{y}" font-size="24" font-weight="700">{route["name"]}</text><text x="{x+35}" y="{y+34}" font-size="21">{seq}</text><text x="{x+35}" y="{y+65}" font-size="18">{route["note"]}</text>')
    out.append('<text x="145" y="2610" font-size="21">休＝明确休息点（01 / 02 / 16 / 27）　B1＝主线Boss　B2＝可选Boss　↩＝领奖侧开本房返程　A / B / C＝待审核的连接调整</text><text x="5850" y="2610" text-anchor="end" font-size="19">示意尺度；房内箭头只表达路线顺序，不代替最终碰撞与动作验证。</text></svg>')
    return '\n'.join(out)


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--out',type=Path,default=ROOT/'build/plains-map-review');args=parser.parse_args();args.out.mkdir(parents=True,exist_ok=True)
    w,rooms,edges,current,ports=sources();geometry,proposed,corridors,ends=candidate(current,edges,ports)
    checks=validate(rooms,proposed,geometry,corridors);info=room_info(w,rooms)
    svg=svg_map(rooms,proposed,geometry,corridors,ends,current,ports,info)
    data=dict(id=PROPOSAL,runtime_build='f9e92d4a30ab',baseline_commit='7c74483fa32dae2eeffc2b46d327ebd95c37215d',exporter_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),status='proposal_pending_user_review_not_runtime',changes=CHANGES,routes=ROUTES,rooms=info,edges=[{k:e[k] for k in ['id','a','b','requires','a_section','b_section'] if k in e} for e in proposed],checks=checks,source_hashes={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in ['config/world/world.json','config/world/construction.json','game/world/regions/P/room_design.json','config/world/collection_design.json']})
    (args.out/'map.svg').write_text(svg);(args.out/'review.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    template=(Path(__file__).with_name('review.html')).read_text();(args.out/'index.html').write_text(template.replace('__SVG__',svg).replace('__DATA__',json.dumps(data,ensure_ascii=False).replace('</','<\\/')))
    print(json.dumps(checks,ensure_ascii=False))
if __name__=='__main__':main()
