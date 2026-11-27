"""Build the drowned valve-bell and the obsidian-backed moulting beast."""
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'machines'))
from build import Shop, IRON, STEEL, GOLD, BRASS, INK

out=Path(__file__).resolve().parents[3]/'production/assets/bosses/tide_and_ember'
out.mkdir(parents=True,exist_ok=True)
s=Shop(132,108)
for x in [10,103]:
    s.part('sunken_ruins_v2_fluted_column',(3,3,113,70),(21,63),(x,42),x>50)
s.plate((16,85,117,103))
s.part('sunken_ruins_v2_air_bell',(0,0,78,88),(84,89),(24,8))
s.wheel(66,65,19)
s.draw.ellipse((59,58,73,72),fill='#524a41',outline=GOLD,width=2)
s.plate((47,16,84,25))
for x in [43,65,87]:
    s.draw.arc((x-8,3,x+8,34),180,360,fill=BRASS,width=4)
    s.draw.rectangle((x-2,13,x+2,19),fill='#87c7b9')
s.image.save(out/'tide_pump_bell.png',optimize=True)
s=Shop(148,80)
for x in [19,44,81,111]:
    s.draw.polygon([(x,43),(x+11,40),(x+12,58),(x+4,73),(x+11,77),(x-7,77),(x,58)],fill='#514047',outline=INK,width=2)
s.draw.polygon([(2,45),(13,34),(30,29),(43,13),(75,5),(105,14),(132,32),(146,42),(137,53),(108,52),(80,63),(35,58)],fill='#322d37',outline=INK,width=2)
s.part('ember_depths_v2_obsidian_fangs',(5,7,74,57),(68,42),(41,4))
for x,y in [(19,34),(43,19),(68,11),(91,18),(110,28)]:
    s.draw.polygon([(x-12,y+12),(x,y),(x+13,y+3),(x+16,y+15),(x+5,y+22)],fill='#5a484d',outline='#292a32',width=2)
    s.draw.line((x-10,y+11,x,y+2,x+9,y+4),fill='#ba6849',width=2)
s.draw.polygon([(112,36),(128,29),(144,38),(144,48),(126,54),(113,48)],fill='#664a4b',outline=INK,width=2)
s.draw.line((127,39,137,38),fill='#f7ab67',width=2)
s.image.save(out/'ember_molter.png',optimize=True)
