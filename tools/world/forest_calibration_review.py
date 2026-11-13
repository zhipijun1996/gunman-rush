#!/usr/bin/env python3
"""Draw the existing plains and complete forest chambers at the same world scale."""
import json,html,sys
from pathlib import Path
from export_editor_project import export
from forest_review import build,svg
from preview_catalog import preview_catalog
ROOT=Path(__file__).resolve().parents[2]
def main():
 out=ROOT/'build/forest-calibration';out.mkdir(parents=True,exist_ok=True)
 preview=preview_catalog(ROOT);plan=build(ROOT,preview=preview);p=export(spatial_draft=True)
 (out/'project.json').write_text(json.dumps(p,ensure_ascii=False,separators=(',',':'))+'\n')
 forest_svg=svg(plan);(out/'forest.svg').write_text(forest_svg)
 template=(ROOT/'tools/world/forest_review.html').read_text();(out/'forest.html').write_text(template.replace('<!-- MAP -->',forest_svg).replace('/* PLAN */',json.dumps(plan,ensure_ascii=False).replace('</','<\\/')))
 rows=[{'id':r['room_id'],'polygon':r['outline'],'label':r['label'],'name':r['name'],'purpose':r['purpose'],'color':'#527c66'} for r in plan['rooms']]
 for r in preview['map_rooms']:
  if not r['id'].startswith('P-'):continue
  room=p['rooms'][r['id']];space=max(room['spaces'],key=lambda b:b[2]*b[3]);label=[room['origin'][0]+space[0]+space[2]/2,room['origin'][1]+space[1]+space[3]/2]
  rows.append({'id':r['id'],'polygon':r['polygon'],'label':label,'name':room['name'],'purpose':room['purpose'],'color':'#a39a61'})
 pts=[pt for r in rows for pt in r['polygon']];x=min(v[0] for v in pts)-400;y=min(v[1] for v in pts)-1400;w=max(v[0] for v in pts)-x+400;h=max(v[1] for v in pts)-y+400
 parts=[f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{x} {y} {w} {h}"><rect x="{x}" y="{y}" width="{w}" height="{h}" fill="#101d24"/><g font-family="sans-serif" fill="#e8e2cb"><text x="{x+400}" y="{y+450}" font-size="280">平原35房（实地基准） × 森林24房（连续空间校准）</text><text x="{x+400}" y="{y+850}" font-size="180">同一坐标／比例 · 森林通道属于房间空间 · 未宣称达到平原玩法与构图质量</text></g>']
 for r in rows:
  points=' '.join(f'{a},{b}' for a,b in r['polygon']);a,b=r['label'];parts.append(f'<polygon points="{points}" fill="{r["color"]}" fill-opacity=".4" stroke="{r["color"]}" stroke-width="18"/><text x="{a}" y="{b}" font-size="110" fill="#eee5c7" text-anchor="middle">{html.escape(r["id"]+" "+r["name"])}</text>')
 parts.append('<circle cx="0" cy="-576" r="80" fill="#ffcd74"/><text x="120" y="-650" fill="#ffcd74" font-size="160">C01 森林／平原共享接口</text></svg>');(out/'comparison.svg').write_text(''.join(parts))
 print('59 rooms compared at same scale; forest 30 internal seams + 5 external reservations')
if __name__=='__main__':main()
