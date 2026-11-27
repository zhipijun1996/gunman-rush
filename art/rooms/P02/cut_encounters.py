"""Cut the two chronological combat moments from one normal-controller P02 run.

Record at 60 fps with Godot's --write-movie and
--script res://tests/plains_p02_terrace.gd -- --encounters.
"""
import argparse
import re
import subprocess
from pathlib import Path


def export(movie: Path, log: Path, output: Path) -> None:
    evidence = log.read_text()
    if "P02 ENCOUNTERS failures=0" not in evidence or "Done recording movie" not in evidence:
        raise ValueError("The recorded encounter route did not finish successfully")
    if re.search(r"^(?:SCRIPT ERROR|ERROR|FAIL )", evidence, re.MULTILINE):
        raise ValueError("The recording contains gameplay errors")
    events = re.findall(r"^ENCOUNTER (\w+) (\d+) P02 ", evidence, re.MULTILINE)
    stages = ["west", "west_clear", "west_loot", "east_approach", "east", "east_clear", "end"]
    if [stage for stage, _ in events] != stages:
        raise ValueError("The recorded fight, pickup, jump or supported landing is missing")
    frames = {stage: int(raw) for stage, raw in events}
    segments = [("west", "west_loot", "西侧草岸　射击"), ("east_approach", "east_clear", "东侧大道　跳越")]
    filters = []
    font = Path(__file__).resolve().parents[3] / "production/assets/ui/demo_ui_01/r2/fonts/fusion-pixel-12px-proportional-zh_hans.otf"
    for i, (begin, end, caption) in enumerate(segments):
        start, stop = frames[begin], frames[end]
        filters.append(
            f"[0:v]trim=start_frame={start}:end_frame={stop},setpts=PTS-STARTPTS,"
            f"drawtext=fontfile='{font}':text='{caption}':fontsize=27:fontcolor=white:"
            f"box=1:boxcolor=black@0.55:boxborderw=8:x=28:y=h-th-28[v{i}]")
        filters.append(f"[0:a]atrim=start={start/60}:end={stop/60},asetpts=PTS-STARTPTS[a{i}]")
    filters.append("[v0][a0][v1][a1]concat=n=2:v=1:a=1[v][a]")
    output.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["ffmpeg", "-v", "error", "-y", "-i", str(movie), "-filter_complex", ";".join(filters),
         "-map", "[v]", "-map", "[a]", "-threads", "2", "-c:v", "libx264", "-crf", "21",
         "-preset", "veryfast", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "96k",
         "-movflags", "+faststart", str(output)], check=True)
    # The cover is an uncaptioned native-camera frame from the actual leap.
    subprocess.run(
        ["ffmpeg", "-v", "error", "-y", "-ss", f"{(frames['east']+12)/60:.8f}", "-i", str(movie),
         "-frames:v", "1", "-threads", "1", "-q:v", "2", str(output.with_name(output.stem+"-cover.jpg"))],
        check=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("movie", type=Path)
    parser.add_argument("log", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    export(args.movie, args.log, args.output)
