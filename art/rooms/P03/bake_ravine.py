"""Bake the prairie limestone strata and wind-cut fault at the authored room scale."""
import json
from pathlib import Path
from random import Random

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageOps


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
DEST = ROOT / 'production/assets/scenery/p03'
DEST.mkdir(parents=True, exist_ok=True)
WORLD_ORIGIN = (128, -432)
WIDTH, HEIGHT = 1920, 1024

# The silhouette of the opposite face is rooted under the whole valley.
# From P02 the prairie remains visible. Inside the turn it recesses behind the stairs.
rim = [(128,331),(151,269),(162,184),(185,125),(191,52),(211,-18),
       (224,-93),(247,-128),(298,-142),(337,-125),(361,-96),(381,-36),
       (404,-24),(422,37),(447,53),(467,102),(495,114),(519,149),
       (551,158),(578,187),(618,201),
       (670,209),(698,194),(729,192),(758,196),(811,206),(852,215),
       (908,214),(946,177),(992,171),(1034,107),(1056,84),(1080,60),
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
# A continuous fracture in the sun-facing east wall identifies the wall-kick route.
# Its narrow, ochre-lit edge breaks along individual bedding planes, then joins the
# rooted field boulder above. The crack exists only inside the actual rock mask.
fracture = [(1518,-29),(1507,-4),(1486,9),(1488,36),(1477,49),(1480,73),
            (1461,90),(1464,111),(1477,128),(1463,154),(1468,181),
            (1455,202),(1460,230),(1453,253),(1460,277),(1451,304),(1451,332)]
branches = [[(1488,36),(1512,44),(1523,63)],[(1464,111),(1493,114),(1512,100)],
            [(1468,181),(1484,193),(1504,192)],[(1460,277),(1485,285),(1493,301)]]
bed_ink = ImageDraw.Draw(colored)
for line,depth in [(fracture,5)] + [(branch,3) for branch in branches]:
    coords = [(x-left,y-top) for x,y in line]
    bed_ink.line(coords,fill=(30,33,32,255),width=depth)
    for i,(a,b) in enumerate(zip(coords,coords[1:])):
        if i%3 != 1:
            bed_ink.line([(a[0]+3,a[1]+1),(b[0]+2,b[1]-2)],fill=(97,92,72,255),width=2)
colored.putalpha(Image.fromarray(face.astype('uint8')))
colored.save(DEST/'ravine_rock_faces.webp',lossless=True,method=6)
