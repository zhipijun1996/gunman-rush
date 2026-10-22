#!/usr/bin/env python3
"""Capture the frozen PLAYER-PRESENTATION-01 formal consumer trace/movie."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import selectors
import shutil
import subprocess
import time

import harness
from capture_underworld_revision2_experience import inventory

ROOT = Path(__file__).resolve().parents[1]
DRIVER = "tests/player_presentation_01_trace.gd"


def source_index():
    result = inventory()
    for path in (DRIVER, "tools/player_presentation_01_trace.py"):
        result[path] = hashlib.sha256((ROOT / path).read_bytes()).hexdigest()
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--movie", action="store_true")
    args = parser.parse_args()
    folder = args.output.resolve()
    if not folder.is_relative_to(ROOT / "build"):
        raise ValueError("Use a new build directory within this worktree")
    folder.mkdir(parents=True, exist_ok=False)
    before = source_index()
    env = os.environ.copy()
    display = None
    report = {"status": "running", "source_commit": subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "source_before": before, "movie_requested": args.movie,
        "scope": "Formal App accepted-input sample with explicitly submitted policy lifecycle damage; not natural combat, user or device acceptance"}
    start = time.monotonic()
    try:
        if args.movie and not env.get("DISPLAY"):
            binary = shutil.which("Xvfb") or str(Path(env["GUNMAN_TOOLCHAIN_ROOT"]) / "xvfb/usr/bin/Xvfb")
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
        command = ["bash", "tools/godot.sh", "--path", ".", "--fixed-fps", "60", "--audio-driver", "Dummy"]
        command += ["--rendering-method", "gl_compatibility", "--write-movie", str(folder / "raw.avi")] if args.movie else ["--headless"]
        command += ["--script", DRIVER, "--", "--trace=" + str(folder / "trace.json")]
        if args.movie:
            command.append("--capture")
        report["command"] = command
        report["execution"] = harness.run_check({"argv": command, "timeout_seconds": 180,
            "success_pattern": r"^PLAYER PRESENTATION 01: frames=720 shots=2 damage=3 failures=0$"},
            folder / "native.log", ROOT, env)
        if report["execution"]["status"] != "passed":
            raise RuntimeError("Native sample failed; preserve its original log")
        trace = json.loads((folder / "trace.json").read_text())
        if trace["failures"] or len(trace["frames"]) != 720:
            raise RuntimeError("Incomplete trace")
        if args.movie:
            with (folder / "encode.log").open("wb") as log:
                subprocess.run(["ffmpeg", "-n", "-i", str(folder / "raw.avi"), "-c:v", "libx264", "-crf", "20", "-pix_fmt", "yuv420p", "-c:a", "aac", str(folder / "movie.mp4")],
                               stdout=log, stderr=subprocess.STDOUT, check=True, timeout=90)
            media = json.loads(subprocess.check_output(["ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(folder / "movie.mp4")], timeout=30))
            video = next(s for s in media["streams"] if s["codec_type"] == "video")
            audio = next(s for s in media["streams"] if s["codec_type"] == "audio")
            if (video["width"], video["height"], video["avg_frame_rate"], audio["sample_rate"]) != (1280, 720, "60/1", "48000"):
                raise RuntimeError("Wrong real movie format")
            subprocess.run(["ffmpeg", "-v", "error", "-i", str(folder / "movie.mp4"), "-f", "null", "-"], check=True, timeout=60)
            report["media"] = media
        report["status"] = "passed"
    except BaseException as error:
        report.update(status="failed", error=str(error))
        raise
    finally:
        report["source_after"] = source_index()
        report["source_stable"] = report["source_after"] == before
        if not report["source_stable"]:
            report["status"] = "failed"
        report["seconds"] = time.monotonic() - start
        report["artifacts"] = [{"name": path.name, "bytes": path.stat().st_size,
            "sha256": hashlib.file_digest(path.open("rb"), "sha256").hexdigest()}
            for path in folder.iterdir() if path.is_file() and path.suffix in {".json", ".mp4", ".log"}]
        (folder / "report.json").write_text(json.dumps(report, indent=2) + "\n")
        if display:
            display.terminate()
            display.wait(timeout=5)
    if not report["source_stable"]:
        raise RuntimeError("Source changed during sample")
    print("PASS: PLAYER-PRESENTATION-01 actual formal sample")


if __name__ == "__main__":
    main()
