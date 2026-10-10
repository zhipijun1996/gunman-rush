"""Record original painted PNGs, atlas regions and read-only alpha measurements."""
from pathlib import Path
import hashlib
import json
from statistics import median
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
PACK=ROOT/'assets/painterly_v2'

def bounds(image,threshold=128,region=None):
    # Pixel analysis only. Original PNGs are never modified or exported.
    if image.mode!='RGBA':
        return [0,0,*image.size]
    x0,y0,x1,y1=region or [0,0,*image.size]
    pixel=image.load()
    xs,ys=[],[]
    for y in range(y0,y1):
        for x in range(x0,x1):
            if pixel[x,y][3]>=threshold:
                xs.append(x);ys.append(y)
    return [min(xs),min(ys),max(xs)+1,max(ys)+1] if xs else None

def main():
    assets=[]
    for path in sorted(PACK.rglob('*.png')):
        if 'candidates' in path.parts or 'rejected' in path.parts or 'seam_candidate' in path.name or '_rejected' in path.name:
            continue
        image=Image.open(path)
        b=bounds(image)
        assets.append({'id':path.relative_to(PACK).with_suffix('').as_posix().replace('/','.'),
            'path':path.relative_to(ROOT).as_posix(),'width':image.width,'height':image.height,
            'mode':image.mode,'opaque_bounds':b,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
            'status':'visual_review','device_status':'device_pending','source_unchanged':True,
            'repeat_approved':False})
    frames=[]
    character=PACK/'character/manifest.json'
    if character.exists():
        data=json.loads(character.read_text())
        # An agent-supplied frame table has priority over nominal sheet grids.
        frames=[f for f in data.get('preview_frames',data.get('frames',[])) if f.get('state') in {'idle','run','jump','fall','recoil','death'}]
    if not isinstance(frames,list):
        frames=[]
    heights=[]
    for frame in frames:
        path=ROOT/frame['path']
        image=Image.open(path)
        x,y,w,h=frame['region']
        b=bounds(image,128,[int(x),int(y),int(x+w),int(y+h)])
        if b:
            heights.append(b[3]-b[1])
        if 'pivot_px' not in frame and b:
            pixel=image.load();xs=[]
            for py in range(max(b[1],b[3]-max(4,int((b[3]-b[1])*.09))),b[3]):
                for px in range(b[0],b[2]):
                    if pixel[px,py][3]>=180:xs.append(px)
            foot_x=sum(xs)/len(xs) if xs else (b[0]+b[2])*.5
            frame['pivot_px']=[round(foot_x-x,2),b[3]-y]
    result={'schema_version':1,'style_version':'painterly_v2','region_id':'windchime_plains',
            'status':'visual_review','generation':'image_gen_originals','assets':assets,'frames':frames,
            'character_scale':90/median(heights) if heights else .1,
            'source_character_height':median(heights) if heights else None,
            'independent_aim_approved':False,
            'scope':'fixed_scene_art_sample_not_random_map_validation'}
    (PACK/'manifest.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(f'Painterly catalog: {len(assets)} untouched PNGs, {len(frames)} atlas frames')

if __name__=='__main__':
    main()
