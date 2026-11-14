"""Small dependency-free geometry checks for regional silhouettes, not collision."""
from math import hypot

EPS = 1e-6


def edges(poly):
    return zip(poly, poly[1:] + poly[:1])


def cross(a, b, c):
    return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])


def on_segment(a, b, p):
    return abs(cross(a, b, p)) <= EPS * max(1, hypot(b[0]-a[0], b[1]-a[1])) and all(min(a[i], b[i])-EPS <= p[i] <= max(a[i], b[i])+EPS for i in (0, 1))


def boundary(poly, point):
    return any(on_segment(a, b, point) for a, b in edges(poly))


def inside(poly, point):
    if boundary(poly, point):
        return False
    x, y = point
    hit = False
    for a, b in edges(poly):
        if (a[1] > y) != (b[1] > y) and x < (b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0]:
            hit = not hit
    return hit


def signed_area(poly):
    return sum(a[0]*b[1] - b[0]*a[1] for a, b in edges(poly)) / 2


def proper_cross(a, b, c, d):
    return cross(a, b, c)*cross(a, b, d) < -EPS and cross(c, d, a)*cross(c, d, b) < -EPS


def valid_polygon(poly):
    if len(poly) < 3 or len(set(map(tuple, poly))) != len(poly) or abs(signed_area(poly)) < EPS:
        return False
    segs = list(edges(poly))
    for i, (a, b) in enumerate(segs):
        for j, (c, d) in enumerate(segs[i+1:], i+1):
            if j == i+1 or (i == 0 and j == len(segs)-1):
                continue
            if proper_cross(a, b, c, d) or any(on_segment(a, b, p) for p in (c, d)) or any(on_segment(c, d, p) for p in (a, b)):
                return False
    return True


def overlap(first, second):
    if any(proper_cross(a, b, c, d) for a, b in edges(first) for c, d in edges(second)):
        return True
    for own, other in ((first, second), (second, first)):
        direction = 1 if signed_area(own) > 0 else -1
        for a, b in edges(own):
            if inside(other, a):
                return True
            length = hypot(b[0]-a[0], b[1]-a[1])
            # Inward midpoint also detects identical or collinear-overlapping shapes.
            p = [(a[0]+b[0])/2 - direction*(b[1]-a[1])/length*.01,
                 (a[1]+b[1])/2 + direction*(b[0]-a[0])/length*.01]
            if inside(own, p) and inside(other, p):
                return True
    return False


def shared_port(first, second, point):
    if not boundary(first, point) or not boundary(second, point):
        return False
    for a, b in edges(first):
        if not on_segment(a, b, point):
            continue
        length = hypot(b[0]-a[0], b[1]-a[1])
        tx, ty = (b[0]-a[0])/length, (b[1]-a[1])/length
        # Require a shared segment on both tangential sides, and opposed interiors.
        if not all(boundary(first, [point[0]+t*tx, point[1]+t*ty]) and boundary(second, [point[0]+t*tx, point[1]+t*ty]) for t in (-1, 1)):
            continue
        for normal in (-1, 1):
            if all(inside(first, [point[0]+t*tx-normal*ty, point[1]+t*ty+normal*tx]) and inside(second, [point[0]+t*tx+normal*ty, point[1]+t*ty-normal*tx]) for t in (-1, 1)):
                return True
    return False


def segment_inside(poly, a, b):
    """Check each interval split by boundary intersections, including concavities."""
    if not all(inside(poly, p) or boundary(poly, p) for p in (a, b)):
        return False
    vx, vy = b[0]-a[0], b[1]-a[1]
    cuts = [0., 1.]
    for c, d in edges(poly):
        wx, wy = d[0]-c[0], d[1]-c[1]
        det = vx*wy-vy*wx
        if abs(det) > EPS:
            t = ((c[0]-a[0])*wy-(c[1]-a[1])*wx)/det
            u = ((c[0]-a[0])*vy-(c[1]-a[1])*vx)/det
            if -EPS <= t <= 1+EPS and -EPS <= u <= 1+EPS:
                cuts.append(max(0., min(1., t)))
        elif abs(vx)+abs(vy)>EPS:
            for p in (c,d):
                if on_segment(a,b,p):
                    cuts.append((p[0]-a[0])/vx if abs(vx)>abs(vy) else (p[1]-a[1])/vy)
    cuts=sorted(set(cuts))
    return all(inside(poly, [a[0]+vx*(lo+hi)/2, a[1]+vy*(lo+hi)/2]) or boundary(poly, [a[0]+vx*(lo+hi)/2, a[1]+vy*(lo+hi)/2]) for lo,hi in zip(cuts,cuts[1:]))
