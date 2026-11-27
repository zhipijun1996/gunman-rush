"""Keep the original movie clock and audio; remove only setup and shutdown frames."""
import argparse
import json
import re
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("room", choices=["P01", "P02", "P03"])
parser.add_argument("movie", type=Path)
parser.add_argument("log", type=Path)
parser.add_argument("folder", type=Path)
args = parser.parse_args()
text = args.log.read_text()
if f"V29_PLAY {args.room} failures=0" not in text or "Done recording movie" not in text:
    parser.error("The room route or recording did not finish")
marks = {name: int(frame) for name, frame in re.findall(r"^V29_FRAME (\w+) (\d+) ", text, re.M)}
start_name, cover_name, end_name = {
    "P01": ("wake", "loft", "chest"),
    "P02": ("field", "bell", "grass"),
    "P03": ("ravine", "turn", "old_road"),
}[args.room]
start, cover, end = [marks[key] for key in (start_name, cover_name, end_name)]
raw = subprocess.check_output(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
                               "stream=r_frame_rate,nb_frames", "-of", "json", str(args.movie)])
stream = json.loads(raw)["streams"][0]
num, denom = map(int, stream["r_frame_rate"].split("/"))
fps = num / denom
end = min(int(stream["nb_frames"]), end + round(fps * .60))
if not 0 <= start < cover < end:
    parser.error(f"Unexpected frame order: {start}, {cover}, {end}")
# trim rather than seek in the player. Both streams have the same source timebase.
base = ["ffmpeg", "-nostdin", "-v", "error", "-y", "-i", str(args.movie)]
# Limit bandwidth in the longer vertical-climb review for the mobile player.
rate_control = ["-crf", "24"]
if args.room == "P03":
    rate_control += ["-maxrate", "1550k", "-bufsize", "1800k"]
subprocess.run(base + ["-vf", f"trim=start_frame={start}:end_frame={end},setpts=PTS-STARTPTS",
                       "-af", f"atrim=start={start/fps}:end={end/fps},asetpts=PTS-STARTPTS",
                       "-threads", "2", "-c:v", "libx264", *rate_control, "-preset", "veryfast",
                       "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "96k", "-movflags", "+faststart",
                       str(args.folder / f"{args.room}-play.mp4")], check=True)
subprocess.run(base + ["-vf", f"select=eq(n\\,{cover})", "-frames:v", "1", "-threads", "1",
                       "-q:v", "2", str(args.folder / f"{args.room}-cover.jpg")], check=True)
print(f"{args.room}: recorded frames {start}..{end}, {(end-start)/fps:.2f}s at {fps:g} frames/s")
