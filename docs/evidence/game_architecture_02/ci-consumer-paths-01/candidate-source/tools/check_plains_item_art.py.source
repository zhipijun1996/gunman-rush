"""Immutable AI item atlas, real resource metadata and presentation consumers."""
import hashlib,json,re
from pathlib import Path
from PIL import Image
root=Path(__file__).resolve().parents[1]
pack=root/'assets/plains_v4/items'
m=json.loads((pack/'manifest.json').read_text())
p=pack/'icons.png';im=Image.open(p)
assert m['generator']=='OpenAI image_gen.imagegen'
assert hashlib.sha256(p.read_bytes()).hexdigest()==m['sha256']
assert list(im.size)==m['size'] and im.mode=='RGBA' and im.getchannel('A').getextrema()[0]==0
assert (root/m['reference']).is_file()
assert 'compress/mode=1' in Path(str(p)+'.import').read_text()
assert len(m['regions'])==9
for key,(x,y,w,h) in m['regions'].items():
 assert x>=0 and y>=0 and x+w<=im.width and y+h<=im.height and w>0 and h>0,key
 assert im.getchannel('A').crop((x,y,x+w,y+h)).getextrema()[1]>0,key
extra=json.loads((pack/'expansion.json').read_text())
p2=pack/'expansion.png';im2=Image.open(p2)
assert extra['generator']=='OpenAI image_gen.imagegen' and extra['source_unchanged']
assert hashlib.sha256(p2.read_bytes()).hexdigest()==extra['sha256']
assert list(im2.size)==extra['size'] and im2.mode=='RGBA' and im2.getchannel('A').getextrema()[0]==0
assert 'compress/mode=1' in Path(str(p2)+'.import').read_text()
assert len(extra['regions'])==6
for key,(x,y,w,h) in extra['regions'].items():
 assert x+w<=im2.width and y+h<=im2.height
 assert im2.getchannel('A').crop((x,y,x+w,y+h)).getextrema()[1]>0,key
all_keys=set(m['regions'])|set(extra['regions'])
items=list((root/'resources/items').glob('*.tres'))
for item in items:
 text=item.read_text();key=re.search(r'icon_key = &"([^"]+)"',text)
 assert key and key.group(1) in all_keys,item
 assert re.search(r'description = "[^\n"]+"',text),item
 assert 'modifiers = ' in text,item
for consumer in ['stage_reward_modal','demo_menu','item_shop_modal']:
 assert 'ItemCard.new()' in (root/f'game/presentation/ui/{consumer}.gd').read_text(),consumer
print(f'PASS: immutable AI atlas, 15 transparent AI icon regions, {len(items)} actual item resources, reward/shop/build consumers; subjective style pending player review.')
