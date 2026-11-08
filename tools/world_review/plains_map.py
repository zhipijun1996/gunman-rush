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

ROOT = Path(__file__).resolve().parents[2]
PROPOSAL = 'plains-map-review-02'
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
 27:(6500,3760),28:(21600,7740),29:(23430,7720),30:(20670,6200),31:(11150,6370),
 32:(13140,6200),33:(15570,5690),34:(13030,7650),35:(15500,7220)}
DEFAULT_LABEL_ANCHORS=dict(LABEL_ANCHORS)
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
    if p.is_empty:return ""
    if p.geom_type in ("MultiPolygon","GeometryCollection"):return " ".join(path_poly(g) for g in p.geoms if g.geom_type in ("Polygon","MultiPolygon"))
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
    raw[rid(31)]=unary_union([raw[rid(31)],box(10816,5632,11872,7100)])
    raw[rid(33)]=box(14432,5216,16736,6240)
    raw[rid(35)]=unary_union([box(14432,6656,16736,8032),box(16736,5904,17120,8032)])
    # The sheltered pre-boss approach rises on the outer cliff, separate from TG02.
    raw[rid(14)]=unary_union([raw[rid(14)],box(6400,2200,6976,3072)])
    raw[rid(27)]=unary_union([raw[rid(27)],box(6432,3072,6848,3456)])
    inset={r:p.buffer(-80 if r in [rid(13),rid(14),rid(27),rid(35)] else -96,join_style=2) for r,p in raw.items()}
    assert all(p.geom_type=='Polygon' and not p.is_empty for p in inset.values())
    proposed=[dict(e) for e in edges if e['id'] not in {x['remove'] for x in CHANGES}]
    proposed.append(dict(id='APPROACH-P27-P14',a=rid(27),b=rid(14),requires=[[]],a_section='main',b_section='main',proposal='C'))
    specials={
      'HUB-P32-P33':[(14000,6048),(14800,6048)],
      'HUB-P32-P35':[(14000,6816),(14800,6816)],
      'HUB-P33-P35':[(15584,6020),(15584,6950)],
      'HUB-P34-P35':[(13900,7680),(14800,7680)],
      'APPROACH-P27-P14':[(6640,3450),(6640,2750)]}
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
    # Large shoulders, side pockets and constrictions follow each room's job.
    # These are authored silhouettes, not random corner noise or reusable room cards.
    inset=authored_contours(inset,proposed,corridors,ends)
    fit_label_anchors(inset)
    return inset,proposed,corridors,ends


def authored_contours(envelopes,edges,corridors,ends):
    # Fractional outlines apply only to a room's own envelope. The variations express
    # a long inhabited passage, an arena, a collapsed bay, a storage alcove, etc.
    profiles={
      3:[(0,.64),(.20,.64),(.20,.54),(.60,.54),(.60,.02),(.94,.02),(.94,.87),(.74,.87),(.74,.96),(.13,.96),(0,.85)],
      4:[(.22,.02),(.43,.02),(.43,.44),(.74,.44),(.74,.59),(.98,.59),(.98,.91),(.63,.91),(.63,.80),(.35,.80),(.35,.97),(.02,.97),(.02,.67),(.22,.67)],
      5:[(.03,.31),(.23,.31),(.23,.12),(.65,.12),(.65,.30),(.97,.30),(.97,.58),(.79,.58),(.79,.86),(.51,.86),(.51,.96),(.03,.96)],
      7:[(.01,.71),(.18,.71),(.18,.48),(.42,.48),(.42,.24),(.75,.24),(.75,.04),(.90,.04),(.98,.23),(.98,.90),(.69,.90),(.69,.79),(.01,.97)],
      9:[(.02,.34),(.34,.34),(.34,.12),(.64,.12),(.64,.32),(.98,.32),(.98,.77),(.70,.77),(.70,.91),(.46,.91),(.46,.71),(.02,.71)],
      11:[(.02,.57),(.14,.57),(.14,.23),(.28,.23),(.28,.04),(.82,.04),(.82,.15),(.97,.15),(.97,.86),(.82,.86),(.82,.97),(.26,.97),(.26,.85),(.02,.85)],
      16:[(.02,.61),(.17,.61),(.17,.18),(.53,.18),(.53,.38),(.75,.38),(.75,.61),(.98,.61),(.98,.90),(.60,.90),(.60,.98),(.02,.98)],
      17:[(.12,.03),(.68,.03),(.68,.20),(.96,.20),(.96,.76),(.74,.76),(.74,.96),(.02,.96),(.02,.55),(.12,.55)],
      19:[(.44,.02),(.64,.02),(.64,.21),(.83,.21),(.83,.53),(.98,.53),(.98,.96),(.69,.96),(.69,.85),(.33,.85),(.33,.70),(.02,.70),(.02,.38),(.22,.38),(.22,.17),(.44,.17)],
      20:[(.02,.04),(.38,.04),(.38,.18),(.69,.18),(.69,.35),(.87,.35),(.87,.60),(.98,.60),(.98,.96),(.69,.96),(.69,.83),(.40,.83),(.40,.66),(.02,.66)],
      21:[(.02,.56),(.14,.56),(.14,.28),(.33,.28),(.33,.07),(.60,.07),(.60,.22),(.83,.22),(.83,.43),(.97,.43),(.97,.78),(.60,.78),(.60,.97),(.02,.97)],
      22:[(.02,.02),(.27,.02),(.27,.14),(.49,.14),(.49,.35),(.69,.35),(.69,.15),(.98,.15),(.98,.80),(.77,.80),(.77,.97),(.54,.97),(.54,.74),(.25,.74),(.25,.90),(.02,.90)],
      23:[(.02,.42),(.14,.42),(.14,.18),(.50,.18),(.50,.02),(.80,.02),(.80,.77),(.97,.77),(.97,.96),(.02,.96)],
      24:[(.02,.72),(.15,.72),(.15,.50),(.42,.50),(.42,.31),(.71,.31),(.71,.05),(.98,.05),(.98,.83),(.53,.83),(.53,.98),(.02,.98)],
      25:[(.02,.64),(.15,.64),(.15,.31),(.38,.31),(.38,.03),(.66,.03),(.66,.20),(.91,.20),(.91,.53),(.98,.53),(.98,.96),(.69,.96),(.69,.78),(.35,.78),(.35,.96),(.02,.96)],
      26:[(.02,.69),(.18,.69),(.18,.27),(.34,.27),(.34,.02),(.65,.02),(.65,.18),(.84,.18),(.84,.49),(.98,.49),(.98,.96),(.02,.96)],
      27:[(.07,.36),(.42,.36),(.42,.02),(.65,.02),(.65,.37),(.93,.37),(.93,.95),(.47,.95),(.47,.80),(.07,.80)],
      28:[(.02,.59),(.15,.59),(.15,.32),(.43,.32),(.43,.03),(.61,.03),(.61,.19),(.97,.19),(.97,.69),(.74,.69),(.74,.93),(.35,.93),(.35,.78),(.02,.78)],
      29:[(.02,.28),(.21,.28),(.21,.03),(.72,.03),(.72,.18),(.96,.18),(.96,.57),(.80,.57),(.80,.94),(.42,.94),(.42,.77),(.19,.77),(.19,.54),(.02,.54)],
      30:[(.02,.16),(.28,.16),(.28,.04),(.55,.04),(.55,.29),(.80,.29),(.80,.50),(.96,.50),(.96,.95),(.67,.95),(.67,.74),(.43,.74),(.43,.64),(.14,.64),(.14,.43),(.02,.43)],
      33:[(.02,.55),(.18,.55),(.18,.23),(.39,.23),(.39,.02),(.70,.02),(.70,.28),(.87,.28),(.87,.48),(.98,.48),(.98,.79),(.60,.79),(.60,.97),(.41,.97),(.41,.80),(.02,.80)]
    }
    bodies={}
    for r,envelope in envelopes.items():
        n=int(r[-2:]);x0,y0,x1,y1=envelope.bounds
        if n in profiles:
            body=Polygon([(x0+x*(x1-x0),y0+y*(y1-y0)) for x,y in profiles[n]]).intersection(envelope)
        else:body=envelope
        bodies[r]=body
    # Purpose-specific compound spaces: slim shafts, a broad hub, bridge decks,
    # street shelters and side chambers. Large voids remain real unwalkable masses.
    pieces={
      1:[(8130,6520,9400,7010),(9300,6650,9650,7570),(9240,7360,9720,7675)],
      2:[(21320,6820,22040,7260),(21820,5800,22100,7090),(22000,5770,22270,6090)],
      6:[(9250,2470,10200,2740),(9970,2580,10200,3300),(9900,3080,11180,3710),(10200,2890,10940,3300)],
      8:[(10200,3950,10580,5470),(10080,5230,10700,6000),(9910,5870,10480,6540)],
      10:[(21820,3880,22800,4180),(22500,4170,23600,5680),(22480,5460,23780,5870),(22920,5660,23770,5870)],
      18:[(17216,5940,17900,6340),(17600,5680,19300,6340),(18400,5540,19584,6100),(19200,6150,19440,7360)],
      12:[(17480,6590,18550,7250),(18240,6970,18800,7380),(17600,7180,17820,9100),(17480,8970,17890,9180)],
      13:[(4820,5870,6040,6400),(5460,5740,6810,5930),(6650,5630,9320,5850),(9300,3730,9490,5800),(9430,3650,9690,3980)],
      14:[(6530,2380,8920,2910),(6800,2120,8920,2690),(7210,1920,8680,2500),(8780,1970,11570,2190),(11280,2040,11570,2220)],
      15:[(11440,2410,11710,4560),(11200,4490,12400,5270),(10930,4760,11500,5270),(12200,4900,12750,5510)],
      31:[(10940,5760,11750,7270),(10320,6790,11750,7410),(9950,7160,10950,7540),(10820,6600,11750,7520)],
      32:[(12800,5910,13750,6500),(12000,6500,14280,6795),(12000,5900,14280,6150),(12440,5750,12770,6650),(13860,6050,14280,6650)],
      34:[(12000,7380,13980,7660),(12550,7510,13980,7900),(12500,7790,12890,8390)],
      35:[(14550,6820,16380,7390),(15250,7330,17000,7750),(16320,7420,16850,7910),(16850,6030,17000,7750),(16000,6750,17000,7210)]
    }
    for n,rects in pieces.items():bodies[rid(n)]=unary_union([box(*r) for r in rects]).intersection(envelopes[rid(n)])
    for r,body in bodies.items():
        envelope=envelopes[r]
        if body.geom_type!='Polygon':
            # Join intentional side chambers along the old connected envelope.
            parts=list(body.geoms)
            body=parts[0]
            for part in parts[1:]:
                a,b=nearest_points(body,part)
                route=inside_path(envelope,a.coords[0],b.coords[0])
                body=unary_union([body,part,LineString(route).buffer(105,join_style=2)]).intersection(envelope)
        for e in edges:
            if r not in (e['a'],e['b']):continue
            target=ends[e['id']][0 if r==e['a'] else 1]
            # Short stems belong to the room; they do not create invisible portals.
            near=nearest_points(body,Point(target))[0].coords[0]
            route=inside_path(envelope,near,target)
            arm=LineString(route).buffer(105,cap_style=3,join_style=2) if len(set(route))>1 else Point(target).buffer(105,cap_style=3)
            body=unary_union([body,arm.intersection(envelope)])
        assert body.geom_type=='Polygon' and body.is_valid,(r,body.geom_type)
        bodies[r]=body
    return bodies


def fit_label_anchors(geometry):
    names={r['id']:r['name'] for r in read('config/world/world.json')['rooms'] if r['region']=='P'}
    for n,anchor in DEFAULT_LABEL_ANCHORS.items():
        poly=geometry[rid(n)]
        width=max(len(CAPTIONS[n])*18+10,len(names[rid(n)])*26+35,220)
        best=None
        for step in range(11):
            factor=1-step*.05
            for dx in range(-600,601,40):
                for dy in range(-480,481,40):
                    score=factor*1000-math.hypot(dx,dy)
                    if best is not None and score<=best[0]:continue
                    x,y=anchor[0]+dx,anchor[1]+dy
                    label=box(x-width*factor/2/SCALE,y-51*factor/SCALE,x+width*factor/2/SCALE,y+60*factor/SCALE)
                    if poly.covers(label):best=(score,(x,y))
        assert best is not None,('No annotation space',n)
        LABEL_ANCHORS[n]=best[1]


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
 dict(id='main',name='① 首访主线 · 基础动作 / 反冲',color='#c46c2e',rooms=[3,21,22,23,24,1,8,6,13,4,25,26,27,14],note='先在22完成综合实践再进站；01东门进井，06转西。26双吊台必经，27直达Boss。'),
 dict(id='return',name='② 钩索与修钟归途',color='#318a88',rooms=[14,15,32,31,1],note='14领H → 15校时开S1 → 重见32铜环；31可回站、往东探桥，或下集入水路。'),
 dict(id='east',name='③ 钩索东行与可选Boss',color='#626ba1',rooms=[32,35,18,7,2,10,16,11],note='得H后试32高桥直达35；基础阶段仍可走31→34→35。02→10房内需H，16整备后挑战11。'),
 dict(id='water',name='④ 下层探索回环',color='#358579',rooms=[31,34,20,19,12,18,35,34,31],note='主通路可探索；20奖励需H、19铜齿需H+D；12为独立射铃挑战。'),
 dict(id='preview',name='⑤ 初期可选 · 看见未来的路',color='#9a5488',rooms=[1,31,32],note='初到站可选步入铃场，在32近桥头看见真实H断桥；下层路开放、预览可退，不代记探索。')]


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
    out.append('<text x="145" y="94" font-size="23" letter-spacing="8" fill="#777c65">GUNMAN RUSH  /  REGION P</text><text x="140" y="174" font-size="63" font-weight="700">风铃平原 · 整区空间审核图</text><text x="145" y="228" font-size="25">35间房 · 连续地貌与短窄通道 · 43条连接已确认 · 轮廓与学习 / 辨路设计，待同步施工</text>')
    out.append('<text x="5850" y="113" text-anchor="end" font-size="29" fill="#a15170">轮廓审核 / 02</text><text x="5850" y="159" text-anchor="end" font-size="23">实线廊道＝实体通路意图；彩箭头＝推荐行进顺序</text><text x="5850" y="200" text-anchor="end" font-size="23">H＝钩索　D＝二段跳　灰虚线＝外区接口方向，未施工</text>')
    # Terrain contours belong to the landscape, not extra playable rooms.
    for z in ZONES.values():
        mass=unary_union([geometry[rid(n)] for n in z['rooms']])
        for distance,opacity in [(180,.12)]:
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
        z=zone(int(r[-2:]));out.append(f'<g class="room" data-room="{r}" tabindex="0" role="button" aria-label="{r} {esc(rooms[r]["name"])} {esc(CAPTIONS[int(r[-2:])])}"><title>{r} {esc(rooms[r]["name"])}</title><path class="roomshape" d="{path_poly(p)}" fill="{z["fill"]}" stroke="{z["edge"]}" stroke-width="2" /><path d="{path_poly(p.difference(p.buffer(-25,join_style=2)))}" fill="url(#hatch)" fill-rule="evenodd"/></g>')
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
        out.append(f'<g class="ghost"><path d="M{ox-33} {oy-33}L{ox+33} {oy+33}M{ox+33} {oy-33}L{ox-33} {oy+33}" stroke="#ab5779" stroke-width="5"/><text x="{ox+40}" y="{oy+5}" font-size="19" fill="#ab5779">已确认取消</text></g>')
    # Labels are drawn last; every room has its one-line responsibility inside it.
    badge_map={1:[('休','rest'),('NPC','npc'),('服务×14','service')],2:[('休','rest')],4:[('TG01 齿轮 · 探索','gear')],5:[('TG02 齿轮 · 挑战↩','gear')],6:[('试制任务件','trial')],11:[('B2 · 巡游机','boss'),('三联机芯','gear')],12:[('装备P01 · 挑战↩','gear')],13:[('HP01 生命片 · 挑战↩','gear')],14:[('B1 · 牧风者','boss'),('获得H','ability')],15:[('H · 修钟','clock')],10:[('房内H路线','ability')],16:[('休','rest')],17:[('装备P03 · 隐藏/H↩','gear')],19:[('TG04 · H+D↩','ability')],20:[('装备P02 · H↩','ability')],23:[('阿栖','npc')],27:[('休','rest')],30:[('TG03 · H↩','ability')],32:[('初期预览H · 战后重见','ability')],33:[('世界钟方向','clock')]}
    badge_colors={'rest':'#3f8371','npc':'#8d6a93','service':'#777452','gear':'#ad7733','boss':'#ae5451','ability':'#507d99','clock':'#8b7443','trial':'#79847b'}
    for r,row in rooms.items():
        n=int(r[-2:]);x,y=xy(LABEL_ANCHORS[n]);p=geometry[r]
        assert p.contains(Point(LABEL_ANCHORS[n])),r
        badges=badge_map.get(n,[])
        label_w=max(len(CAPTIONS[n])*18+10,len(row['name'])*26+35,220)
        widths=[len(text)*14+18 for text,kind in badges]
        label_w=max(label_w,sum(widths)+6*max(0,len(widths)-1))
        factor=1.0
        while factor>.4:
            corner1=(LABEL_ANCHORS[n][0]-label_w*factor/2/SCALE,LABEL_ANCHORS[n][1]-51*factor/SCALE)
            corner2=(LABEL_ANCHORS[n][0]+label_w*factor/2/SCALE,LABEL_ANCHORS[n][1]+60*factor/SCALE)
            if p.covers(box(*corner1,*corner2)):break
            factor-=.025
        assert factor>.4,('No readable label chamber',r)
        out.append(f'<g class="room-label" data-label="{r}" transform="translate({x} {y}) scale({factor:.3f})"><rect x="{-label_w/2}" y="-51" width="{label_w}" height="111" rx="7" fill="{zone(n)["fill"]}" opacity=".9"/><text x="0" y="-25" text-anchor="middle" font-size="27" font-weight="700"><tspan font-size="17" fill="#6e7c68">{n:02} </tspan>{esc(row["name"])}</text><text x="0" y="4" text-anchor="middle" font-size="18">{CAPTIONS[n]}</text>')
        left=-(sum(widths)+6*max(0,len(widths)-1))/2
        out.append('<g class="poi">')
        for (text,kind),ww in zip(badges,widths):
            out.append(f'<rect x="{left}" y="18" width="{ww}" height="26" rx="5" fill="{badge_colors[kind]}"/><text x="{left+ww/2}" y="37" text-anchor="middle" style="fill:white" font-size="14">{text}</text>');left+=ww+6
        out.append('</g></g>')
    # First-visit preview and post-ability choice are spatial cues in this design.
    for key,title,detail,p in [
       ('learn','教学后做一次独立实践','22三河湾：初练 → 变式 → 空中射铃＋反冲；23/24舒缓抵站',(6400,9120)),
       ('first','初访：先知道这里有路','01 → 31 → 32可选探路；H铜环可见，下层普通通路保持开放',(12500,4220)),
       ('again','得H后：回到熟悉枢纽再选择','15 → 32重见铜环；31分流回站 / 东行 / 下集水路',(15400,3840))]:
        x,y=xy(p)
        out.append(f'<g class="poi wayfinding" data-cue="{key}"><text x="{x}" y="{y}" font-size="22" font-weight="700" fill="#536e62">{title}</text><text x="{x}" y="{y+32}" font-size="17" fill="#536e62">{detail}</text></g>')
    # Exterior stubs are deliberately separated from the region's 43 internal passages.
    for n,label,p,q in [(3,'→ 蘑菇 / 下水道',(4200,7820),(4200,9200)),(4,'→ 森林',(3000,6100),(2300,6600)),(5,'墓园接口 ↙',(7250,3300),(6950,3300)),(9,'矿井侧开通 →',(23300,9160),(25200,9350)),(18,'→ 古堡 / 工城',(19500,5600),(20300,4300)),(33,'世界钟心 ←',(14700,5400),(14400,4500))]:
        x,y=xy(q);out.append(f'<g class="poi"><path d="{path_line([p,q])}" fill="none" stroke="#8d9c8b" stroke-width="2" stroke-dasharray="9 8"/><text x="{x}" y="{y-12}" font-size="20" fill="#7a8879">{label}</text></g>')
    # Printed reading key and full-route index remain in the downloadable image.
    out.append('<path d="M145 2225H5850" stroke="#c4c9b8" stroke-width="2"/><text x="145" y="2280" font-size="29" font-weight="700">路线与要素</text>')
    for i,route in enumerate(ROUTES[:4]):
        x=145+(i%2)*2800;y=2335+(i//2)*114
        seq=' → '.join(f'{n:02}' for n in route['rooms'])
        out.append(f'<circle cx="{x+10}" cy="{y-8}" r="9" fill="{route["color"]}"/><text x="{x+35}" y="{y}" font-size="24" font-weight="700">{route["name"]}</text><text x="{x+35}" y="{y+34}" font-size="21">{seq}</text><text x="{x+35}" y="{y+65}" font-size="18">{route["note"]}</text>')
    out.append('<text x="145" y="2610" font-size="21">休＝明确休息点（01 / 02 / 16 / 27）　B1＝主线Boss　B2＝可选Boss　↩＝领奖侧开本房返程　A / B / C＝已确认的连接调整</text><text x="5850" y="2610" text-anchor="end" font-size="19">示意尺度；房内箭头只表达路线顺序，不代替最终碰撞与动作验证。</text></svg>')
    return '\n'.join(out)


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--out',type=Path,default=ROOT/'build/plains-map-review');args=parser.parse_args();args.out.mkdir(parents=True,exist_ok=True)
    w,rooms,edges,current,ports=sources();geometry,proposed,corridors,ends=candidate(current,edges,ports)
    checks=validate(rooms,proposed,geometry,corridors);info=room_info(w,rooms)
    svg=svg_map(rooms,proposed,geometry,corridors,ends,current,ports,info)
    data=dict(id=PROPOSAL,runtime_build='f9e92d4a30ab',baseline_commit='00f2a3c09e5fb352e6c450de7f1aaeaa30afc6b3',runtime_source_commit='1acefe0315ab51d1f280e2c5a3e56b5c2a65fb55',exporter_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),status='topology_approved_contours_in_review_not_runtime',changes=CHANGES,routes=ROUTES,rooms=info,edges=[{k:e[k] for k in ['id','a','b','requires','a_section','b_section'] if k in e} for e in proposed],checks=checks,source_hashes={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in ['config/world/world.json','config/world/construction.json','game/world/regions/P/room_design.json','config/world/collection_design.json']})
    (args.out/'map.svg').write_text(svg);(args.out/'review.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    template=(Path(__file__).with_name('review.html')).read_text();(args.out/'index.html').write_text(template.replace('__SVG__',svg).replace('__DATA__',json.dumps(data,ensure_ascii=False).replace('</','<\\/')))
    print(json.dumps(checks,ensure_ascii=False))
if __name__=='__main__':main()
