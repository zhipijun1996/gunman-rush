"""Decode original literal native palette rows; no source-image transforms.
Source-board magnification is nearest-only and never used as runtime pixels.
"""
from pathlib import Path
from PIL import Image,ImageDraw
import hashlib,json
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
NATIVE=ROOT/'assets/forest_bible_v2/native'
PREVIEW=ROOT/'build/region_bible_v2/forest-art/thorn-briar-native-integration'
PREVIEW.mkdir(parents=True,exist_ok=True)
palette=json.loads((HERE/'palette.json').read_text())['palette_RGBA']
metadata=json.loads((HERE/'regions.authored.json').read_text())
atlas=Image.new('RGBA',(128,96))
regions={};images={};proof={}
for i,(name,record) in enumerate(metadata.items()):
 w,h=record['size'];rows=(HERE/(name+'.authored.rows')).read_text().splitlines()
 assert len(rows)==h and all(len(r)==w for r in rows)
 im=Image.new('RGBA',(w,h));im.putdata([tuple(palette[c])for row in rows for c in row]);images[name]=im
 x=(i%4)*32;y=(i//4)*32
 atlas.paste(im,(x,y))
 face=record['face'];seam=record['seam_native']
 if face=='up':outer=[0,0,w,seam];root=[0,seam,w,h-seam];port=[0,seam+5]
 elif face=='down':outer=[0,seam,w,h-seam];root=[0,0,w,seam];port=[0,seam-5]
 elif face=='left':outer=[0,0,seam,h];root=[seam,0,w-seam,h];port=[seam+3,0]
 else:outer=[0,0,0,0];root=[0,0,w,h];port=[0,4] if name=='bare_short'else[3,0]if name=='bare_vertical'else[0,3]
 anchor_y=[]
 if face in ['up','down']:
  for column in range(w):
   choices=[yy for yy in range(root[1],root[1]+root[3]) if rows[yy][column] in 'KDBTL']
   anchor_y.append(min(choices,key=lambda yy:abs(yy+0.5-port[1]))+1 if choices else port[1])
 regions[name]={'root_anchor_y_by_x':anchor_y,'atlas_rect':[x,y,w,h],'outer_rect':outer,'root_rect':root,'port':port,'face':face,'seam_native':seam,'size':[w,h]}
 im.save(PREVIEW/(name+'.native1x.png'));im.resize((w*8,h*8),Image.Resampling.NEAREST).save(PREVIEW/(name+'.display8x.png'))
 proof[name]={'size':[w,h],'alpha_values':sorted(set(im.tobytes()[3::4])),'native_rgba_sha256':hashlib.sha256(im.tobytes()).hexdigest(),'rows_sha256':hashlib.sha256((HERE/(name+'.authored.rows')).read_bytes()).hexdigest()}
# Proofs at ALL row depths: exact native depths, no scaled or cropped tips.
for name in ['up12_a','up12_b','down10_a','down10_b','down8_a','down8_b']:
 im=images[name];face=regions[name]['face'];outer=regions[name]['outer_rect'];depth=outer[3]
 edge=lambda x:[im.getpixel((x,y))for y in range(im.height)]
 assert edge(0)==edge(31),(name,'ports mismatch')
 proof[name]['edge_rgba_equal']=True
 tip_rows=[y for y in range(im.height)for x in range(im.width)if im.getpixel((x,y))==tuple(palette['P'])]
 assert (min(tip_rows)==0 if face=='up'else max(tip_rows)==im.height-1)
 proof[name]['outer_native_depth']=depth
 if face=='down':
  # Upper root face has a light facet, lower root face is dark: native relighting.
  assert im.getpixel((0,2))==tuple(palette['T']) and im.getpixel((0,3))==tuple(palette['D'])
  proof[name]['local_upper_root_light_T_lower_dark_D']=True
  # Recorded actual horizontal remainders of the current strictly bound host spans.
  if name.endswith('_a'):
   # Pale connected components cannot be sliced at current consumer end columns.
   seen=set();components=[]
   for yy in range(outer[1],outer[1]+outer[3]):
    for xx in range(im.width):
     if (xx,yy)in seen or im.getpixel((xx,yy))not in [tuple(palette['P']),tuple(palette['p'])]:continue
     q=[(xx,yy)];seen.add((xx,yy));component=[]
     while q:
      u,v=q.pop();component.append((u,v))
      for du,dv in [(-1,0),(1,0),(0,-1),(0,1)]:
       uv=(u+du,v+dv)
       if 0<=uv[0]<im.width and outer[1]<=uv[1]<outer[1]+outer[3] and uv not in seen and im.getpixel(uv)in [tuple(palette['P']),tuple(palette['p'])]:seen.add(uv);q.append(uv)
     components.append([min(p[0]for p in component),max(p[0]for p in component)])
   proof[name]['pale_component_x_bounds']=components
# Complete pale heads at actual finite-run tail widths, including up12.
for name in ['up12_a','down10_a','down8_a']:
 im=images[name];outer=regions[name]['outer_rect']
 coordinates={(xx,yy) for yy in range(outer[1],outer[1]+outer[3]) for xx in range(im.width) if im.getpixel((xx,yy))in [tuple(palette['p']),tuple(palette['P'])]}
 components=[]
 while coordinates:
  queue=[coordinates.pop()];component=queue[:]
  while queue:
   xx,yy=queue.pop()
   for dy in [-1,0,1]:
    for dx in [-1,0,1]:
     point=(xx+dx,yy+dy)
     if point in coordinates:coordinates.remove(point);queue.append(point);component.append(point)
  components.append(component)
 for tail in [2,3,16,19,30]:
  assert all(all(xx<tail for xx,yy in comp)or all(xx>=tail for xx,yy in comp)for comp in components),(name,tail)
 proof[name]['actual_tail_columns_complete_pale_heads']=[2,3,16,19,30]
atlas.save(NATIVE/'thorn_briar_atlas_v1.png')
(HERE/'thorn_briar_atlas_v1.original.png').write_bytes((NATIVE/'thorn_briar_atlas_v1.png').read_bytes())
output={'status':'CANDIDATE_NATIVE_ACTUAL_HUD_PENDING','native_scale_world':2,'atlas_size':list(atlas.size),'atlas_sha256':hashlib.sha256((NATIVE/'thorn_briar_atlas_v1.png').read_bytes()).hexdigest(),'regions':regions,'part_count':9,'region_count':10,'compact_equivalent':'bare_short part includes independently authored horizontal and vertical native cells; no flipped lighting or stretched root.','runtime_tiling':'One run per actual surface, independent of support segment boundaries. A tails retain complete pale heads at actual native remainders; all outer pixels clip only original hazard bounds.','unaccepted':['antler/repetition risks','whole forest art','actual HUD danger legibility','routes and moving camera']}
(NATIVE/'thorn_briar_atlas_v1.json').write_text(json.dumps(output,indent=2)+'\n')
(HERE/'alpha_ports_depth_proof.json').write_text(json.dumps(proof,indent=2)+'\n')
board=Image.new('RGBA',(420,150),(28,34,32,255));d=ImageDraw.Draw(board)
for i,(name,im)in enumerate(images.items()):
 x=(i%5)*84;y=(i//5)*72
 d.text((x+2,y+1),name,fill=(218,221,204));board.alpha_composite(im,(x+4,y+17))
 d.text((x+2,y+47),str(im.size),fill=(169,182,154))
board.save(PREVIEW/'all-variants-native1x.png');board.resize((1680,600),Image.Resampling.NEAREST).save(PREVIEW/'all-variants-display4x.png')
print(output['atlas_sha256'])
