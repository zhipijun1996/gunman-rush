from pathlib import Path
from PIL import Image
import csv,io,json,subprocess,os,re,time,hashlib
out=Path(__file__).parent;inputs=[]
inputs.append(('ci7_plains1',Path('build/integration01/local-gui07/touch-plains-map1-entry.png'),'WINDCHIME PLAINS 1/2',True))
for device in ['mouse','touch']:
 for index in [1,2]:inputs.append((f'old_{device}_forest{index}',Path(f'build/forest_grapple02/browser_gui02/{device}-thorn_forest-map{index}-entry.png'),f'THORN FOREST {index}/2',True))
for name in ['wrong_region','wrong_map','blank','actual_glyphs_with_suffix','duplicate_title']:inputs.append((name,Path(f'build/integration01/hud-title-ocr-diagnosis01/{name}.png'),'WINDCHIME PLAINS 1/2',False))
norm=lambda s:re.sub('[^A-Z0-9]','',s.upper());records=[]
for name,path,expected,should_pass in inputs:
 im=Image.open(path).convert('RGB')
 for strategy in ['A','B']:
  observations=[];matches=[]
  for panel_y in [8,220,382,590]:
   box=(12,panel_y+6,250 if strategy=='A' else 332,panel_y+(26 if strategy=='A' else 52));crop=im.crop(box).convert('L');p=out/f'{name}-{strategy}-{panel_y}.png';crop.resize((crop.width*6,crop.height*6),Image.Resampling.LANCZOS).save(p);started=time.monotonic();r=subprocess.run(['tesseract',str(p),'stdout','--psm','7'if strategy=='A'else'6','tsv'],capture_output=True,text=True,timeout=10,env={**os.environ,'OMP_THREAD_LIMIT':'1'});p.with_suffix('.tsv').write_text(r.stdout);words=[w for w in csv.DictReader(io.StringIO(r.stdout),delimiter='\t')if w.get('text','').strip()];lines={}
   for w in words:lines.setdefault(tuple(w[k]for k in ['page_num','block_num','par_num','line_num']),[]).append(w)
   rendered=[' '.join(w['text']for w in row)for row in lines.values()];guard=False
   if strategy=='A':
    # Refuse a crop that intersects actual bright heading ink at the title
    # field boundary. Never decide success by cutting away a suffix.
    guard=any(min(im.getpixel((x,y)))>=235 and max(im.getpixel((x,y)))-min(im.getpixel((x,y)))<=25 for x in range(246,251)for y in range(box[1],box[3]))
    count=int(norm(' '.join(rendered))==norm(expected)and not guard)
   else:count=sum(norm(line)==norm(expected+' INFO')for line in rendered)
   observations.append({'box':box,'lines':rendered,'cut_boundary_ink':guard,'matches':count,'seconds':time.monotonic()-started})
   matches.extend([panel_y]*count)
  accepted=len(matches)==1;records.append({'case':name,'strategy':strategy,'expected':expected,'should_pass':should_pass,'accepted':accepted,'correct_outcome':accepted==should_pass,'observations':observations});print(name,strategy,accepted,accepted==should_pass,observations[0]['lines'],flush=True)
(out/'report.json').write_text(json.dumps({'scope':'Bounded A complete title field with ink-boundary guard versus B taller entire panel OCR complete heading+INFO; actual CI7 Plains and4 OLD native Forest plus5 pixelnegative controls. Offline only, no source edits.','cases':records},indent=2)+'\n')
