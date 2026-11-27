"""Build the forest's two actor atlases and the hermit's paired timber walls."""
from pathlib import Path
from PIL import Image
import numpy as np

HERE = Path(__file__).resolve().parent
OUT = HERE.parents[2] / "production/assets/scenery/forest"

def silhouette(image, box):
    pixels = np.array(image.crop(box).convert("RGBA"))
    rgb = pixels[:, :, :3].astype(int)
    mask = (rgb[:,:,0] > 125) & (rgb[:,:,2] > 105) & (rgb[:,:,0] - rgb[:,:,1] > 65) & (rgb[:,:,2] - rgb[:,:,1] > 65)
    pixels[mask,3] = 0
    cut = Image.fromarray(pixels)
    return cut.crop(cut.getbbox())

def actor(atlas, boxes, cell, body_height, name):
    sheet = Image.new("RGBA",(cell[0]*len(boxes),cell[1]))
    parts=[silhouette(atlas,box) for box in boxes]
    scale = min(body_height/parts[0].height,(cell[0]-2)/max(p.width for p in parts),(cell[1]-2)/max(p.height for p in parts))
    for i,part in enumerate(parts):
        sprite=part.resize((round(part.width*scale),round(part.height*scale)),Image.Resampling.NEAREST)
        sheet.alpha_composite(sprite,(i*cell[0]+(cell[0]-sprite.width)//2,cell[1]-sprite.height))
    sheet.save(OUT/name)

actors=Image.open(HERE/"forest_duels_source.webp")
actor(actors,[(0,0,475,502),(475,0,1013,502),(1013,0,1536,502)],(118,98),94,"hollow_antler.png")
actor(actors,[(0,509,450,1024),(450,509,945,1024),(945,509,1536,1024)],(79,56),54,"reed_mentor.png")
building=Image.open(HERE/"practice_house_source.webp")
for name,box,width in [("practice_house",(0,0,1030,724),410),("practice_wall",(1040,0,2172,724),570)]:
    part=silhouette(building,box)
    part.resize((width,round(width*part.height/part.width)),Image.Resampling.NEAREST).save(OUT/(name+".png"))

wood=Image.open(HERE/"branch_construction_source.webp")
for name,box,width in [
    ("stem_limb",(0,45,755,318),192),
    ("trailing_limb",(760,55,1536,323),192),
    ("old_trunk",(145,386,562,1002),152),
    ("leaning_root",(650,389,1536,990),330),
]:
    part=silhouette(wood,box)
    sprite=part.resize((width,round(width*part.height/part.width)),Image.Resampling.NEAREST)
    pixels=np.array(sprite)
    colors=pixels[:,:,:3].astype(float)
    luma=colors[:,:,0]*.29+colors[:,:,1]*.58+colors[:,:,2]*.13
    pixels[:,:,:3]=np.clip((colors*.66+luma[:,:,None]*.34)*[.83,.86,.87]+[6,9,10],0,255)
    if name in ("leaning_root","old_trunk"):
        # The high cross section joins the background trunk mass in shade.
        yy,xx=np.mgrid[0:sprite.height,0:sprite.width]
        edge=7+((xx//4)*13%17)
        fade=np.clip((yy-edge)/46,0,1)
        pixels[:,:,3]=(pixels[:,:,3].astype(float)*fade).astype(np.uint8)
    Image.fromarray(pixels).save(OUT/(name+".png"))
sky=Image.open(HERE/"forest_depths_source.webp")
w,h=sky.size
for name,box in [("hollow",(0,0,w//2,h//2)),("high_canopy",(w//2,0,w,h//2)),("mire",(0,h//2,w//2,h)),("buried_arcade",(w//2,h//2,w,h))]:
    sky.crop(box).resize((640,360),Image.Resampling.NEAREST).save(OUT/(name+".webp"),lossless=True,method=4)

# A single continuous room sized wall, one sunlight window and one pair of targets.
# The framing bays are dark lumber taken from the same source, with no stacked floors.
from PIL import ImageEnhance
wall=Image.open(OUT/"practice_wall.png")
interior=Image.new("RGB",(1400,450),"#24231b")
roof=wall.crop((25,0,150,35)).convert("RGB").resize((230,100),Image.Resampling.NEAREST)
timber=wall.crop((17,46,60,160)).convert("RGB").resize((124,308),Image.Resampling.NEAREST)
for x in range(0,1400,124):interior.paste(ImageEnhance.Brightness(timber).enhance(.65),(x,107))
for x in range(0,1400,230):interior.paste(roof,(x,12))
base=wall.crop((12,wall.height-21,wall.width-12,wall.height-6)).convert("RGB").resize((490,42),Image.Resampling.NEAREST)
for x in range(0,1400,490):interior.paste(base,(x,408))
main=wall.resize((826,355),Image.Resampling.NEAREST)
interior.paste(main,(287,95),main)
post=wall.crop((0,7,22,wall.height)).resize((37,408),Image.Resampling.NEAREST)
for x in (106,1280):interior.paste(post,(x,42),post)
interior.save(OUT/"practice_hall.webp",lossless=True)
