"""Bake independently placeable regional pixel props and three depth settings per biome."""
from pathlib import Path
from PIL import Image, ImageEnhance, ImageOps
ROOT = Path(__file__).resolve().parents[3]
src = ROOT / "art/world-art-v2/assets/pixel"
SOURCES={
 "mushroom_caverns": {
  "back":"mushroom-background","mid":"mushroom_caverns_mid","far":"v2/mushroom_caverns_mid_v2",
  "props":{"fungal_arch":("mushroom_landmark",270),"glowcap":("mushroom_lamp",60),"cap_cluster":("v2/mushroom_caverns_v2_shelf_cap",133),"closed_cap":("v2/mushroom_caverns_v2_hollow_cap",96),"spore_pods":("v2/mushroom_caverns_v2_spore_pods",72),"hyphae":("v2/mushroom_caverns_v2_mycelium_span",151),"wall_gills":("mushroom_caverns_near",70),"spore_bed":("v2/mushroom_caverns_near_v2",221)}},
 "echo_mines":{
  "back":"echo_mines-background","mid":"echo_mines_mid","far":"v2/echo_mines_mid_v2",
  "props":{"headframe":("echo_mines_landmark",226),"wick":("echo_mines_lamp",54),"ore_cart":("v2/echo_mines_v2_mine_cart",121),"lift_cage":("v2/echo_mines_v2_lift_cage",145),"rope_span":("v2/echo_mines_v2_rope_bridge",155),"ore_cluster":("v2/echo_mines_v2_ore_cluster",82),"rail_joint":("echo_mines_attached",91),"steel_jack":("echo_mines_near",70)}}
}
for region, art in SOURCES.items():
    dst=ROOT/"production/assets/scenery"/region
    dst.mkdir(exist_ok=True,parents=True)
    def image(key):
        return Image.open(src/(key+".png")).convert("RGBA")
    for label,(key,width) in art["props"].items():
        original=image(key);original=original.crop(original.getbbox())
        original.resize((width,round(original.height*width/original.width)),Image.Resampling.NEAREST).save(dst/(label+".png"),optimize=True)
    for name,depth,bright in [('entrance',90,1.04),('hollow',137,.85),('deep',174,.70)]:
        base=image(art['back'])
        opaque=Image.new('RGBA',base.size,(20,23,34,255));opaque.alpha_composite(base)
        for key,span,y,opacity in [('far',474,depth-36,.56),('mid',428,depth+35,.74)]:
            layer=image(art[key]);layer=layer.resize((span,round(layer.height*span/layer.width)),Image.Resampling.NEAREST)
            layer.putalpha(layer.getchannel('A').point(lambda a:round(a*opacity)))
            opaque.alpha_composite(layer,(-85,y))
            opaque.alpha_composite(ImageOps.mirror(layer),(355,y-17))
        ImageEnhance.Brightness(opaque.convert('RGB')).enhance(bright).save(dst/(name+'.webp'),quality=93,method=6)

# Three pixel poses share a baseline. The mine machines have fixed bogies and
# moving superstructures; fungal feet flex under their caps before each attack.
from PIL import ImageDraw
for actor in ('spore_larva','mycelium_shell','rail_crawler','stray_excavator'):
    fungal=actor in ('spore_larva','mycelium_shell')
    region='mushroom_caverns' if fungal else 'echo_mines'
    bot=actor=='stray_excavator'
    shell=actor=='mycelium_shell'
    dst=ROOT/"production/assets/scenery"/region/(actor+'.png')
    atlas=Image.new('RGBA',(3*60,51))
    for phase in range(3):
        im=Image.new('RGBA',(60,51));g=ImageDraw.Draw(im)
        if fungal:
            dark='#26313a';mid='#554361';high='#ae8298';light='#b6edd2'
            for x in (12,22,33,42):
                y=38+(x//10+phase)%2
                g.polygon([(x,y-7),(x+5,y-6),(x+7,45),(x+4+phase,48),(x,46)],fill=dark)
                g.line([(x+4,y),(x+5,43),(x+3,45)],fill='#889781',width=2)
            h=phase*2
            g.polygon([(6,33),(9,26),(17,23),(43,22),(51,29),(54,35),(49,41),(25,43),(13,39)],fill=dark)
            g.polygon([(10,32),(15,27),(29,26),(38,28),(48,26),(50,34),(44,38),(22,38)],fill='#808475')
            if shell:
                g.polygon([(7,29),(11,18+h),(19,12+h),(26,10+h),(37,9+h),(47,13+h),(52,21+h),(55,29),(49,31),(29,28),(14,32)],fill=dark)
                g.polygon([(10,25),(16,17+h),(25,12+h),(37,12+h),(47,18+h),(50,24),(36,22),(22,26)],fill=mid)
                for x,y in ((15,22),(24,16),(37,16),(43,20)):g.rectangle((x,y+h,x+3,y+h+2),fill=high)
                g.line([(9,29),(22,27),(36,24),(52,27)],fill=light,width=2)
            else:
                for x,y,r in [(12,29,7),(23,26,8),(34,27,7)]:
                    g.ellipse((x-r,y-r+h,x+r,y+r+h),fill=mid,outline=dark,width=2)
                    g.ellipse((x-r+3,y-r+2+h,x-r+6,y-r+5+h),fill='#d1aaad')
                g.line([(43,27),(45,18-h),(49,16-h)],fill=high,width=2);g.rectangle((48,14-h,51,17-h),fill=light)
            g.rectangle((45,32,51,34),fill=dark);g.rectangle((48,32,51,33),fill=light)
        else:
            edge='#252936';iron='#535461';gold='#ab8462';shine='#c7b3a0';hot='#ffce7e'; offset=(0,-2,2)[phase]
            g.polygon([(5,36),(12,32),(43,32),(53,37),(54,43),(48,48),(12,48),(5,43)],fill=edge)
            for x in (13,23,33,43):g.ellipse((x-4,36,x+4,44),fill=iron,outline=gold);g.point((x+phase-1,39),fill=shine)
            y=26+offset
            g.polygon([(9,34),(12,y-5),(21,y-10),(40,y-9),(46,y-3),(49,34),(43,38),(14,38)],fill=edge)
            g.polygon([(12,32),(17,y-4),(25,y-8),(39,y-6),(43,y),(39,32),(26,35)],fill=iron)
            g.line([(14,31),(21,y-4),(37,y-5)],fill=gold,width=2)
            for x in (23,28,33):g.line([(x,y-2),(x-1,y+4)],fill='#333743',width=2)
            g.rectangle((36,y,45,y+4),fill=edge);g.rectangle((38,y+1,44,y+2),fill=hot)
            if bot:
                g.polygon([(35,28),(41,20+offset),(48,22+offset),(51,27),(58,29),(49,36),(41,34)],fill=gold,outline=edge)
                g.line([(45,25+offset),(50,30),(56,29)],fill=shine,width=2)
                g.line([(17,24),(14,15+offset),(16,10+offset)],fill=edge,width=4);g.line([(15,12+offset),(19,12+offset)],fill=gold,width=2)
            else:g.rectangle((14,28,21,31),fill=gold);g.line([(12,35),(39,35)],fill=shine)
        atlas.alpha_composite(im,(phase*60,0))
    atlas.save(dst,optimize=True)
