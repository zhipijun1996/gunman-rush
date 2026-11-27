"""Bake the two guardian silhouettes from the regional native stone and harbor fittings."""
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'bosses/machines'))
from build import Shop, INK, IRON, BRASS, GOLD
OUT=Path(__file__).resolve().parents[3]/'production/assets/bosses/harbor_ember'
OUT.mkdir(exist_ok=True)
harbor=Shop(128,84)
d=harbor.draw
for x in (35,75):
    harbor.plate((x,46,x+13,76))
    d.polygon([(x+2,67),(x+15,66),(x+23,76),(x+21,81),(x-6,81),(x-6,76)],fill='#505554',outline=INK,width=2)
    d.line((x-3,78,x+18,78),fill='#93a097',width=2)
harbor.part('sunken_ruins_v2_fluted_column',(5,11,111,72),(65,48),(25,20))
harbor.part('sunken_ruins_v2_air_bell',(9,9,71,73),(38,40),(51,3))
d.polygon([(66,24),(86,23),(88,29),(69,32)],fill=INK)
d.line((72,27,84,25),fill='#91d8c6',width=2)
d.line((76,49,115,31),fill=INK,width=8)
d.line((76,47,116,30),fill=BRASS,width=3)
d.polygon([(105,28),(127,21),(119,32),(112,33),(110,40)],fill='#96ada2',outline=INK)
harbor.part('sunken_ruins_v2_shell_relic',(4,3,70,46),(51,51),(7,26))
harbor.wheel(31,51,12)
harbor.image.save(OUT/'harbor_warden.png',optimize=True)
ember=Shop(122,80)
d=ember.draw
for x in (13,84):
    ember.part('ember_depths_v2_chain_stand',(15,10,76,78),(28,57),(x,20),x>60)
for x,y,r in ((60,25,21),(47,30,15),(73,32,15)):
    d.ellipse((x-r,y-r,x+r,y+r),fill='#8c4236',outline=INK,width=2)
    d.ellipse((x-r+5,y-r+4,x+r-5,y+r-5),fill='#ed9150')
    d.arc((x-r+7,y-r+3,x+r-4,y+r-6),180,315,fill='#ffcd7e',width=3)
ember.part('ember_depths_v2_stone_cauldron',(1,4,110,88),(88,62),(18,17))
for x in (35,48,62,75,88):
    d.line((x,30,x-3,17,x+2,10),fill=INK,width=4)
    d.line((x-1,29,x-4,17,x+1,11),fill='#8e7769',width=1)
d.arc((25,1,96,39),192,349,fill='#b49b74',width=3)
d.line((46,74,76,74),fill='#786666',width=2)
ember.image.save(OUT/'thermal_bell_keeper.png',optimize=True)
