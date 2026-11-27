"""Bake distant architecture for the three districts from the original pixel kit."""
from math import cos, pi, sin
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "art/world-art-v2/assets/pixel"
OUT = ROOT / "production/assets/scenery/gear_city"
SIZE = (1152, 508)


def native(name):
    return Image.open(next(SOURCE.rglob(name + ".png"))).convert("RGBA")


def room_shell():
    wall = native("gear-background")
    canvas = Image.new("RGB", SIZE)
    for i in range(2):
        panel = ImageOps.mirror(wall) if i else wall
        canvas.paste(panel.resize((680, 508), Image.Resampling.NEAREST), (i * 680, 0))
    return canvas


def muted_prop(canvas, name, x, floor, width, strength):
    sprite = native(name)
    sprite = sprite.resize((width, round(sprite.height * width / sprite.width)), Image.Resampling.NEAREST)
    point = (x, floor - sprite.height)
    behind = canvas.crop((*point, point[0] + sprite.width, floor))
    tint = ImageOps.colorize(ImageOps.grayscale(sprite), "#15212b", "#697680")
    canvas.paste(Image.blend(behind, tint, strength), point, sprite.getchannel("A"))


def giant_drive():
    canvas = room_shell()
    shade = Image.new("L", SIZE)
    pen = ImageDraw.Draw(shade)
    cx, cy, radius = 714, 243, 265
    ring = []
    for tooth in range(40):
        for turn, length in [(0, .94), (.17, 1), (.62, 1), (.80, .94)]:
            theta = (tooth + turn) / 40 * pi * 2
            ring.append((round(cx + cos(theta) * radius * length), round(cy + sin(theta) * radius * length)))
    pen.polygon(ring, fill=197)
    inner = int(radius * .82)
    pen.ellipse((cx - inner, cy - inner, cx + inner, cy + inner), fill=0)
    for spoke in range(10):
        theta = (spoke + .23) * pi / 5
        pen.line((cx, cy, int(cx + cos(theta) * radius * .90), int(cy + sin(theta) * radius * .90)), fill=173, width=24)
    for r, amount in [(65, 220), (42, 168), (23, 219)]:
        pen.ellipse((cx-r, cy-r, cx+r, cy+r), fill=amount)
    # The teeth share the source wall's grain and cool reflected light.
    texture = ImageOps.colorize(ImageOps.grayscale(room_shell()), "#1b2932", "#56616c")
    canvas.paste(texture, (0, 0), shade)
    muted_prop(canvas, "gear_city_v2_pipe_junction", 92, 504, 146, .53)
    muted_prop(canvas, "gear_city_v2_gear_conveyor", 802, 480, 350, .39)
    return canvas


def pump_gallery():
    canvas = Image.blend(room_shell(), Image.new("RGB", SIZE, "#213137"), .24)
    draw = ImageDraw.Draw(canvas)
    # A continuous low viaduct below the machinery fills the base of the gallery.
    for x in range(0, 1250, 166):
        draw.rectangle((x, 348, x + 36, 508), fill="#27363c")
    draw.rectangle((0, 340, 1152, 352), fill="#38444a")
    draw.line((0, 340, 1152, 340), fill="#4a5358", width=2)
    for name, x, width in [("gear_city_v2_piston_press", 120, 185), ("gear_city_v2_pipe_junction", 344, 127),
                           ("gear_city_v2_valve_panel", 606, 120), ("gear_city_v2_piston_press", 843, 219)]:
        muted_prop(canvas, name, x, 343, width, .48)
    return canvas


def bridge_district():
    canvas = Image.new("RGB", SIZE)
    draw = ImageDraw.Draw(canvas)
    for y in range(0, SIZE[1], 3):
        t = y / SIZE[1]
        color = tuple(round(a + (b-a)*t) for a, b in zip((45,61,74), (103,101,90)))
        draw.rectangle((0,y,SIZE[0],y+2),fill=color)
    for i, roof in enumerate([302, 265, 286, 232, 279, 248, 290, 259]):
        x = i * 153 - 28
        draw.rectangle((x,roof,x+156,508),fill="#34434b")
        muted_prop(canvas,"gear_city_mid_v2",x-11,roof+5,185,.64)
        for offset in [23,74,121]:
            for floor in range(roof+22,451,36):
                draw.rectangle((x+offset,floor,x+offset+7,floor+10),fill="#4c5658")
    for x in [63,455,855]:
        draw.rectangle((x,371,x+186,508),fill="#28353c")
        muted_prop(canvas,"gear_city_mid_v2",x-12,376,207,.74)
    return canvas


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for name, image in [("wheel_hall", giant_drive()), ("pump_gallery", pump_gallery()), ("bridge_district", bridge_district())]:
        image.save(OUT / (name + ".webp"), lossless=True)


def metalwork():
    plate = native("gear_city_v2_gear_conveyor")
    grain = ImageOps.colorize(ImageOps.grayscale(plate.crop((45,18,69,40))), "#222832", "#787878")
    mast = Image.new("RGBA", (20,110))
    for y in range(0,110,22):
        mast.paste(grain.crop((0,0,14,22)), (3,y))
    p = ImageDraw.Draw(mast)
    p.line((4,1,4,108), fill="#88837c")
    p.line((13,0,13,109), fill="#272b31",width=2)
    for y in [4,38,73,101]:
        p.rectangle((1,y,19,y+5), fill="#46484b", outline="#27292e")
        p.point((4,y+1),fill="#aa957d")
    mast.save(OUT/"shortcut_post.png")
    shutter=Image.new("RGBA",(39,106)); d=ImageDraw.Draw(shutter)
    for x in [2,12,22,32]:
        for y in range(4,102,22): shutter.paste(grain.crop((3,0,8,min(22,103-y))),(x,y))
        d.line((x+1,5,x+1,100),fill="#a09684")
    for y in [8,49,94]:
        d.rectangle((1,y,37,y+6),fill="#6c6764",outline="#272b30")
        for x in [4,15,26,34]: d.point((x,y+2),fill="#c6ae83")
    d.rectangle((15,46,25,56),fill="#857547",outline="#252c31")
    shutter.save(OUT/"shortcut_leaf.png")


def build_frames():
    # Every non-solid steel catwalk visibly transfers load to the first
    # authored bearing below. Lattice openings stay transparent to actors.
    import json
    folder=ROOT/"production/rooms/world"
    print("Building open frames from authored catwalks")
    for path in sorted(folder.glob("G*.json")):
        doc=json.loads(path.read_text())
        _,_,width,height=doc["bounds"]
        beams=[]
        blocks=[]
        for obj in doc["entities"].values():
            if obj["definition_id"] in ["platform.solid","platform.one_way"]:
                x,y,w,h=obj["properties"]["rect"]
                blocks.append((x,y,w,h))
                if obj["definition_id"]=="platform.one_way": beams.append((x,y,w,h))
        filename="frame_"+doc["room_id"]+".png"
        pieces=doc["scenery"]["pieces"]
        pieces[:]=[row for row in pieces if not row.get("texture","").endswith("/"+filename)]
        if not beams: continue
        img=Image.new("RGBA",(width,height))
        pen=ImageDraw.Draw(img)
        for x,y,w,h in beams:
            left,right=x+11,x+w-11
            bottom=min([s[1] for s in blocks if s[1]>y and s[0]<=left and right<=s[0]+s[2]]+[height])
            if bottom<=y+h+6: continue
            # Bolt a narrow triangular knee beneath each end of the walkway.
            for side,sign in [(left,1),(right,-1)]:
                bearing=min([s[1] for s in blocks if s[1]>y and s[0]<=side<=s[0]+s[2]]+[height])
                p=y+h-4
                for xx,color,sw in [(side,"#222a30",6),(side-1,"#535157",2),(side+1,"#343941",1)]:
                    pen.line((xx,p,xx,bearing),fill=color,width=sw)
                length=min(37,(w-24)//3,bearing-p)
                pen.line((side,p+length,side+sign*length,p),fill="#30343b",width=5)
                pen.line((side-1,p+length-2,side+sign*length-1,p),fill="#67605a",width=1)
                for bolt in range(p+9,bearing,49):
                    pen.rectangle((side-3,bolt,side+2,bolt+3),fill="#434347")
                    pen.point((side-2,bolt),fill="#81776c")
                pen.rectangle((side-5,bearing-3,side+4,bearing),fill="#343940")
        box=img.getbbox()
        if not box:continue
        sprite=img.crop(box)
        sprite.save(OUT/filename,optimize=True)
        pieces.insert(0,{"texture":"res://assets/scenery/gear_city/"+filename,"at":[(box[0]+box[2])/2,box[3]],"z_index":-19})
        path.write_text(json.dumps(doc,ensure_ascii=False,indent=2)+"\n")


if __name__ == "__main__":
    metalwork()
    build_frames()
