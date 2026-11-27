"""Bake the P13 return passage from the current P03 cliff at the d017 seam."""
import argparse
import json
from io import BytesIO
from pathlib import Path

from PIL import Image

PROJECT = Path(__file__).resolve().parents[3] / "production"
WORLD = PROJECT / "rooms/world"
SOURCE_ASSET = "res://assets/scenery/p03/ravine_backwall.webp"
TARGET_ASSET = "res://rooms/world/p02_connections/ridge_backwall.webp"
OUTPUT_SIZE = (970, 520)


def anchor(document, texture):
    piece, = (row for row in document["scenery"]["pieces"] if row["texture"] == texture)
    return piece["at"]


def bake():
    source_doc = json.loads((WORLD / "P03.json").read_text())
    target_doc = json.loads((WORLD.parents[1] / "tests/fixtures/plains_receivers/P13.json").read_text())
    source_at = anchor(source_doc, SOURCE_ASSET)
    target_at = anchor(target_doc, TARGET_ASSET)
    source_gate = source_doc["exits"]["d017"]["point"]
    target_gate = target_doc["exits"]["d017"]["point"]
    with Image.open(PROJECT / SOURCE_ASSET.removeprefix("res://")) as raw:
        source = raw.convert("RGBA")
    width, height = OUTPUT_SIZE
    # Scenery anchors use bottom center. Map the two foreground canvases through
    # their paired physical gate before sampling the ravine at native scale.
    left = target_at[0] - width // 2 + source_gate[0] - target_gate[0] - (source_at[0] - source.width // 2)
    top = target_at[1] - height + source_gate[1] - target_gate[1] - (source_at[1] - source.height)
    if not (0 <= left < source.width and 0 <= top <= source.height - height):
        raise ValueError("The P13 mouth no longer overlaps the authored P03 backdrop")
    straight = min(width, source.width - left)
    reflected = width - straight
    if reflected > source.width:
        raise ValueError("The P13 extension exceeds one reflected cliff face")
    result = Image.new("RGBA", OUTPUT_SIZE)
    result.paste(source.crop((left, top, left + straight, top + height)), (0, 0))
    if reflected:
        cliff = source.crop((source.width - reflected, top, source.width, top + height))
        result.paste(cliff.transpose(Image.Transpose.FLIP_LEFT_RIGHT), (straight, 0))
    buffer = BytesIO()
    result.save(buffer, format="WEBP", lossless=True, method=6)
    return buffer.getvalue()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="verify the current bake without writing")
    args = parser.parse_args()
    output = PROJECT / TARGET_ASSET.removeprefix("res://")
    baked = bake()
    if args.check:
        # Compare decoded pixels so a different libwebp build is also accepted.
        with Image.open(output) as current, Image.open(BytesIO(baked)) as expected:
            if current.size != expected.size or current.convert("RGBA").tobytes() != expected.convert("RGBA").tobytes():
                raise SystemExit("P13 ridge_backwall.webp is stale. Run this script without --check.")
        print("P13 backdrop matches P03 and d017.")
    else:
        output.write_bytes(baked)
