"""Build the native-pixel pieces used by the Windchime Slope starting room."""
from pathlib import Path

from PIL import Image, ImageEnhance, ImageOps

ROOT = Path(__file__).resolve().parents[3]
PLAINS = ROOT / "assets/plains_v07/native"
OUT = ROOT / "production/assets/scenery/p01"


def native(path, width):
    art = Image.open(path).convert("RGBA")
    bounds = art.getchannel("A").point(lambda a: 255 if a >= 32 else 0).getbbox()
    art = art.crop(bounds)
    art = art.resize((width,round(width*art.height/art.width)),Image.Resampling.LANCZOS)
    art.putalpha(art.getchannel("A").point(lambda a: 0 if a < 22 else a))
    return art


def save(image, name):
    image.save(OUT/(name+".png"), optimize=True)


def build():
    OUT.mkdir(parents=True,exist_ok=True)
    # Native forest silhouettes frame the west boundary. Their feet and exposed
    # roots share the low ground under the fence on both approaches.
    tree = native(ROOT/"assets/forest_bible_v2/source/midtree_v2.original.png",285)
    tree = ImageEnhance.Color(tree).enhance(.62)
    save(tree,"p01_forest_verge")

    # Behind the near roots, the lower of the two native woodland ridge
    # studies recedes into the valley. Bury the cut edge below the west bank.
    donor = ROOT/"assets/region_production_v3/spaces/woodland_two_depth_ridges_v2/source.png"
    ridge = Image.open(donor).convert("RGBA").crop((0,450,1536,987))
    ridge = ridge.resize((353,123),Image.Resampling.LANCZOS)
    alpha = ridge.getchannel("A").point(lambda a: 0 if a<32 else a)
    ridge = ImageEnhance.Color(ridge).enhance(.44)
    ridge = Image.blend(ridge,Image.new("RGBA",ridge.size,(132,145,134,255)),.43)
    ridge.putalpha(alpha)
    save(ridge,"p01_forest_distance")

    # Both feet of the timber bent meet the real grass. Its cross member sits
    # directly beneath the room's one-way deck; the cloth starts on that deck.
    bent = native(PLAINS/"mill_timber_bent.png",166)
    bent = ImageEnhance.Color(bent).enhance(.80)
    # Hang the actual plains chime from the underside of the cross member.
    # The standing post belongs to its source study; this landing has its own.
    chime = Image.open(PLAINS/"hanging_chime.png").convert("RGBA").crop((30,8,49,56))
    bent.alpha_composite(chime,(33,30))
    save(bent,"p01_loft_frame")
    save(native(PLAINS/"aqi_ribbon.png",37),"p01_wind_ribbon")
    save(ImageOps.mirror(native(PLAINS/"orchard_fence.png",112)),"p01_verge_fence")


if __name__ == "__main__":
    build()
