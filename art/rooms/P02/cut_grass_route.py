"""Subtitle the uninterrupted, real-time first visit recorded by capture_grass_route.gd."""
import argparse
import json
import math
import subprocess
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

STAGES = ["west_far", "east_far", "clue", "discover", "revealed", "below", "jump",
          "bank", "clear", "restored", "revisit", "end"]
CAPTIONS = [
    ("revealed", "below", "草叶在近处退开"),
    ("restored", "revisit", "远处重新遮住，地图保留了这次发现"),
]
HEADER = """[Script Info]
ScriptType: v4.00+
PlayResX: 1280
PlayResY: 720
[V4+ Styles]
Format: Name,Fontname,Fontsize,PrimaryColour,SecondaryColour,OutlineColour,BackColour,Bold,Italic,Underline,StrikeOut,ScaleX,ScaleY,Spacing,Angle,BorderStyle,Outline,Shadow,Alignment,MarginL,MarginR,MarginV,Encoding
Style: Grass,Noto Sans CJK SC,29,&H00FFFFFF,&H00FFFFFF,&H8822221E,&H8822221E,-1,0,0,0,100,100,0,0,3,5,0,8,45,45,60,1
[Events]
Format: Layer,Start,End,Style,Name,MarginL,MarginR,MarginV,Effect,Text
"""


def stamp(frame):
    centis = round(frame * 100 / 60)
    sec, centis = divmod(centis, 100)
    minutes, sec = divmod(sec, 60)
    return f"{minutes//60}:{minutes%60:02d}:{sec:02d}.{centis:02d}"


def extract_frame(movie, frame, output):
    subprocess.run(
        ["ffmpeg", "-v", "error", "-y", "-ss", f"{frame/60:.8f}", "-i", str(movie),
         "-frames:v", "1", "-threads", "1", str(output)],
        check=True)


def comparison(folder):
    # Preserve the same native pixel window from both normal-camera frames.
    # Its right edge includes the player's starting position on the far bank.
    box = (68, 328, 676, 718)
    width, height = box[2] - box[0], box[3] - box[1]
    sheet = Image.new("RGB", (width*2 + 6, height + 66), (33, 33, 31))
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.truetype("/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc", 36)
    for i, (name, label) in enumerate([("east_far", "初次远望"), ("revealed", "走近以后")]):
        left = i*(width+6)
        draw.text((left+12, 4), label, font=font, fill=(248, 244, 229))
        with Image.open(folder / f"{name}.png") as image:
            if image.size != (1280, 720):
                raise ValueError(f"Expected gameplay at 1280×720, got {image.size}")
            sheet.paste(image.convert("RGB").crop(box), (left, 66))
    sheet.save(folder / "P02-grass-before-after.jpg", quality=94, subsampling=0)


def export(movie, log, output):
    source = log.read_text()
    rows = [json.loads(line.removeprefix("GRASS_ROUTE "))
            for line in source.splitlines() if line.startswith("GRASS_ROUTE ")]
    by_stage = {row["stage"]: row for row in rows}
    if [row["stage"] for row in rows] != STAGES or "Done recording movie" not in source:
        raise ValueError("The first-visit gameplay or its recording is incomplete")
    for row in rows:
        expected_room = "P16" if row["stage"] in ("below", "jump") else "P02"
        if row["room"] != expected_room or row["known"] != (row["frame"] >= by_stage["discover"]["frame"]):
            raise ValueError(f"Invalid room or discovery at {row['stage']}")
        if row["visited"] != (row["frame"] >= by_stage["below"]["frame"]):
            raise ValueError(f"A visit was recorded out of order at {row['stage']}")
    for stage in ("west_far", "revealed", "restored", "revisit"):
        if math.dist(by_stage["east_far"]["camera"], by_stage[stage]["camera"]) > 0.5 or by_stage[stage]["zoom"] != by_stage["east_far"]["zoom"]:
            raise ValueError(f"The native gameplay viewpoints differ at {stage}")
    for stage in ("west_far", "east_far", "restored"):
        if not 0 <= by_stage[stage]["reveal_at_grass"] <= 0.03:
            raise ValueError(f"The sampled throat is still open at {stage}")
    for stage in ("revealed", "revisit"):
        if by_stage[stage]["reveal_at_grass"] < 0.97:
            raise ValueError(f"The sampled throat did not reveal at {stage}")
    start_frame = by_stage["east_far"]["frame"]
    frames = {stage: row["frame"] - start_frame for stage, row in by_stage.items()}
    if not 0 < frames["end"] / 60 < 20:
        raise ValueError("Route must last less than 20 seconds")
    script = HEADER + "".join(
        f"Dialogue: 0,{stamp(frames[start])},{stamp(frames[end])},Grass,,0,0,0,,{text}\n"
        for start, end, text in CAPTIONS
    )
    output.parent.mkdir(exist_ok=True, parents=True)
    # A neutral temp cwd keeps spaces or punctuation in user-selected paths safe for libass.
    with tempfile.TemporaryDirectory() as tmp:
        Path(tmp, "route.ass").write_text(script, encoding="utf-8")
        subprocess.run(
            ["ffmpeg", "-v", "error", "-y", "-ss", f"{start_frame/60:.8f}", "-i", str(movie.resolve()),
             "-t", f"{frames['end']/60:.8f}", "-vf", "ass=route.ass", "-threads", "2",
             "-c:v", "libx264", "-preset", "veryfast", "-crf", "22", "-pix_fmt", "yuv420p",
             "-c:a", "aac", "-b:a", "96k", "-movflags", "+faststart", str(output.resolve())],
            cwd=tmp, check=True)
    for stage in ("west_far", "east_far", "clue", "revealed", "restored", "revisit"):
        extract_frame(movie, by_stage[stage]["frame"], output.parent / f"{stage}.png")
    comparison(output.parent)
    (output.parent / "first-visit-frames.json").write_text(
        json.dumps({"fps": 60, "first_video_frame": start_frame, "stages": rows},
                   indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    if output.stat().st_size >= 3_000_000:
        raise ValueError("Route movie exceeds the 3 MB delivery limit")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("movie", type=Path)
    parser.add_argument("log", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    export(args.movie, args.log, args.output)
