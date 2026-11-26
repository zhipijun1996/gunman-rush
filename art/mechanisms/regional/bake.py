"""Bake the 16 native hardware strips from the region catalog and bearing sheet."""
import json
from pathlib import Path
from collections import deque
from PIL import Image, ImageEnhance, ImageFilter

ROOT = Path(__file__).resolve().parents[3]
ART = ROOT / "art/world-art-v2"
OUTPUT = ROOT / "production/assets/mechanisms/regional"
PIXELS = ART / "assets/pixel"
CATALOG = json.loads((ART / "region-catalog.json").read_text())["regions"]
MASTER = Path(__file__).with_name("bearings.png")
FINIALS = ["road_marker","hook_root","shelf_cap","swamp_pods","weather_vane","ice_column",
           "bell_memorial","royal_banner","pipe_junction","ore_cluster","obsidian_fangs",
           "root_knot","shell_relic","stone_cluster","glass_crystals","regulator_panel"]


def donor(name):
    for folder in (PIXELS, PIXELS / "v2"):
        path = folder / (name + ".png")
        if path.is_file():
            return Image.open(path).convert("RGBA")
    raise ValueError(name)


def silhouette(image, size):
    alpha = image.getchannel("A")
    bounds = alpha.point(lambda x: 255 if x >= 112 else 0).getbbox()
    if not bounds:
        raise ValueError("Empty hardware part")
    part = image.crop(bounds)
    part.thumbnail(size, Image.Resampling.LANCZOS)
    alpha = part.getchannel("A").point(lambda x: 255 if x >= 106 else 0)
    part = ImageEnhance.Brightness(part).enhance(1.13)
    part.putalpha(alpha)
    return part


def add(atlas, art, x, w, h):
    part = silhouette(art, (w, h))
    atlas.alpha_composite(part,(x+(w-part.width)//2,(h-part.height)//2))


def native_tile(atlas, coords):
    x,y = coords
    return atlas.crop((32*x,32*y,32*x+32,32*y+32))


def material(region):
    terrain = region["terrain47"]
    image = Image.open(ART / terrain["atlas"]).convert("RGBA")
    coords = terrain["maskToAtlas"]
    tile = native_tile(image,coords["255"]).copy()
    top = native_tile(image,coords["124"])
    # Use the exposed surface under each column's silhouette as the top rail.
    for x in range(32):
        ys = [y for y in range(32) if top.getpixel((x,y))[3] >= 128]
        for y in range(4):
            if ys:
                tile.putpixel((x,y),top.getpixel((x,min(31,ys[0]+y))))
    # The cutaway face has a short shadow rebate at its underside.
    tile.paste(ImageEnhance.Brightness(tile.crop((0,29,32,32))).enhance(.67),(0,29))
    return tile


def bearing_part(master, index):
    # The contact sheet has three printed gutters; the last row is taller.
    column, row = index % 4, index // 4
    edges = (0, 310, 611, 898, master.height)
    part = master.crop((master.width*column//4, edges[row],
                        master.width*(column+1)//4, edges[row+1]))
    # Neutral studio matte is translucent; even silver/ice highlights on the
    # artwork are opaque. Retain bright interior highlights behind outlines.
    mask = Image.new("L", part.size)
    mask.putdata([255 if a >= 218 and (min(r,g,b)<204 or a>=232) else 0
                  for r,g,b,a in part.getdata()])
    mask = mask.filter(ImageFilter.MedianFilter(5)).filter(ImageFilter.MaxFilter(3))
    # Exclude neighbouring props that protrude into a contact-sheet cell.
    pixels = mask.load()
    remaining = {(x,y) for y in range(mask.height) for x in range(mask.width) if pixels[x,y]}
    largest = set()
    while remaining:
        start = remaining.pop()
        connected = {start}
        queue = deque([start])
        while queue:
            x,y = queue.popleft()
            for neighbour in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
                if neighbour in remaining:
                    remaining.remove(neighbour)
                    connected.add(neighbour)
                    queue.append(neighbour)
        if len(connected)>len(largest):
            largest = connected
    mask.paste(0,(0,0,*mask.size))
    for point in largest:
        pixels[point] = 255
    part.putalpha(mask)
    return part


def build(master):
    for i,r in enumerate(CATALOG):
        region = r["id"]
        atlas = Image.new("RGBA",(148,36))
        fx = next(n for n in r["newProps"] if n.endswith("_"+FINIALS[i]))
        lamp = next(n for n in r["assets"] if n.endswith("_lamp") or n=="bell_post")
        bearing = bearing_part(master,i)
        add(atlas,bearing,0,24,24)
        add(atlas,donor(fx),24,32,32)
        add(atlas,donor(lamp),56,28,36)
        add(atlas,donor(region+"_hazard"),84,32,32)
        atlas.alpha_composite(material(r),(116,0))
        atlas.save(OUTPUT/(region+".png"),optimize=True)
    # The unassigned room keeps the familiar brass bell, wheel and metal fittings.
    common = Image.open(OUTPUT/"gear_city.png").copy()
    original = Image.open(ROOT/"production/assets/mechanisms/bell_gate/bell_gate.png").convert("RGBA")
    common.paste((0,0,0,0),(0,0,84,36))
    add(common,original.crop((80,0,106,26)),0,24,24)
    add(common,original.crop((32,0,74,48)),24,32,32)
    add(common,original.crop((0,0,28,34)),56,28,36)
    common.save(OUTPUT/"common.png",optimize=True)


if __name__ == "__main__":
    build(Image.open(MASTER).convert("RGBA"))
