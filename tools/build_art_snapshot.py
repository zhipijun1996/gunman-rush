"""Compose runtime SVG assets into a portable static integration preview."""
from pathlib import Path
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
NS = 'http://www.w3.org/2000/svg'
ET.register_namespace('', NS)
root = ET.Element(f'{{{NS}}}svg', {'width':'1280','height':'720','viewBox':'0 0 1280 720'})
sequence = 0
def place(path, x, y, width, height, rotation=None):
    global sequence
    sequence += 1
    text = (ROOT / path).read_text()
    # Namespace gradient IDs so repeated individual SVGs retain their own materials.
    ids = re.findall(r'\bid="([^"]+)"', text)
    for name in ids:
        text = text.replace(f'id="{name}"', f'id="s{sequence}_{name}"').replace(f'#{name})', f'#s{sequence}_{name})')
    svg = ET.fromstring(text)
    svg.attrib.update(x=str(x), y=str(y), width=str(width), height=str(height))
    if rotation:
        group=ET.SubElement(root, f'{{{NS}}}g', {'transform':rotation})
        group.append(svg)
    else:
        root.append(svg)

for name in ['plains_sky','plains_far_hills','plains_meadow','plains_distant_ruins']:
    place(f'assets/backgrounds/plains/{name}.svg',0,0,1280,720)
for x,y,n in [(0,540,5),(410,420,3),(670,460,2),(930,500,2),(1150,540,3)]:
    for j in range(n):
        cap='left' if j==0 else 'right' if j==n-1 else 'middle'
        place(f'assets/terrain/plains/grass_{cap}_1.svg',x+j*64,y-8,64,64)
        row=1
        while y-8+row*64<720:
            place('assets/terrain/plains/rock_fill_1.svg',x+j*64,y-8+row*64,64,64)
            row+=1
place('assets/objects/moving_platform.svg',330,560,128,32)
place('assets/objects/saw_wheel.svg',796,256,88,88)
place('assets/objects/shot_recharge_active.svg',640,335,48,48)
place('assets/objects/jump_recharge_active.svg',445,330,48,48)
place('assets/objects/checkpoint_active.svg',1190,460,48,80)
place('assets/enemies/plains/patrol_drone_idle.svg',925,390,64,64)
place('assets/characters/courier/leg.svg',190,518,15,25)
place('assets/characters/courier/leg.svg',204,518,15,25)
place('assets/characters/courier/scarf.svg',159,490,40,20)
place('assets/characters/courier/body.svg',170,470,60,60)
place('assets/characters/courier/weapon_arm.svg',200,500,50,20)
for name,x,y,size in [('control_move',28,575,112),('control_aim',1095,575,112),('control_jump',985,600,80),('shot_resource',25,25,32),('jump_resource',25,65,32)]:
    place(f'assets/ui/{name}.svg',x,y,size,size)
target=ROOT/'preview/plains_runtime_snapshot.svg'
target.parent.mkdir(exist_ok=True)
ET.ElementTree(root).write(target,encoding='unicode',xml_declaration=False)
print(target.relative_to(ROOT))
