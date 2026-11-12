"""Rebuild the final animal/sky delivery from its recorded crops and native anchors.
No painting, pose normalization or historical human sprite regeneration.
"""
from pathlib import Path
import argparse,hashlib,json
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'assets/plains_v07'
def bake(row):
 source=Image.open(ROOT/row['source']).convert('RGBA')
 if row.get('kind')=='npc':
  result=Image.new('RGBA',(row['cell'][0]*row['frames'],row['cell'][1]))
  for i,box in enumerate(row['source_cells']):
   cell=source.crop(tuple(box));cell.putalpha(cell.getchannel('A').point(lambda a:255 if a>=row['alpha_threshold'] else 0))
   scale=row['bake_scale'];center=cell.width*.5
   cell=cell.resize((round(cell.width*scale),round(cell.height*scale)),Image.Resampling.NEAREST)
   bounds=cell.getbbox();x=round(row['anchor'][0]-center*scale);y=row['anchor'][1]-bounds[3]
   if x+bounds[0]<0 or x+bounds[2]>row['cell'][0] or y+bounds[1]<0:raise ValueError('sprite exceeds cell: '+row['asset'])
   result.alpha_composite(cell,(i*row['cell'][0]+x,y))
 else:
  box=row['source_rect'];box=box if row['source_rect_format']=='xyxy' else [box[0],box[1],box[0]+box[2],box[1]+box[3]]
  result=source.crop(box).resize(tuple(row['size']),Image.Resampling.NEAREST)
  if row.get('alpha_threshold') is not None:result.putalpha(result.getchannel('A').point(lambda a:255 if a>=row['alpha_threshold'] else 0))
 return result
if __name__=='__main__':
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--verify',action='store_true');args=parser.parse_args()
 path=BASE/'source/inhabitants-sky-provenance.json';provenance=json.loads(path.read_text());manifest=json.loads((BASE/'manifest.json').read_text())
 for row in provenance['assets']:
  image=bake(row);target=ROOT/row['image']
  if args.verify:
   current=Image.open(target).convert('RGBA')
   if image.size!=current.size or image.tobytes()!=current.tobytes():raise ValueError('native asset differs from recorded bake: '+row['asset'])
  else:
   image.save(target);row['sha256']=hashlib.sha256(target.read_bytes()).hexdigest()
   table='assets' if row.get('kind')=='npc' else 'backgrounds';manifest[table][row['asset']]['sha256']=row['sha256']
 if not args.verify:
  path.write_text(json.dumps(provenance,ensure_ascii=False,indent=2)+'\n');(BASE/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
 print(('Verified' if args.verify else 'Baked'),len(provenance['assets']),'final native assets')
