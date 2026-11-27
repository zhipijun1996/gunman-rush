"""Fit the retained prairie limestone master to the authored v29 vertical ravine."""
import json
from pathlib import Path
from random import Random

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageOps

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
DEST = ROOT / 'production/assets/scenery/p03'
ROOM = json.loads((ROOT / 'production/rooms/world/P03.json').read_text())
MASTER = Image.open(HERE / 'ravine_master.webp').convert('RGB')
WIDTH, HEIGHT = ROOM['bounds'][2:]
SIZE = (WIDTH, HEIGHT)
rng = Random(2903)

# View into three recesses of one opposite limestone face. The central cleft
# opens onto the room's real prairie horizon, widest high on the west road.
cliff = Image.new('RGBA', SIZE)
for x, y, contour, box, tint in [
    (0, 60, [(0,90),(73,116),(115,189),(122,284),(165,328),(191,478),(233,505),(236,584),(274,631),(300,818),(342,894),(369,1090),(391,1132),(441,1192),(454,1405),(520,1455),(540,1740),(0,1740)], (15,0,730,1024), (117,144,142)),
    (0, 0, [(344,1840),(417,1348),(481,1170),(473,1057),(444,977),(478,855),(512,812),(497,653),(453,560),(453,483),(480,434),(445,303),(464,229),(503,184),(500,126),(567,84),(664,106),(695,61),(840,20),(840,1820)], (645,0,1430,1024), (120,139,133)),
]:
    # Background has broad strata. Sample the hand-authored master without
    # stretching individual rock chips, and wrap at different strata heights.
    tile = ImageEnhance.Color(MASTER.crop(box)).enhance(.68)
    sheet = Image.new('RGB', SIZE)
    sheet.paste(tile, (x, y))
    sheet.paste(ImageOps.flip(tile), (x, y+tile.height))
    sheet.paste(ImageOps.mirror(tile), (x+tile.width, y))
    sheet.paste(ImageOps.flip(ImageOps.mirror(tile)), (x+tile.width, y+tile.height))
    sheet = Image.blend(sheet, Image.new('RGB',SIZE,tint), .58)
    shape = Image.new('L',SIZE)
    edge = []
    for a,b in zip(contour,contour[1:]+contour[:1]):
        n=max(1, int(np.hypot(b[0]-a[0],b[1]-a[1])/7))
        for i in range(n):
            edge.append((round(a[0]+(b[0]-a[0])*i/n)+rng.randrange(-2,3),round(a[1]+(b[1]-a[1])*i/n)))
    ImageDraw.Draw(shape).polygon(edge,fill=255)
    sheet.putalpha(shape)
    cliff.alpha_composite(sheet)
# Rear spurs of the same ravine carry the central stepping stones. These
# subdued faces join the previous stratum behind the walkable stone lip.
# Each pier continues into an actual bank or into the bowl floor. Their
# contacts vary: bedded shelf, branching buttress, deep diagonal and low toe.
spurs = [
    [(231,1344),(314,1344),(311,1370),(292,1384),(284,1403),(301,1429),(221,1440),(230,1398)],
    [(338,1248),(414,1248),(413,1280),(443,1307),(454,1330),(498,1355),(518,1390),(563,1430),(405,1431),(417,1402),(396,1368),(389,1324),(365,1301)],
    [(83,1099),(123,1080),(154,1074),(180,1061),(218,1053),(257,1055),(291,1045),(326,1045),(330,1069),(312,1081),(270,1093),(248,1110),(222,1114),(206,1137),(173,1141),(145,1166),(107,1180),(84,1176)],
    [(309,854),(381,850),(409,830),(436,824),(459,799),(482,790),(502,765),(522,771),(522,866),(496,876),(475,889),(445,889),(422,901),(387,898),(373,886),(343,880)],
    [(78,570),(124,578),(158,601),(191,600),(228,617),(259,620),(288,640),(334,651),(365,648),(362,676),(328,688),(302,678),(276,676),(244,661),(217,661),(182,643),(157,646),(127,634),(91,637)],
    [(291,447),(364,446),(397,460),(426,455),(459,469),(490,462),(516,450),(520,547),(497,542),(475,525),(443,520),(423,500),(394,498),(367,482),(337,479),(318,465)],
    [(125,203),(170,201),(190,212),(218,216),(239,230),(262,229),(291,248),(317,250),(313,278),(288,278),(266,266),(245,270),(216,254),(192,258),(166,242),(134,244)]
]
rear_mask=Image.new('L',SIZE)
backdraw=ImageDraw.Draw(rear_mask)
for spur in spurs:
    cut=[]
    for a,b in zip(spur,spur[1:]+spur[:1]):
        n=max(1,int(np.hypot(b[0]-a[0],b[1]-a[1])/5))
        for i in range(n):
            cut.append((int(a[0]+(b[0]-a[0])*i/n)+rng.randrange(-3,4),
                        int(a[1]+(b[1]-a[1])*i/n)+rng.randrange(-1,2)))
    backdraw.polygon(cut, fill=255)
bedding=Image.new('RGB',SIZE)
slab=MASTER.crop((110,15,950,1015))
bedding.paste(slab,(0,0))
bedding.paste(ImageOps.flip(slab),(0,1000))
grain=np.asarray(ImageOps.grayscale(bedding),dtype='float32')/255
# Dark undersides meet the playable outcrop. At regular pixel strata above
# them, reflected green light keeps this attached rear face distinct from the
# near dark collision face and the brighter far wall.
alpha=np.asarray(rear_mask)
inner=np.asarray(rear_mask.filter(ImageFilter.MinFilter(7)))
lit=np.zeros((HEIGHT,WIDTH),dtype='float32')
for x in range(WIDTH):
    depth=0
    for y in range(HEIGHT):
        if alpha[y,x]:
            lit[y,x]=max(0,1-depth/27)
            depth+=1
        else: depth=0
value=np.clip((grain-.12)*1.32+.08,0,1)
shade=np.array([40,49,53])+value[:,:,None]*np.array([70,69,60])+lit[:,:,None]*np.array([11,12,8])
shade+=(inner.astype('float32')-alpha)[:,:,None]*.013
bedding=Image.fromarray(np.clip(shade,0,255).astype('uint8')).convert('RGBA')
bedding.putalpha(rear_mask)
cliff.alpha_composite(bedding)
# The single survey bridge has two feet bedded on the coin outcrop and
# ravine, and a knee-brace profiled from the original region's mill trestle.
frame=Image.open(ROOT/'production/assets/scenery/plains_trail/mill_timber_bent.png').convert('RGBA')
wood=ImageEnhance.Brightness(frame).enhance(.74)
cliff.alpha_composite(wood.resize((111,191),Image.Resampling.NEAREST),(231,1151))
cliff.save(DEST/'switchback_relief.webp',lossless=True,method=6)

# Exposed outcrops inherit the exact collision silhouettes and leave the
# walkable grass crowns to the regional tiles. Use compact native-scale grain.
mask = Image.new('L',SIZE)
draw=ImageDraw.Draw(mask)
for row in ROOM['entities'].values():
    if row['definition_id']=='terrain.polygon':
        draw.polygon([tuple(p) for p in row['properties']['points']],fill=255)
mask = mask.filter(ImageFilter.MinFilter(9))
texture=Image.new('RGB',SIZE)
bed=ImageOps.mirror(MASTER).crop((95,10,935,1010))
texture.paste(bed,(0,0))
texture.paste(ImageOps.flip(bed),(0,1000))
value=np.asarray(ImageOps.grayscale(texture),dtype='float32')/255
strata=np.array([26,33,40])+np.clip((value-.17)*1.60+.09,0,1)[:,:,None]*np.array([83,78,64])
surface=Image.fromarray(strata.astype('uint8')).convert('RGBA')
ink=ImageDraw.Draw(surface)
for start,stop in [((614,1360),(676,900)),((527,1199),(546,660))]:
    x,y=start
    while y>stop[1]:
        nx=round(x+(stop[0]-x)*.12+rng.randrange(-8,8))
        ny=y-rng.randrange(12,38)
        ink.line([(x,y),(nx,ny)],fill=(89,91,69),width=2)
        ink.line([(x-2,y),(nx-2,ny)],fill=(33,39,40),width=2)
        x,y=nx,ny
opacity=np.array(mask,dtype='float32')
xx=np.arange(WIDTH).reshape(1,-1)
opacity*=np.minimum(np.clip(xx/60,0,1),np.clip((WIDTH-xx)/60,0,1))
surface.putalpha(Image.fromarray((opacity*.92).astype('uint8')))
surface.save(DEST/'switchback_strata.webp',lossless=True,method=6)
