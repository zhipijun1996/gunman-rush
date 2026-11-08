"""Crop fresh image-generated masters; preserve source, nearest bake, assemble review.

No A-D enemy art is read. The unchanged game hero is a scale reference only.
"""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'art/reviews/plains_enemies_pr142_restart'
for folder in ['cutouts','static']:(OUT/folder).mkdir(exist_ok=True)
records={}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def bake(name,label,source,box,height=None,scale=None):
    data=np.array(Image.open(OUT/'source'/source).convert('RGBA').crop(box))
    labels,_=ndimage.label(data[:,:,3]>=128)
    sizes=np.bincount(labels.ravel());sizes[0]=0;keep=sizes[labels]>=20
    data[:,:,3]=np.where(keep,255,0);data[~keep]=0
    im=Image.fromarray(data);bounds=im.getbbox();assert bounds
    im=im.crop(bounds);im.save(OUT/'cutouts'/f'{name}.png')
    factor=scale if scale is not None else height/im.height
    native=im.resize((round(im.width*factor),round(im.height*factor)),Image.Resampling.NEAREST)
    target=OUT/'static'/f'{name}.png';native.save(target)
    records[name]={'label':label,'source':source,'crop_xyxy':[box[0]+bounds[0],box[1]+bounds[1],box[0]+bounds[2],box[1]+bounds[3]],'source_size':im.size,'scale':factor,'native_size':native.size,'anchor_px':[native.width//2,native.height],'sha256':sha(target)}

rows=[('patrol','01 巡逻体',40),('charger','02 冲锋体',56),('hopper','03 跃击体',62),('sentry','04 单发哨兵',58),('fan_sentry','05 扇射哨兵',62),('root_bell','06 根铃',90),('diver','07 俯冲体',42)]
w,h=Image.open(OUT/'source/ordinary.png').size
for i,(name,label,height) in enumerate(rows):
    if i<4:
        edges=[0,314,650,945,w]
        box=(edges[i],round(h*.25),edges[i+1],round(h*.55))
    else:
        col=i-4;box=(round(col*w/3),round(h*.57),round((col+1)*w/3),h)
    bake(name,label,'ordinary.png',box,height=height)
w,h=Image.open(OUT/'source/bellstrider.png').size
bake('bellstrider','08 鸣铃巡游机','bellstrider.png',(0,round(h*.21),w,h),height=220)
w,h=Image.open(OUT/'source/windkeeper.png').size
bake('windkeeper_phase1','09 牧风者一阶段','windkeeper.png',(0,round(h*.25),w//2,h),height=190)
bake('windkeeper_phase2','10 牧风者二阶段','windkeeper.png',(w//2,round(h*.25),w,h),scale=records['windkeeper_phase1']['scale'])

font='/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc'
hero_path=ROOT/'art/world-art-v2/assets/pixel/hero.png'
hero=Image.open(hero_path).convert('RGBA');hero=hero.crop(hero.getbbox())
bg_path=ROOT/'art/world-art-v2/assets/pixel/v2/windchime_plains_v2.png'
bg=Image.open(bg_path).convert('RGBA').resize((1600,900),Image.Resampling.NEAREST)
def label(draw,xy,text,size=20):draw.text(xy,text,font=ImageFont.truetype(font,size),fill='#efe3bf',stroke_width=2,stroke_fill='#17252a',anchor='mt')
def board(height,title):
    im=bg.crop((0,0,1600,height));d=ImageDraw.Draw(im);d.rectangle((0,0,1600,80),fill='#182124');d.rectangle((0,height-60,1600,height),fill='#182124');label(d,(800,10),title,26);label(d,(800,47),'原主角与 PR142 场景重新建立参考 · 全新静态候选，待审批 · 拼版不是游戏截图',17);return im
ordinary=board(380,'全新平原怪物 · 01—07');d=ImageDraw.Draw(ordinary);baseline=310
for i,name in enumerate(['hero']+[r[0] for r in rows]):
    im=hero if name=='hero' else Image.open(OUT/'static'/f'{name}.png')
    im=im.resize((im.width*2,im.height*2),Image.Resampling.NEAREST);x=90+i*200
    ordinary.alpha_composite(im,(x-im.width//2,baseline-im.height-(20 if name=='diver' else 0)))
    label(d,(x,326),'原主角 44px' if name=='hero' else records[name]['label'],18)
ordinary.convert('RGB').save(OUT/'review-ordinary.png')
boss=board(570,'全新平原 Boss · 08—10');d=ImageDraw.Draw(boss);baseline=500
boss.alpha_composite(hero,(60,baseline-hero.height));label(d,(85,522),'原主角 44px',17)
for name,x in [('bellstrider',370),('windkeeper_phase1',850),('windkeeper_phase2',1320)]:
    im=Image.open(OUT/'static'/f'{name}.png');boss.alpha_composite(im,(x-im.width//2,baseline-im.height));label(d,(x,522),records[name]['label']+' · '+str(im.height)+'px',20)
boss.convert('RGB').resize((3200,1140),Image.Resampling.NEAREST).save(OUT/'review-bosses.png')
references=[hero_path,bg_path,ROOT/'assets/plains_v07/native/reclaimer.png',ROOT/'assets/plains_v07/native/windmill_frame.png']
manifest={'status':'fresh static candidates; no user approval; no animation or production replacement',
          'baseline':'PR142@cc62d369d3cec2597db483f1137ff976e25863cf',
          'inputs':'Only original game hero, NPC, background and windmill; A-D artwork excluded',
          'reference_strip':'Generated top reference strips are discarded; boards and captures use unchanged original game hero',
          'derivation':'alpha>=128; remove isolated components below20 source pixels; tight crop; uniform nearest bake. No code painting or recoloring',
          'phase_consistency':'Both Windkeeper phases share one uniform source scale; exact animation registration remains pending',
          'references':{str(p.relative_to(ROOT)):sha(p) for p in references},
          'sources':{p.name:sha(p) for p in (OUT/'source').iterdir()},'assets':records}
(OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:v['native_size'] for k,v in records.items()}))
