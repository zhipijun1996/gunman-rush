"""Locate the actual canvas menu on screenshots, then use normal pointer input."""
import io,csv,os,subprocess
from functools import lru_cache
from collections import Counter
from PIL import Image

class StudioMenuLabelMissing(AssertionError):
 """Only a missing visible label permits another actual scroll observation."""

def _studio_label_box(tsv, label, scale=1):
 """Exact rendered OCR row, including suffixes; never a coordinate fallback."""
 import csv,re
 normalize=(lambda value:''.join(c for c in value.upper() if c.isalnum())) if any('\u3400'<=c<='\u9fff' for c in label) else (lambda value:re.sub(r'[^A-Z0-9]','',value.upper()))
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
 try:return _studio_legacy_actions_from_pixels(pixels,folder,stem,observation)
 except StudioMenuLabelMissing as legacy_missing:
  observation['legacy_actions_missing']=str(legacy_missing)
 path=folder/(stem+'.png')
 if not path.exists():path.write_bytes(pixels)
 elif path.read_bytes()!=pixels:raise AssertionError('Current Actions screenshot differs from observed bytes')
 point=_studio_current_reference(path,'actions')
 observation['locator']='source_bound_current_full_control_pixels'
 return point

def _studio_legacy_actions_from_pixels(pixels,folder,stem,observation):
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

def _studio_legacy_title_from_pixels(pixels,folder,stem,observation,whole_tsv):
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

def _complete_native_fill(image,box):
 """Require four actual fill boundaries, including unclipped outer pixels."""
 import numpy as np
 a=np.asarray(image.convert('RGB'));left,top,right,bottom=box;w=right-left;h=bottom-top
 if left<1 or top<1 or right>=image.width or bottom>=image.height:return False
 crop=image.crop(box);color=Counter(crop.getdata()).most_common(1)[0][0]
 mask=np.max(np.abs(a.astype(int)-color),axis=2)<3
 xs=slice(left+w//4,right-w//4);ys=slice(top+h//4,bottom-h//4)
 inside=[mask[top,xs],mask[bottom-1,xs],mask[ys,left],mask[ys,right-1]]
 outside=[mask[top-1,xs],mask[bottom,xs],mask[ys,left-1],mask[ys,right]]
 return all(np.mean(edge)>=.8 for edge in inside) and all(np.mean(~edge)>=.8 for edge in outside)

def locate_pixel_control(path,phrase,tess_args=(),exact=False):
 from PIL import Image,ImageOps
 import numpy as np,scipy.ndimage as ndi
 pic=Image.open(path).convert('RGB');array=np.asarray(pic).astype(int)
 normalize=lambda t: ''.join(x for x in t if x.isalnum()).upper()
 target=normalize(phrase);cjk=any(0x3400<=ord(x)<=0x9fff for x in phrase)
 matches={}
 if exact and cjk:
  languages=subprocess.run(['tesseract',*tess_args,'--list-langs'],capture_output=True,text=True,check=True,timeout=10).stdout.splitlines()
  if not {'eng','chi_sim'}.issubset(set(languages)):raise RuntimeError('Current Chinese title requires eng and chi_sim; configure TESSDATA_PREFIX or tess_args')
 _,surfaces=native_surfaces(path,[(41,58,59),(59,78,76),(195,163,102),(37,53,56)])
 for left,top,right,bottom in surfaces:
   xx=slice(left,right);yy=slice(top,bottom);width=right-left;height=bottom-top
   if exact and not _complete_native_fill(pic,(left,top,right,bottom)):continue
   roi=path.with_name(path.stem+'-control-'+str(xx.start)+'-'+str(yy.start)+'.png')
   pic.crop((xx.start,yy.start,xx.stop,yy.stop)).resize((width*3,height*3)).save(roi)
   versions=[roi]
   if cjk:
    binary=roi.with_name(roi.stem+'-binary.png')
    ImageOps.invert(Image.open(roi).convert('L').point(lambda v:255 if v>145 else 0)).save(binary)
    versions.append(binary)
   for observed in versions:
    for psm in (['7','6'] if cjk else ['7']):
     args=['tesseract',str(observed),'stdout','--psm',psm]
     if cjk:args+=[*tess_args,'-l','chi_sim+eng','-c','tessedit_create_tsv=1']
     else:args+=['tsv']
     result=subprocess.run(args,capture_output=True,text=True,check=True,timeout=10,env={**os.environ,'OMP_THREAD_LIMIT':'1'})
     observed.with_suffix('.psm'+psm+'.tsv').write_text(result.stdout)
     if exact:
      try:local=_studio_label_box(result.stdout,phrase,3)
      except StudioMenuLabelMissing:continue
      matches[(left,top,right,bottom)]=(left+local[0],top+local[1])
      continue
     words=[normalize(r.get('text','')) for r in csv.DictReader(io.StringIO(result.stdout),delimiter='\t') if normalize(r.get('text',''))]
     for start in range(len(words)):
      for end in range(start+1,min(len(words),start+14)+1):
       if ''.join(words[start:end])==target:return (xx.start+xx.stop)/2,(yy.start+yy.stop)/2
 if exact and matches:
  if len(matches)!=1:raise AssertionError(f'Expected one complete rendered menu label {phrase!r}; found {len(matches)} complete button matches')
  return next(iter(matches.values()))
 if exact and phrase=='开发入口':
  try:return _studio_current_reference(path,'title')
  except StudioMenuLabelMissing:pass
 raise ValueError('Actual native button text missing from cropped pixel controls: '+phrase)

def native_surfaces(path,colors,minimum=(60,28)):
 from PIL import Image
 import numpy as np,scipy.ndimage as ndi
 pic=Image.open(path).convert('RGB');a=np.asarray(pic).astype(int);result=[]
 for color in colors:
  labels,_=ndi.label(np.max(np.abs(a-color),axis=2)<3)
  for bounds in ndi.find_objects(labels):
   if bounds is None:continue
   yy,xx=bounds;w=xx.stop-xx.start;h=yy.stop-yy.start
   if w>=minimum[0] and h>=minimum[1]:result.append((xx.start,yy.start,xx.stop,yy.stop))
 return pic.size,result

def title_surface(path,index):
 (w,h),rectangles=native_surfaces(path,[(41,58,59),(59,78,76),(195,163,102)])
 rectangles=[r for r in rectangles if r[0]<w*.5 and r[2]-r[0]>w*.23 and r[3]-r[1]<h*.23 and r[1]<h*.86]
 rectangles.sort(key=lambda r:r[1])
 if len(rectangles)<4:raise ValueError('Four actual native title surfaces are not rendered')
 r=rectangles[index];return (r[0]+r[2])/2,(r[1]+r[3])/2

def touch_menu_surface(path):
 (w,h),rectangles=native_surfaces(path,[(37,53,56)])
 rectangles=[r for r in rectangles if r[0]>w*.5 and r[1]<h*.2 and r[2]-r[0]<w*.25]
 if not rectangles:raise ValueError('Actual top-right touch MENU surface not found')
 r=min(rectangles,key=lambda r:r[1]);return (r[0]+r[2])/2,(r[1]+r[3])/2

def _studio_title_from_pixels(pixels,folder,stem,observation,whole_tsv):
 """Retain historical English contract; current title uses shared strict pixels."""
 try:return _studio_legacy_title_from_pixels(pixels,folder,stem,observation,whole_tsv)
 except StudioMenuLabelMissing as legacy_missing:
  observation['legacy_title_missing']=str(legacy_missing)
 path=folder/(stem+'.png')
 if not path.exists():path.write_bytes(pixels)
 elif path.read_bytes()!=pixels:raise AssertionError('Current title screenshot differs from observed bytes')
 try:point=locate_pixel_control(path,'开发入口',exact=True)
 except ValueError as exc:raise StudioMenuLabelMissing(str(exc)) from exc
 observation['actual_title_label']='开发入口'
 observation['locator']='shared_native_surfaces_exact_complete_label'
 return point

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
    control={'DEVELOPMENT DEMOS / ALL ENTRIES':'title','ACTIONS':'actions'}.get(label)
    try:
     if control is None:raise StudioMenuLabelMissing('No current contract for navigation label')
     point=_studio_current_reference(folder/(stem+'.png'),control)
     observation['locator']='source_bound_current_full_control_pixels'
    except StudioMenuLabelMissing:
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

def _studio_reference_data(root):
 import hashlib,json
 data=json.loads((root/'tests/fixtures/studio_gui_pointer/current_navigation_37950.json').read_text())
 for name,expected in data['source_sha256'].items():
  if hashlib.sha256((root/name).read_bytes()).hexdigest()!=expected:raise AssertionError('Current Studio reference source drift: '+name)
 return data

def _studio_current_reference(path,control,root=None,*,details=False,all_matches=False):
 """Finite same-source raw glyphs; actual location is always rediscovered."""
 import hashlib,json
 import numpy as np
 from pathlib import Path
 root=Path(root) if root is not None else Path(__file__).resolve().parents[1]
 folder=root/'tests/fixtures/studio_gui_pointer'
 data=_studio_reference_data(root)
 image=Image.open(path).convert('RGB');rgb=np.asarray(image);matches={}
 refs=[r for r in data['references'] if r['control']==control and r['viewport']==list(image.size)]
 if len(refs)!=1:raise StudioMenuLabelMissing('No observed current navigation reference for control/viewport')
 ref=refs[0];source=folder/ref['fixture']
 if hashlib.sha256(source.read_bytes()).hexdigest()!=ref['sha256']:raise AssertionError('Current Studio raw reference drift')
 crop=np.asarray(Image.open(source).convert('RGB').crop(ref['box']))
 paper=_studio_control_contract(root)['paper'];glyph=np.all(crop==paper,axis=2);ys,xs=np.where(glyph)
 l,t,r,b=int(xs.min()),int(ys.min()),int(xs.max())+1,int(ys.max())+1
 if ref['mode']=='native_full_glyph':
  expected=glyph[t:b,l:r]
  _,surfaces=native_surfaces(path,[(41,58,59),(59,78,76),(195,163,102),(37,53,56)],minimum=(60*min(image.width/1280,image.height/720),28*min(image.width/1280,image.height/720)))
  for box in surfaces:
   if not _complete_native_fill(image,box):continue
   left,top,right,bottom=box;actual=np.all(rgb[top:bottom,left:right]==paper,axis=2)
   yy,xx=np.where(actual)
   if not len(xx):continue
   al,at,ar,ab=int(xx.min()),int(yy.min()),int(xx.max())+1,int(yy.max())+1
   actual=actual[at:ab,al:ar]
   if actual.shape==expected.shape and np.array_equal(actual,expected):matches[box]=(left+(al+ar)/2,top+(at+ab)/2)
 elif ref['mode']=='source_bound_horizontal_edges_full_raster':
  # Exactly this observed 13/24 viewport rendering: both complete horizontal
  # edges, every glyph and every margin pixel. Never a generic missing-edge rule.
  height,width=crop.shape[:2];edge=crop[0,0]
  if not(np.all(crop[0]==edge)and np.all(crop[-1]==edge)):raise AssertionError('Reference horizontal edges incomplete')
  candidates=np.argwhere(np.all(rgb==edge,axis=2))
  for top,left in candidates:
   if left<1 or top<1 or left+width>=image.width or top+height>=image.height:continue
   # Same-span lines must end on both sides, not a prefix of a larger panel.
   if np.all(rgb[top,left-1]==edge)or np.all(rgb[top,left+width]==edge):continue
   if np.array_equal(rgb[top:top+height,left:left+width],crop):matches[(int(left),int(top),int(left+width),int(top+height))]=(left+(l+r)/2,top+(t+b)/2)
 else:raise AssertionError('Unknown current navigation reference mode')
 if all_matches:return [{'point':point,'bounds':box,'label':ref['label']} for box,point in matches.items()]
 if not matches:raise StudioMenuLabelMissing('Current full control pixels not observed: '+control)
 if len(matches)!=1:raise AssertionError('Ambiguous current full control pixels: '+control)
 box,point=next(iter(matches.items()))
 return {'point':point,'bounds':box,'label':ref['label']} if details else point

def _studio_control_contract(root=None):
 """Read existing runtime label/font authorities; no second weapon name table."""
 import re
 from pathlib import Path
 root=Path(root) if root is not None else Path(__file__).resolve().parents[1]
 reference=_studio_reference_data(root)
 catalog=(root/'game/combat/weapons/weapon_catalog.gd').read_text()
 ids=re.fullmatch(r'const IDS: Array\[String\] = \[(.*)\]',next(line for line in catalog.splitlines() if line.startswith('const IDS:')))
 if ids is None:raise AssertionError('Studio WeaponCatalog IDS syntax changed')
 names=re.findall(r'"([a-z_]+)"',ids[1])
 if len(names)!=15 or len(set(names))!=15:raise AssertionError('Studio requires the actual fifteen unique catalog IDs')
 definition=(root/'scripts/combat/weapon_definition.gd').read_text()
 default_name=re.search(r'^@export var display_name := "([^"\n]+)"$',definition,re.M)
 default_tier=re.search(r'^@export var tier := ([123])$',definition,re.M)
 if default_name is None or default_tier is None:raise AssertionError('WeaponDefinition display defaults missing')
 labels=[]
 for name in names:
  source=(root/f'resources/weapons/{name}.tres').read_text()
  display=re.search(r'^display_name = "([^"\n]+)"$',source,re.M)
  tier=re.search(r'^tier = ([123])$',source,re.M)
  labels.append(f'Lv.{tier[1] if tier else default_tier[1]} {display[1] if display else default_name[1]}')
 typography=(root/'game/presentation/ui/demo_ui_01/game_typography.gd').read_text()
 font=re.search(r'^const FONT := preload\("res://([^"\n]+)"\)$',typography,re.M)
 if font is None:raise AssertionError('GameTypography canonical font missing')
 theme=(root/'game/presentation/ui/demo_ui_01/clockwork_theme.gd').read_text()
 size=re.search(r'^\s*result.default_font_size = (\d+)$',theme,re.M)
 paper=re.search(r'^const PAPER := Color\("([0-9a-f]{6})"\)$',theme,re.M)
 if size is None or paper is None:raise AssertionError('Current native button typography missing')
 studio=(root/'experiments/motion/action_studio.gd').read_text()
 patrol=re.search(r'^\s*_training_toggle.text = "([^"\n]+)"$',studio,re.M)
 static=re.search(r'^\s*_training_toggle.text = "([^"\n]+)" if value else "([^"\n]+)"$',studio,re.M)
 practice=re.search(r'_button\(weapon_row,"([^"\n]+)",func\(\)->void:restart\(4\)\)',studio)
 if patrol is None or static is None or practice is None or static[2]!=patrol[1]:raise AssertionError('Studio visible control labels changed')
 checkpoints=re.search(r'_button\(row,\[(.*?)\]\[i\],func\(\) -> void: restart\(index\)\)',studio)
 if checkpoints is None:raise AssertionError('Studio practice checkpoint labels changed')
 checkpoint_labels=re.findall(r'"([^"\n]+)"',checkpoints[1])
 if len(checkpoint_labels)!=4:raise AssertionError('Studio checkpoint index contract changed')
 return {'font':root/font[1],'font_sha256':reference['source_sha256'][font[1]],'font_size':int(size[1]),'paper':tuple(int(paper[1][i:i+2],16) for i in (0,2,4)),
         'labels':{'weapon':tuple(labels),'training':(patrol[1],static[1]),'practice':(practice[1],),'hook_practice':(checkpoint_labels[2],)}}

def _studio_viewport_masks(mask,scale):
 """Exact nearest viewport samples for every integer logical glyph origin."""
 import numpy as np
 from fractions import Fraction
 ratio=Fraction(scale).limit_denominator(128)
 if abs(float(ratio)-scale)>1e-12 or ratio<=0 or ratio.denominator>128:raise AssertionError('Unsupported exact viewport scale')
 if ratio==1:return [mask]
 numerator,denominator=ratio.numerator,ratio.denominator
 def samples(length):
  found={}
  for origin in range(denominator):
   start=origin*numerator//denominator
   end=((origin+length)*numerator+denominator-1)//denominator
   indices=((2*np.arange(start,end)+1)*denominator)//(2*numerator)-origin
   valid=(indices>=0)&(indices<length)
   key=(tuple(indices),tuple(valid));found[key]=(np.clip(indices,0,length-1),valid)
  return list(found.values())
 variants={}
 for yy,yvalid in samples(mask.shape[0]):
  for xx,xvalid in samples(mask.shape[1]):
   result=mask[yy[:,None],xx]&yvalid[:,None]&xvalid
   ys,xs=np.where(result)
   if not len(xs):continue
   result=result[ys.min():ys.max()+1,xs.min():xs.max()+1]
   variants[(result.shape,result.tobytes())]=result
 return list(variants.values())

@lru_cache(maxsize=8)
def _studio_glyph_templates(font_bytes,font_size,labels,scale):
 """Cache only deterministic immutable glyph masks, never observations/guards."""
 import numpy as np
 from PIL import ImageFont,ImageDraw
 font=ImageFont.truetype(io.BytesIO(font_bytes),font_size)
 templates=[]
 for label in labels:
  bounds=font.getbbox(label)
  glyph=Image.new('1',(bounds[2]-bounds[0],bounds[3]-bounds[1]))
  ImageDraw.Draw(glyph).text((-bounds[0],-bounds[1]),label,font=font,fill=1)
  mask=np.asarray(glyph);ys,xs=np.where(mask)
  for variant in _studio_viewport_masks(mask[ys.min():ys.max()+1,xs.min():xs.max()+1],scale):
   # Immutable bytes backing prevents callers from re-enabling array writes.
   readonly=np.frombuffer(variant.tobytes(),dtype=variant.dtype).reshape(variant.shape)
   templates.append((label,readonly))
 return tuple(templates)

def _studio_bitmap_control(path,control,scale=1,root=None):
 """Exact complete rendered glyph mask inside a complete observed native fill."""
 import numpy as np
 import hashlib
 contract=_studio_control_contract(root)
 if control not in contract['labels']:raise ValueError('Unknown Studio control: '+control)
 image=Image.open(path).convert('RGB');rgb=np.asarray(image)
 if image.size not in ((1280,720),(844,390)) or scale!=min(image.width/1280,image.height/720):raise AssertionError('Unobserved current Studio viewport/scale')
 font_bytes=contract['font'].read_bytes()
 if hashlib.sha256(font_bytes).hexdigest()!=contract['font_sha256']:raise AssertionError('Current Studio font bytes differ from source authority')
 templates=_studio_glyph_templates(font_bytes,contract['font_size'],contract['labels'][control],scale)
 matches={}
 _,surfaces=native_surfaces(path,[(41,58,59),(59,78,76),(195,163,102),(37,53,56)])
 for box in surfaces:
  if not _complete_native_fill(image,box):continue
  left,top,right,bottom=box
  mask=np.all(rgb[top:bottom,left:right]==contract['paper'],axis=2)
  ys,xs=np.where(mask)
  if not len(xs):continue
  l,t,r,b=int(xs.min()),int(ys.min()),int(xs.max())+1,int(ys.max())+1
  actual=mask[t:b,l:r]
  for label,expected in templates:
   if actual.shape==expected.shape and np.array_equal(actual,expected):
    matches[box]={'point':(left+(l+r)/2,top+(t+b)/2),'label':label,'bounds':box}
 if image.size==(844,390) and control in ('hook_practice','practice'):
  # Every legal rendering participates. A font match must not hide another
  # actual raw-reference control; only the same complete box is deduplicated.
  for reference in _studio_current_reference(path,control,root,all_matches=True):
   if reference['label'] not in contract['labels'][control]:raise AssertionError('Current control reference label differs from its source authority')
   matches[reference['bounds']]=reference
 if len(matches)!=1:raise AssertionError(f'Expected one complete Studio {control} label; found {len(matches)} exact glyph matches')
 return next(iter(matches.values()))

async def studio_control_point(page,control):
 """Read screenshot only, then return the actual full-label glyph center."""
 import tempfile
 from pathlib import Path
 scale,_,_=geometry(page)
 with tempfile.TemporaryDirectory() as directory:
  path=Path(directory)/'studio.png';path.write_bytes(await page.screenshot())
  return _studio_bitmap_control(path,control,scale)['point']

def studio_reference_aim_point(page,case,root=None):
 """Finite authored reset-reference point, NOT the live camera/original ray.

 Current desktop HUD covers the old aim points. Hook references project the
 reset origin/ring midpoint; blade focus retains its x at the viewport midline.
 Actual cast angle, kick, side and recovery remain the consumer's assertions.
 This is a current interactive aiming contract migration, not equal numeric aim.
 """
 import hashlib
 from pathlib import Path
 if page.viewport_size!={'width':1280,'height':720}:raise AssertionError('Unobserved hook reference viewport')
 if case not in ('oblique','vertical','air_blade_focus'):raise ValueError('Unknown hook reference case: '+str(case))
 root=Path(root) if root is not None else Path(__file__).resolve().parents[1]
 _studio_reference_data(root)  # Includes exact ActionStudio reset/camera/anchor source.
 traversal=root/'game/player/actions/traversal_ability.gd'
 if hashlib.sha256(traversal.read_bytes()).hexdigest()!='36aae4b822563f6b2e391af2da1948564c934ab8e73f26578a9545b5b2eab369':raise AssertionError('Hook origin source drift')
 if case=='air_blade_focus':
  # Retain authored x790; the observed desktop HUD ends at344. Its viewport
  # centerline360 is outside, and actual accepted blade motion proves upturn.
  return (790.0,page.viewport_size['height']/2)
 player=(1490.0,400.0);camera=(player[0]+130.0,player[1]-100.0)
 origin=(player[0],player[1]-6.0)
 anchor=(1570.0,240.0) if case=='oblique' else (1490.0,190.0)
 midpoint=tuple((a+b)/2 for a,b in zip(origin,anchor))
 return tuple(center+(value-offset)*1.6 for center,value,offset in zip((640.0,360.0),midpoint,camera))

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
  from scipy import ndimage
  # Explicit four-neighbor connectivity preserves the original flood fill.
  labels,count=ndimage.label(mask,structure=((0,1,0),(1,1,1),(0,1,0)))
  if count==0:return
  for number,bounds in enumerate(ndimage.find_objects(labels),1):
   if bounds is None:continue
   yy,xx=bounds;ys,xs=np.nonzero(labels[yy,xx]==number)
   points=list(zip((xs+xx.start).tolist(),(ys+yy.start).tolist()))
   yield (xx.start,yy.start,xx.stop,yy.stop),points
 def round_boxes(mask,origin):
  for (l,t,r,b),part in components(mask):
   mw,mh=r-l,b-t
   if not(6*scale<=min(mw,mh) and max(mw,mh)<=24*scale and .85<=mw/mh<=1.18):continue
   silhouette=np.zeros((mh,mw),dtype=bool)
   for x,y in part:silhouette[y-t,x-l]=True
   density=silhouette.mean()
   if density>=.95:
    # At a fractional scale a true9x9 checked ring occupies77/81 pixels,
    # one pixel beyond .95. Permit only the rounded-up pixel, with an actual
    # dark center and brighter cardinal ring edges; flat squares fail closed.
    if len(part)>int(np.ceil(.95*mw*mh)):continue
    cx,cy=origin[0]+l+mw//2,origin[1]+t+mh//2
    center=int(np.sum(rgb[cy,cx]))
    if not all(int(np.sum(rgb[origin[1]+t+y,origin[0]+l+x]))>center for x,y in ((mw//2,0),(mw//2,mh-1),(0,mh//2),(mw-1,mh//2))):continue
   # Fractional rasterization can place the circle's reflection center half a
   # pixel from its bounding-box center. Compare actual pixels at the original
   # center and each adjacent half-pixel center; discard at most one outer row
   # or column for this symmetry measurement only. The complete component,
   # density, empty corners and full cardinal cross remain required below.
   def reflected(axis):
    views=(silhouette,)+tuple(np.take(silhouette,range(start,end),axis=axis)
                             for start,end in ((0,silhouette.shape[axis]-1),(1,silhouette.shape[axis])))
    return max(np.mean(view==np.flip(view,axis=axis))for view in views)
   if not(.65<=density and reflected(1)>=.9 and reflected(0)>=.9):continue
   if any(silhouette[y,x]for x,y in ((0,0),(mw-1,0),(0,mh-1),(mw-1,mh-1))):continue
   if not(silhouette[mh//2,:].all() and silhouette[:,mw//2].all()):continue
   yield (origin[0]+l,origin[1]+t,origin[0]+r,origin[1]+b)
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
   if border==color or not all(np.mean(edge==border)>=.8 for edge in edges):
    # Fractional rasterization need not give every outline the same RGB.
    # Still require FOUR complete visible fill boundaries, never a frame edge.
    inside=[packed[top,xs],packed[bottom-1,xs],packed[ys,left],packed[ys,right-1]]
    if not(all(np.mean(edge==color)>=.8 for edge in inside) and all(np.mean(edge!=color)>=.8 for edge in edges)):continue
   crop=packed[top:bottom,left:right]
   markers=list(round_boxes(crop!=color,(left,top)))
   columns={}
   for box in markers:
    # Exact observed component centers; no estimates for absent radio rows.
    columns.setdefault((box[0]+box[2]-1)/2,[]).append(box)
   observed=set()
   for _seed_x,seeds in columns.items():
    # Only an actually seen round component proposes a marker column. A hover
    # row has a different background; measure the real adjacent gap at EACH
    # row and rediscover complete circles through the entire panel height.
    # No pitch/phase is used to infer, insert or truncate a missing marker.
    marker_left=min(box[0]for box in seeds);marker_right=max(box[2]for box in seeds)
    if marker_right>=right:continue
    strip=packed[top:bottom,marker_left:marker_right]
    gap=packed[top:bottom,marker_right]
    boxes=list(round_boxes(strip!=gap[:,None],(marker_left,top)))
    if not set(seeds).issubset(boxes) or len(boxes)!=15:continue
    if len({(box[0]+box[2]-1)/2 for box in boxes})!=1:continue
    boxes.sort(key=lambda b:b[1]);signature=tuple(boxes)
    if signature in observed:continue
    observed.add(signature)
    rows=[(box[1]+box[3]-1)/2 for box in boxes]
    gaps=[b-a for a,b in zip(rows,rows[1:])]
    if min(gaps)>20*scale and max(gaps)-min(gaps)<4*scale:
     candidates.append({'marker_x':(boxes[0][0]+boxes[0][2]-1)/2,'rows':rows,'marker_boxes':boxes,'bounds':(left-1,top-1,right+1,bottom+1),'background_rgb':tuple((color>>shift)&255 for shift in (16,8,0))})
 assert len(candidates)==1,f'actual fifteen evenly spaced item markers not uniquely observed: {len(candidates)} complete popup/column candidates'
 return candidates[0]

async def open_weapon_picker(page,touch=False,*,historical_fixture=False):
 # Only the two archived screenshot unit fixtures explicitly retain the old HUD scan.
 # Current consumers never fall back to it on a missing or ambiguous label.
 scale,pad,h=geometry(page)
 point=(pad+145*scale,await weapon_row_y(page)) if historical_fixture else await studio_control_point(page,'weapon')
 await click(page,*point,touch);await page.wait_for_timeout(200)
 im=Image.open(io.BytesIO(await page.screenshot())).convert('RGB')
 start_y=round((await weapon_row_y(page) if historical_fixture else point[1])+18*scale)
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
