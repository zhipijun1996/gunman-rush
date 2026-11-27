"""Build the three mobile machines at native resolution using the regional metalwork masters."""
from pathlib import Path
from math import cos, sin, pi
from PIL import Image, ImageDraw, ImageOps

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / 'art/world-art-v2/assets/pixel/v2'
OUT = ROOT / 'production/assets/bosses/machines'
INK, IRON, STEEL, LIGHT = '#201f2c', '#343945', '#57636a', '#93a098'
COPPER, BRASS, GOLD = '#724934', '#ab794b', '#e2bd79'
IVORY, BLUE, WHITE = '#ccceb5', '#65acac', '#eae5c9'


class Shop:
    def __init__(self, width, height):
        self.image = Image.new('RGBA', (width, height))
        self.draw = ImageDraw.Draw(self.image)

    def plate(self, box, palette=(IRON, STEEL, LIGHT)):
        x, y, r, b = box
        self.draw.rectangle(box, fill=INK)
        self.draw.rectangle((x+1,y+1,r-1,b-1), fill=palette[0])
        self.draw.line([(x+2,b-3),(x+2,y+2),(r-2,y+2)], fill=palette[2])
        self.draw.rectangle((x+4,y+4,r-3,b-4), fill=palette[1])
        for u,v in [(x+3,y+3),(r-3,y+3),(x+3,b-3),(r-3,b-3)]:
            self.draw.point((u,v),fill=WHITE)

    def wheel(self, x, y, r):
        for radius, col in [(r,INK),(r-2,STEEL),(r-4,LIGHT),(r-5,IRON)]:
            self.draw.ellipse((x-radius,y-radius,x+radius,y+radius),fill=col)
        for i in range(8):
            a = 2*pi*i/8
            self.draw.line((x,y,round(x+(r-5)*cos(a)),round(y+(r-5)*sin(a))),fill=BRASS,width=2)
        self.draw.ellipse((x-3,y-3,x+3,y+3),fill=INK,outline=GOLD)

    def part(self, master, box, size, position, mirror=False):
        image = Image.open(SOURCE / (master+'.png')).convert('RGBA').crop(box)
        image = image.resize(size,Image.Resampling.NEAREST)
        if mirror:
            image = ImageOps.mirror(image)
        self.image.alpha_composite(image,position)

    def save(self, name):
        self.image.save(OUT / (name+'.png'),optimize=True)


def inspection():
    s = Shop(128,76)
    s.plate((8,16,25,51))
    s.plate((6,11,27,19),(COPPER,BRASS,GOLD))
    s.plate((15,44,108,65))
    for x in [22,51,80,104]:
        s.wheel(x,62,12)
    s.part('gear_city_v2_piston_press',(6,12,101,94),(76,50),(22,7))
    s.plate((33,14,87,46),(COPPER,BRASS,GOLD))
    s.plate((42,19,79,41))
    for y in range(24,39,4):
        s.draw.line((47,y,75,y),fill=INK,width=2)
    s.plate((88,32,118,54))
    s.wheel(100,34,13)
    s.draw.ellipse((94,28,106,40),fill=BLUE,outline=INK,width=2)
    s.draw.line((96,31,103,31),fill=WHITE,width=2)
    s.draw.line((19,62,81,62,103,59),fill=INK,width=5)
    s.draw.line((19,61,81,61,103,58),fill=BRASS,width=2)
    s.save('gear_overseer')


def traction():
    s = Shop(152,92)
    for x in (32,118):
        s.plate((x-6,0,x+6,36))
        s.wheel(x,18,13)
    s.plate((5,26,147,43))
    s.plate((22,35,131,63),(COPPER,BRASS,GOLD))
    for x in (18,117):
        s.part('gear_city_v2_pipe_junction',(9,5,69,91),(27,47),(x,36),x>50)
    s.plate((44,34,108,77))
    for x in range(49,103,5):
        s.draw.line((x,39,x-2,68),fill=INK,width=3)
        s.draw.line((x+1,40,x-1,67),fill=BRASS)
    for x in (42,110):
        s.wheel(x,70,16)
    s.plate((59,68,94,88),(COPPER,BRASS,GOLD))
    s.draw.rectangle((67,72,85,81),fill=INK)
    s.draw.line((68,73,84,73),fill=BLUE,width=2)
    s.save('traction_engine')


def regulator():
    s = Shop(124,128)
    for x in (12,89):
        s.plate((x,51,x+21,120),(IRON,IVORY,WHITE))
        s.part('world_clockheart_v2_porcelain_coil',(9,15,84,70),(21,45),(x,64),x>50)
        s.plate((x-5,111,x+24,124))
    s.plate((29,29,96,118),(COPPER,BRASS,GOLD))
    s.part('world_clockheart_v2_regulator_panel',(14,13,112,78),(62,63),(31,53))
    for radius,color in ((31,INK),(29,BRASS),(27,IVORY),(24,IRON),(22,STEEL)):
        s.draw.ellipse((62-radius,38-radius,62+radius,38+radius),fill=color)
    for i in range(12):
        a = 2*pi*i/12
        s.draw.line((round(62+18*cos(a)),round(38+18*sin(a)),round(62+21*cos(a)),round(38+21*sin(a))),fill=GOLD,width=2)
    s.draw.line((62,38,50,27),fill=WHITE,width=3)
    s.draw.line((62,38,74,22),fill=GOLD,width=2)
    s.wheel(62,90,16)
    s.plate((26,114,99,126))
    s.save('clock_regulator')


if __name__ == '__main__':
    OUT.mkdir(parents=True,exist_ok=True)
    inspection()
    traction()
    regulator()
