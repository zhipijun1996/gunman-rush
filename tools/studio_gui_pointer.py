"""Locate the actual canvas menu on screenshots, then use normal pointer input."""
import io
from collections import Counter
from PIL import Image

class StudioMenuLabelMissing(AssertionError):
 """Only a missing visible label permits another actual scroll observation."""

def _studio_label_box(tsv, label, scale=1):
 """Exact rendered OCR row, including suffixes; never a coordinate fallback."""
 import csv,re
 normalize=lambda value:re.sub(r'[^A-Z0-9]','',value.upper())
 rows={}
 for word in csv.DictReader(io.StringIO(tsv),delimiter='\t'):
  if not word.get('text','').strip():continue
  key=tuple(word.get(k,'')for k in ('page_num','block_num','par_num','line_num'))
  rows.setdefault(key,[]).append(word)
 matches=[]
 for words in rows.values():
  rendered=' '.join(w['text']for w in words)
  selected=words
  if label=='ACTIONS'and re.search(r'[/|]',rendered):
   # This one actual bilingual button has a stable complete English clause.
   # The left clause is not an English OCR spelling/word whitelist for Chinese.
   # Require exactly one real delimiter and one complete right-side OCR word;
   # never accept substring/suffix matches or estimate bounds within a word.
   clauses=re.split(r'[/|]',rendered)
   if len(clauses)!=2 or not clauses[0].strip()or clauses[1].strip().upper()!='ACTIONS':continue
   selected=[w for w in words if w['text'].strip().upper()=='ACTIONS']
   if len(selected)!=1:continue
  elif normalize(rendered)!=normalize(label):continue
  left=min(int(w['left'])for w in selected);top=min(int(w['top'])for w in selected)
  right=max(int(w['left'])+int(w['width'])for w in selected);bottom=max(int(w['top'])+int(w['height'])for w in selected)
  matches.append((left,top,right,bottom))
 if label=='DEVELOPMENT DEMOS / ALL ENTRIES':
  # Tesseract can split this one complete visible button across blocks. Join
  # only words on an identical pixel baseline/height and a contiguous run;
  # never search a substring within another row or bridge a large blank gap.
  baselines={}
  for words in rows.values():
   for word in words:
    key=(word.get('page_num',''),int(word['top']),int(word['height']))
    baselines.setdefault(key,[]).append(word)
  for (_page,top,height),words in baselines.items():
   runs=[]
   for word in sorted(words,key=lambda w:int(w['left'])):
    if not runs or int(word['left'])-(int(runs[-1][-1]['left'])+int(runs[-1][-1]['width']))>2*height:runs.append([])
    runs[-1].append(word)
   for run in runs:
    if normalize(' '.join(w['text']for w in run))!=normalize(label):continue
    left=min(int(w['left'])for w in run);right=max(int(w['left'])+int(w['width'])for w in run)
    matches.append((left,top,right,top+height))
  # Both parsers must participate in ambiguity detection. A normal OCR row
  # cannot hide a second complete button split across other OCR blocks.
  # Deduplicate only the same actual pixel rectangle found by both paths.
  matches=list(dict.fromkeys(matches))
 if not matches:raise StudioMenuLabelMissing(f'Expected one complete rendered menu label {label!r}; found 0')
 if len(matches)!=1:raise AssertionError(f'Expected one complete rendered menu label {label!r}; found {len(matches)}')
 left,top,right,bottom=matches[0]
 return (left+right)/2/scale,(top+bottom)/2/scale

def _studio_ready_event(event):
 return (isinstance(event,dict)and event.get('action')in ('weapon_entities','weapon_motion','training_motion')
         and type(event.get('physics_tick'))is int and event['physics_tick']>0
         and isinstance(event.get('weapon'),str)and bool(event['weapon'])
         and isinstance(event.get('position'),list)and len(event['position'])==2
         and isinstance(event.get('detail'),dict))

def _studio_button_boxes(image):
 """Complete visible rectangular borders, derived only from screenshot pixels."""
 from PIL import ImageFilter
 import numpy as np
 image=image.convert('RGB');width,height=image.size
 palette=Counter(image.getdata()).most_common(16)
 background=np.asarray(palette[0][0],dtype=np.float32)
 values=np.asarray(image,dtype=np.float32)-background
 boxes=set()
 for color,_count in palette:
  direction=np.asarray(color,dtype=np.float32)-background
  squared=float(np.dot(direction,direction))
  if not squared:continue
  # Subpixel UI borders are the observed anchor blended with the observed
  # panel background. Accept only that color segment (<=3/channel residual),
  # never a broad color-distance threshold or alterations to OCR source pixels.
  alpha=np.sum(values*direction,axis=2)/squared
  residual=np.max(np.abs(values-alpha[:,:,None]*direction),axis=2)
  coverage=(alpha>=.25)&(alpha<=1)&(residual<=3)
  mask=Image.fromarray(coverage.astype(np.uint8)*255)
  # Join only antialiased corner gaps; OCR always uses unaltered source pixels.
  mask=mask.filter(ImageFilter.MaxFilter(5))
  pixels={(i%width,i//width)for i,value in enumerate(mask.getdata())if value}
  while pixels:
   seed=pixels.pop();pending=[seed];left=right=seed[0];top=bottom=seed[1];count=0
   while pending:
    x,y=pending.pop();count+=1
    left=min(left,x);right=max(right,x);top=min(top,y);bottom=max(bottom,y)
    for point in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
     if point in pixels:pixels.remove(point);pending.append(point)
   w=right-left+1;h=bottom-top+1
   if not(80<=w<=width*.9 and 20<=h<=height*.15 and 2<=w/h<=24 and count/(w*h)<.6):continue
   # Every complete border must have all four straight central edges. Text
   # components and partially visible buttons must never define a crop.
   xs=range(left+w//4,right-w//4+1);ys=range(top+h//4,bottom-h//4+1)
   edges=([mask.getpixel((x,top))for x in xs],
          [mask.getpixel((x,bottom))for x in xs],
          [mask.getpixel((left,y))for y in ys],
          [mask.getpixel((right,y))for y in ys])
   if all(sum(bool(value)for value in edge)/len(edge)>=.8 for edge in edges):boxes.add((left,top,right+1,bottom+1))
 # Refuse complexity rather than truncating candidate geometry and hiding an
 # ambiguous second button. This cap is not a gameplay assertion/attempt cap.
 if len(boxes)>32:raise AssertionError('More than 32 complete screenshot button borders')
 return sorted(boxes)

def _studio_actions_from_pixels(pixels,folder,stem,observation):
 """OCR every complete button, then require one actual ACTIONS glyph rectangle."""
 import csv,json,os,subprocess,time
 image=Image.open(io.BytesIO(pixels)).convert('RGB');started=time.monotonic()
 boxes=_studio_button_boxes(image);observation['button_geometry_seconds']=time.monotonic()-started
 observation['button_rois']=[];matches={}
 for index,box in enumerate(boxes):
  name=f'{stem}-button-{index}';roi=image.crop(box).convert('L')
  roi=roi.resize((roi.width*6,roi.height*6),Image.Resampling.LANCZOS)
  path=folder/(name+'.png');roi.save(path);started=time.monotonic()
  result=subprocess.run(['tesseract',str(path),'stdout','--psm','7','tsv'],capture_output=True,text=True,check=True,timeout=10,env={**os.environ,'OMP_THREAD_LIMIT':'1'})
  (folder/(name+'.tsv')).write_text(result.stdout)
  item={'bounds':box,'screenshot':name+'.png','ocr':name+'.tsv','seconds':time.monotonic()-started}
  observation['button_rois'].append(item)
  try:local=_studio_label_box(result.stdout,'ACTIONS',6)
  except StudioMenuLabelMissing as exc:item.update(result='missing',error=str(exc));continue
  # Any ambiguity within a complete button is immediately a failure.
  item['result']='complete_label';point=(local[0]+box[0],local[1]+box[1]);item['point']=point
  words=[word for word in csv.DictReader(io.StringIO(result.stdout),delimiter='\t')
         if word.get('text','').strip().upper()=='ACTIONS'
         and int(word['left'])<=local[0]*6<=int(word['left'])+int(word['width'])
         and int(word['top'])<=local[1]*6<=int(word['top'])+int(word['height'])]
  assert len(words)==1,'Complete ACTIONS label has no unique actual glyph bounds'
  word=words[0];glyph=(box[0]+int(word['left'])/6,box[1]+int(word['top'])/6,
                     box[0]+(int(word['left'])+int(word['width']))/6,box[1]+(int(word['top'])+int(word['height']))/6)
  item['actual_glyph_bounds']=glyph;matches[glyph]=point
 if not matches:raise StudioMenuLabelMissing("Expected one complete rendered menu label 'ACTIONS'; found 0 complete button matches")
 assert len(matches)==1,f"Expected one complete rendered menu label 'ACTIONS'; found {len(matches)} complete button matches"
 return next(iter(matches.values()))

async def enter_action_studio(page,touch=False,between_clicks_ms=300):
 """Navigate visible menus with actual pointer input; require a fresh Studio event.

 No DOM/game-state evaluation, synthetic engine event, fixed-point fallback or
 weapon-picker changes. Existing consumers retain their post-entry timing.
 """
 import json,os,subprocess,time
 from pathlib import Path
 folder=Path('build/studio-navigation')/str(time.time_ns());folder.mkdir(parents=True,exist_ok=False)
 observed=[];receipt={'touch':touch,'clicks':[],'observations':[],'gestures':[],'status':'failed','scope':'Screenshot OCR navigation and read-only actual STUDIO_EVENT; no gameplay acceptance'}
 def console(message):
  if 'STUDIO_EVENT 'not in message.text:return
  try:observed.append(json.loads(message.text.split('STUDIO_EVENT ',1)[1]))
  except json.JSONDecodeError:pass
 page.on('console',console)
 async def scroll_visible_menu(name):
  width,height=page.viewport_size['width'],page.viewport_size['height']
  # These are a scroll gesture within the visible menu, never button targets.
  # Scale the original forest consumer's real 900,570 -> 900,338 DOM swipe
  # to the actual viewport, including the original 844x390 mobile consumer.
  x=width*900/1280;start=height*570/720;end=height*338/720
  if touch:
   session=await page.context.new_cdp_session(page)
   try:
    await session.send('Input.dispatchTouchEvent',{'type':'touchStart','touchPoints':[{'x':x,'y':start,'id':0,'radiusX':8,'radiusY':8,'force':1}]})
    for step in range(1,9):
     await session.send('Input.dispatchTouchEvent',{'type':'touchMove','touchPoints':[{'x':x,'y':start+(end-start)*step/8,'id':0,'radiusX':8,'radiusY':8,'force':1}]})
     await page.wait_for_timeout(25)
    await session.send('Input.dispatchTouchEvent',{'type':'touchEnd','touchPoints':[]})
   finally:
    await session.detach()
   gesture={'kind':'CDP_real_DOM_touch_scroll','from':[x,start],'to':[x,end]}
  else:
   await page.mouse.move(x,start)
   await page.mouse.wheel(0,start-end)
   gesture={'kind':'real_mouse_wheel','at':[x,start],'delta':[0,start-end]}
  receipt['gestures'].append({'menu':name,'viewport':[width,height],**gesture})
  await page.wait_for_timeout(200)
 async def label_click(name,label):
  for attempt in range(5):
   stem=f'{name}-{attempt}'
   pixels=await page.screenshot();(folder/(stem+'.png')).write_bytes(pixels)
   observation={'label':label,'attempt':attempt,'screenshot':stem+'.png'}
   receipt['observations'].append(observation)
   try:
    if label=='ACTIONS':
     point=_studio_actions_from_pixels(pixels,folder,stem,observation)
    else:
     im=Image.open(io.BytesIO(pixels)).convert('L');im=im.resize((im.width*3,im.height*3))
     data=io.BytesIO();im.save(data,format='PNG')
     result=subprocess.run(['tesseract','stdin','stdout','--psm','11','tsv'],input=data.getvalue(),capture_output=True,check=True,timeout=10,env={**os.environ,'OMP_THREAD_LIMIT':'1'})
     tsv=result.stdout.decode();(folder/(stem+'.tsv')).write_text(tsv)
     observation['ocr']=stem+'.tsv'
     point=_studio_label_box(tsv,label,3)
   except StudioMenuLabelMissing as exc:
    observation['result']='missing';observation['error']=str(exc)
    if attempt==4:raise
    await scroll_visible_menu(name)
    continue
   observation['result']='unique_visible_match'
   receipt['clicks'].append({**observation,'point':point})
   await click(page,*point,touch)
   return
 try:
  await label_click('title','DEVELOPMENT DEMOS / ALL ENTRIES')
  await page.wait_for_timeout(between_clicks_ms)
  await label_click('development','ACTIONS')
  # Bounded readiness belongs to navigation only; original checks and action
  # delays start after this fresh actual consumer has identified itself.
  end=time.monotonic()+5
  while not any(_studio_ready_event(e)for e in observed)and time.monotonic()<end:
   await page.wait_for_timeout(50)
  assert any(_studio_ready_event(e)for e in observed),'ActionStudio did not emit a fresh read-only STUDIO_EVENT after actual menu clicks'
  receipt['status']='passed'
 except Exception as exc:
  receipt['error']=f'{type(exc).__name__}: {exc}'
  raise
 finally:
  page.remove_listener('console',console)
  receipt['observed_events']=observed
  (folder/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')

def geometry(page):
 w,h=page.viewport_size['width'],page.viewport_size['height'];scale=min(w/1280,h/720)
 return scale,(w-1280*scale)/2,h

async def weapon_row_y(page):
 scale,pad,h=geometry(page);im=Image.open(io.BytesIO(await page.screenshot())).convert('RGB');x=round(pad+970*scale);start=round(100*scale);ref=im.getpixel((x,start));y=start
 while y<min(h,round(270*scale))and sum(abs(a-b)for a,b in zip(im.getpixel((x,y)),ref))<70:y+=1
 assert y>start+20*scale,'HUD panel bottom not observed'
 return y-32*scale

async def click(page,x,y,touch=False):
 if touch:await page.touchscreen.tap(x,y)
 else:await page.mouse.click(x,y)

async def open_weapon_picker(page,touch=False):
 scale,pad,h=geometry(page);await click(page,pad+145*scale,await weapon_row_y(page),touch);await page.wait_for_timeout(200)
 im=Image.open(io.BytesIO(await page.screenshot())).convert('RGB');x=round(pad+45*scale);reference_x=round(pad+54*scale)
 # Radio icons are dark/white against the plain gray gap beside each icon.
 start_y=round((await weapon_row_y(page))+18*scale)
 colors=Counter(im.getpixel((reference_x,yy)) for yy in range(start_y,h) if max(im.getpixel((reference_x,yy)))-min(im.getpixel((reference_x,yy)))<14 and max(im.getpixel((reference_x,yy)))<100)
 assert colors,"native dark menu background not observed"
 background=colors.most_common(1)[0][0]
 bounds=[]
 for yy in range(start_y,h):
  reference=im.getpixel((reference_x,yy))
  if max(reference)<min(120,max(background)+50) and max(reference)-min(reference)<14:
   if not bounds or yy>bounds[-1][-1]+1:bounds.append([yy])
   else:bounds[-1].append(yy)
 assert bounds,"native popup vertical bounds missing"
 menu=max(bounds,key=len)
 assert len(menu)>300*scale,"full native menu not observed"
 hits=[]
 for yy in menu:
  pixel=im.getpixel((x,yy));reference=im.getpixel((reference_x,yy))
  if max(reference)<min(120,max(background)+50) and max(reference)-min(reference)<14 and max(pixel)-min(pixel)<14 and abs(sum(pixel)-sum(reference))>25:hits.append(yy)
 groups=[]
 for yy in hits:
  if not groups or yy-groups[-1][-1]>10*scale:groups.append([yy])
  else:groups[-1].append(yy)
 centers=[(g[0]+g[-1])/2 for g in groups];candidates=[]
 for start in range(len(centers)-14):
  rows=centers[start:start+15];gaps=[b-a for a,b in zip(rows,rows[1:])]
  if min(gaps)>20*scale and max(gaps)-min(gaps)<4*scale:candidates.append(rows)
 if len(candidates)!=1:
  from pathlib import Path
  Path('build/weapon_feel').mkdir(parents=True,exist_ok=True)
  im.save('build/weapon_feel/popup_failure.png')
 assert len(candidates)==1,f'actual fifteen evenly spaced item markers not observed: {centers}'
 return pad+145*scale,candidates[0]

async def select_weapon(page,index,touch=False):
 x,rows=await open_weapon_picker(page,touch);target_y=rows[index]
 if not touch:await page.mouse.move(x,target_y);await page.wait_for_timeout(200)
 await click(page,x,target_y,touch)
