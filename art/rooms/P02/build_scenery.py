"""Export the regional artwork used by P02 at its native in-game pixel scale."""
import argparse
import json
from pathlib import Path
from shutil import copyfile

import numpy as np
from PIL import Image, ImageDraw, ImageOps

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
NATIVE = ROOT / "assets/plains_v07/native"
REGIONAL = ROOT / "art/world-art-v2/assets/pixel"


def irrigation_panorama(output):
    # Retain the furrows and skyline but keep sunlit distant fields below foreground contrast.
    image = Image.open(HERE / "irrigation_panorama_master.webp").convert("RGB")
    image = image.resize((1392, 662), Image.Resampling.LANCZOS)
    palette = np.asarray(image, dtype=float)
    y = np.arange(image.height)[:, None, None] / (image.height - 1)
    haze = .09 + .18 * np.clip((y - .18) / .60, 0, 1)
    luminance = palette @ np.array([.27, .57, .16])
    local = palette * .82 + luminance[:, :, None] * .18
    air = np.array([168, 174, 154]) * (1 - y * .25) + np.array([155, 147, 122]) * y * .25
    image = Image.fromarray(np.uint8(np.clip(local * (1-haze) + air*haze, 0, 255)))
    image.quantize(144, dither=Image.Dither.NONE).convert("RGB").save(output / "irrigation_panorama.webp", lossless=True, method=6)


def field_grasses(output):
    # Its seed heads reach over the passage while the entire root grows from the right-hand bank.
    native = Image.open(NATIVE / "concealing_grass.png").convert("RGBA")
    native = ImageOps.mirror(native.resize((76, 41), Image.Resampling.LANCZOS))
    # Soften the master cutout's one-pixel fringe without moving the roots.
    native.putalpha(native.getchannel("A").point(lambda value: 0 if value < 30 else value))
    native.save(output / "p02_reed_screen.png", optimize=True)

    # Native 1:1 leaves and seed tips on the daylight side of the low passage.
    tuft = Image.open(REGIONAL / "plains_grass.png").convert("RGBA")
    tuft = ImageOps.mirror(tuft)
    # The terrace slope rises rightward at 1:3. Follow that contact line rather
    # than letting a horizontal patch of soil cut across the bank.
    array = np.asarray(tuft)
    grass = np.zeros_like(array)
    alpha = array[:, :, 3]
    for x in range(tuft.width):
        opaque = np.where(alpha[:, x] > 78)[0]
        if not opaque.size:
            continue
        contact = tuft.height-1 - int(round((x-tuft.width*.5)/3))
        drop = max(0, min(3, int(opaque[-1])-contact))
        if drop:
            grass[:-drop, x] = array[drop:, x]
        else:
            grass[:, x] = array[:, x]
    Image.fromarray(grass).save(output / "p02_slope_grass.png", optimize=True)


def grass_cutaway(output):
    """Native ground cover for G34, baked at P02 world phase, one pixel per unit."""
    terrain = json.loads((ROOT/"production/config/terrain_materials.json").read_text())
    plains = terrain["materials"]["windchime_plains"]
    source = np.asarray(Image.open(ROOT/"production"/plains["source"].removeprefix("res://")).convert("RGBA"))
    left, top, width, height = 128, 544, 224, 256
    ys, xs = np.indices((height,width))
    world_x, world_y = xs+left, ys+top
    # The grass head meets visible ground at both ends. The foreground crosses
    # above the old lip; the soil below it continues past the bottom of the room.
    profile = [(128,608),(151,608),(167,606),(183,602),(205,598),
               (221,593),(243,590),(264,585),(282,579),(300,576),(352,576)]
    crest = np.rint(np.interp(world_x,*zip(*profile))).astype(int)
    depth = world_y-crest
    # Same three 32-pixel variants, source rectangles and world-space phase as
    # formal_fine_boundary.gdshader: outer grass row, then the interior albedo.
    column = 64 + 352*((world_x//32)%3) + world_x%32
    trim = int(plains["surface_y"])
    row = np.where(depth<16,np.clip(depth+trim,0,31),32+world_y%32)
    pixels = source[row,column].copy()
    overlap = np.minimum(np.clip((world_x-left)/16,0,1),np.clip((left+width-1-world_x)/16,0,1))
    pixels[:,:,3] = np.uint8(pixels[:,:,3]*overlap*(depth>=-trim))
    cover = Image.fromarray(pixels)
    # A few wind-bent leaf tips give the closed bank a clue at actor scale.
    # Their base is buried in the existing grass crown, not outlined as a portal.
    herb = Image.open(NATIVE/"concealing_grass.png").convert("RGBA")
    herb = ImageOps.mirror(herb.resize((34,18),Image.Resampling.LANCZOS))
    herb.putalpha(herb.getchannel("A").point(lambda v: 0 if v<32 else v))
    cover.alpha_composite(herb,(269-left,582-18-top))
    cover.save(output/"p02_grass_cutaway.png",optimize=True)


def inner_bank(output):
    """A rear cut in the grass passage. Foreground solids draw their own tile faces."""
    width, height = 460, 202
    left, top = 0, 426
    y, x = np.indices((height,width))
    world_y = y+top
    native = Image.open(ROOT/"assets/plains_v3/terrain/organic_cliff_fill.png").convert("L")
    archive = native.crop((86,203,1152,683)).resize((width,height),Image.Resampling.LANCZOS)
    rock = np.asarray(archive, dtype=float)
    lo,hi = np.quantile(rock,[.03,.96])
    relief = np.clip((rock-lo)/(hi-lo),0,1)
    colors = np.array([[22,25,32],[34,35,40],[44,44,46],[56,52,48],[64,60,52]])
    rgb = np.stack([np.interp(relief,[0,.25,.5,.78,1],colors[:,i]) for i in range(3)],axis=-1)
    floor_y = np.interp(x,[0,144,192,240,460],[608,608,624,576,576])
    ceiling_y = np.where(x<152,476,448)
    ceiling = np.clip((world_y-ceiling_y)/45,0,1)
    side_light = np.exp(-x/106) + .95*np.exp(-(width-x)/68)
    low_bounce = .8*np.exp(-((world_y-floor_y+17)/24)**2)
    rgb = rgb*(.68+.29*ceiling+.17*side_light)[:,:,None]
    rgb += (side_light*ceiling+low_bounce*.23)[:,:,None]*np.array([17,12,6])
    bank = Image.fromarray(np.uint8(np.clip(rgb,0,255))).convert("RGBA")
    moss = Image.open(NATIVE/"bank_moss.png").convert("RGBA")
    for cx,cy,w,flip in [(31,472,67,False),(104,473,46,True),(182,442,61,True),(319,442,78,False),(380,441,47,True)]:
        spr=moss.resize((w,round(w*moss.height/moss.width)),Image.Resampling.LANCZOS)
        if flip: spr=ImageOps.mirror(spr)
        data=np.asarray(spr).copy()
        light=(data[:,:,:3] @ np.array([.33,.55,.12]))
        data[:,:,:3]=np.clip(light[:,:,None]*np.array([.46,.37,.23])+[21,19,18],0,255)
        bank.alpha_composite(Image.fromarray(data),(cx,cy-top))
    # The field shoulder buries the back cut above the passage. A low, eroded
    # outside edge opens to daylight on the right side of the hidden grass lane.
    mask = Image.new("L",bank.size)
    profile=[(0,426),(430,426),(430,447),(423,452),(419,457),(409,465),
             (409,472),(403,477),(399,488),(399,509),(405,524),(413,533),
             (419,543),(429,551),(430,555),(442,560),(450,568),(460,573)]
    path=profile+[(460,577),(243,578),(191,625),(144,609),(0,609)]
    ImageDraw.Draw(mask).polygon([(px-left,py-top) for px,py in path],fill=255)
    bank.putalpha(mask)
    bank.save(output / "p02_grass_bank.png",optimize=True)


def grass_throat(output):
    """The same rear soil section spans the two rooms from P02 y572 to P16 y289."""
    width, height = 96, 262
    y, x = np.indices((height,width))
    native = Image.open(ROOT / "assets/plains_v3/terrain/organic_cliff_fill.png").convert("L")
    sample = native.crop((350,219,539,654)).resize((width,height),Image.Resampling.LANCZOS)
    grain = np.asarray(sample,dtype=float)
    low, high = np.quantile(grain,[.02,.98])
    relief = np.clip((grain-low)/(high-low),0,1)
    palette = np.array([[24,24,27],[41,35,33],[63,50,39],[83,63,46]])
    rgb = np.stack([np.interp(relief,[0,.36,.74,1],palette[:,i]) for i in range(3)],axis=-1)
    side = np.minimum(x,width-1-x)
    # Curved side light at the two banks. Root fibers taper into softer earth below.
    light = .91 + .23*np.exp(-side/12) + .22*np.exp(-y/72)
    wall = Image.fromarray(np.uint8(np.clip(rgb*light[:,:,None],0,255))).convert("RGBA")
    for px,py,w,flip in [(-11,2,43,False),(63,4,47,True),(-17,54,42,True),(82,118,31,False)]:
        moss = Image.open(NATIVE/"bank_moss.png").convert("RGBA")
        spr = moss.resize((w,round(w*moss.height/moss.width)),Image.Resampling.LANCZOS)
        if flip: spr = ImageOps.mirror(spr)
        data = np.asarray(spr).copy()
        luma = data[:,:,:3]@np.array([.33,.55,.12])
        data[:,:,:3] = np.clip(luma[:,:,None]*[.46,.34,.21]+[25,19,17],0,255)
        wall.alpha_composite(Image.fromarray(data),(px,py))
    # The top disappears gently into the existing grass sill. Under it the two
    # rooms show the exact same pixels at each side of the physical crossing.
    surface = np.interp(x,[0,46,95],[16,2,1])
    alpha = np.uint8(255*np.clip((y-surface+4)/7,0,1))
    wall.putalpha(Image.fromarray(alpha))
    # The inset of the three east-bank treads can be seen through the shaft.
    # Its back soil fills that 36-pixel recess and continues behind solid tiles.
    inset = ImageOps.mirror(wall.crop((60,0,96,height)))
    inset_rgb = np.asarray(inset).copy()
    inset_rgb[:,:,:3] = np.uint8(inset_rgb[:,:,:3]*.77)
    whole = Image.new("RGBA",(width+36,height))
    whole.paste(wall,(0,0))
    whole.paste(Image.fromarray(inset_rgb),(width,0))
    whole.save(output/"p02_root_throat.png",optimize=True)


def drainage_well(output):
    """The stone shoulder is bonded behind the right bank; its open shaft continues down."""
    left,top=1080,456
    width,height=138,312
    y,x=np.indices((height,width))
    world_y=y+top
    shaft=Image.open(NATIVE/"interior_well.png").convert("RGB")
    # The regional study shows curved courses, seepage and side ribs at native scale.
    sides=np.asarray(shaft.crop((31,0,350,256)).resize((width,height),Image.Resampling.LANCZOS),dtype=float)
    projection=np.clip((x-40.)/96.,0,1)
    bend=np.sin(np.pi*projection)
    depth=np.clip((world_y-608.)/160.,0,1)
    near=np.minimum(np.abs(x-40),np.abs(x-136))
    illumination=.97+.20*np.exp(-near/8)-.14*bend+.28*(1-depth)
    tip_light=np.exp(-((x-53)/7)**2-((world_y-652)/68)**2)
    ceiling=np.clip((world_y-462)/45,0,1)
    rgb=sides*illumination[:,:,None]+(1-depth)[:,:,None]*np.array([12,12,7])
    rgb+=tip_light[:,:,None]*[8,16,18]
    rgb*= (.80+.20*ceiling)[:,:,None]
    wall=Image.fromarray(np.uint8(np.clip(rgb,0,255))).convert("RGBA")
    mask=Image.new("L",wall.size)
    # The east overhang is 72wu wide. Weathered corbels turn into the actual
    # right-hand bank. The reverse side of the well mouth dips toward its centre.
    points=[(1142,456),(1218,456),(1218,768),(1120,768),(1120,608),
            (1080,608),(1082,605),(1090,602),(1103,601),(1117,596),
            (1125,600),(1137,604),(1151,611),(1161,613),(1178,614),
            (1190,608),(1197,604),(1204,599),(1206,584),(1207,563),
            (1204,546),(1200,534),(1197,524),(1191,517),(1190,506),
            (1181,501),(1177,490),(1167,487),(1163,479),(1154,477),(1151,468),(1142,467)]
    ImageDraw.Draw(mask).polygon([(px-left,py-top) for px,py in points],fill=255)
    # A subdued reflection traces the side of the shaft. A few mineral grains
    # use the wall's own relief; the recess stays open to the sky at its head.
    wall.putalpha(mask)
    wall.save(output/"p02_well_lining.png",optimize=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=ROOT / "production/assets/scenery/p02")
    output = parser.parse_args().out
    output.mkdir(parents=True, exist_ok=True)
    irrigation_panorama(output)
    field_grasses(output)
    inner_bank(output)
    grass_throat(output)
    grass_cutaway(output)
    drainage_well(output)
    bell = "windchime_plains_v2_chime_span.png"
    copyfile(REGIONAL / "v2" / bell, output / bell)
