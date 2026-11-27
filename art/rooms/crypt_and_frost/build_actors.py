"""Build the three separate production-scale actors from their transparent master."""
from pathlib import Path
from PIL import Image

HERE = Path(__file__).resolve().parent
OUT = HERE.parents[2] / "production/assets/bosses/crypt_and_frost"
master = Image.open(HERE / "boss_source.png").convert("RGBA")
third = master.width // 3
for i, (name, height) in enumerate([("royal_bell_bearer", 115), ("mirror_bell_warden", 128), ("frost_echo_doll", 91)]):
    actor = master.crop((i * third, 0, (i + 1) * third, master.height))
    # Remove almost transparent edge noise before scaling to the playable pixel grid.
    actor = actor.crop(actor.getchannel("A").point(lambda a: 255 if a >= 110 else 0).getbbox())
    actor = actor.resize((round(actor.width * height / actor.height), height), Image.Resampling.LANCZOS)
    actor.putalpha(actor.getchannel("A").point(lambda a: 255 if a >= 120 else 0))
    actor.save(OUT / (name + ".png"))
