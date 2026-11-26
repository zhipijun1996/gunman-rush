"""Bake native movement hardware and field sprites from the recorded source rectangles."""
from pathlib import Path
import json

from PIL import Image

HERE = Path(__file__).resolve().parent
NATIVE = HERE.parents[2] / "production/assets/world_traversal/native"

def bake(source_path, cells):
    with Image.open(source_path) as source:
        for name, cell in cells.items():
            art = source.convert("RGBA").crop(cell["crop"]).resize(tuple(cell["size"]), Image.Resampling.BOX)
            alpha = art.getchannel("A")
            color = art.convert("RGB").quantize(colors=96, dither=Image.Dither.NONE).convert("RGBA")
            color.putalpha(alpha.point(lambda value: value if value >= 18 else 0))
            color.save(NATIVE / (name + ".png"), optimize=True)

if __name__ == "__main__":
    manifest = json.loads((HERE / "sources.json").read_text())
    for source in manifest["sources"]:
        bake(HERE / source["filename"], source["cells"])
