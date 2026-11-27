"""Bake the recessed rear face and its fungal lip at the authored room scale."""
import json
from pathlib import Path
from random import Random

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageOps


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
DEST = ROOT / 'production/assets/scenery/p03'
DEST.mkdir(parents=True, exist_ok=True)
PIXEL = ROOT / 'art/world-art-v2/assets/pixel'
WORLD_ORIGIN = (128, -432)
WIDTH, HEIGHT = 1920, 1024

# The silhouette of the opposite face is rooted under the whole valley.
# From P02 the prairie remains visible. Inside the turn it recesses behind the stairs.
rim = [(128,331),(151,269),(162,184),(185,125),(191,52),(211,-18),
       (224,-93),(247,-128),(298,-142),(337,-125),(361,-96),(381,-36),
       (404,-24),(422,37),(447,53),(467,102),(495,114),(519,149),
       (551,158),(578,187),(618,201),
       (670,205),(698,185),(727,185),(758,152),(814,141),(861,148),
       (881,116),(909,82),(947,85),(977,55),(1012,51),(1048,-8),
       (1093,-20),(1110,-51),(1158,-40),(1184,-63),(1230,-71),
       (1258,-102),(1282,-109),(1330,-91),(1382,-102),(1400,-141),
       (1457,-152),(1505,-133),(1550,-139),(1596,-161),(1651,-154),
       (1690,-164),(1724,-150),(1810,-162),(1870,-152),(2048,-171)]
rng = Random(351)
points = []
for (x,y),(x2,y2) in zip(rim,rim[1:]):
    count = (x2-x)//5
    for i in range(count):
        t = i/count
        points.append((round(x + t*(x2-x)) - WORLD_ORIGIN[0],
                       round(y + t*(y2-y)) - WORLD_ORIGIN[1] + rng.randrange(-2,3)))
points.extend([(WIDTH, rim[-1][1]-WORLD_ORIGIN[1]),(WIDTH,HEIGHT),(0,HEIGHT)])
profile = Image.new('L',(WIDTH,HEIGHT))
ImageDraw.Draw(profile).polygon(points,fill=255)
master = Image.open(HERE/'ravine_master.webp').convert('RGB')
# Form the distant wall at a restrained spatial frequency; terrain keeps its bright rims.
rear = ImageOps.fit(master,(WIDTH//2,HEIGHT//2),method=Image.Resampling.LANCZOS)
rear = ImageEnhance.Color(rear).enhance(.79)
rear = Image.blend(rear,Image.new('RGB',rear.size,'#89948b'),.42)
rear = rear.quantize(84,dither=Image.Dither.NONE).convert('RGB').resize((WIDTH,HEIGHT),Image.Resampling.NEAREST)
rear.putalpha(profile)
rear.save(DEST/'ravine_backwall.webp',lossless=True,method=6)

# A bracket mushroom grows from the actual lip. Retain the kit's native transparent edges.
bracket = Image.open(PIXEL/'mushroom_caverns_near.png').convert('RGBA')
bracket.save(DEST/'fungal_seam.png',optimize=True)

# Aligned weathering on exposed backs and cliff faces. Masks come from the
# same solid polygons as the collision and leave the native terrain rims visible.
room = json.loads((ROOT/'production/rooms/world/P03.json').read_text())
left,top = -260,-440
width,height = 2130,1032
mask = Image.new('L',(width,height))
for row in room['entities'].values():
    if row['definition_id'] != 'terrain.polygon':
        continue
    shape = [(x-left,y-top) for x,y in row['properties']['points']]
    ImageDraw.Draw(mask).polygon(shape,fill=255)
mask = mask.filter(ImageFilter.MinFilter(7))
# Large bedding planes follow the cliff mass. A little native limestone grain
# breaks up the master without drawing soft brushstrokes at player scale.
beds = ImageOps.fit(ImageOps.mirror(master),(width//2,height//2),method=Image.Resampling.LANCZOS)
beds = beds.resize((width,height),Image.Resampling.NEAREST)
native = Image.open(ROOT/'production/rooms/world/p02_connections/stone.png').convert('L')
grain = np.tile(np.asarray(native,dtype=float),(1+height//native.height,1+width//native.width))[:height,:width]
value = np.asarray(ImageOps.grayscale(beds),dtype=float)/255
value = np.clip((value-.16)*1.7+.2+(grain-grain.mean())*.0005,0,1)
base = np.array([22,28,34]) + value[:,:,None]*np.array([65,65,53])
colored = Image.fromarray(base.astype('uint8')).quantize(78,dither=Image.Dither.NONE).convert('RGBA')
# Fade down within the thick foundation, preserving the blue-ground cutaway.
ys = np.arange(height).reshape(-1,1)+top
face = np.asarray(mask).astype('float32')
face *= np.clip((510-ys)/145,.08,.97)
xs = np.arange(width).reshape(1,-1)+left
face *= np.clip((xs+136)/136,0,1)*np.clip((1744-xs)/138,0,1)
colored.putalpha(Image.fromarray(face.astype('uint8')))
colored.save(DEST/'ravine_rock_faces.webp',lossless=True,method=6)

for file, source, size in [('seam_lantern','mushroom_lamp',(24,35)),('seam_bracket','mushroom_caverns_near',(31,46))]:
    image = Image.open(PIXEL/(source+'.png')).convert('RGBA').resize(size,Image.Resampling.LANCZOS)
    image.putalpha(image.getchannel('A').point(lambda a: 0 if a<96 else 255))
    image.save(DEST/(file+'.png'),optimize=True)
