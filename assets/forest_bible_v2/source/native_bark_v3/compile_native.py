"""Native source compiler for assets/.../source/native_bark_v3.
No neighbor algorithm fork. Reassemble retained exact13slot alpha + indexedRGB,
then original47quarter recipe. Executed offline during explicitrootGO; noengine/import is involved.
"""
from pathlib import Path
import json
from PIL import Image
here=Path(__file__).resolve().parent
root=here.parents[3]
spec=json.loads((root/'assets/underworld_plains/terrain/terrain_build.json').read_text())
original=Image.open(root/'assets/underworld_plains/terrain/source.png').convert('RGBA')
material=original.copy()
palette=json.loads((here/'material.palette.json').read_text())['palette_RGB']
for role,xy in spec['native_regions'].items():
 rows=(here/(role+'.authored.rows')).read_text().splitlines()
 assert len(rows)==16 and all(len(row)==16 for row in rows)
 sx,sy=xy[0]*16,xy[1]*16
 for y,row in enumerate(rows):
  for x,symbol in enumerate(row):
   alpha=original.getpixel((sx+x,sy+y))[3]
   if alpha>0:material.putpixel((sx+x,sy+y),(*palette[symbol],alpha))
def assemble(source):
 atlas=Image.new('RGBA',(128,96))
 for mask,parts in spec['source_regions'].items():
  ax,ay=spec['mask_to_atlas'][mask]
  for part in parts:
   piece=source.crop(tuple(part['source']))
   if part['horizontal_flip']:piece=piece.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
   dx,dy,_,_=part['destination'];atlas.paste(piece,(ax*16+dx,ay*16+dy))
 return atlas
assert original.getchannel('A').tobytes()==material.getchannel('A').tobytes()
old=assemble(original)
assert old.tobytes()==Image.open(root/'assets/underworld_plains/terrain/terrain.png').convert('RGBA').tobytes()
atlas=assemble(material)
assert old.getchannel('A').tobytes()==atlas.getchannel('A').tobytes()
material.save(here/'bark-source.native.png');atlas.save(here/'bark-atlas47.native.png')
print('Rebuiltnative13mothers/original47withsamealpha; noartacceptance')
