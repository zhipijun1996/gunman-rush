"""Register the live-body continuation: full crops, one nearest scale, no painting."""
import hashlib,json
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
D=ROOT/'assets/player_presentation_01/wake_wall'
REFERENCE=ROOT/'assets/player_presentation_01/motion_v1/motion_source.png'
# The generated neutral control is 214px tall. All poses share its scale;
# never normalize a crouched, prone, tilted or hanging pose to standing height.
SCALE=46/214
WAKE_PIVOTS=[210,200,192,190]
# Live idle pivot is not the boot midpoint: preserve its 3px stance offset.
STANCE_CENTER=round(((129+234)/2-168)*46/182)

def build():
    source=Image.open(D/'generated/source.png').convert('RGBA')
    sheets={'poses':Image.new('RGBA',(320,192)),'look':Image.new('RGBA',(240,128))}
    frames=[]
    for output_index,source_index in enumerate(range(1,19)):
        row,col=divmod(source_index,5)
        rect=(col*source.width//5,row*source.height//4,(col+1)*source.width//5,(row+1)*source.height//4)
        cell=source.crop(rect)
        cell.putalpha(cell.getchannel('A').point(lambda a:a if a>=128 else 0))
        source_bounds=cell.getchannel('A').getbbox()
        if output_index<4: pivot=WAKE_PIVOTS[output_index]
        elif output_index<8 or output_index>=12:
            boots=cell.crop((0,source_bounds[3]-22,cell.width,source_bounds[3])).getchannel('A').getbbox()
            pivot=(boots[0]+boots[2])/2
        else: pivot=None
        cell=cell.resize((round(cell.width*SCALE),round(cell.height*SCALE)),Image.Resampling.NEAREST)
        bounds=cell.getchannel('A').getbbox()
        dx=53-bounds[2] if pivot is None else 40+STANCE_CENTER-round(pivot*SCALE)
        dy=58-bounds[3]
        canvas=Image.new('RGBA',(80,64));canvas.paste(cell,(dx,dy))
        name,index,columns=('poses',output_index,4) if output_index<12 else ('look',output_index-12,3)
        sheets[name].paste(canvas,(index%columns*80,index//columns*64))
        frames.append({'frame':output_index,'source_frame':source_index,'source_rect':list(rect),'source_opaque_bounds':source_bounds,'translation':[dx,dy],'atlas':name+'.png','rect':[index%columns*80,index//columns*64,80,64],'pixel_sha256':hashlib.sha256(canvas.tobytes()).hexdigest(),'runtime_body':'existing idle renderer' if output_index==7 else 'authored'})
    for name,sheet in sheets.items():sheet.save(D/(name+'.png'))
    data={'source':'generated/source.png','source_sha256':hashlib.sha256((D/'generated/source.png').read_bytes()).hexdigest(),'reference':str(REFERENCE.relative_to(ROOT)),'reference_sha256':hashlib.sha256(REFERENCE.read_bytes()).hexdigest(),'reference_rect':[0,0,256,256],'reference_pivot':[168,242],'reference_body_height':182,'reference_display_height_wu':44,'generated_standing_control_height':214,'uniform_scale':SCALE,'stance_center_native':STANCE_CENTER,'processing':'complete cells; exterior alpha<128 removed; one uniform nearest scale for all 18 poses; integer registration; opaque RGB unchanged','canvas':[80,64],'anchor':[40,58],'standing_height':46,'frames':frames}
    (D/'build.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
if __name__=='__main__':build()
