"""Register generated full poses; crop/nearest/translate only, never paint pixels."""
import hashlib,json
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
D=ROOT/'assets/player_presentation_01/wake_wall'
def build():
    source=Image.open(D/'generated/source.png').convert('RGBA')
    sheet=Image.new('RGBA',(320,192))
    frames=[]
    for i in range(12):
        x,y=i%4*362,i//4*362
        cell=source.crop((x,y,x+362,y+362)).resize((63,63),Image.Resampling.NEAREST)
        bounds=cell.getchannel('A').point(lambda a:255 if a>=128 else 0).getbbox()
        # Wake: keep pelvis over the same floor support. Wall: right hand/boot
        # edge touches the 12wu collision side; every pose keeps its full pixels.
        pivots=[250,240,220,210,210,210,210,200]
        dx=40-round(pivots[i]*63/362) if i<8 else 53-bounds[2]
        dy=58-bounds[3]
        canvas=Image.new('RGBA',(80,64));canvas.paste(cell,(dx,dy))
        sheet.paste(canvas,(i%4*80,i//4*64))
        frames.append({'frame':i,'source_rect':[x,y,362,362],'translation':[dx,dy],'rect':[i%4*80,i//4*64,80,64],'pixel_sha256':hashlib.sha256(canvas.tobytes()).hexdigest()})
    sheet.save(D/'poses.png')
    data={'source':'generated/source.png','source_sha256':hashlib.sha256((D/'generated/source.png').read_bytes()).hexdigest(),'reference':'assets/style_exploration/underworld/player.png','processing':'full nonoverlapping cells; uniform 63/362 nearest scale; integer registration; no pixel painting','canvas':[80,64],'anchor':[40,58],'standing_height':46,'frames':frames}
    (D/'build.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
def build_look():
    source=Image.open(D/'generated/look-source.png').convert('RGBA')
    sheet=Image.new('RGBA',(240,128));frames=[]
    for i in range(6):
        x,y=i%3*512,i//3*512
        cell=source.crop((x,y,x+512,y+512))
        # Only remove generated low-alpha exterior haze; keep opaque art RGB.
        cell.putalpha(cell.getchannel('A').point(lambda a: a if a>=128 else 0))
        cell=cell.resize((64,64),Image.Resampling.NEAREST)
        bounds=cell.getchannel('A').getbbox()
        boots=cell.crop((0,50,64,64)).getchannel('A').getbbox()
        dx=40-round((boots[0]+boots[2])/2);dy=58-bounds[3]
        canvas=Image.new('RGBA',(80,64));canvas.paste(cell,(dx,dy))
        sheet.paste(canvas,(i%3*80,i//3*64))
        frames.append({'frame':i,'source_rect':[x,y,512,512],'translation':[dx,dy],'rect':[i%3*80,i//3*64,80,64],'pixel_sha256':hashlib.sha256(canvas.tobytes()).hexdigest()})
    sheet.save(D/'look.png')
    data={'source':'generated/look-source.png','source_sha256':hashlib.sha256((D/'generated/look-source.png').read_bytes()).hexdigest(),'processing':'full cells; alpha below 128 removed (exterior haze); uniform 1/8 nearest scale; integer foot registration; opaque RGB unchanged','frames':frames}
    (D/'look-build.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
if __name__=='__main__':build();build_look()
