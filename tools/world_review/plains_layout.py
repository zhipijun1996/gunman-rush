"""Draw the approved region from the sole physical construction source.

Label anchors and projection scale below are presentation only. Room footprints,
paired doors and short connecting chambers are owned by construction.json.
"""
import json,sys
from pathlib import Path
from shapely.geometry import Polygon,Point
from shapely.ops import unary_union
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/world'))
from spatial import navigation_geometry
ANCHORS={1:(1480,1320),2:(3480,1530),3:(490,1495),4:(310,1090),5:(1450,590),6:(1720,625),7:(3335,1250),8:(1750,1200),9:(3750,2100),10:(3750,1250),11:(4140,890),12:(2960,1640),13:(1100,980),14:(1340,350),15:(2010,1030),16:(3750,940),17:(3870,1605),18:(2980,1410),19:(2610,1950),20:(2190,1900),21:(890,1570),22:(1100,1820),23:(1490,1810),24:(1380,1590),25:(570,850),26:(1020,770),27:(1170,560),28:(3400,1830),29:(3710,1830),30:(3220,1580),31:(1870,1420),32:(2240,1230),33:(2630,1190),34:(2170,1630),35:(2530,1510)}


def build_layout(edges):
    construction=json.loads((ROOT/'config/world/construction.json').read_text())
    source={r['room_id']:r for r in construction['rooms'] if r['room_id'].startswith('P-')}
    pairs={p['edge_id']:p for p in construction['door_pairs']}
    contracts={}
    for rid,r in source.items():
        doors=[]
        for e in edges:
            if rid not in (e['a'],e['b']):continue
            d=next(d for d in r['doors'] if d['id']==e['id']+':'+rid)
            other=e['b'] if rid==e['a'] else e['a']
            doors.append(dict(d,target_room=other,target_door_id=e['id']+':'+other,direction=pairs[e['id']]['construction_sides'][rid]))
        contracts[rid]=dict(world_geometry=dict(space_rects=r['space_rects'],bounds_world_units=[0,0,*r['extent']]),doors=doors)
    layout=navigation_geometry(contracts,'P-R03')
    project=lambda p:(p[0]/6.4+320,p[1]/6.4+1260)
    geometry={r:Polygon([project(p) for p in row['polygon']]) for r,row in layout.items()}
    corridors={};ends={};paths={}
    for e in edges:
        d=next(d for d in contracts[e['a']]['doors'] if d['id']==e['id']+':'+e['a'])
        x,y=d['position_candidate']['local_world_units'];ox,oy=layout[e['a']]['origin'];p=project((x+ox,y+oy))
        # These are existing shared threshold areas, not extra map geometry.
        corridors[e['id']]=Point(p).buffer(8).intersection(unary_union([geometry[e['a']],geometry[e['b']]]))
        ends[e['id']]=(p,p);paths[e['id']]=[p,p]
    return geometry,corridors,ends,paths
