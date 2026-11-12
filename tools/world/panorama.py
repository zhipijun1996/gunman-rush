#!/usr/bin/env python3
"""Stitch actual Godot room captures using the canonical physical map; build sparse zoom tiles."""
from pathlib import Path
import argparse,hashlib,json,math,subprocess,shutil
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[2]
BG=(13,16,30)
def bounds(points):return min(p[0] for p in points),min(p[1] for p in points),max(p[0] for p in points),max(p[1] for p in points)
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--captures',type=Path);p.add_argument('--output',type=Path,required=True);p.add_argument('--markers',type=Path);p.add_argument('--metadata-only',action='store_true');args=p.parse_args();out=args.output;out.mkdir(parents=True,exist_ok=True)
 runtime=json.loads((ROOT/'build/world/runtime.json').read_text());rooms=runtime['rooms'];maps={r['id']:r for r in runtime['map_rooms']};groups={}
 for rid,row in maps.items():groups.setdefault(row['map_component'],[]).append(rid)
 base=maps[runtime['start']['room']]['map_component'];order=[base]+[c for c in groups if c!=base];main_box=bounds([p for rid in groups[base] for p in maps[rid]['polygon']]);margin=128
 main_w=round(main_box[2]-main_box[0])+margin*2;main_h=round(main_box[3]-main_box[1])+margin*2;placements={};panels=[];width=main_w;height=main_h;side_y=margin
 for component in order:
  members=groups[component];box=bounds([p for rid in members for p in maps[rid]['polygon']]);extra=component!=base
  offset=[margin-main_box[0],margin-main_box[1]] if not extra else [main_w+margin-box[0],side_y+160-box[1]]
  if extra:
   panel=[main_w+64,side_y,round(box[2]-box[0])+128,round(box[3]-box[1])+224];panels.append({'component':component,'rect':panel,'title':'钟心内室 · 独立室内层 · C07由P33进入' if component=='Z-R01' else component+' · 独立空间层'});width=max(width,panel[0]+panel[2]+64);side_y+=panel[3]+margin;height=max(height,side_y)
  for rid in members:
   ox,oy=maps[rid]['origin'];placements[rid]={'at':[round(ox+offset[0]),round(oy+offset[1])],'polygon':[[round(x+offset[0]),round(y+offset[1])] for x,y in maps[rid]['polygon']],'center':[round(maps[rid]['map_centre'][0]+offset[0]),round(maps[rid]['map_centre'][1]+offset[1])],'component':component}
 # A shared doorway must land on the same output pixel in the continuous plane.
 for rid,row in rooms.items():
  for door in row['doors']:
   if not door['target_implemented'] or door.get('front_door'):continue
   target=door['target_room'];paired=next(d for d in rooms[target]['doors'] if d['id']==door['target_door_id'])
   a=[placements[rid]['at'][i]+door['position_candidate']['local_world_units'][i] for i in (0,1)]
   b=[placements[target]['at'][i]+paired['position_candidate']['local_world_units'][i] for i in (0,1)]
   assert a==b,(door['id'],'stitch seam drift',a,b)
 marker_path=args.markers or ((args.captures.parent if args.captures else out.parent)/'captures.json')
 marker_rows={r['room']:r.get('markers',[]) for r in json.loads(marker_path.read_text())} if marker_path.exists() else {}
 design=json.loads((ROOT/'game/world/regions/P/room_design.json').read_text());purposes={r['room_id']:r['purpose'] for r in design['rooms']}
 def annotate(records):
  for record in records:
   rid=record['id'];record['preview']=rooms[rid]['world_geometry']['shape_class']=='threshold_sample';record['at']=placements[rid]['at'];record['purpose']='区域入口示例；后续路线封闭' if record['preview'] else '钟心室内剧情；C07往返平原前庭' if rid=='Z-R01' else purposes.get(rid,rooms[rid]['purpose']);record['markers']=marker_rows.get(rid,record.get('markers',[]))
  return records
 if args.metadata_only:
  target=out/'panorama.json';manifest=json.loads(target.read_text());assert manifest['content_version']==runtime['content_version'] and [manifest['width'],manifest['height']]==[width,height],'Captures require rebuilding'
  manifest['rooms']=annotate(manifest['rooms']);manifest['main_component']=base;manifest['builder_commit']=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip();manifest['revision']=hashlib.sha256(json.dumps(manifest['rooms'],sort_keys=True,ensure_ascii=False).encode()).hexdigest()[:16];target.write_text(json.dumps(manifest,ensure_ascii=False,separators=(',',':'))+'\n');shutil.copy(ROOT/'tools/world/panorama.html',out/'index.html');print('PANORAMA METADATA',len(manifest['rooms']),'rooms');return
 if args.captures is None:p.error('--captures is required unless --metadata-only is used')
 image=Image.new('RGB',(width,height),BG);draw=ImageDraw.Draw(image);font=ImageFont.truetype('/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',48)
 for panel in panels:
  x,y,w,h=panel['rect'];draw.rectangle((x,y,x+w,y+h),fill='#18202a',outline='#7d929c',width=5);draw.text((x+32,y+36),panel['title'],font=font,fill='#dbd7c5')
 records=[]
 for rid,row in rooms.items():
  source=args.captures/(rid+'.png');assert source.is_file(),source
  assert hashlib.sha256((ROOT/row['scene_ref'].removeprefix('res://')).read_bytes()).hexdigest()==runtime['scene_sources'][row['scene_ref']],rid+' scene differs from compiled runtime'
  with Image.open(source) as raw:
   rgb=raw.convert('RGB');extent=row['world_geometry']['bounds_world_units'][2:];assert list(rgb.size)==extent,(rid,rgb.size,extent)
   placed=placements[rid];at=placed['at'];mask=Image.new('L',rgb.size);ImageDraw.Draw(mask).polygon([(x-at[0],y-at[1]) for x,y in placed['polygon']],fill=255);image.paste(rgb,tuple(at),mask)
  box=bounds(placed['polygon']);entries=[d for d in row['doors'] if d['target_implemented']];entry=entries[0]['id'] if entries else ''
  records.append({'id':rid,'name':row['name'],'box':[box[0],box[1],box[2]-box[0],box[3]-box[1]],'center':placed['center'],'polygon':placed['polygon'],'component':placed['component'],'preview':not rid.startswith('P-') and rid!='Z-R01','entry':entry,'capture_sha256':hashlib.sha256(source.read_bytes()).hexdigest()})
 print('STITCHED',len(records),'rooms',width,height,flush=True)
 image.save(out/'panorama-full.jpg',quality=95,subsampling=0,optimize=True)
 preview=image.copy();preview.thumbnail((2400,1600),Image.Resampling.LANCZOS);preview.save(out/'overview.jpg',quality=90)
 # Adjacent rectangles are clipped at the actual polygon, so no room masks another.
 tile_size=512;max_z=max(0,math.ceil(math.log2(max(width,height)/tile_size)));levels=[]
 for z in range(max_z+1):
  factor=2**(max_z-z);w=math.ceil(width/factor);h=math.ceil(height/factor);levels.append({'width':w,'height':h,'factor':factor,'tiles':[]})
 for z in range(max_z,-1,-1):
  level=levels[z];scaled=image if z==max_z else image.resize((level['width'],level['height']),Image.Resampling.LANCZOS);directory=out/'tiles'/str(z);directory.mkdir(parents=True,exist_ok=True)
  for y in range(0,scaled.height,tile_size):
   for x in range(0,scaled.width,tile_size):
    tile=scaled.crop((x,y,min(x+tile_size,scaled.width),min(y+tile_size,scaled.height)))
    lohi=tile.getextrema()
    if all(lo==hi==BG[i] for i,(lo,hi) in enumerate(lohi)):continue
    name=f'{x//tile_size}-{y//tile_size}.webp';tile.save(directory/name,lossless=True,method=1);level['tiles'].append(f'{x//tile_size}-{y//tile_size}')
  print('TILES',z,len(level['tiles']),flush=True)
 commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip();build_info=json.loads((ROOT/'build/opening-atmosphere/prepared-web/build-info.json').read_text())
 manifest={'schema':1,'width':width,'height':height,'background':'#0d101e','tile_size':tile_size,'max_z':max_z,'levels':levels,'rooms':annotate(records),'panels':panels,'main_component':base,'builder_commit':commit,'source_commit':commit,'content_version':runtime['content_version'],'game_build':build_info['build_id'],'units_per_native_pixel':1,'method':'actual 1wu/px Godot overview captures; polygon-clipped in canonical world coordinates; independent interiors inset without changing their internal scale; HUD/player hidden; overview background/parallax differs from normal gameplay camera','full_jpeg_bytes':(out/'panorama-full.jpg').stat().st_size}
 manifest['revision']=hashlib.sha256(json.dumps(manifest['rooms'],sort_keys=True,ensure_ascii=False).encode()).hexdigest()[:16]
 (out/'panorama.json').write_text(json.dumps(manifest,ensure_ascii=False,separators=(',',':'))+'\n');shutil.copy(ROOT/'tools/world/panorama.html',out/'index.html')
 assert len(records)==len(maps)==len(rooms)
 print('PANORAMA COMPLETE',len(records),'rooms',sum(len(l['tiles']) for l in levels),'tiles',flush=True)
if __name__=='__main__':main()
