"""Cut real Godot movie captures at the three frame markers emitted by capture_passage.gd."""
import argparse
import json
import re
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

MARKER = re.compile(r"PASSAGE_FRAMES (P\d+) (d\d+) (P\d+) (\d+) (\d+) (\d+) crop_delta=([\d.]+)")


def ffmpeg(*args):
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-threads", "2", "-filter_threads", "1", *map(str, args)], check=True)


def export(raw, out):
    data = []
    document = Path(__file__).resolve().parents[3] / "production/rooms/world/P02.json"
    doors = sorted(json.loads(document.read_text())["exits"])
    for door in doors:
        for direction in ["to-field","from-field"]:
            base = raw / f"{door}-{direction}"
            log = base.with_suffix(".log")
            if not log.exists():
                raise ValueError(f"Missing recording or completed passage in {log}")
            record = MARKER.search(log.read_text())
            if record is None or "Done recording movie" not in log.read_text():
                raise ValueError(f"Missing recording or completed passage in {log}")
            src, edge, dst, started, swapped, finished, jump = record.groups()
            a,b,c = map(int, (started,swapped,finished))
            avi = base.with_suffix(".avi")
            out_name = f"{edge}-{src}-{dst}"
            # Keep one second of approach, the complete real transition, and one
            # second after control returns. No speed change or synthetic frames.
            start,end = a-60,c+60
            ffmpeg("-ss",f"{start/60:.7f}","-i",avi,"-t",f"{(end-start)/60:.7f}",
                   "-c:v","libx264","-crf","19","-preset","veryfast","-pix_fmt","yuv420p",
                   "-c:a","aac","-b:a","96k","-movflags","+faststart",out/f"{out_name}.mp4")
            for label, frame in [("before",a-4),("after",c+3)]:
                ffmpeg("-i",avi,"-vf",f"select=eq(n\\,{frame})","-frames:v","1",out/f"{out_name}-{label}.png")
            spread = Image.new("RGB",(1280,392),"#20292d")
            draw = ImageDraw.Draw(spread)
            for i,(label,room) in enumerate([("before",src),("after",dst)]):
                frame = Image.open(out/f"{out_name}-{label}.png").convert("RGB")
                spread.paste(frame.resize((640,360),Image.Resampling.LANCZOS),(640*i,32))
                draw.text((640*i+12,10),f"{room}    {edge}",fill="white",font=ImageFont.load_default(size=15))
            spread.save(out/f"{out_name}-pair.jpg",quality=91)
            section = re.search(r"PASSAGE_SECTION \S+ \S+ \S+ ([-\d.]+) ([-\d.]+)",log.read_text())
            heights = [float(section.group(1)),float(section.group(2))] if section else []
            data.append({"door":edge,"from":src,"to":dst,"fps":60,"approach":60,"departure":60,
                         "covered_and_landing":c-a,"room_swap_frame_in_cut":b-start,
                         "panorama_crop_change_px":float(jump),"screen_section_y":heights,"file":out_name+".mp4"})
    (out/"frames.json").write_text(json.dumps(data,ensure_ascii=False,indent=2)+"\n")
    if len(data)==2*len(doors):
        listing=out/"concat.txt"
        listing.write_text("".join(f"file '{row['file']}'\n" for row in data))
        ffmpeg("-f","concat","-safe","0","-i",listing,"-c","copy","-movflags","+faststart",out/"all-passages.mp4")
        listing.unlink()
    return data


if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("raw",type=Path)
    parser.add_argument("output",type=Path)
    args=parser.parse_args()
    args.output.mkdir(parents=True,exist_ok=True)
    records=export(args.raw,args.output)
    print(f"Exported {len(records)} directed crossings")
