"""Physical orthogonal room space, shared by boundary collision and map projection.

Authored rectangles are chambers, not independently placed map icons.  The
compiler traces their union and solves world origins from actual paired doors.
No optional geometry dependency or alternate survey projection is used.
"""
import math


def room_space(rectangles, extent):
    if not rectangles:
        raise ValueError('Implemented room needs authored space rectangles')
    for r in rectangles:
        if len(r) != 4 or any(type(v) not in (int, float) or not math.isfinite(v) for v in r) or min(r[2:]) <= 0:
            raise ValueError('Invalid physical room rectangle')
    xs = sorted({v for x, y, w, h in rectangles for v in (x, x + w)})
    ys = sorted({v for x, y, w, h in rectangles for v in (y, y + h)})
    if [xs[0], ys[0], xs[-1], ys[-1]] != [0, 0, *extent]:
        raise ValueError('Physical room extent does not match its authored union')
    occupied = {(i, j) for i in range(len(xs) - 1) for j in range(len(ys) - 1)
                if any(x <= xs[i] and xs[i+1] <= x+w and y <= ys[j] and ys[j+1] <= y+h
                       for x, y, w, h in rectangles)}
    edges = {}
    for i, j in occupied:
        x, y, xx, yy = xs[i], ys[j], xs[i+1], ys[j+1]
        for neighbour, a, b in [((i, j-1), (x,y), (xx,y)), ((i+1,j), (xx,y), (xx,yy)),
                                ((i,j+1), (xx,yy), (x,yy)), ((i-1,j), (x,yy), (x,y))]:
            if neighbour not in occupied:
                if a in edges:
                    raise ValueError('Room chambers may not connect only at a corner')
                edges[a] = b
    first = min(edges, key=lambda p: (p[1], p[0])); point = first; outline = []
    while point in edges:
        outline.append(point); point = edges.pop(point)
        if point == first: break
    if edges or point != first:
        raise ValueError('Physical room must be one connected space without enclosed holes')
    # Merge collinear grid partitions; preserve concave bends.
    outline = [p for i,p in enumerate(outline)
               if (p[0]-outline[i-1][0])*(outline[(i+1)%len(outline)][1]-p[1])
               != (p[1]-outline[i-1][1])*(outline[(i+1)%len(outline)][0]-p[0])]
    segments = []
    for i, a in enumerate(outline):
        b = outline[(i+1)%len(outline)]
        side = ('up' if b[0] > a[0] else 'down') if a[1] == b[1] else ('right' if b[1] > a[1] else 'left')
        segments.append({'side':side, 'from':list(a), 'to':list(b)})
    return {'rects':rectangles, 'outline':[list(p) for p in outline], 'boundary':segments}


def contains_rect(space, rect):
    """Exact area coverage, including a rectangle spanning adjacent chambers."""
    x,y,w,h = rect
    if w <= 0 or h <= 0: return False
    xs = sorted({x, x+w, *[v for a,b,c,d in space['rects'] for v in (a,a+c) if x<v<x+w]})
    ys = sorted({y, y+h, *[v for a,b,c,d in space['rects'] for v in (b,b+d) if y<v<y+h]})
    return all(any(a <= xs[i] and xs[i+1] <= a+c and b <= ys[j] and ys[j+1] <= b+d
                   for a,b,c,d in space['rects'])
               for i in range(len(xs)-1) for j in range(len(ys)-1))


def door_on_boundary(space, door):
    x,y = door['position_candidate']['local_world_units'];side = door['direction']
    # A walk door uses its floor point; vertical doors use aperture centre.
    lo,hi = (x-64,x+64) if side in ('up','down') else (y-96,y)
    for segment in space['boundary']:
        if side != segment['side']: continue
        a,b = segment['from'],segment['to']
        axis = 0 if side in ('up','down') else 1
        if (y if axis==0 else x) == a[1-axis] and min(a[axis],b[axis]) <= lo and hi <= max(a[axis],b[axis]):
            return True
    return False


def navigation_geometry(rooms, anchor):
    spaces = {}
    for rid,row in rooms.items():
        geom = row['world_geometry']
        if 'map_origin' in geom:
            raise ValueError('Independent map_origin is not a physical room space: '+rid)
        spaces[rid] = room_space(geom.get('space_rects',[]),geom['bounds_world_units'][2:])
        exposed = [d for d in row['doors'] if d['target_room'] in rooms]
        for i,door in enumerate(exposed):
            if not door_on_boundary(spaces[rid],door):
                raise ValueError('Door aperture is not on its physical boundary: '+door['id'])
            for other in exposed[i+1:]:
                if door['direction'] == other['direction'] and math.dist(door['position_candidate']['local_world_units'],other['position_candidate']['local_world_units']) < 192:
                    raise ValueError('Crowded physical exits: '+rid)
    origins = {anchor:(0,0)};pending = [anchor]
    while pending:
        rid = pending.pop()
        for door in rooms[rid]['doors']:
            target = door['target_room']
            if target not in rooms: continue
            paired = next(d for d in rooms[target]['doors'] if d['id']==door['target_door_id'])
            a,b = door['position_candidate']['local_world_units'],paired['position_candidate']['local_world_units']
            proposed = tuple(origins[rid][n]+a[n]-b[n] for n in (0,1))
            if target in origins:
                if proposed != origins[target]: raise ValueError('Room map seam conflicts: '+door['id'])
            else: origins[target]=proposed;pending.append(target)
    if len(origins) != len(rooms): raise ValueError('Implemented rooms need a connected physical map')
    placed = []
    result = {}
    for rid,space in spaces.items():
        ox,oy = origins[rid];core = space['rects'][0]
        result[rid] = {'origin':[ox,oy], 'polygon':[[x+ox,y+oy] for x,y in space['outline']],
                       'map_centre':[ox+core[0]+core[2]/2,oy+core[1]+core[3]/2]}
        for x,y,w,h in space['rects']:
            for other,xx,yy,ww,hh in placed:
                if other != rid and min(ox+x+w,xx+ww)>max(ox+x,xx) and min(oy+y+h,yy+hh)>max(oy+y,yy):
                    raise ValueError('Physical room spaces overlap: '+rid+'/'+other)
            placed.append((rid,ox+x,oy+y,w,h))
    return result
