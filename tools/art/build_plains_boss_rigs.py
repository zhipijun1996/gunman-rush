#!/usr/bin/env python3
"""Extract generated isolated parts; alpha segmentation and one-time nearest calibration only."""
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/plains_boss_rigs_142'
# Explicit source boxes allow unequal gutters. Never cut by assumed equal grid.
PARTS={
'front':[('bell_chassis',(20,70,760,570),(130,88)),('wheel',(870,20,1120,580),(12,42)),('wind_torso',(20,650,700,1240),(130,112)),('wind_head',(700,570,1254,1220),(78,106))],
'bellstrider':[
 ('chassis',(0,120,520,410),(196,88)),('arch',(520,0,870,420),(118,138)),
 ('bell',(950,60,1220,400),(48,64)),('rear_wheel',(40,430,395,790),(42,42)),
 ('front_wheel',(470,430,825,790),(42,42)),('cannon',(880,480,1254,750),(72,48)),
 ('mount',(120,910,350,1095),(44,30)),('cloth',(390,790,800,1240),(76,88)),
 ('axle',(860,910,1254,1095),(150,44))],
'windkeeper':[
 ('torso',(0,0,450,350),(178,112)),('head',(450,0,800,350),(104,106)),
 ('front_upper',(810,0,1040,350),(44,70)),('front_lower',(1150,0,1400,350),(44,64)),
 ('rear_upper',(40,360,310,700),(46,70)),('rear_lower',(370,360,625,700),(44,64)),
 ('cape',(660,350,1110,710),(148,124)),('banner',(1150,360,1400,710),(38,66)),
 ('pole',(40,710,300,1086),(48,108)),('rotor',(320,700,750,1086),(130,130)),
 ('tail',(780,740,1100,1030),(72,50)),('medallion',(1170,730,1400,1020),(32,40))]}
rows=[]
for kind,parts in PARTS.items():
 source=OUT/'source'/f'{kind}.png'
 src=np.array(Image.open(source).convert('RGBA'))
 for name,box,size in parts:
  x,y,r,b=box; a=src[y:b,x:r].copy()
  # Generated export has low-alpha coloured matte and isolated red/yellow
  # fringe. Remove only background-connected matte; never recolour art.
  rgb=a[:,:,:3].astype(int)
  matte=((rgb[:,:,0]>225)&(rgb[:,:,1]<70)&(rgb[:,:,2]<70))|((rgb[:,:,0]>225)&(rgb[:,:,1]>210)&(rgb[:,:,2]<35))
  candidate=(a[:,:,3]<192)|matte
  edge=np.zeros(candidate.shape,dtype=bool)
  edge[0,:]=candidate[0,:];edge[-1,:]=candidate[-1,:]
  edge[:,0]=candidate[:,0];edge[:,-1]=candidate[:,-1]
  exterior=ndimage.binary_propagation(edge,mask=candidate)
  mask=(a[:,:,3]>=192)&~exterior
  labels,n=ndimage.label(mask)
  counts=np.bincount(labels.ravel());counts[0]=0
  mask=labels==counts.argmax()
  a[:,:,3]=np.where(mask,255,0)
  im=Image.fromarray(a); bounds=im.getbbox(); im=im.crop(bounds).resize(size,Image.Resampling.NEAREST)
  target=OUT/f'{kind}_{name}.png'; im.save(target)
  rows.append(dict(id=f'{kind}_{name}',source=source.relative_to(ROOT).as_posix(),source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),box=box,alpha_bounds=bounds,size=size,sha256=hashlib.sha256(target.read_bytes()).hexdigest()))
(OUT/'manifest.json').write_text(json.dumps(rows,indent=2)+'\n')
print('Baked',len(rows),'fixed native parts; RGB comes only from imagegen source')
