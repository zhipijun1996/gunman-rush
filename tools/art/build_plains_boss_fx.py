#!/usr/bin/env python3
"""Bake painted boss effects; never paints pixels."""
from pathlib import Path
import json
import hashlib
import numpy as np
from PIL import Image
from scipy import ndimage
from build_plains_actor_animations import bands, ROOT

ART=ROOT/'assets/plains_boss_fx_142'

def main():
    manifest=[]
    for name in ('bellstrider_fx','windkeeper_fx'):
        source=ART/'source'/f'{name}.png'
        raw=np.array(Image.open(source).convert('RGBA'))
        mask=raw[:,:,3]>=128
        labels,_=ndimage.label(mask);areas=np.bincount(labels.ravel())
        mask &= areas[labels]>=3
        raw[:,:,3]=mask.astype('uint8')*255;raw[~mask,:3]=0
        clean=Image.fromarray(raw);rows=bands(mask)
        assert len(rows)==4,(name,rows)
        cell_size=(160,64)
        sizes=[(38,24),(26,28),(58,52),(70,36)] if name.startswith('bell') else [(32,18),(34,24),(58,52),(150,42)]
        atlas=Image.new('RGBA',(640,256));boxes=[]
        for row,(top,bottom) in enumerate(rows):
            strip=clean.crop((0,top,clean.width,bottom))
            cols=bands(np.array(strip)[:,:,3].T>0)
            while len(cols)>4:
                i=min(range(len(cols)-1),key=lambda k:cols[k+1][0]-cols[k][1])
                cols[i:i+2]=[(cols[i][0],cols[i+1][1])]
            assert len(cols)==4,(name,row,cols)
            # A fixed row scale preserves the expansion of impact/dust frames.
            crops=[strip.crop((left,0,right,bottom-top)) for left,right in cols]
            crops=[c.crop(c.getbbox()) for c in crops]
            scale=min(sizes[row][0]/max(c.width for c in crops),sizes[row][1]/max(c.height for c in crops))
            for col,c in enumerate(crops):
                c=c.resize((max(1,round(c.width*scale)),max(1,round(c.height*scale))),Image.Resampling.NEAREST)
                projectile_front=(row==0 or (name.startswith('wind') and row==1))
                anchor_x=c.width-c.height//2 if projectile_front else c.width//2
                at=(80-anchor_x,32-c.height//2)
                atlas.paste(c,(col*160+at[0],row*64+at[1]));boxes.append([*at,c.width,c.height])
        atlas.save(ART/f'{name}.png')
        meta={'id':name,'columns':4,'rows':4,'frame_size':list(cell_size),'pivot':[80,32],'visible_boxes':boxes,'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'atlas_sha256':hashlib.sha256((ART/f'{name}.png').read_bytes()).hexdigest()}
        manifest.append(meta)
        print(name,'16 frames',rows)
    (ART/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')

if __name__=='__main__':main()
