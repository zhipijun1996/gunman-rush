"""Bake the regional archive's native props for the old road, village and waterworks."""
from pathlib import Path
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "assets/plains_v07/native"
OUT = ROOT / "production/assets/scenery/plains_trail"
# Width at one world unit per texel. Trim transparent margins so every root sits at the placed foot.
WIDTHS = {
    "carriage": 181,
    "travel_bundle": 48,
    "orchard_arch_east": 300,
    "orchard_arch_west": 258,
    "orchard_fence": 116,
    "windmill_frame": 244,
    "market_stalls": 224,
    "station_houses": 676,
    "waiting_shelter": 188,
    "merchant_counter": 83,
    "storage_crates": 74,
    "aqi_bench": 92,
    "mill_drive_frame": 178,
    "clockheart_ruin": 236,
    "mill_window_bay": 129,
    "hanging_chime": 37,
    "building_threshold": 96,
    "barrel": 42,
    "mill_timber_bent": 196,
    "longbridge_crane": 204,
    "junction_rotor": 136,
    "opening_guard_gallery": 360,
    "well_winch_mount": 119,
    "bank_moss": 80,
}
OUT.mkdir(parents=True,exist_ok=True)
for name,width in WIDTHS.items():
    art = Image.open(SOURCE / (name+".png")).convert("RGBA")
    art = art.crop(art.getbbox())
    if art.width != width:
        art = art.resize((width,round(art.height*width/art.width)), Image.Resampling.LANCZOS)
        art.putalpha(art.getchannel("A").point(lambda alpha: 0 if alpha<40 else alpha))
    art.save(OUT / (name+".png"), optimize=True)
# Recombine the existing field sky and transparent regional midground at native scale.
# The three silhouettes place the canal, meadow or clock tower behind the playable road.
field = Image.open(ROOT/"production/assets/scenery/p02/irrigation_panorama.webp").convert("RGBA")
for name,overlay in [("lowlands","canal_lowlands"),("market_field","junction_meadow"),("clock_horizon","longbridge_vista")]:
    backdrop=field.copy()
    strip=Image.open(SOURCE/(overlay+".png")).convert("RGBA")
    strip=strip.resize((field.width,round(strip.height*field.width/strip.width)),Image.Resampling.LANCZOS)
    strip.putalpha(strip.getchannel("A").point(lambda value:round(value*.72)))
    backdrop.alpha_composite(strip,(0,backdrop.height-strip.height+65))
    backdrop.convert("RGB").save(OUT/(name+".webp"),quality=93,method=6)
for name,source in [("store_shed","grain_loft"),("stone_cellar","interior_cellar"),("mill_attic","interior_mill")]:
    interior=ImageOps.fit(Image.open(SOURCE/(source+".png")).convert("RGB"), (1152,648), method=Image.Resampling.NEAREST)
    interior.save(OUT/(name+".webp"),quality=91,method=6)
