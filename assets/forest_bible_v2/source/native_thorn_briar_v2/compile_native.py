"""Deterministic literal native-pixel compiler. No reference-image read/resize.
Both hazardous profiles and the two actual elbow contours are original rows.
"""
from pathlib import Path
from PIL import Image,ImageDraw
import hashlib,json
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3]
NATIVE=ROOT/'assets/forest_bible_v2/native';PREVIEW=ROOT/'build/region_bible_v2/forest-art/thorn-briar-native-v2';PREVIEW.mkdir(parents=True,exist_ok=True)
palette=json.loads((HERE/'palette.json').read_text())['palette_RGBA'];meta=json.loads((HERE/'regions.authored.json').read_text())
atlas=Image.new('RGBA',(256,96));regions={};images={};proof={};x=y=row_h=0
for name,m in meta.items():
 w,h=m['size'];rows=(HERE/(name+'.authored.rows')).read_text().splitlines();assert len(rows)==h and all(len(r)==w for r in rows)
 im=Image.new('RGBA',(w,h));im.putdata([tuple(palette[c])for r in rows for c in r]);images[name]=im
 if x+w>256:x=0;y+=row_h+2;row_h=0
 assert y+h<=96
 atlas.paste(im,(x,y));face=m['face'];seam=m['seam_native'];anchor=[];tails=[]
 if face=='up':outer=[0,0,w,seam];inner=[0,seam,w,h-seam];port=[0,seam+5]
 elif face=='down':outer=[0,seam,w,h-seam];inner=[0,0,w,seam];port=[0,seam-5]
 elif face=='left':outer=[0,0,seam,h];inner=[seam,0,w-seam,h];port=[seam+3,0]
 else:outer=[0,0,0,0];inner=[0,0,w,h];port=[0,4]
 if face in['up','down']:
  assert [r[0]for r in rows]==[r[-1]for r in rows]
  for column in range(w):
   choices=[yy for yy in range(inner[1],inner[1]+inner[3])if rows[yy][column]in'KDBTL'];anchor.append(min(choices,key=lambda yy:abs(yy+.5-port[1]))+1 if choices else port[1])
  coords={(xx,yy)for yy in range(outer[1],outer[1]+outer[3])for xx in range(w)if rows[yy][xx]in'pP'};components=[]
  while coords:
   queue=[coords.pop()];component=queue[:]
   while queue:
    xx,yy=queue.pop()
    for dy in[-1,0,1]:
     for dx in[-1,0,1]:
      point=(xx+dx,yy+dy)
      if point in coords:coords.remove(point);queue.append(point);component.append(point)
   components.append([min(p[0]for p in component),max(p[0]for p in component)])
  tails=[n for n in range(1,w+1)if all(hi<n or lo>=n for lo,hi in components)]
  tip_y=[yy for yy in range(h)for xx in range(w)if rows[yy][xx]=='P'];assert min(tip_y)==0 if face=='up'else max(tip_y)==h-1
  if face=='down':assert rows[2][0]=='T'and rows[3][0]=='D'
 else:components=[]
 regions[name]={'atlas_rect':[x,y,w,h],'size':[w,h],'face':face,'seam_native':seam,'outer_rect':outer,'root_rect':inner,'port':port,'root_anchor_y_by_x':anchor,'safe_tail_columns':tails}
 proof[name]={'size':[w,h],'alpha_values':sorted(set(im.tobytes()[3::4])),'opaque_fraction':sum(c!='.'for r in rows for c in r)/(w*h),'rows_sha256':hashlib.sha256((HERE/(name+'.authored.rows')).read_bytes()).hexdigest(),'native_rgba_sha256':hashlib.sha256(im.tobytes()).hexdigest(),'pale_component_x_bounds':components,'safe_tail_columns':tails,'left_right_RGBA_equal':face not in['up','down']or[r[0]for r in rows]==[r[-1]for r in rows]}
 im.save(PREVIEW/(name+'.native1x.png'));im.resize((w*8,h*8),Image.Resampling.NEAREST).save(PREVIEW/(name+'.display8x.png'))
 x+=w+2;row_h=max(row_h,h)
# Simulate actual finite native widths. Width accumulation uses EACH authored
# width64/48, not the old32 or old-tail proof. All partial pale heads are whole.
pattern=[0,1,1,0,0,1,0,1]
layouts={}
for family in['up12','down10','down8']:
 layouts[family]={}
 for total in[275,195,130,80,30]:
  at=0;parts=[]
  while at<total:
   preferred=family+('_a'if pattern[len(parts)%len(pattern)]==0 else'_b');other=family+('_b'if preferred.endswith('_a')else'_a');left=total-at
   selected=next((n for n in[preferred,other]if left>=regions[n]['size'][0]or left in regions[n]['safe_tail_columns']),None)
   assert selected,(family,total,at)
   width=min(left,regions[selected]['size'][0]);parts.append({'name':selected,'at_native':at,'visible_native_width':width,'full_pale_heads':True});at+=width
  layouts[family][str(total)]=parts
proof['actual_finite_width_layouts']=layouts
atlas.save(NATIVE/'thorn_briar_atlas_v2.png');(HERE/'thorn_briar_atlas_v2.original.png').write_bytes((NATIVE/'thorn_briar_atlas_v2.png').read_bytes())
record={'status':'CANDIDATE_SECOND_AND_FINAL_NATIVE_ACTUAL_SAMPLE_PENDING','atlas_size':[256,96],'native_scale_world':2,'atlas_sha256':hashlib.sha256((NATIVE/'thorn_briar_atlas_v2.png').read_bytes()).hexdigest(),'regions':regions,'scope':'Same native family refined; long64/48 originals; exact up12/down10/down8/left20, two real bounded bare elbows. No material/physics changes.','risks':['antler/repetition','main-root continuity','final actual HUD independent review pending']}
(NATIVE/'thorn_briar_atlas_v2.json').write_text(json.dumps(record,indent=2)+'\n');(HERE/'alpha_ports_depth_proof.json').write_text(json.dumps(proof,indent=2)+'\n')
board=Image.new('RGBA',(560,190),(28,34,32,255));d=ImageDraw.Draw(board)
for i,(name,im)in enumerate(images.items()):
 px=(i%5)*112;py=(i//5)*92;d.text((px+2,py+1),name,fill=(220,224,197));board.alpha_composite(im,(px+4,py+17));d.text((px+2,py+77),str(im.size),fill=(160,175,147))
board.save(PREVIEW/'all-variants-native1x.png');board.resize((2240,760),Image.Resampling.NEAREST).save(PREVIEW/'all-variants-display4x.png')
print(record['atlas_sha256'])
