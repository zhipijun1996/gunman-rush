"""Technical atlas registration only; retain generated pixels at one fixed scale."""
import hashlib,json
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
D=ROOT/'assets/player_presentation_01/charging'
SCALE=46/250

def build():
    im=Image.open(D/'generated/player.png').convert('RGBA')
    atlas=Image.new('RGBA',(320,192));frames=[]
    for i in range(12):
        x,y=i%4,i//4
        rect=(x*im.width//4,y*im.height//3,(x+1)*im.width//4,(y+1)*im.height//3)
        c=im.crop(rect);c.putalpha(c.getchannel('A').point(lambda a:a if a>=128 else 0))
        b=c.getbbox();boots=c.crop((0,b[3]-25,c.width,b[3])).getchannel('A').getbbox()
        pivot=(boots[0]+boots[2])/2
        c=c.resize((round(c.width*SCALE),round(c.height*SCALE)),Image.Resampling.NEAREST)
        dx=43-round(pivot*SCALE);dy=58-c.getbbox()[3]
        frame=Image.new('RGBA',(80,64));frame.paste(c,(dx,dy));atlas.paste(frame,(x*80,y*64))
        frames.append({'source_cell':rect,'translation':[dx,dy],'bbox':frame.getbbox(),'pixel_sha256':hashlib.sha256(frame.tobytes()).hexdigest()})
    atlas.save(D/'poses.png')
    receipt={'reference':'assets/player_presentation_01/motion_v1/motion_source.png','reference_rect':[0,0,256,256],'reference_pivot':[168,242],'reference_body_height':182,'display_height':44,'control_height':250,'uniform_scale':SCALE,'anchor':[40,58],'canvas':[80,64],'frames':frames,'processing':'full cells; alpha<128 exterior cleanup; nearest resample at ONE scale; integer translation; no repainting or per-pose scaling'}
    station=Image.open(D/'generated/station.png').convert('RGBA')
    station.putalpha(station.getchannel('A').point(lambda a:a if a>=128 else 0))
    crop=station.getbbox();station=station.crop(crop)
    station=station.resize((round(station.width*84/station.height),84),Image.Resampling.NEAREST)
    back=Image.new('RGBA',(96,96));back.paste(station,((96-station.width)//2,8));back.save(D/'station.png')
    front=back.copy()
    # Extract the authored front jambs and sill, without painting any pixels.
    for y in range(96):
        for x in range(96):
            if y<49 or (y<86 and 27<=x<69):front.putpixel((x,y),(0,0,0,0))
    front.save(D/'station_front.png')
    receipt['station']={'source_crop':crop,'native_height':84,'anchor':[48,92],'front_extract':'lower jambs y>=49 outside x27..68; sill y>=86'}
    (D/'build.json').write_text(json.dumps(receipt,indent=2)+'\n')
if __name__=='__main__':build()
