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
 background=np.asarray(Counter(image.getdata()).most_common(1)[0][0],dtype=np.float32)
 rgb=np.asarray(image,dtype=np.uint32)
 packed=(rgb[:,:,0]<<16)|(rgb[:,:,1]<<8)|rgb[:,:,2]
 def run_colors(lines,minimum):
  result=set()
  for line in lines:
   starts=np.r_[0,np.flatnonzero(line[1:]!=line[:-1])+1]
   ends=np.r_[starts[1:],line.size]
   result.update(line[starts[(ends-starts)>=minimum]].tolist())
  return result
 # A rare highlighted button border can be absent from any top-N palette.
 # Observe actual straight runs in both axes instead. These lengths are the
 # central half-edges of the minimum accepted 80x20 rectangle below; they
 # propose colors only, never relax complete four-edge/bounds verification.
 colors=run_colors(packed,40)&run_colors(packed.T,10)
 values=rgb.astype(np.float32)-background
 boxes=set()
 for packed_color in sorted(colors):
  color=tuple((packed_color>>shift)&255 for shift in (16,8,0))

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

def _studio_button_inner_fill(image,box):
 """An observed inner rectangle, only within an already complete border ROI."""
 import numpy as np
 crop=image.crop(box).convert('RGB');rgb=np.asarray(crop)
 color=Counter(crop.getdata()).most_common(1)[0][0]
 fill=np.all(rgb==color,axis=2);ys,xs=np.where(fill)
 left,top,right,bottom=int(xs.min()),int(ys.min()),int(xs.max())+1,int(ys.max())+1
 w,h=right-left,bottom-top
 if not(80<=w and 20<=h and left>0 and top>0 and right<crop.width and bottom<crop.height):return None
 if np.mean(fill[top:bottom,left:right])<=.6:return None
 xs=slice(left+w//4,right-w//4);ys=slice(top+h//4,bottom-h//4)
 inside=[fill[top,xs],fill[bottom-1,xs],fill[ys,left],fill[ys,right-1]]
 outside=[fill[top-1,xs],fill[bottom,xs],fill[ys,left-1],fill[ys,right]]
 if not(all(np.mean(edge)>=.8 for edge in inside) and all(np.mean(~edge)>=.8 for edge in outside)):return None
 return (box[0]+left,box[1]+top,box[0]+right,box[1]+bottom)

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
  origin=box[:2];ocr_scale=6
  try:local=_studio_label_box(result.stdout,'ACTIONS',ocr_scale)
  except StudioMenuLabelMissing as first_missing:
   # Keep the complete four-stroke border requirement above. Only its observed
   # closed inner fill may omit the border from this one fixed OCR derivative.
   item['border_ocr_missing']=str(first_missing)
   inner=_studio_button_inner_fill(image,box)
   if inner is None:item.update(result='missing',error=str(first_missing));continue
   name=f'{stem}-button-{index}-inner';roi=image.crop(inner).convert('L')
   roi=roi.resize((roi.width*8,roi.height*8),Image.Resampling.LANCZOS)
   path=folder/(name+'.png');roi.save(path);started=time.monotonic()
   result=subprocess.run(['tesseract',str(path),'stdout','--psm','7','tsv'],capture_output=True,text=True,check=True,timeout=10,env={**os.environ,'OMP_THREAD_LIMIT':'1'})
   (folder/(name+'.tsv')).write_text(result.stdout)
   item.update(inner_fill_bounds=inner,inner_screenshot=name+'.png',inner_ocr=name+'.tsv',inner_seconds=time.monotonic()-started)
   origin=inner[:2];ocr_scale=8
   try:local=_studio_label_box(result.stdout,'ACTIONS',ocr_scale)
   except StudioMenuLabelMissing as exc:item.update(result='missing',error=str(exc));continue
  # Any ambiguity within a complete button is immediately a failure.
  item['result']='complete_label';point=(local[0]+origin[0],local[1]+origin[1]);item['point']=point
  words=[word for word in csv.DictReader(io.StringIO(result.stdout),delimiter='\t')
         if word.get('text','').strip().upper()=='ACTIONS'
         and int(word['left'])<=local[0]*ocr_scale<=int(word['left'])+int(word['width'])
         and int(word['top'])<=local[1]*ocr_scale<=int(word['top'])+int(word['height'])]
  assert len(words)==1,'Complete ACTIONS label has no unique actual glyph bounds'
  word=words[0];glyph=(origin[0]+int(word['left'])/ocr_scale,origin[1]+int(word['top'])/ocr_scale,
                     origin[0]+(int(word['left'])+int(word['width']))/ocr_scale,origin[1]+(int(word['top'])+int(word['height']))/ocr_scale)
  item['actual_glyph_bounds']=glyph;matches[glyph]=point
 if not matches:raise StudioMenuLabelMissing("Expected one complete rendered menu label 'ACTIONS'; found 0 complete button matches")
 assert len(matches)==1,f"Expected one complete rendered menu label 'ACTIONS'; found {len(matches)} complete button matches"
 return next(iter(matches.values()))

def _studio_title_from_pixels(pixels,folder,stem,observation,whole_tsv):
 """Full-frame title first; only missing text permits same-frame complete ROIs."""
 label='DEVELOPMENT DEMOS / ALL ENTRIES'
 try:return _studio_label_box(whole_tsv,label,3)
 except StudioMenuLabelMissing:observation['whole_frame_title']='missing'
 import numpy as np
 import os,subprocess,time
 image=Image.open(io.BytesIO(pixels)).convert('RGB');started=time.monotonic()
 rgb=np.asarray(image,dtype=np.uint32);packed=(rgb[:,:,0]<<16)|(rgb[:,:,1]<<8)|rgb[:,:,2]
 def run_colors(lines,minimum):
  colors=set()
  for line in lines:
   starts=np.r_[0,np.flatnonzero(line[1:]!=line[:-1])+1]
   ends=np.r_[starts[1:],line.size]
   colors.update(line[starts[(ends-starts)>=minimum]].tolist())
  return colors
 boxes=set()
 for color in run_colors(packed,80)&run_colors(packed.T,20):
  remaining={(int(x),int(y))for y,x in np.argwhere(packed==color)}
  while remaining:
   seed=remaining.pop();pending=[seed];points=[]
   while pending:
    x,y=pending.pop();points.append((x,y))
    for point in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
     if point in remaining:remaining.remove(point);pending.append(point)
   xs,ys=zip(*points);left,top,right,bottom=min(xs),min(ys),max(xs)+1,max(ys)+1
   w,h=right-left,bottom-top
   if not(80<=w<=image.width*.9 and 20<=h<=image.height*.15 and 2<=w/h<=24 and len(points)/(w*h)>.6):continue
   if left<1 or top<1 or right>=image.width or bottom>=image.height:continue
   # Fractional rasterization can omit a colored outline pixel on one side.
   # Require all FOUR actual straight fill boundaries instead: central inner
   # edges are the observed fill, immediately outer edges must not be that fill.
   xs=slice(left+w//4,right-w//4);ys=slice(top+h//4,bottom-h//4)
   inside=[packed[top,xs],packed[bottom-1,xs],packed[ys,left],packed[ys,right-1]]
   outside=[packed[top-1,xs],packed[bottom,xs],packed[ys,left-1],packed[ys,right]]
   if all(np.mean(edge==color)>=.8 for edge in inside) and all(np.mean(edge!=color)>=.8 for edge in outside):boxes.add((left,top,right,bottom))
 observation['title_geometry_seconds']=time.monotonic()-started
 observation['title_button_rois']=[];matches={}
 for index,box in enumerate(sorted(boxes)):
  name=f'{stem}-title-button-{index}';roi=image.crop(box).convert('L')
  # Nearest copies the actual small glyph pixels; it neither reconstructs
  # missing letters nor blurs the tiny native gaps into different letters.
  roi=roi.resize((roi.width*6,roi.height*6),Image.Resampling.NEAREST)
  path=folder/(name+'.png');roi.save(path);started=time.monotonic()
  result=subprocess.run(['tesseract',str(path),'stdout','--psm','7','tsv'],capture_output=True,text=True,check=True,timeout=10,env={**os.environ,'OMP_THREAD_LIMIT':'1'})
  (folder/(name+'.tsv')).write_text(result.stdout)
  item={'bounds':box,'screenshot':name+'.png','ocr':name+'.tsv','seconds':time.monotonic()-started};observation['title_button_rois'].append(item)
  try:local=_studio_label_box(result.stdout,label,6)
  except StudioMenuLabelMissing as exc:item.update(result='missing',error=str(exc));continue
  point=(local[0]+box[0],local[1]+box[1]);item.update(result='complete_label',actual_glyph_center=point)
  matches[point]=point
 if not matches:raise StudioMenuLabelMissing(f'Expected one complete rendered menu label {label!r}; found 0 complete button matches')
 assert len(matches)==1,f'Expected one complete rendered menu label {label!r}; found {len(matches)} complete button matches'
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
     point=_studio_title_from_pixels(pixels,folder,stem,observation,tsv) if label=='DEVELOPMENT DEMOS / ALL ENTRIES' else _studio_label_box(tsv,label,3)
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

def _weapon_popup_from_pixels(image,scale,start_y):
 """One complete popup and fifteen actual circular radio components, any palette."""
 import numpy as np
 rgb=np.asarray(image.convert('RGB'),dtype=np.uint32)
 height,width=rgb.shape[:2];packed=(rgb[:,:,0]<<16)|(rgb[:,:,1]<<8)|rgb[:,:,2]
 def components(mask):
  pixels={(int(x),int(y))for y,x in np.argwhere(mask)}
  while pixels:
   seed=pixels.pop();pending=[seed];points=[]
   while pending:
    x,y=pending.pop();points.append((x,y))
    for point in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
     if point in pixels:pixels.remove(point);pending.append(point)
   xs,ys=zip(*points)
   yield (min(xs),min(ys),max(xs)+1,max(ys)+1),points
 # A long, exact fill run proposes a panel background; neither gray color nor
 # a preselected screen column is a popup identity or an item-coordinate fallback.
 colors=set()
 for column in packed.T:
  starts=np.r_[0,np.flatnonzero(column[1:]!=column[:-1])+1]
  ends=np.r_[starts[1:],column.size]
  colors.update(column[starts[(ends-starts)>300*scale]].tolist())
 candidates=[]
 for color in sorted(colors):
  for (left,top,right,bottom),points in components(packed==color):
   w,h=right-left,bottom-top
   if not(bottom>start_y and h>300*scale and 80*scale<=w<width*.9 and len(points)/(w*h)>.5):continue
   if left<1 or top<1 or right>=width or bottom>=height:continue
   # The actual fill must be enclosed by all four matching straight border
   # edges. A partially clipped popup cannot supply inferred missing items.
   xs=slice(left+w//4,right-w//4);ys=slice(top+h//4,bottom-h//4)
   edges=[packed[top-1,xs],packed[bottom,xs],packed[ys,left-1],packed[ys,right]]
   border=Counter(int(value)for edge in edges for value in edge).most_common(1)[0][0]
   if border==color or not all(np.mean(edge==border)>=.8 for edge in edges):continue
   crop=packed[top:bottom,left:right];markers=[]
   for (l,t,r,b),part in components(crop!=color):
    mw,mh=r-l,b-t
    if not(6*scale<=min(mw,mh) and max(mw,mh)<=24*scale and .85<=mw/mh<=1.18):continue
    silhouette=np.zeros((mh,mw),dtype=bool)
    for x,y in part:silhouette[y-t,x-l]=True
    # Real selected/unselected radios share a filled, round silhouette even
    # when their low-contrast RGB values differ from each other/background.
    if not(.65<=silhouette.mean()<.95 and np.mean(silhouette==silhouette[:,::-1])>=.9 and np.mean(silhouette==silhouette[::-1,:])>=.9):continue
    if any(silhouette[y,x]for x,y in ((0,0),(mw-1,0),(0,mh-1),(mw-1,mh-1))):continue
    if not(silhouette[mh//2,:].all() and silhouette[:,mw//2].all()):continue
    markers.append((left+l,top+t,left+r,top+b))
   columns={}
   for box in markers:
    # Exact observed component centers; no estimates for absent radio rows.
    columns.setdefault((box[0]+box[2]-1)/2,[]).append(box)
   for x,boxes in columns.items():
    if len(boxes)!=15:continue
    boxes.sort(key=lambda b:b[1]);rows=[(b[1]+b[3]-1)/2 for b in boxes]
    gaps=[b-a for a,b in zip(rows,rows[1:])]
    if min(gaps)>20*scale and max(gaps)-min(gaps)<4*scale:
     candidates.append({'marker_x':x,'rows':rows,'marker_boxes':boxes,'bounds':(left-1,top-1,right+1,bottom+1),'background_rgb':tuple((color>>shift)&255 for shift in (16,8,0))})
 assert len(candidates)==1,f'actual fifteen evenly spaced item markers not uniquely observed: {len(candidates)} complete popup/column candidates'
 return candidates[0]

async def open_weapon_picker(page,touch=False):
 scale,pad,h=geometry(page);await click(page,pad+145*scale,await weapon_row_y(page),touch);await page.wait_for_timeout(200)
 im=Image.open(io.BytesIO(await page.screenshot())).convert('RGB')
 start_y=round((await weapon_row_y(page))+18*scale)
 try:popup=_weapon_popup_from_pixels(im,scale,start_y)
 except AssertionError:
  from pathlib import Path
  Path('build/weapon_feel').mkdir(parents=True,exist_ok=True)
  im.save('build/weapon_feel/popup_failure.png')
  raise
 return popup['marker_x'],popup['rows']

async def select_weapon(page,index,touch=False):
 x,rows=await open_weapon_picker(page,touch);target_y=rows[index]
 if not touch:await page.mouse.move(x,target_y);await page.wait_for_timeout(200)
 await click(page,x,target_y,touch)
