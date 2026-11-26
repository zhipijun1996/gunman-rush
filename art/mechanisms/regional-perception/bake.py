"""Bake native perception instruments from the regional prop masters. Run from anywhere with Pillow."""
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageOps
import math

ROOT = Path(__file__).resolve().parents[3]
PIXELS = ROOT / 'art/world-art-v2/assets/pixel'
OUTPUT = ROOT / 'production/assets/world_elements/perception_regions'
N = Image.Resampling.NEAREST

# Lamp head bounds and its light center are fractions of the original lamp. The other
# three props supply the petal material, the standing screen and the hanging foreground.
# Raw names use the shared original pixel catalog; @ names select a region's v2 master.
REGIONS = {
    'windchime_plains': ('bell_post', (.62,.23,.98,.63),(.80,.47),'seed_stems','plains_grass','@chime_span','grass','#cfac65'),
    'mushroom_caverns': ('mushroom_lamp',(.18,0,.95,.39),(.56,.27),'@shelf_cap','@spore_pods','@mycelium_span','caps','#85c5c6'),
    'firefly_marsh': ('lamp',(.67,.16,.96,.49),(.82,.35),'@swamp_pods','attached','@reed_bridge','grass','#d5c881'),
    'windswept_canyon': ('lamp',(.60,.18,.95,.57),(.78,.44),'@weather_vane','@ragged_wheel','@bridge_fragment','sail','#da9c6f'),
    'frostmirror_glacier': ('lamp',(.38,.14,.67,.53),(.53,.40),'@ice_column','@mirror_relic','@ice_span','crystal','#a9d5e9'),
    'moonshadow_cemetery': ('lamp',(.18,.00,.85,.53),(.50,.26),'@urn_flowers','attached','@broken_gate','rail','#e5bf79'),
    'moon_crown_castle': ('lamp',(.05,.01,.91,.50),(.50,.20),'@glass_fragment','@royal_banner','attached','drape','#dcbd90'),
    'gear_city': ('gear_lamp',(.42,.11,.91,.39),(.72,.27),'@valve_panel','@pipe_junction','@gear_conveyor','pipe','#d8a665'),
    'echo_mines': ('lamp',(.61,.25,.99,.56),(.79,.46),'@ore_cluster','@lift_cage','@rope_bridge','rail','#dbbb99'),
    'ember_depths': ('ember_lamp',(.21,.10,.79,.83),(.53,.56),'@obsidian_fangs','@chain_stand','@chain_stand','pipe','#ee966c'),
    'root_sanctuary': ('lamp',(.05,.00,.91,.42),(.49,.21),'@votive_bowl','attached','@root_knot','roots','#b6c887'),
    'sunken_ruins': ('lamp',(.14,.08,.80,.57),(.49,.36),'@shell_relic','attached','@fluted_column','roots','#9fcabd'),
    'shattered_isles': ('lamp',(.51,.18,.83,.45),(.68,.32),'@wind_ribbon','attached','@rope_anchor','grass','#d2ba88'),
    'starbridge_gate': ('lamp',(.12,.04,.90,.46),(.50,.26),'@glass_crystals','@inscribed_pier','@orbital_anchor','crystal','#b2c9f2'),
    'world_clockheart': ('lamp',(.23,.01,.76,.43),(.52,.22),'@porcelain_coil','@counterweights','@escapement','rail','#ecc995'),
}

def source(region, name):
    if name.startswith('@'):
        path = PIXELS / 'v2' / f'{region}_v2_{name[1:]}.png'
    else:
        path = PIXELS / (f'{region}_{name}.png' if name in ('lamp','attached') else f'{name}.png')
    return Image.open(path).convert('RGBA')

def crop(image, box):
    return image.crop(tuple(round(n*image.size[i%2]) for i,n in enumerate(box)))

def fit(image, w, h):
    ratio = min(w/image.width,h/image.height)
    dims = max(1,round(image.width*ratio)),max(1,round(image.height*ratio))
    return image.resize(dims,Image.Resampling.LANCZOS if ratio < 1 else N)

def stamp(out, image, x, y, ax=.5, ay=1):
    out.alpha_composite(image,(round(x-image.width*ax),round(y-image.height*ay)))

def empty(w,h):
    return Image.new('RGBA',(w,h))

def lit(image,factor):
    rgb=ImageEnhance.Brightness(image.convert('RGB')).enhance(factor)
    rgb.putalpha(image.getchannel('A'))
    return rgb

def bake(region, recipe):
    lamp_name,head_box,focus,petal_name,screen_name,veil_name,form,color = recipe
    lamp=source(region,lamp_name)
    head=crop(lamp,head_box)
    petal=source(region,petal_name)
    bank=source(region,screen_name)
    veil_source=source(region,veil_name)
    frame=empty(320,160)
    # Flying carriage: one light-bearing case, two region-specific wing vanes, hinged into the sides.
    wing=fit(crop(petal,(.08,.02,.92,.76)),20,12)
    stamp(frame,ImageOps.mirror(wing).rotate(24,N,expand=True),31,31,1,.75)
    stamp(frame,wing.rotate(-24,N,expand=True),33,31,0,.75)
    stamp(frame,fit(head,13,20),32,34,.5,.6)
    # Closed and deployed receiver share one fixed, grounded stem. The working head stays at (32,22).
    stem=fit(crop(lamp,(0,.40,1,1)),24,37)
    petal_tip=crop(petal,(.10,.02,.91,.63))
    for number,opened in [(1,False),(2,True)]:
        x=number*64+32
        ImageDraw.Draw(frame).line((x,22,x,54),fill='#655a4e',width=3)
        stamp(frame,stem,x,60)
        if opened:
            blade=fit(petal_tip,20,17)
            for degrees in [-83,-41,0,41,83]:
                tip=blade.rotate(-degrees,N,expand=True)
                stamp(frame,tip,x+math.sin(math.radians(degrees))*12,23-math.cos(math.radians(degrees))*11,.5,.5)
        else:
            bud=fit(petal_tip,11,17)
            stamp(frame,bud.rotate(13,N,expand=True),x-3,25,.5,.7)
            stamp(frame,ImageOps.mirror(bud).rotate(-13,N,expand=True),x+3,25,.5,.7)
        stamp(frame,fit(head,17 if opened else 11,15),x,23,.5,.55)
    # Cocoon matches the physical shot radius. The fixed light preserves the original regional lamp silhouette.
    stamp(frame,fit(head,25,29),224,32,.5,.5)
    fixed=fit(lamp,52,47)
    stamp(frame,fixed,288,32,focus[0],focus[1])
    # Upright screens have separate cut crowns and real grounded feet. Organic patches grow in staggered
    # clumps; the rigid variants have intervals between individual poles, cords or columns.
    screen=empty(96,96)
    placements={
        'grass':[(11,49,66),(29,44,82),(55,50,94),(79,41,72),(93,30,56)],
        'caps':[(15,39,64),(43,59,88),(78,48,75)],
        'sail':[(8,36,59),(35,53,91),(77,57,74)],
        'crystal':[(9,35,59),(31,47,86),(58,42,72),(81,41,93)],
        'rail':[(3,32,58),(28,42,89),(65,45,77),(92,32,65)],
        'drape':[(10,27,83),(37,55,68),(68,35,93),(87,28,71)],
        'pipe':[(8,35,62),(32,46,92),(69,50,74),(91,30,54)],
        'roots':[(8,39,67),(36,52,92),(68,46,75),(87,32,60)]}[form]
    for i,(x,w,h) in enumerate(placements):
        cluster=ImageOps.mirror(bank) if i%2 else bank
        # Give each shoot a complete base: elongated stems preserve a plant's crown
        # while a span of screen, grille or ice is cropped from the intact regional prop.
        if form in ('grass','caps','roots','sail'):
            crown=fit(cluster,w,min(h,40))
            cx=x+(-5 if i%2 else 5)
            sd=ImageDraw.Draw(screen)
            sd.line((x,95,cx+2,95-h//3,cx-1,95-h+crown.height//2),fill='#373936',width=3)
            sd.line((x+1,95,cx+3,95-h//3,cx,95-h+crown.height//2),fill='#6d6751',width=1)
            for side in [-1,1]:
                leaf=fit(cluster,w//2,20)
                stamp(screen,leaf,cx+side*w//5,95-h//2+side*4)
            stamp(screen,lit(crown,.9 if i%2==0 else 1),cx,95-h,.5,0)
            stamp(screen,fit(cluster,w,36),x,95)
        else:
            tall=cluster.resize((max(1,round(cluster.width*h/cluster.height)),h),Image.Resampling.LANCZOS)
            cut_x=round((tall.width-w)*(.58 if i%2 else .36))
            tuft=tall.crop((max(0,cut_x),0,min(tall.width,max(0,cut_x)+w),h))
            stamp(screen,lit(tuft,.82 if i%2==0 else 1),x,96)
    # Fill the ground seam with a horizontal patch of the same native prop.
    patch=fit(bank,66,19)
    for x in [4,45,90]:stamp(screen,patch,x,96)
    frame.alpha_composite(screen,(0,64))
    for x,w in [(112,38),(141,42),(173,36)]:
        stamp(frame,fit(bank,w,21),x,96)
    # A contiguous top surface with shallow pieces; no tall props on the walkable mat.
    mat=empty(64,16)
    ImageDraw.Draw(mat).line((0,10,63,10),fill='#514b43',width=3)
    for x in [1,18,36,53,66]:stamp(mat,fit(veil_source,25,15),x,16)
    # The load-bearing surface is exactly the first row, including on dark masonry.
    # Light catches the tops of the linked reeds or stamped ribs much more than the underside.
    md=ImageDraw.Draw(mat)
    md.rectangle((0,0,63,4),fill='#55514a')
    md.line((0,5,63,5),fill='#302f32')
    for x in range(0,64,8):
        md.line((x,0,x+5,0),fill=color)
        md.line((x+1,1,x+5,1),fill='#9b9582')
        md.line((x+5,2,x+6,4),fill='#756e61')
    frame.alpha_composite(mat,(96,98))
    # Shot lure: asymmetric bracket and a hanging resonant part at the actual hit point.
    charm=empty(40,52)
    frame_strut=fit(crop(lamp,(.15,.40,.76,1)),12,43)
    stamp(charm,frame_strut,5,52)
    dc=ImageDraw.Draw(charm)
    dc.line((4,47,5,12,12,6,30,8,32,12),fill='#50494a',width=3)
    dc.line((6,13,13,7,28,9),fill='#a09071',width=1)
    dc.line((32,11,32,24),fill='#9c845e',width=1)
    stamp(charm,fit(head,17,16),32,30,.5,.55)
    # Parallel hanging resonators distinguish the sound target from a lamp even at rest.
    for xx,length in [(25,10),(30,15),(35,12)]:
        dc.line((xx,32,xx,32+length),fill='#524b44',width=3)
        dc.line((xx-1,33,xx-1,31+length),fill=color,width=1)
    dc.line((24,32,37,32),fill=color,width=1)
    frame.alpha_composite(charm,(205,66))
    # A curtain hangs from above. Shafts continue across vertical repeats, with only
    # native pieces of the chosen prop lashed to them (never whole platforms or conveyors).
    tile=empty(96,96)
    dt=ImageDraw.Draw(tile)
    detail_boxes={
        'windchime_plains':(.40,.33,.70,.72), 'mushroom_caverns':(.34,.08,.71,.69),
        'firefly_marsh':(.42,.30,.72,.79), 'windswept_canyon':(.38,.28,.74,.84),
        'frostmirror_glacier':(.28,.19,.57,.96), 'moonshadow_cemetery':(.34,.17,.58,.83),
        'moon_crown_castle':(.54,.02,.98,.72), 'gear_city':(.02,.18,.39,.87),
        'echo_mines':(.31,.31,.64,.79), 'ember_depths':(.08,.35,.59,.98),
        'root_sanctuary':(.24,.15,.74,.89), 'sunken_ruins':(.55,.09,.94,.61),
        'shattered_isles':(.29,.08,.64,.69), 'starbridge_gate':(.46,.08,.88,.54),
        'world_clockheart':(.23,.05,.69,.57)}
    ornament=crop(veil_source,detail_boxes[region])
    if form in ('crystal','roots','drape'):
        # Cut a single hanging shard, leafy spray or torn cloth panel from its
        # source cluster. Retain the donor's existing interior and transparent holes.
        shape={
            'crystal':[(.31,.03),(.76,0),(.85,.19),(.61,.73),(.30,1),(.15,.48)],
            'roots':[(.45,0),(.62,.06),(1,.45),(.88,.7),(.57,.78),(.24,1),(.01,.58),(.19,.29)],
            'drape':[(.30,0),(.79,.04),(1,.49),(.94,.85),(.75,.69),(.59,.99),(.42,.78),(.17,1),(.11,.54)]}[form]
        mask=Image.new('L',ornament.size,0)
        ImageDraw.Draw(mask).polygon([(round(x*ornament.width),round(y*ornament.height)) for x,y in shape],fill=255)
        ornament.putalpha(ImageChops.multiply(ornament.getchannel('A'),mask))
    curtain=form=='drape'
    metal=form in ('rail','pipe','crystal')
    for j,(start,phase,amp) in enumerate([(6,15,5),(33,54,8),(63,34,6),(85,2,4)]):
        def line_x(y):
            return round(start+amp*math.sin(math.tau*(y+phase)/96))
        for wrap in [-96,0,96]:
            pts=[(line_x(y)+wrap,y) for y in range(-2,99)]
            dt.line(pts,fill='#29292d',width=4)
            dt.line([(x-1,y) for x,y in pts],fill='#625c57' if metal else '#73674f',width=1)
            if metal:
                for y in range(-18+j*3,113,12):
                    x=line_x(y)+wrap
                    dt.ellipse((x-2,y-3,x+3,y+4),outline='#999286' if j%2 else '#7f7769',width=1)
            for k,y0 in enumerate([11+j*7,58+j*5]):
                size=(33,43) if curtain else ((23,28) if metal else (29,25))
                spr=fit(ornament,*size)
                if k%2:spr=ImageOps.mirror(spr)
                if not metal and not curtain:spr=ImageOps.flip(spr).rotate(-24 if j%2 else 24,N,expand=True)
                for yy in [y0-96,y0]:
                    stamp(tile,spr,line_x(yy)+wrap,yy,.5,.13)
            if not metal and not curtain:
                for yy in [34+j*3,81+j*2,-15+j*2]:
                    leaf=fit(petal_tip,18,18)
                    if j%2:leaf=ImageOps.mirror(leaf)
                    stamp(tile,leaf,line_x(yy)+wrap,yy,.2 if j%2 else .8,.2)
    for i,(x,y) in enumerate([(32,33),(96,22),(160,22),(224,32)]):
        ImageDraw.Draw(frame).point((x,y),fill=color)
    frame.save(OUTPUT/(region+'.png'),optimize=True)
    tile.save(OUTPUT/(region+'_veil.png'),optimize=True)

if __name__ == '__main__':
    OUTPUT.mkdir(parents=True,exist_ok=True)
    for region,recipe in REGIONS.items(): bake(region,recipe)
