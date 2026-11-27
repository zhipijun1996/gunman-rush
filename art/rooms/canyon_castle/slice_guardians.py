"""Bake the two encounter silhouettes from the reviewed transparent master."""
from pathlib import Path

from PIL import Image

HERE = Path(__file__).parent
OUTPUT = HERE.parents[2] / "production/assets/bosses/machines"

with Image.open(HERE / "arena_guardians.webp") as source:
    for index, (name, height) in enumerate((("crown_strider", 72), ("star_warden", 94))):
        cell = source.crop((source.width * index // 2, 0, source.width * (index + 1) // 2, source.height))
        solid = cell.getchannel("A").point(lambda opacity: 255 if opacity > 185 else 0)
        pose = cell.crop(solid.getbbox())
        pose.thumbnail((int(pose.width * height / pose.height), height), Image.Resampling.LANCZOS)
        sprite = pose.convert("RGB").quantize(80, method=Image.Quantize.MEDIANCUT,
                                               dither=Image.Dither.NONE).convert("RGBA")
        sprite.putalpha(pose.getchannel("A").point(lambda opacity: 255 if opacity >= 132 else 0))
        sprite.save(OUTPUT / (name + ".png"))
