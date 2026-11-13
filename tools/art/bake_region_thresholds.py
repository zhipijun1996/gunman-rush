#!/usr/bin/env python3
"""Mechanically repack existing regional 47 tiles for the formal exact-boundary renderer."""
from pathlib import Path
import argparse,hashlib,json
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--verify',action='store_true');args=p.parse_args()
 m=json.loads((ROOT/'art/world-art-v2/assets/terrain47/manifest.json').read_text());rows={}
 for family in m["regions"]:
  if family == "windchime_plains": continue
  spec=m['regions'][family];src=ROOT/'art/world-art-v2'/spec['atlas'];im=Image.open(src).convert('RGBA')
  tile=lambda mask:im.crop((int(spec['maskToAtlas'][str(mask)][0])*32,int(spec['maskToAtlas'][str(mask)][1])*32,int(spec['maskToAtlas'][str(mask)][0]+1)*32,int(spec['maskToAtlas'][str(mask)][1]+1)*32))
  atlas=Image.new('RGBA',(768,192));source=Image.new('RGBA',(1056,288))
  for bank in range(3):
   atlas.paste(im,(bank*256,0))
   for y in range(0,288,32):
    for x in range(0,352,32):source.paste(tile(255),(bank*352+x,y))
   for pos,mask in { (32,0):28,(64,0):124,(96,0):112,(32,32):31,(64,32):255,(96,32):241,(32,64):7,(64,64):199,(96,64):193,(128,0):223,(160,0):247,(128,32):127,(160,32):253}.items():source.paste(tile(mask),(bank*352+pos[0],pos[1]))
  outputs={}
  for kind,pixels in [('atlas47',atlas),('source',source)]:
   dst=ROOT/f'assets/region_thresholds/native/{family}_{kind}.png'
   if args.verify:assert Image.open(dst).convert('RGBA').tobytes()==pixels.tobytes(),dst
   else:pixels.save(dst)
   outputs[kind]={'image':str(dst.relative_to(ROOT)),'sha256':hashlib.sha256(dst.read_bytes()).hexdigest()}
  rows[family]={'source':str(src.relative_to(ROOT)),'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'outputs':outputs}
 out=ROOT/'assets/region_thresholds/manifest.json';data={'schema':1,'method':'native32 unchanged RGBA; three identical banks; exact-boundary mask repack','families':rows}
 if args.verify:assert json.loads(out.read_text())==data
 else:out.write_text(json.dumps(data,indent=2)+'\n')
 print(('VERIFIED' if args.verify else 'BAKED'),len(rows),'regional material families')
if __name__=='__main__':main()
