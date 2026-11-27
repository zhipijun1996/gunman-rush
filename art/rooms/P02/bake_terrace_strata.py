"""Cut the v29 field banks from the approved native loam. Keep both mouths open."""
from pathlib import Path
import math
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "production/assets/scenery/p02/p02_terrace_strata.webp"
SOIL = ROOT / "art/rooms/P02/bank_subsoil.png"
texture = np.asarray(Image.open(SOIL).convert("L"), dtype=float)
height, width = 438, 1650
y, x = np.indices((height, width))
world_y = y + 408
# Mirror the native stone bed at its seams. Broader layers follow the pressure
# of the banks and are lit from the direction of the open field.
def mirror(u, size):
    folded = u % (2 * size)
    return np.where(folded < size, folded, 2 * size - 1 - folded).astype(int)
relief = texture[mirror(world_y + 10*np.sin(x/142), texture.shape[0]), mirror(x+13*np.sin(world_y/58), texture.shape[1])]
relief = np.clip((relief-36)/66, -.45, 1.35)
shelf = np.sin(world_y/20+x/195)*.16 + np.sin(world_y/47-x/400)*.22
depth = np.clip((845-world_y)/330,0,1)
light = .28+.48*depth + shelf
colors = np.clip(np.array([17,21,29])+(light*relief)[:,:,None]*np.array([53,46,30]), 0,255).astype('uint8')
mask = Image.new('L',(width,height))
draw = ImageDraw.Draw(mask)
def face(left,top,right,bottom=846,fray=True):
    # Keep each actual grass edge and the immediate soil beneath it visible.
    points=[(x,round(top-408 + (3*math.sin(x/37)+2*math.sin(x/13) if fray else 0))) for x in range(left,right,3)]
    points.extend([(right-1,top-408),(right-1,bottom-408),(left,bottom-408)])
    draw.polygon(points,fill=255)
face(0,543,120)
face(0,447,360,490)
face(120,640,192)
face(192,830,288)
face(288,787,325)
face(325,609,416)
face(416,529,454)
face(454,577,496)
face(496,609,648)
face(648,449,790)
face(790,512,820)
face(820,565,850)
face(850,618,880)
face(880,681,882)
face(1008,486,1284)
face(1284,462,1650)
im=Image.fromarray(colors,'RGB');im.putalpha(mask)
im.save(OUT,lossless=True,method=6)
