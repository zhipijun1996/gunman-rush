"""Assemble static approval art; no painting, animation, or runtime replacement.

Pillow/NumPy/SciPy. Crop generated masters, clean alpha, uniform nearest baking.
"""
from pathlib import Path
import hashlib
import json

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'art/reviews/plains_enemies_pr142'
NATIVE = OUT / 'static'
NATIVE.mkdir(exist_ok=True)
MASTERS = OUT / 'cutouts'
MASTERS.mkdir(exist_ok=True)
RECORDS = {}
FONT = '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def clean_crop(source, box):
    data = np.array(Image.open(OUT / 'source' / source).convert('RGBA').crop(box))
    mask = data[:, :, 3] >= 128
    labels, _ = ndimage.label(mask)
    sizes = np.bincount(labels.ravel())
    sizes[0] = 0
    keep = sizes[labels] >= 20
    data[:, :, 3] = np.where(keep, 255, 0)
    data[~keep] = 0
    im = Image.fromarray(data)
    bounds = im.getbbox()
    assert bounds
    return im.crop(bounds), [box[0]+bounds[0], box[1]+bounds[1], box[0]+bounds[2], box[1]+bounds[3]]


def bake(name, label, source, box, height=None, scale=None):
    im, crop = clean_crop(source, box)
    im.save(MASTERS / (name + '.png'))
    factor = scale if scale is not None else height / im.height
    size = (round(im.width * factor), round(im.height * factor))
    native = im.resize(size, Image.Resampling.NEAREST)
    native.save(NATIVE / (name + '.png'))
    RECORDS[name] = dict(label=label, source='source/'+source, crop_xyxy=crop,
                         source_size=list(im.size), scale=factor, native_size=list(size),
                         anchor_px=[size[0]//2, size[1]], sha256=sha(NATIVE/(name+'.png')))
    return native


rows = [
    ('patrol', '01 巡逻体', 44), ('charger', '02 冲锋体', 52),
    ('hopper', '03 跃击体', 64), ('sentry', '04 单发哨兵', 72),
    ('fan_sentry', '05 扇射哨兵', 68), ('root_bell', '06 根铃', 102),
    ('diver', '07 俯冲体', 46),
]
ordinary_source = Image.open(OUT/'source/ordinary.png')
w, h = ordinary_source.size
for i, (name, label, height) in enumerate(rows):
    col, row = i % 4, i // 4
    box = (round(col*w/4), 0 if row == 0 else 400, round((col+1)*w/4), 400 if row == 0 else h)
    bake(name, label, 'ordinary.png', box, height=height)
bell_source = Image.open(OUT/'source/bellstrider.png')
bake('bellstrider', '08 鸣铃巡游机', 'bellstrider.png', (0, 0, *bell_source.size), height=220)
keeper_source = Image.open(OUT/'source/windkeeper.png')
kw, kh = keeper_source.size
k1 = bake('windkeeper_phase1', '09 牧风者 · 一阶段', 'windkeeper.png', (0, 0, 830, kh), height=210)
factor = RECORDS['windkeeper_phase1']['scale']
bake('windkeeper_phase2', '10 牧风者 · 二阶段', 'windkeeper.png', (830, 0, kw, kh), scale=factor)

bg_path = ROOT/'art/world-art-v2/assets/pixel/v2/windchime_plains_v2.png'
hero_path = ROOT/'art/world-art-v2/assets/pixel/hero.png'
hero = Image.open(hero_path).convert('RGBA')
hero = hero.crop(hero.getbbox())  # The unchanged reference hero's body is 44px tall.
bg = Image.open(bg_path).convert('RGBA')


def font(size):
    return ImageFont.truetype(FONT, size)


def board(height, title, subtitle):
    # Background is the actual PR142 reference, presented as a static mood board.
    im = bg.resize((1280,720), Image.Resampling.NEAREST).crop((0,0,1280,height))
    draw = ImageDraw.Draw(im)
    draw.rectangle((0,0,1280,81), fill='#142b2b')
    draw.text((24,12), title, font=font(25), fill='#f1e7cd')
    draw.text((24,49), subtitle, font=font(13), fill='#c9d1ba')
    draw.rectangle((0,height-54,1280,height), fill='#142b2b')
    return im


def caption(draw, at, text, size=13):
    draw.text(at, text, font=font(size), fill='#faf2da', stroke_width=2, stroke_fill='#243b38', anchor='mt')


ordinary = board(360, 'PR #142 平原怪物｜C 主色块重绘', '七类普通怪 · 同一比例，主角身体高44px · 仅设计拼版，未接入游戏或制作动画')
d = ImageDraw.Draw(ordinary)
baseline = 296
centers = [60, 185, 350, 510, 675, 850, 1020, 1180]
ordinary.alpha_composite(hero.resize((hero.width*2,hero.height*2),Image.Resampling.NEAREST), (centers[0]-hero.width,baseline-hero.height*2))
caption(d,(centers[0],312),'主角 44px')
for i,(name,label,height) in enumerate(rows):
    sprite=Image.open(NATIVE/(name+'.png'))
    display=sprite.resize((sprite.width*2,sprite.height*2),Image.Resampling.NEAREST)
    y=baseline-display.height-(22 if name=='diver' else 0)
    ordinary.alpha_composite(display,(centers[i+1]-display.width//2,y))
    caption(d,(centers[i+1],312),label)
    caption(d,(centers[i+1],333),str(height)+'px',11)
ordinary.convert('RGB').save(OUT/'review-ordinary.png')

bosses = board(560, 'PR #142 平原Boss｜C 主色块重绘', '同一比例，主角身体高44px · 牧风者两阶段使用同一身体比例 · 头顶风车从二阶段展开')
d = ImageDraw.Draw(bosses)
baseline=490
bosses.alpha_composite(hero,(45,baseline-hero.height))
caption(d,(70,513),'主角 44px')
for name,center in [('bellstrider',292),('windkeeper_phase1',658),('windkeeper_phase2',1064)]:
    sprite=Image.open(NATIVE/(name+'.png'))
    bosses.alpha_composite(sprite,(center-sprite.width//2,baseline-sprite.height))
    caption(d,(center,513),RECORDS[name]['label'],16)
    caption(d,(center,539),str(sprite.height)+'px · 体型提案',11)
bosses.convert('RGB').resize((2560,1120),Image.Resampling.NEAREST).save(OUT/'review-bosses.png')

references=[bg_path,hero_path,ROOT/'assets/plains_v07/source/architecture-generated.png']
manifest=dict(status='static proposal; awaiting explicit user approval; not runtime art',
    baseline='PR142@cc62d369d3cec2597db483f1137ff976e25863cf',
    generator='image_gen.imagegen',
    style_revision='C: peacock-blue cloth, warm ivory masks, amber bells; rejected B retained only in Git comparison baseline',
    derivation='alpha>=128, discard isolated alpha components below20 source pixels, tight crop, aspect-preserving nearest bake; no code painting',
    phase_consistency='Windkeeper shares one uniform source-pixel scale across both states; animation registration remains pending approval',
    approval_required_for=['idle','move','attack','hurt','death','phase_transition','runtime replacement and collision/room-scale validation'],
    reference_sha256={str(p.relative_to(ROOT)):sha(p) for p in references},
    sources={p.name:sha(p) for p in (OUT/'source').iterdir()},assets=RECORDS,
    license='New generated candidate artwork; tool provides no separate license identifier. Existing reference attribution remains unchanged.')
(OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:v['native_size'] for k,v in RECORDS.items()},ensure_ascii=False))
