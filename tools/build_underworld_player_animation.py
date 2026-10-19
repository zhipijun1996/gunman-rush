#!/usr/bin/env python3
"""Pack real generated keyframes without painting: declared crop/translate/nearest.

The complete source RGBA is retained. No thresholding, palette replacement,
body drawing, synthetic pose, or per-frame squash is performed.
"""
from pathlib import Path
import argparse,hashlib,json,io
from PIL import Image
ROOT=Path(__file__).resolve().parents[1];REL=Path('assets/underworld_plains/player_animation')
def sha(b):return hashlib.sha256(b).hexdigest()
def build(check=False):
    recipe=json.loads((ROOT/REL/'recipe.json').read_text())
    output=[];frames=[]
    for page in recipe['pages']:
        data=(ROOT/REL/page['source']).read_bytes();im=Image.open(io.BytesIO(data)).convert('RGBA')
        assert sha(data)==page['source_sha256']
        cols,rows=page['grid'];cell_w=im.width/cols;cell_h=im.height/rows
        atlas=Image.new('RGBA',(recipe['canvas'][0]*cols,recipe['canvas'][1]*rows))
        for i,frame in enumerate(page['frames']):
            c=i%cols;r=i//cols
            box=tuple(frame.get("source_rect",(round(c*cell_w),round(r*cell_h),round((c+1)*cell_w),round((r+1)*cell_h))))
            raw=im.crop(box)
            factor=page['nearest_scale']
            resized=raw.resize((round(raw.width*factor),round(raw.height*factor)),Image.Resampling.NEAREST)
            dx=round(recipe['anchor'][0]-frame['pivot_x']*factor)
            dy=round(recipe['anchor'][1]-frame['baseline_y']*factor)
            if 'foot_anchor_y' in frame:
                source_opaque=resized.getchannel('A').point(lambda v:255 if v>=128 else 0).getbbox()
                dy=int(frame['foot_anchor_y'])-source_opaque[3]
            canvas=Image.new('RGBA',tuple(recipe['canvas']));canvas.paste(resized,(dx,dy))
            atlas.paste(canvas,(c*recipe['canvas'][0],r*recipe['canvas'][1]))
            alpha=canvas.getchannel('A');opaque=alpha.point(lambda v:255 if v>=128 else 0).getbbox()
            assert opaque and opaque[0]>0 and opaque[1]>0 and opaque[2]<canvas.width and opaque[3]<canvas.height
            frames.append({'state':frame['state'],'index':frame['index'],'atlas':page['output'],'rect':[c*canvas.width,r*canvas.height,canvas.width,canvas.height],'raw_cell':box,'translation':[dx,dy],'opaque_bounds':opaque,'pixel_sha256':sha(canvas.tobytes()),'anchor':recipe['anchor']})
        buf=io.BytesIO();atlas.save(buf,format='PNG');output.append((REL/page['output'],buf.getvalue()))
    meta={'schema':'underworld-player-animation-v1','builder':'tools/build_underworld_player_animation.py','recipe':'res://'+str(REL/'recipe.json'),'reference':'res://assets/style_exploration/underworld/player.png','canvas':recipe['canvas'],'anchor':recipe['anchor'],'standing_body_source_height':recipe['standing_body_source_height'],'animations':recipe['animations'],'frames':frames,'operations':['exact source cell crops','one declared nearest scale per source page','measured pivot+baseline translation into shared transparent canvas','legal runtime horizontal mirror'],'generated_keyframes':len(frames),'synthetic_pose_count':0,'scope':'Real image-generated body keyframes. Existing weapon remains separate at accepted CourierVisual muzzle. No collision/motor/resource edits.'}
    output.append((REL/'animation_build.json',(json.dumps(meta,ensure_ascii=False,indent=2)+'\n').encode()))
    for rel,data in output:
        if check:assert (ROOT/rel).read_bytes()==data,str(rel)+' differs'
        else:(ROOT/rel).write_bytes(data)
    print('UNDERWORLD PLAYER ANIMATION: '+str(len(frames))+' true generated keyframes; '+('CHECK PASSED (no writes)' if check else 'BUILT'))
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');build(p.parse_args().check)
