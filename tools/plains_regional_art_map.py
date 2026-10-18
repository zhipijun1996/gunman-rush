"""Visualize an actual native regional receipt; diagnostics never replace Godot art."""
import argparse
import html
import json
from pathlib import Path


def render(receipt):
    snapshot = receipt['actual_snapshot']
    plan = snapshot['art_plan']
    x, y, w, h = plan['bounds']
    margin = 160
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{x-margin} {y-margin} {w+2*margin} {h+2*margin}">',
             '<style>text{font:70px sans-serif;paint-order:stroke;stroke:#fff;stroke-width:9px;fill:#172a2b} .edge{stroke:#197fa3;stroke-width:14;fill:none;opacity:.65} .body{fill:#b7a073;stroke:#564c37;stroke-width:4} .clear{fill:#e97272;opacity:.12}</style>',
             f'<rect x="{x-margin}" y="{y-margin}" width="{w+2*margin}" height="{h+2*margin}" fill="#eef3ef"/>']
    def points(rows):
        return ' '.join(f'{a},{b}' for a,b in rows)
    colors = ['#d4e0db', '#b4cec2', '#97b8aa']
    parts.append('<g id="layers"><title>Actual global layer constraints, diagnostic projection</title>')
    for index, belt in enumerate(plan['layer_belts']):
        line = belt['world_polyline']
        polygon = line + [[line[-1][0],y+h], [line[0][0],y+h]]
        parts.append(f'<polygon points="{points(polygon)}" fill="{colors[index%3]}" opacity=".35"/>')
    parts.append('</g><g id="geology"><title>Actual plan-owned geological contours</title>')
    for body in plan['geological_bodies']:
        loops = [body['polygon']] + body.get('holes', [])
        path = ' '.join('M '+' L '.join(f'{a} {b}' for a,b in loop)+' Z' for loop in loops)
        parts.append(f'<path class="body" fill-rule="evenodd" d="{path}"/>')
    parts.append('</g><g id="routes"><title>Actual topology edges, not proof of traversal</title>')
    areas = {row['id']:row for row in plan['topology']['areas']}
    for edge in plan['topology']['connections']:
        a,b = areas[edge['a']]['position'],areas[edge['b']]['position']
        parts.append(f'<path class="edge" d="M {a[0]} {a[1]} L {b[0]} {b[1]}"><title>{html.escape(str(edge.get("kind", "")))}</title></path>')
    for row in areas.values():
        a,b = row['position']
        parts.append(f'<circle cx="{a}" cy="{b}" r="35" fill="#197fa3"/><text x="{a+45}" y="{b-45}">{html.escape(row["id"]+" / "+str(row.get("role","")))}</text>')
    parts.append('</g><g id="landmarks"><title>Actual rooted art attachments</title>')
    for row in plan['landmarks']:
        a,b = row['position']
        parts.append(f'<circle cx="{a}" cy="{b}" r="70" fill="none" stroke="#b76724" stroke-width="13"><title>{html.escape(row["id"])}</title></circle>')
    parts.append('</g></svg>')
    return '\n'.join(parts)+'\n'


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('receipt',type=Path)
    parser.add_argument('output',type=Path)
    args=parser.parse_args()
    receipt=json.loads(args.receipt.read_text())
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(render(receipt))
    print('REGIONAL MAP DIAGNOSTIC: '+str(args.output))

if __name__=='__main__':
    main()
