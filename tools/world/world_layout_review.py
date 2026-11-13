#!/usr/bin/env python3
"""Generate a self-contained, touch-enabled review and SVG from the spatial source."""
import argparse,json,html
from pathlib import Path
from collections import Counter
from forest_review import overlap
ROOT=Path(__file__).resolve().parents[2]
def build(project,out):
 p=json.loads(Path(project).read_text());d=json.loads((ROOT/'config/world/spatial_layout.json').read_text());out=Path(out);out.mkdir(parents=True,exist_ok=True)
 rooms=p['rooms'];conflicts=[];baseline=[]
 def rects(r):return [[x+r['origin'][0],y+r['origin'][1],w,h] for x,y,w,h in r['spaces']]
 ids=list(rooms)
 for i,a in enumerate(ids):
  for b in ids[i+1:]:
   if rooms[a]['layer']!=rooms[b]['layer']:continue
   if any(overlap(s,t) for s in rects(rooms[a]) for t in rects(rooms[b])):
    (baseline if d['rooms'][a]['status']==d['rooms'][b]['status']=='authored_anchor' else conflicts).append([a,b])
 assert not conflicts,conflicts
 assert all(len(r['ports'])==len(d['rooms'][rid]['ports']) for rid,r in rooms.items())
 paths=Counter(c['kind'] for c in d['connections'].values());unresolved=[cid for cid,c in d['connections'].items() if c['kind']=='interface_needs_review']
 report={'rooms':len(rooms),'regions':len(p['planning']['regions']),'connections':len(p['connections']),'new_room_overlap':conflicts,'existing_anchor_overlaps':baseline,'connection_types':dict(paths),'unresolved_interfaces':unresolved,'crossing_connections_to_review':[cid for cid,c in d['connections'].items() if c.get('grade_separation_candidates')],'long_passages_over_6000':[cid for cid,c in d['connections'].items() if c['kind']=='passage_draft' and c['length']>6000],'runtime_gameplay_verified':False}
 (out/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
 colors={r['code']:r['color'] for r in p['planning']['regions']}
 def marks(r):return ('休息 ' if r['rest'] else '')+('Boss ' if 'boss' in r['role'] else '')+' '.join(k for k,v in p['rewards'].items() if v['room']==r['id'])
 world=[r for r in rooms.values() if r['layer']=='world'];x=min(r['origin'][0] for r in world)-500;y=min(r['origin'][1] for r in world)-500;right=max(r['origin'][0]+r['bounds'][2] for r in world)+500;bottom=max(r['origin'][1]+r['bounds'][3] for r in world)+500
 elements=[f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{x} {y} {right-x} {bottom-y}"><rect x="{x}" y="{y}" width="{right-x}" height="{bottom-y}" fill="#101d24"/>']
 for cid,c in d['connections'].items():
  if c['kind']=='occluded_scene_transition':continue
  points=' '.join(f'{a},{b}' for a,b in c['path']);elements.append(f'<polyline points="{points}" fill="none" stroke="#728582" stroke-width="{max(48,c["width"])}"/>')
 for r in world:
  color=colors[r['region']]
  for a,b,w,h in rects(r):elements.append(f'<rect x="{a}" y="{b}" width="{w}" height="{h}" fill="{color}" fill-opacity=".30" stroke="{color}" stroke-width="12"/>')
  a,b=r['origin'];bw,bh=r['bounds'][2:];txt=[r['id']+' '+r['name'],r['purpose'],marks(r)]
  for i,t in enumerate(txt):elements.append(f'<text x="{a+bw/2}" y="{b+bh/2+i*100}" text-anchor="middle" fill="#eef0db" font-family="sans-serif" font-size="80">{html.escape(t)}</text>')
 elements.append('</svg>');(out/'world.svg').write_text(''.join(elements))
 data={'rooms':{rid:{k:r[k] for k in ['id','name','region','purpose','role','rest','authored','origin','bounds','spaces','routes','layer']} for rid,r in rooms.items()},'connections':{cid:{k:c[k] for k in ['id','a','b','condition_text','spatial_draft'] if k in c} for cid,c in p['connections'].items()},'rewards':{k:{'room':r['room']} for k,r in p['rewards'].items()},'npcs':{k:{a:n[a] for a in ['id','name','room_id'] if a in n} for k,n in p['npcs'].items()},'regions':p['planning']['regions'],'validation':report}
 template=Path(__file__).with_name('world_layout_review.html').read_text();(out/'index.html').write_text(template.replace('__DATA__',json.dumps(data,ensure_ascii=False).replace('</','<\\/')))
 print(json.dumps(report,ensure_ascii=False))
if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('--project',default=ROOT/'build/world-layout/world-project.json');a.add_argument('--output',default=ROOT/'build/world-layout/review');args=a.parse_args();build(args.project,args.output)
