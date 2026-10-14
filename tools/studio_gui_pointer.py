"""Locate the actual canvas menu on screenshots, then use normal pointer input."""
import io
from collections import Counter
from PIL import Image

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
 hits=[]
 for yy in range(start_y,h):
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
