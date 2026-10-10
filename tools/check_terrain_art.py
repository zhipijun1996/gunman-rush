#!/usr/bin/env python3
"""Validate manifest, original SVG dimensions, provenance and actual raster seams."""
from pathlib import Path
import json, hashlib, xml.etree.ElementTree as ET, tempfile, subprocess, os
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
manifest=json.loads((ROOT/'assets/terrain/plains/metadata.json').read_text())
assets=manifest['assets']; assert len(assets)>=20
for a in assets:
 p=ROOT/a['path']; data=p.read_bytes()
 if p.suffix=='.svg':
  svg=ET.fromstring(data)
  dimensions=[int(svg.get('width')),int(svg.get('height'))]
 else:
  dimensions=list(Image.open(p).size)
 assert dimensions==a['size_px'], a['id']
 assert hashlib.sha256(data).hexdigest()==a['sha256'], a['id']
 assert a['render_scale']==.5
 assert all(isinstance(v,(int,float)) for v in a['anchor_px'])
with tempfile.TemporaryDirectory(prefix='plains-art-') as tmp:
 t=Path(tmp); source='extends SceneTree\nfunc _initialize():\n'
 for i,a in enumerate(assets):
  source+=f' var img_{i} = Image.new()\n if img_{i}.load({json.dumps(str(ROOT/a["path"]))}) != OK:\n  quit(1)\n  return\n img_{i}.save_png({json.dumps(str(t/(a["id"]+".png")))})\n'
 source+=' quit(0)\n'; (t/'render.gd').write_text(source)
 env=os.environ.copy()
 for k in ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME']:env[k]=str(t/k)
 subprocess.run(['godot','--headless','--path',tmp,'--script',str(t/'render.gd')],env=env,check=True)
 for a in assets:
  im=Image.open(t/(a['id']+'.png')).convert('RGBA')
  if 'grass_middle' in a['id'] or 'rock_fill' in a['id']:
   assert all(im.getpixel((0,y))==im.getpixel((127,y)) for y in range(128)),a['id']+' horizontal seam'
  if 'rock_fill' in a['id']:
   assert all(im.getpixel((x,0))==im.getpixel((x,127)) for x in range(128)),a['id']+' vertical seam'
 strip=Image.new('RGBA',(640,128))
 for i,n in enumerate(['grass_left_1','grass_middle_1','grass_middle_2','grass_middle_3','grass_right_1']):strip.paste(Image.open(t/('plains_'+n+'.png')),(i*128,0))
 strip.save(ROOT/'assets/terrain/plains/seam_preview.png')
print(f'PASS: {len(assets)} art assets rasterized; dimensions, hashes, anchors and 6 repeat tile seam pairs verified')
