"""Validate immutable AI originals and measured runtime sprite regions."""
import hashlib,json
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
pack=ROOT/'assets/plains_v4/spatial'
m=json.loads((pack/'manifest.json').read_text())
assert m['generator']=='OpenAI image_gen.imagegen' and m['source_unchanged']
for source in m['sources']:
    p=pack/source['file'];im=Image.open(p)
    assert hashlib.sha256(p.read_bytes()).hexdigest()==source['sha256']
    assert list(im.size)==source['size'] and im.mode==source['mode']
    assert (ROOT/source['reference']).is_file()
    assert 'compress/mode=1' in Path(str(p)+'.import').read_text()
    if source['file']=='actors.png':
        assert im.mode=='RGBA' and im.getchannel('A').getextrema()[0]==0
        for key,(x,y,w,h) in m['regions'].items():
            assert x>=0 and y>=0 and w>0 and h>0 and x+w<=im.width and y+h<=im.height,key
            assert im.getchannel('A').crop((x,y,x+w,y+h)).getextrema()[1]>0,key
assert 'spatial/chassis.png' in (ROOT/'scripts/bosses/bellstrider_presentation.gd').read_text()
assert 'chassis.svg' not in (ROOT/'scripts/bosses/bellstrider_presentation.gd').read_text()
assert 'spatial/actors.png' in (ROOT/'scripts/combat/player_projectile.gd').read_text()
assert 'spatial/actors.png' in (ROOT/'scripts/enemies/enemy_presentation.gd').read_text()
assert 'smoothstep' in (ROOT/'scripts/art/plains_depth.gdshader').read_text()
print('PASS: AI original hashes, alpha, 4 measured regions and actual player/mini/drone consumers; subjective style awaiting player review.')
