#!/usr/bin/env python3
"""Record a real Godot UI slice pair, retain audio and honest comparison metadata."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import selectors
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import harness


def digest(path):
    return hashlib.file_digest(path.open("rb"), "sha256").hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--task", default="CLOUD-PRODUCTION-01")
    parser.add_argument("--seed", default="cloud-review-01")
    args = parser.parse_args()
    folder = args.output.resolve()
    folder.mkdir(parents=True, exist_ok=False)
    before = harness.git_metadata()
    report = {"status": "running", "source": before, "task": args.task, "seed": args.seed,
              "scope": "development review banner on/off in real ActionStudio; no gameplay or animation improvement claim",
              "conditions": {"resolution": [1280, 720], "fps": 60, "renderer": "gl_compatibility/software GPU",
                             "entry": "actions", "target": "static training", "persistence": False, "air_focus_disabled": True},
              "baseline": "same source, new banner hidden; not a historical source baseline",
              "captures": [], "user_acceptance": "unverified", "device_acceptance": "unverified"}
    env = os.environ.copy()
    env["LIBGL_ALWAYS_SOFTWARE"] = "1"
    display = None
    started = time.monotonic()
    try:
        if not env.get("DISPLAY"):
            candidate = Path(os.environ.get("GUNMAN_TOOLCHAIN_ROOT", str(ROOT.parent / "toolchains"))) / "xvfb/usr/bin/Xvfb"
            binary = shutil.which("Xvfb") or (str(candidate) if candidate.is_file() else None)
            if not binary:
                raise RuntimeError("Xvfb required for actual engine rendering")
            display = subprocess.Popen([binary, "-displayfd", "1", "-screen", "0", "1280x720x24", "-nolisten", "tcp", "-ac"],
                                       stdout=subprocess.PIPE, stderr=(folder / "display.log").open("wb"))
            with selectors.DefaultSelector() as selector:
                selector.register(display.stdout, selectors.EVENT_READ)
                if not selector.select(30):
                    raise RuntimeError("Xvfb startup timeout")
                number = display.stdout.readline().decode().strip()
            if not number.isdigit():
                raise RuntimeError("Invalid Xvfb display")
            env["DISPLAY"] = ":" + number
        for variant in ("before", "after"):
            avi = folder / (variant + ".avi")
            movie = folder / (variant + ".mp4")
            trace = folder / (variant + ".json")
            command = ["bash", "tools/godot.sh", "--path", ".", "--rendering-method", "gl_compatibility",
                       "--write-movie", str(avi), "--fixed-fps", "60", "--script", "tools/cloud_slice_capture.gd",
                       "--", "--task=" + args.task, "--seed=" + args.seed, "--entry=actions", "--variant=" + variant, "--trace=" + str(trace)]
            result = harness.run_check({"argv": command, "timeout_seconds": 240,
                                        "success_pattern": r"^CLOUD SLICE: 720 frames$"}, folder / (variant + ".log"), ROOT, env)
            report["captures"].append({"variant": variant, "execution": result, "command": command})
            if result["status"] != "passed":
                raise RuntimeError("Godot recording failed: " + variant + " " + result["status"])
            subprocess.run(["ffmpeg", "-y", "-i", str(avi), "-c:v", "libx264", "-crf", "20", "-pix_fmt", "yuv420p", "-c:a", "aac", str(movie)],
                           check=True, stdout=subprocess.DEVNULL, stderr=(folder / (variant + "-encode.log")).open("wb"), timeout=90)
            media = json.loads(subprocess.check_output(["ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(movie)], timeout=30))
            video = next(s for s in media["streams"] if s["codec_type"] == "video")
            audio = next(s for s in media["streams"] if s["codec_type"] == "audio")
            frames = json.loads(trace.read_text())["frames"]
            if not (video["avg_frame_rate"] == "60/1" and audio["sample_rate"] == "48000" and audio["channels"] == 2
                    and len(frames) == 720 and 12 <= float(media["format"]["duration"]) <= 13):
                raise RuntimeError("Missing continuous 12-second movie or real stereo audio")
            if not (max(f["position"][0] for f in frames) - min(f["position"][0] for f in frames) > 20
                    and any(f["velocity"][1] < -20 for f in frames) and any(abs(f["recoil"][0]) > 1 for f in frames)):
                raise RuntimeError("Movie lacks actual accepted movement, jump or shot recoil")
            report["captures"][-1].update(mp4_sha256=digest(movie), avi_sha256=digest(avi), trace_sha256=digest(trace), media=media)
        inputs_before = json.loads((folder / "before.json").read_text())["frames"]
        inputs_after = json.loads((folder / "after.json").read_text())["frames"]
        report["same_gameplay_trace"] = inputs_before == inputs_after
        report["comparison_differences"] = [] if inputs_before == inputs_after else ["Engine run traces differ; do not infer gameplay changes from this UI comparison."]
        # Concatenate actual continuous engine movies; no static-image reconstruction.
        (folder / "pair.txt").write_text("file 'before.mp4'\nfile 'after.mp4'\n")
        subprocess.run(["ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", str(folder / "pair.txt"), "-c", "copy", str(folder / "comparison.mp4")],
                       check=True, stdout=subprocess.DEVNULL, stderr=(folder / "concat.log").open("wb"), timeout=30)
        report["comparison_sha256"] = digest(folder / "comparison.mp4")
        report["source_stable"] = before == harness.git_metadata()
        if not report["source_stable"]:
            raise RuntimeError("Source changed during capture; preserve this failed run")
        report["status"] = "passed"
        print("CLOUD CAPTURE: two real 12-second movies, stereo audio and provenance saved")
    except BaseException as exc:
        report.update(status="failed", error=str(exc))
        raise
    finally:
        report["seconds"] = time.monotonic() - started
        (folder / "report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
        if display:
            display.terminate()
            try: display.wait(timeout=5)
            except subprocess.TimeoutExpired: display.kill(); display.wait()


if __name__ == "__main__":
    main()
