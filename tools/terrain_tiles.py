"""Blob47 coverage and multi-cell packing contracts; does not score artwork."""
from pathlib import Path
import json

OFFSETS = [(0,-1),(1,0),(0,1),(-1,0),(-1,-1),(1,-1),(1,1),(-1,1)]
DIAGONALS = [(4,0,3),(5,0,1),(6,1,2),(7,2,3)]


def normalize(mask):
    for diagonal, a, b in DIAGONALS:
        if not (mask & (1 << a) and mask & (1 << b)):
            mask &= ~(1 << diagonal)
    return mask


def mask_at(cells, cell):
    x,y=cell
    return normalize(sum(1<<i for i,(dx,dy) in enumerate(OFFSETS) if (x+dx,y+dy) in cells))


def quadrants(mask):
    result=[]
    for diagonal,a,b in DIAGONALS:
        first,second=bool(mask & 1<<a),bool(mask & 1<<b)
        result.append('outer' if not first and not second else 'edge_a' if not first else 'edge_b' if not second else 'inner' if not mask & 1<<diagonal else 'fill')
    return result


def pack(cells, sizes=((2,2),(1,2),(2,1),(1,1))):
    """Art macrotiles only cover occupied cells. Never change collision/topology."""
    if (1,1) not in sizes or any(w<1 or h<1 for w,h in sizes):
        raise ValueError('Positive macro sizes and a 1x1 fallback are required')
    remaining=set(cells); result=[]
    while remaining:
        x,y=min(remaining,key=lambda p:(p[1],p[0]))
        for w,h in sizes:
            footprint={(x+dx,y+dy) for dy in range(h) for dx in range(w)}
            if footprint <= remaining:
                result.append({'at':[x,y], 'size':[w,h], 'masks':[mask_at(cells,(x+dx,y+dy)) for dy in range(h) for dx in range(w)]})
                remaining-=footprint
                break
    return result


def polyominoes(limit=6):
    forms={frozenset({(0,0)})}; result=set(forms)
    for _ in range(1,limit):
        next_forms=set()
        for form in forms:
            for x,y in form:
                for dx,dy in OFFSETS[:4]:
                    enlarged=set(form)|{(x+dx,y+dy)}
                    if len(enlarged)!=len(form)+1:continue
                    lo_x=min(a for a,b in enlarged);lo_y=min(b for a,b in enlarged)
                    next_forms.add(frozenset((a-lo_x,b-lo_y) for a,b in enlarged))
        result|=next_forms;forms=next_forms
    return result


def manifest():
    masks=sorted({normalize(i) for i in range(256)})
    return {'schema_version':1,'status':'candidate; GPU seams and user art approval required',
            'grid_world_units':32,'material_pixel_density':4,
            'neighbour_order':['N','E','S','W','NW','NE','SE','SW'],
            'join_contract':{'material':'painted-limestone-candidate-v4','position':'world-space shared sampling','grass':'up-facing boundary only','macro_boundary':'shared canonical connector band; variants only in interior','collision':'unchanged; grid masks plus exact axis-aligned rectangle union adapter; slopes and mixed materials excluded'},
            'macro_sizes':[[1,1],[1,2],[2,1],[2,2],[4,2]],
            'tiles':[{'id':f'blob-{m:03d}','mask':m,'quadrants':quadrants(m)} for m in masks]}


if __name__=='__main__':
    output=Path('game/presentation/world/resources/art/plains_tile_catalog.json')
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(json.dumps(manifest(),ensure_ascii=False,indent=2)+'\n')
    print('PASS: generated 47 canonical neighbourhood definitions; no artwork acceptance claim')
