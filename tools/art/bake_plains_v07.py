"""Bake source-native pixel sampling, alpha cleanup and fixed foot anchors.
Does not paint or synthesize artwork; sources come from image generation.
"""
from pathlib import Path
import hashlib,json
from PIL import Image
ROOT=Path(__file__).resolve().parents[2];BASE=ROOT/'assets/plains_v07'
def bake(source,rows):
 image=Image.open(BASE/'source'/source).convert('RGBA');cw,ch=image.width//6,image.height//4
 records={}
 for row,(name,height,cell,kind) in enumerate(rows):
  frames=[];rects=[]
  for col in range(6):
   tile=image.crop((col*cw,row*ch,(col+1)*cw,(row+1)*ch));alpha=tile.getchannel('A').point(lambda a:255 if a>=128 else 0);tile.putalpha(alpha)
   bbox=alpha.getbbox()
   if bbox is None:raise ValueError(name)
   frames.append((tile,bbox));rects.append([col*cw,row*ch,cw,ch])
  factor=height/max(b[3]-b[1] for t,b in frames)
  sheet=Image.new('RGBA',(cell*6,cell))
  for col,(tile,b) in enumerate(frames):
   crop=tile.crop(b);crop=crop.resize((max(1,round(crop.width*factor)),max(1,round(crop.height*factor))),Image.Resampling.NEAREST)
   # Foot/base always stable; burst uses an invariant centre instead.
   x=col*cell+(cell-crop.width)//2;y=cell-4-crop.height if kind!='burst' else (cell-crop.height)//2
   sheet.alpha_composite(crop,(x,y))
  dest=BASE/'native'/f'{name}.png';dest.parent.mkdir(parents=True,exist_ok=True);sheet.save(dest)
  records[name]={'image':str(dest.relative_to(ROOT)),'cell':[cell,cell],'frames':6,'anchor':[cell//2,cell-4] if kind!='burst' else [cell//2,cell//2],'fps':6 if kind!='burst' else 15,'source':f'assets/plains_v07/source/{source}','source_cells':rects,'bake_scale':factor,'native_body_height':height,'alpha_threshold':128,'kind':kind,'sha256':hashlib.sha256(dest.read_bytes()).hexdigest()}
 return records
records=bake('inhabitants-generated.png',[('reclaimer',44,64,'npc'),('weaver',44,64,'npc'),('aqi',42,64,'npc'),('charging_station',72,96,'station')])
records.update(bake('collectibles-generated.png',[('time_gear',32,48,'pickup'),('health_shard',28,48,'pickup'),('resonance_shard',32,48,'pickup'),('collection_burst',56,72,'burst')]))
records.update(bake('mechanisms-generated.png',[('grapple_device',32,48,'pickup'),('equipment',32,48,'pickup'),('clock_altar',88,112,'mechanism'),('pulley_switch',48,64,'mechanism')]))
records.update(bake('aqi-story-generated.png',[(name,42,64,'npc') for name in ['aqi_clock','aqi_tea','aqi_lantern','aqi_lookout']]))
# Independent back-wall planes; mechanical 2x2 extraction at native pixel density.
interior=Image.open(BASE/'source/interiors-generated.png').convert('RGBA')
backgrounds={}
for i,name in enumerate(['mill','barn','cellar','well']):
 x=(i%2)*768;y=(i//2)*512
 panel=interior.crop((x,y,x+768,y+512)).resize((384,256),Image.Resampling.NEAREST)
 dest=BASE/'native'/('interior_'+name+'.png');panel.save(dest)
 backgrounds[name]={'image':str(dest.relative_to(ROOT)),'source':'assets/plains_v07/source/interiors-generated.png','source_rect':[x,y,768,512],'size':[384,256],'sha256':hashlib.sha256(dest.read_bytes()).hexdigest()}
props={}
prop_source=Image.open(BASE/'source/props-generated.png').convert('RGBA')
for i,(name,height) in enumerate([('barrel',48),('tilted_barrel',40),('storage_crates',64),('merchant_counter',80),('hanging_chime',72),('travel_bundle',24)]):
 x=(i%3)*512;y=(i//3)*512
 tile=prop_source.crop((x,y,x+512,y+512));alpha=tile.getchannel('A').point(lambda a:255 if a>=128 else 0);tile.putalpha(alpha)
 crop=tile.crop(alpha.getbbox());factor=height/crop.height
 native=crop.resize((round(crop.width*factor),height),Image.Resampling.NEAREST)
 dest=BASE/'native'/(name+'.png');native.save(dest)
 props[name]={'image':str(dest.relative_to(ROOT)),'source':'assets/plains_v07/source/props-generated.png','source_rect':[x,y,512,512],'size':list(native.size),'bake_scale':factor,'sha256':hashlib.sha256(dest.read_bytes()).hexdigest()}
# Large architecture remains individual editable scenery, never baked room pictures.
for source,entries,columns,rows in [
 ('architecture-generated.png',[('carriage',160),('waiting_shelter',176),('windmill_frame',320),('bridge_pier',208),('market_stalls',144),('sunken_well',160)],3,2),
 ('story-traces-generated.png',[('aqi_ribbon',64),('aqi_note',80),('aqi_bench',96)],3,1),
 ('clocktower-generated.png',[('world_clock_close',512),('world_clock_far',176)],1,1)]:
 image=Image.open(BASE/'source'/source).convert('RGBA');cw,ch=image.width//columns,image.height//rows
 for i,(name,height) in enumerate(entries):
  idx=i if columns>1 else 0;x=idx%columns*cw;y=idx//columns*ch
  tile=image.crop((x,y,x+cw,y+ch));alpha=tile.getchannel('A').point(lambda a:255 if a>=128 else 0);tile.putalpha(alpha)
  crop=tile.crop(alpha.getbbox());factor=height/crop.height
  native=crop.resize((round(crop.width*factor),height),Image.Resampling.NEAREST)
  dest=BASE/'native'/(name+'.png');native.save(dest)
  props[name]={'image':str(dest.relative_to(ROOT)),'source':'assets/plains_v07/source/'+source,'source_rect':[x,y,cw,ch],'size':list(native.size),'bake_scale':factor,'sha256':hashlib.sha256(dest.read_bytes()).hexdigest()}
(BASE/'manifest.json').write_text(json.dumps({'schema':1,'style':'underworld-regional-v1','generator':'image_gen','sources':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (BASE/'source').glob('*.png')},'assets':records,'backgrounds':backgrounds,'props':props,'validation':'native assets require actual Godot composite and animation review'},ensure_ascii=False,indent=2)+'\n')
