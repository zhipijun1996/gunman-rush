"""Build viewport-sized inspection tiles from real Godot room captures."""
from pathlib import Path
import argparse,hashlib,json,math
from PIL import Image

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--captures',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
    records=json.loads((a.captures/'captures.json').read_text());rooms={}
    for record in records:
        source=a.captures/'rooms'/record['file'];digest=hashlib.sha256(source.read_bytes()).hexdigest();folder=a.output/digest[:20];folder.mkdir(exist_ok=True)
        image=Image.open(source).convert('RGB');levels=[]
        for scale in [0.0625,0.25,1.0]:
            size=(max(1,math.ceil(image.width*scale)),max(1,math.ceil(image.height*scale)));scaled=image.resize(size,Image.Resampling.LANCZOS);tiles=[]
            for y in range(0,size[1],512):
                for x in range(0,size[0],512):
                    tile=scaled.crop((x,y,min(x+512,size[0]),min(y+512,size[1])));name=f'{scale}-{x}-{y}.webp';tile.save(folder/name,'WEBP',quality=83,method=4)
                    tiles.append({'bounds':[x/scale,y/scale,tile.width/scale,tile.height/scale],'url':digest[:20]+'/'+name})
            levels.append({'scale':scale,'tiles':tiles})
        rooms[record['room']]={'source_sha256':digest,'size':record['size'],'levels':levels,'inspection_only':True}
    (a.output/'manifest.json').write_text(json.dumps({'schema':1,'rooms':rooms},ensure_ascii=False,separators=(',',':')))
    print(f'REAL ROOM TILES: {len(rooms)} rooms, {sum(f.stat().st_size for f in a.output.rglob("*.webp"))} bytes')
if __name__=='__main__':main()
