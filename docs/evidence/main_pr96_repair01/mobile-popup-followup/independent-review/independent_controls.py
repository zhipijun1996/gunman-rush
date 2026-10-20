import hashlib, importlib.util, json, pathlib, sys, time
import numpy as np
from PIL import Image, ImageDraw
root=pathlib.Path(__file__).resolve().parents[3]
sys.dont_write_bytecode=True
sys.path.insert(0,str(root/'tools'))
import studio_gui_pointer as helper
out=pathlib.Path(__file__).resolve().parent
raw=root/'tests/fixtures/studio_gui_pointer/popup_S_mobile.png'
image=Image.open(raw).convert('RGB'); scale=390/720
base=helper._weapon_popup_from_pixels(image,scale,106)
cases=[]
def run(name,img,expected,offset=None):
 t=time.monotonic()
 try:
  result=helper._weapon_popup_from_pixels(img,scale,106)
  accepted=True; detail=result
 except AssertionError as e:
  accepted=False; detail=str(e)
 require=accepted==expected
 if offset is not None and accepted:
  require= require and result['rows']==[y+offset[1] for y in base['rows']] and result['marker_x']==base['marker_x']+offset[0]
 cases.append({'case':name,'expected_accept':expected,'accepted':accepted,'passed':require,'detail':detail,'seconds':time.monotonic()-t})
 assert require, name
# Translate the complete actually observed panel without assigning any target to the parser.
moved=image.copy(); panel=image.crop((94,102,231,355)); ImageDraw.Draw(moved).rectangle((94,102,230,354),fill=(9,3,7)); moved.paste(panel,(254,112))
run('complete_actual_panel_translation_dx160_dy10',moved,True,(160,10))
# Retain the selected silhouette (77/81) but flatten its measured ring contrast.
for name,mode in [('selected_77pixel_shape_flat',0),('selected_cardinal_edges_darker_than_center',1)]:
 altered=image.copy(); l,t,r,b=base['marker_boxes'][0]; bg=image.getpixel((r,t))
 for y in range(t,b):
  for x in range(l,r):
   if image.getpixel((x,y))!=bg: altered.putpixel((x,y),(100,100,100))
 if mode:
  cx,cy=l+(r-l)//2,t+(b-t)//2
  altered.putpixel((cx,cy),(120,120,120))
  for x,y in [(cx,t),(cx,b-1),(l,cy),(r-1,cy)]: altered.putpixel((x,y),(90,90,90))
 run(name,altered,False)
# Shift an actual intact middle circle, keeping the rest of the complete panel and all labels.
altered=image.copy(); l,t,r,b=base['marker_boxes'][7]; patch=image.crop((l,t,r,b))
for y in range(t,b): ImageDraw.Draw(altered).line((l,y,r-1,y),fill=image.getpixel((r,y)))
altered.paste(patch,(l,t+4)); run('actual_middle_circle_shift4px_nonuniform_gaps',altered,False)
# Verify the exact selected foreground area and cardinal contrast in the untouched raw source.
l,t,r,b=base['marker_boxes'][0]; rgb=np.asarray(image); mask=np.any(rgb[t:b,l:r]!=rgb[t:b,r:r+1],axis=2); cx,cy=l+(r-l)//2,t+(b-t)//2
ring={'width':r-l,'height':b-t,'actual_foreground':int(mask.sum()),'area':int(mask.size),'density':float(mask.mean()),'ceil_95percent_area':int(np.ceil(.95*mask.size)),'center_rgb_sum':int(rgb[cy,cx].sum()),'cardinal_edge_rgb_sums':[int(rgb[y,x].sum()) for x,y in [(cx,t),(cx,b-1),(l,cy),(r-1,cy)]]}
assert ring['actual_foreground']==77 and ring['area']==81 and all(x>ring['center_rgb_sum'] for x in ring['cardinal_edge_rgb_sums'])
result={'scope':'Independent in-memory pixel controls only; no browser/native/gameplay claim','helper_sha256':hashlib.sha256((root/'tools/studio_gui_pointer.py').read_bytes()).hexdigest(),'raw_sha256':hashlib.sha256(raw.read_bytes()).hexdigest(),'base':base,'selected_ring':ring,'cases':cases}
(out/'independent-controls.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'cases':[{k:v for k,v in c.items() if k!='detail'} for c in cases],'selected_ring':ring},indent=2))
