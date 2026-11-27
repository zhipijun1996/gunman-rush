"""Export a room's native touch-control review film and uncaptioned cover.

Record with Godot --write-movie and --script res://tests/plains_intro_rooms.gd
followed by -- --film-p01 or -- --film-p03, then pass its AVI and log below.
"""
import argparse
import re
import subprocess
from pathlib import Path


def export(room: str, movie: Path, log: Path, folder: Path) -> None:
    recording = log.read_text()
    if ("PLAINS INTRO failures=0" not in recording or "Done recording movie" not in recording
            or re.search(r"^(?:ERROR|SCRIPT ERROR|FAIL )", recording, re.MULTILINE)):
        raise ValueError("This gameplay recording did not finish cleanly")
    frames = {stage: int(frame) for stage, frame in
              re.findall(r"^INTRO_FRAME (\w+) (\d+) ", recording, re.MULTILINE)}
    frame_rate = int(re.search(r"recording movie.*?@ (\d+) FPS", recording).group(1))
    def offset(seconds: float) -> int:
        return round(seconds * frame_rate)
    if room == "P01":
        segments = [(frames["p01_start"], frames["p01_end"], None)]
        cover = frames["p01_deck"] - offset(.6)
    elif room == "P02":
        segments = [(frames["p02_grass"], frames["p02_foot"]+offset(.5), None),
                    (frames["p02_launch"], frames["p02_east"], None)]
        cover = frames["p02_bell"] - offset(.55)
    else:
        segments = [(frames["p03_grub"]-offset(.55), frames["p03_bottom"]+offset(.5), None),
                    (frames["p03_turn"]-offset(.55), frames["p03_sentry_clear"]+offset(.5), None),
                    (frames["p03_look"], frames["p03_look_end"], None),
                    (frames["p03_w_start"], frames["p03_w_end"], "持 W 回访")]
        cover = frames["p03_grub"] + offset(.25)
    seconds = sum((end - begin)/frame_rate for begin, end, _ in segments)
    if not 10 <= seconds <= 18:
        raise ValueError(f"Unexpected film duration of {seconds:.3f}s")
    filters = []
    font = Path(__file__).resolve().parents[3] / "production/assets/ui/demo_ui_01/r2/fonts/fusion-pixel-12px-proportional-zh_hans.otf"
    for i, (begin, end, label) in enumerate(segments):
        video = f"[0:v]trim=start_frame={begin}:end_frame={end},setpts=PTS-STARTPTS"
        if label:
            video += (f",drawtext=fontfile='{font}':text='{label}':fontsize=26:fontcolor=white:"
                      "box=1:boxcolor=black@0.55:boxborderw=8:x=(w-tw)/2:y=25")
        filters.append(f"{video}[v{i}]")
        filters.append(f"[0:a]atrim=start={begin/frame_rate}:end={end/frame_rate},asetpts=PTS-STARTPTS[a{i}]")
    chain = "".join(f"[v{i}][a{i}]" for i in range(len(segments)))
    filters.append(f"{chain}concat=n={len(segments)}:v=1:a=1[v][a]")
    folder.mkdir(parents=True, exist_ok=True)
    output = folder / f"{room}-play.mp4"
    # The scrolling native rock faces need a delivery bitrate ceiling. Keep
    # the simpler P01 recording at its original constant-quality settings.
    video_quality = ["-crf", "25"] if room == "P01" else ["-crf", "27", "-maxrate", "1350k", "-bufsize", "1350k"]
    subprocess.run(
        ["ffmpeg", "-v", "error", "-y", "-i", str(movie), "-filter_complex", ";".join(filters),
         "-map", "[v]", "-map", "[a]", "-threads", "2", "-c:v", "libx264", *video_quality,
         "-preset", "veryfast", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "96k",
         "-movflags", "+faststart", str(output)], check=True)
    if output.stat().st_size >= 3_000_000:
        raise ValueError("Review film exceeds its 3 MB limit")
    subprocess.run(
        ["ffmpeg", "-v", "error", "-y", "-ss", f"{cover/frame_rate:.8f}", "-i", str(movie),
         "-frames:v", "1", "-threads", "1", "-q:v", "2", str(folder / f"{room}-cover.jpg")],
        check=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("room", choices=["P01", "P02", "P03"])
    parser.add_argument("movie", type=Path)
    parser.add_argument("log", type=Path)
    parser.add_argument("folder", type=Path)
    arguments = parser.parse_args()
    export(arguments.room, arguments.movie, arguments.log, arguments.folder)
