"""Subtitle the uninterrupted, real-time first visit recorded by capture_grass_route.gd."""
import argparse
import re
import subprocess
import tempfile
from pathlib import Path

STAGES = ["brink", "lane", "reveal", "below", "jump", "bank", "clear", "end"]
CAPTIONS = [
    ("brink", "lane", "从上层田沿落到草坡"),
    ("lane", "reveal", "沿田埂往回走，靠近草丛"),
    ("reveal", "below", "草叶退开，从露出的竖口落下"),
    ("below", "jump", "落到 P16 的藏物窝"),
    ("jump", "clear", "在井底朝上跳，沿近岸的凹阶返回"),
    ("clear", "end", "回到 P02 的草坡"),
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


def export(movie, log, output):
    source = log.read_text()
    rows = re.findall(r"^GRASS_ROUTE (\w+) (\d+) (P\d+) ", source, re.MULTILINE)
    if [key for key, _, _ in rows] != STAGES or "Done recording movie" not in source:
        raise ValueError("Missing or out-of-order gameplay events in the recorded route")
    if [room for _, _, room in rows] != ["P02", "P02", "P02", "P16", "P16", "P02", "P02", "P02"]:
        raise ValueError("The recording did not complete both real room handoffs")
    frames = {key: int(frame) - int(rows[0][1]) for key, frame, _ in rows}
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
            ["ffmpeg", "-v", "error", "-y", "-ss", f"{int(rows[0][1])/60:.8f}", "-i", str(movie.resolve()),
             "-t", f"{frames['end']/60:.8f}", "-vf", "ass=route.ass", "-threads", "2",
             "-c:v", "libx264", "-preset", "veryfast", "-crf", "22", "-pix_fmt", "yuv420p",
             "-c:a", "aac", "-b:a", "96k", "-movflags", "+faststart", str(output.resolve())],
            cwd=tmp, check=True)
    if output.stat().st_size >= 3_000_000:
        raise ValueError("Route movie exceeds the 3 MB delivery limit")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("movie", type=Path)
    parser.add_argument("log", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    export(args.movie, args.log, args.output)
