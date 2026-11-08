"""Bake two D calibration sprites and a same-scale sheet; never paint or recolor."""
from pathlib import Path
import hashlib
import json
import sys
import zipfile
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT/'art/reviews/plains_enemies_pr142'
OUT = ART/'pixel_samples'
(OUT/'static').mkdir(exist_ok=True)
records = {}
for name, height in [('sentry',72),('windkeeper_phase2',358)]:
    source = OUT/'source'/f'{name}.png'
    data = np.array(Image.open(source).convert('RGBA'))
    labels, _ = ndimage.label(data[:,:,3]>=128)
    sizes = np.bincount(labels.ravel()); sizes[0]=0
    keep = sizes[labels]>=20
    data[:,:,3] = np.where(keep,255,0); data[~keep]=0
    im = Image.fromarray(data); bounds=im.getbbox(); im=im.crop(bounds)
    native=im.resize((round(im.width*height/im.height),height),Image.Resampling.NEAREST)
    output=OUT/'static'/f'{name}.png'; native.save(output)
    records[name]={'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
                   'crop':bounds,'native_size':native.size,'sha256':hashlib.sha256(output.read_bytes()).hexdigest()}
font='/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc'
board=Image.new('RGB',(1700,1240),'#242b2e'); draw=ImageDraw.Draw(board)
def label(x,y,text,size=22):draw.text((x,y),text,font=ImageFont.truetype(font,size),fill='#ded5bc')
def paste(path,x,y,scale):
    im=Image.open(path).convert('RGBA'); im=im.crop(im.getbbox())
    im=im.resize((im.width*scale,im.height*scale),Image.Resampling.NEAREST)
    board.paste(im,(x,y),im)
label(30,15,'D 配色与像素簇样板：同组同倍率，原主角不改绘',30)
label(30,65,'主角 ×4');label(300,65,'C 哨兵 ×4');label(760,65,'D 哨兵 ×4')
paste(ROOT/'art/world-art-v2/assets/pixel/hero.png',30,210,4)
paste(ART/'static/sentry.png',300,100,4);paste(OUT/'static/sentry.png',760,100,4)
label(30,430,'C 牧风者二阶段 ×2');label(860,430,'D 牧风者二阶段 ×2')
paste(ART/'static/windkeeper_phase2.png',30,480,2);paste(OUT/'static/windkeeper_phase2.png',860,480,2)
paste(ROOT/'art/world-art-v2/assets/pixel/hero.png',750,1108,2)
board.save(OUT/'pixel-comparison.png')
manifest={'status':'two static calibration samples; no user approval; remaining eight C candidates are not restyled',
          'baseline':'PR142; previous C a5668a4',
          'derivation':'alpha>=128, remove disconnected components<20 source pixels; tight crop; uniform nearest bake; no palette filter or code painting',
          'assets':records}
(OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(records))

if '--package-context' in sys.argv:
    context=ROOT/'build/plains_enemies_pr142/pixel-d/context'
    shots=json.loads((context/'capture.json').read_text())['shots']
    assert len(shots)==6
    sheet=Image.new('RGB',(2560,2160))
    for row,(old,new) in enumerate(zip(shots[::2],shots[1::2])):
        assert old['variant']=='C' and new['variant']=='D'
        for key in ['case','camera','zoom','player','room']:assert old[key]==new[key]
        assert [(s['id'],s['feet']) for s in old['sprites']]==[(s['id'],s['feet']) for s in new['sprites']]
        for col,shot in enumerate([old,new]):
            assert all(s['inside_viewport'] for s in shot['sprites'])
            frame=Image.open(ROOT/shot['file'].removeprefix('res://'))
            assert frame.size==(1280,720)
            sheet.paste(frame,(col*1280,row*720))
    sheet.save(context/'context-comparison.png')
    evidence={'scope':'Three actual PR142 rooms; C left, D right, same camera/feet, static only',
              'hashes':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in context.glob('*.png')}}
    (context/'evidence.json').write_text(json.dumps(evidence,indent=2)+'\n')
    with zipfile.ZipFile(context.parent/'pixel-d-samples.zip','w',zipfile.ZIP_DEFLATED) as archive:
        for folder,prefix in [(OUT,'samples'),(context,'context')]:
            for p in folder.rglob('*'):
                if p.is_file():archive.write(p,Path(prefix)/p.relative_to(folder))
    print('PASS: three matching C/D pairs, all sprites in viewport; comparison and ZIP written')
