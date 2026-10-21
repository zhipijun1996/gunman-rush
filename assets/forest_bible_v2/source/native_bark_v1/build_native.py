"""Compile explicitly authored I pixels with the unchanged shared47 crop recipe.
This is an asset assembly recipe, not an imagegen edit or a new topology builder.
Default verifies the retained source outputs; --write reproduces them locally.
"""
from pathlib import Path
import argparse,json
from PIL import Image
p=Path(__file__).resolve().parent
root=p.parents[3]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--write',action='store_true')
args=parser.parse_args()
spec=json.loads((root/'assets/underworld_plains/terrain/terrain_build.json').read_text())
base=Image.open(root/'assets/underworld_plains/terrain/source.png').convert('RGBA')
palette={'k':(7,10,22,255),'s':(5,8,17,255),'b':(18,20,22,255),'h':(31,29,24,255)}
rows=(p/'interior-bark.rows').read_text().splitlines()
assert len(rows)==16 and all(len(row)==16 for row in rows)
assert all(symbol in '=ksbh' for row in rows for symbol in row)
source=base.copy()
for y,row in enumerate(rows):
 for x,symbol in enumerate(row):
  if symbol!='=':source.putpixel((32+x,16+y),palette[symbol])
assert source.getchannel('A').tobytes()==base.getchannel('A').tobytes()
def assemble(material):
 atlas=Image.new('RGBA',(128,96))
 for mask,parts in spec['source_regions'].items():
  ax,ay=spec['mask_to_atlas'][mask]
  for part in parts:
   piece=material.crop(tuple(part['source']))
   if part['horizontal_flip']:piece=piece.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
   dx,dy,ex,ey=part['destination']
   assert piece.size==(ex-dx,ey-dy)
   atlas.paste(piece,(ax*16+dx,ay*16+dy))
 return atlas
# First prove the exact same recipe reconstructs the actual shared atlas.
assert assemble(base).tobytes()==Image.open(root/'assets/underworld_plains/terrain/terrain.png').convert('RGBA').tobytes()
atlas=assemble(source)
for name,image in [('bark-source.native.png',source),('bark-atlas47.native.png',atlas)]:
 if args.write:image.save(p/name)
 stored=Image.open(p/name).convert('RGBA')
 assert stored.size==image.size and stored.tobytes()==image.tobytes(),name
print('PASS: original47 recipe exact; authored native I source/atlas reproduced; no geometry claim')
