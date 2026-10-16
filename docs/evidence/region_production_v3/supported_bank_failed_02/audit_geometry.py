from pathlib import Path
import json,re,hashlib
capture=Path('build/region_production_v3/current_canonical_after_ivy/capture.json');c=json.loads(capture.read_text());m=c['manifest'];rows=[];sources={}
for n in m['nodes']:
 assert not n.get('mirrored') and not n.get('reverse_traversal'),n['id']
 if 'geometry' in n:g=n['geometry'];rs=g['platforms'];one=g['one_way']
 else:
  p=Path('resources/generation/modules')/(n['module_id']+'.tres');s=p.read_text();sources[str(p)]=hashlib.sha256(p.read_bytes()).hexdigest();line=re.search(r'^platforms\s*=\s*(.*)$',s,re.M).group(1);rs=[[float(x) for x in r.split(',')] for r in re.findall(r'Rect2\(([^)]+)\)',line)];mat=re.search(r'^one_way_platform_indices\s*=\s*.*?\(\[([^]]*)\]',s,re.M);one=[] if not mat else [int(x) for x in re.findall(r'\d+',mat.group(1))]
 for i,r in enumerate(rs):
  if i not in one:rows.append({'rect':[r[0]+n['offset'][0],r[1]+n['offset'][1],r[2],r[3]],'node':n['id'],'module':n['module_id'],'index':i})
allrows=rows+[{'rect':r,'column':True} for r in m['ground_supports']]
def touch(a,b):return a[0]<=b[0]+b[2] and b[0]<=a[0]+a[2] and a[1]<=b[1]+b[3] and b[1]<=a[1]+a[3]
groups=[];todo=allrows[:]
while todo:
 g=[todo.pop()];change=True
 while change:
  change=False
  for r in todo[:]:
   if any(touch(r['rect'],v['rect']) for v in g):g.append(r);todo.remove(r);change=True
 x=min(v['rect'][0] for v in g);y=min(v['rect'][1] for v in g);xx=max(v['rect'][0]+v['rect'][2] for v in g);yy=max(v['rect'][1]+v['rect'][3] for v in g)
 groups.append({'bounds':[x,y,xx-x,yy-y],'rooted':any(v.get('column') for v in g),'parts':g})
report={'manifest_hash':m['manifest_hash'],'source_capture':str(capture),'source_capture_sha256':hashlib.sha256(capture.read_bytes()).hexdigest(),'reconstruction':'Literal recorded node geometry or actual current .tres definitions; not new native execution; all nodes unmirrored and forward verified','definition_sources':sources,'groups':groups}
Path('build/spatial_bank_repair_02/formal_manifest_solids_inventory.json').write_text(json.dumps(report,indent=2)+'\n')
print('ROOTED',[(g['bounds'],len(g['parts'])) for g in groups if g['rooted']]);print('exact420x152', [g for g in groups if g['bounds'][2:]==[420,152]])
