"""Deterministically crop generated masters; no procedural painting.
Requires Pillow, NumPy and SciPy. Run from any working directory.
"""
from pathlib import Path
import json, hashlib
from PIL import Image
import numpy as np
from scipy import ndimage
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/plains_redraw_02'
(ROOT/'build/plains_redraw_02').mkdir(parents=True, exist_ok=True)
records={}
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def extract(source, count):
    im=Image.open(OUT/'source'/source).convert('RGBA')
    a=np.array(im); mask=a[:,:,3]>=128
    labels,n=ndimage.label(mask)
    sizes=np.bincount(labels.ravel()); sizes[0]=0
    ids=sorted(range(1,n+1),key=lambda i:sizes[i],reverse=True)[:count]
    boxes=[]
    for i in ids:
        ys,xs=np.where(labels==i); boxes.append((int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)))
    # Sort by row, then column; generated baselines are not perfectly aligned.
    boxes.sort(key=lambda b:((b[1]+b[3])//2))
    cols=4 if source=='diver.png' else 2
    boxes=[b for j in range(0,count,cols) for b in sorted(boxes[j:j+cols])]
    a[:,:,3]=np.where(mask,255,0); a[~mask]=0
    return Image.fromarray(a),boxes

def piece(im,box):
    a=np.array(im.crop(box)); labels,n=ndimage.label(a[:,:,3]>=128)
    sizes=np.bincount(labels.ravel()); sizes[0]=0
    a[labels!=int(sizes.argmax())]=0
    return Image.fromarray(a)

def save(im,name,box,size,source):
    crop=piece(im,box).resize(size,Image.Resampling.NEAREST)
    crop.save(OUT/(name+'.png'))
    records[name]={'source':'source/'+source,'source_xywh':[box[0],box[1],box[2]-box[0],box[3]-box[1]],'native_size':list(size),'anchor_px':[size[0]/2,size[1]],'sha256':sha(OUT/(name+'.png'))}

im,boxes=extract('ordinary.png',6)
ordinary=[('patrol',(41,39)),('charger',(40,30)),('hopper',(41,33)),('sentry',(41,42)),('fan_sentry',(41,30)),('root_bell',(50,60))]
for (name,size),box in zip(ordinary,boxes): save(im,name,box,size,'ordinary.png')
im,boxes=extract('boss_parts.png',8)
parts=[('cart_hull',(132,44)),('cart_canopy',(80,28)),('cart_wheel',(42,42)),('boss_bell',(30,36)),('keeper_torso',(144,74)),('keeper_head',(53,47)),('keeper_leg',(16,44)),('keeper_sail',(70,58))]
for (name,size),box in zip(parts,boxes): save(im,name,box,size,'boss_parts.png')
im,boxes=extract('keeper_details.png',2)
for (name,size),box in zip([('keeper_core',(36,36)),('keeper_hoof',(24,14))],boxes): save(im,name,box,size,'keeper_details.png')
# One fixed 1/8 source-pixel scale for every diver pose, never fit poses separately.
im,boxes=extract('diver.png',8)
sheet=Image.new('RGBA',(256,128)); regions=[]; anchors=[]; crop_rows=[]
for i,box in enumerate(boxes):
    size=(round((box[2]-box[0])/8),round((box[3]-box[1])/8))
    frame=piece(im,box).resize(size,Image.Resampling.NEAREST)
    at=(i%4*64+(64-size[0])//2,i//4*64+60-size[1])
    sheet.alpha_composite(frame,at)
    regions.append([i%4*64,i//4*64,64,64]); anchors.append([32,60]); crop_rows.append({'box':list(box),'native_size':list(size)})
sheet.save(OUT/'diver_frames.png')
data={'texture':'underworld_diver.png','regions':regions,'anchors':anchors,'basis_px':crop_rows[3]['native_size']}
(OUT/'diver_frames.json').write_text(json.dumps(data,indent=2)+'\n')
records['diver_frames']={'source':'source/diver.png','scale':0.125,'frames':crop_rows,'sha256':sha(OUT/'diver_frames.png')}
manifest={'version':2,'baseline':'d04912228d6f53f61bd6dde84b22876a5d444487','region_id':'windchime_plains','tool':'image_gen.imagegen','status':'candidate; user visual acceptance not asserted','derivation':'Alpha >=128, largest connected silhouettes, tight crop; nearest-neighbor bake at declared native dimensions. Diver uses one 1/8 scale for all frames. No code painting or color replacement.','license':'Generated artwork; tool did not expose a separate license identifier. Existing reference attribution retained in original asset directories.','sources':{p.name:sha(p) for p in sorted((OUT/'source').glob('*')) if p.suffix in ['.png','.txt']},'assets':records}
reference_paths=[
    'assets/underworld_plains/terrain/fine_32/terrain.png',
    'assets/underworld_plains/scenery_build.json',
    'assets/underworld_plains/actors/bellstrider.png',
    'assets/underworld_plains/actors/windkeeper.png',
    'assets/enemy_feedback_01/frames_v8/underworld_diver.png',
    *['assets/plains_revision_01/'+name+'.png' for name,_ in ordinary],
]
reference_paths += [spec['image'] for spec in json.loads((ROOT/'assets/underworld_plains/scenery_build.json').read_text())['backgrounds']]
manifest['references']={path:sha(ROOT/path) for path in reference_paths}
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2,ensure_ascii=False)+'\n')
# Native-scale sprite inspection strip plus 4x nearest view (assembly only).
board=Image.new('RGBA',(600,260),'#314550')
for i,(name,size) in enumerate(ordinary+parts):
    crop=Image.open(OUT/(name+'.png')); x=(i%5)*120+(120-crop.width)//2; y=(i//5)*85+80-crop.height
    board.alpha_composite(crop,(x,y))
board.resize((1200,520),Image.Resampling.NEAREST).convert('RGB').save(ROOT/'build/plains_redraw_02/native-sheet.png')
print(json.dumps({k:v.get('source_xywh',v.get('frames')) for k,v in records.items()}))
