"""Native sprites for the cavern stone curtain and the third tunnelling machine."""
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'machines'))
from build import Shop, IRON, INK, STEEL, BRASS, GOLD, WHITE, COPPER

OUT=Path(__file__).resolve().parents[3]/'production/assets/bosses/depths'
OUT.mkdir(exist_ok=True,parents=True)
s=Shop(140,82)
for x in [14,46,92,116]:
    s.draw.polygon([(x,57),(x+7,44),(x+14,58),(x+8,80),(x-5,80)],fill='#312c40',outline=INK,width=2)
    s.draw.line((x+7,52,x+2,75),fill='#777179',width=3)
s.part('mushroom_caverns_v2_spore_pods',(0,0,72,57),(68,50),(33,26))
s.draw.polygon([(3,42),(20,24),(46,17),(63,2),(89,5),(106,19),(133,29),(138,47),(115,44),(88,56),(67,53),(50,61),(27,50)],fill='#4b4558',outline=INK,width=3)
for x,y in [(20,24),(51,18),(71,5),(97,17),(115,28)]:
    s.draw.polygon([(x,y),(x+13,y+3),(x+6,y+17),(x-12,y+23)],fill='#79747a',outline='#4b4656')
    s.draw.line((x-8,y+16,x,y+2,x+9,y+3),fill='#aaa599')
s.part('mushroom_caverns_v2_hollow_cap',(1,0,80,41),(64,26),(7,24))
s.part('mushroom_caverns_v2_hollow_cap',(1,0,80,41),(54,23),(80,23),True)
for x,y in [(31,39),(51,43),(88,39),(108,38),(67,53)]:
    s.draw.ellipse((x-2,y-1,x+2,y+2),fill='#98d7bc')
s.image.save(OUT/'stone_curtain_lord.png',optimize=True)
s=Shop(146,76)
s.plate((5,37,141,66))
for x in [20,46,75,103,128]:
    s.wheel(x,60,14)
s.part('echo_mines_v2_mine_cart',(1,1,99,64),(95,43),(25,11))
s.plate((50,6,103,34))
s.plate((56,3,99,13),(COPPER,BRASS,GOLD))
for x in range(57,93,8):
    s.draw.line((x,18,x+4,27),fill=GOLD,width=2)
s.plate((104,23,134,49),(COPPER,BRASS,GOLD))
s.plate((118,27,145,43))
s.wheel(24,40,17)
s.draw.ellipse((17,33,31,47),fill='#51988e',outline=INK,width=2)
s.image.save(OUT/'borer_three.png',optimize=True)
