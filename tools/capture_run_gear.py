#!/usr/bin/env python3
"""Record a continuous real-input fixed-development inventory/equipment route.

Use an exclusive engine/GPU slot. All failures and raw recordings remain in a
new build directory. --development permits dirty sources for timing diagnosis;
only a clean --source-commit capture is suitable for final delivery.
"""
from pathlib import Path
import argparse
import contextlib
import hashlib
import json
import os
import re
import subprocess
import sys
import time

from run_tests import run_engine
from run_underworld_home_tests import Tee

ROOT = Path(__file__).resolve().parents[1]
DRIVER = "tests/run_gear_movie.gd"
FOLDERS = ("scripts", "scenes", "resources", "assets", "config", "shaders", "addons", "tools", "tests", "game", "experiments")


def sha(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def inventory():
    paths = [ROOT / "project.godot", ROOT / "export_presets.cfg"]
    for folder in FOLDERS:
        paths.extend(p for p in (ROOT / folder).rglob("*") if p.is_file()
                     and "__pycache__" not in p.parts and p.suffix != ".pyc")
    return {p.relative_to(ROOT).as_posix(): sha(p) for p in sorted(set(paths))}


def git(*arguments):
    return subprocess.check_output(["git", *arguments], cwd=ROOT, text=True).strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True)
    parser.add_argument("--source-commit", default="HEAD")
    parser.add_argument("--display", default=":99")
    parser.add_argument("--development", action="store_true")
    parser.add_argument("--plan", action="store_true")
    args = parser.parse_args()
    target = Path(args.output).resolve()
    if not target.is_relative_to(ROOT / "build") or target.exists():
        raise RuntimeError("Use a NEW directory beneath build; prior captures must be retained")
    commit = git("rev-parse", args.source_commit + "^{commit}")
    selectors = ["project.godot", "export_presets.cfg", *FOLDERS]
    dirty = git("diff", "--name-only", commit, "--", *selectors).splitlines()
    untracked = git("ls-files", "--others", "--exclude-standard", "--", *selectors).splitlines()
    if not args.development and (dirty or untracked):
        raise RuntimeError("Final capture needs committed frozen runtime/producer; dirty: " + ", ".join(dirty + untracked))
    trace_path = "res://" + (target / "trace.json").relative_to(ROOT).as_posix()
    command = ["--path", ".", "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy",
               "--resolution", "1280x720", "--write-movie", str(target / "raw.avi"),
               "--fixed-fps", "60", "--script", DRIVER, "--", "--trace=" + trace_path]
    if args.plan:
        print(json.dumps({"source_commit": commit, "argv": command, "development": args.development,
                          "scope": "Plan only. Needs an exclusive engine/GPU slot."}, indent=2))
        return
    target.mkdir(parents=True)
    os.environ["DISPLAY"] = args.display
    os.environ["LIBGL_ALWAYS_SOFTWARE"] = "1"
    os.environ.setdefault("LP_NUM_THREADS", "1")
    before = inventory()
    report = {"schema": "run-gear-native-capture-v1", "source_commit": commit,
              "head": git("rev-parse", "HEAD"), "development": args.development,
              "dirty_paths": dirty + untracked, "argv": ["bash", "tools/godot.sh", *command],
              "source_before": before, "status": "failed", "engine_exit_code": None,
              "source_stable": False, "scope": "Natural fixed development three-room route, production transaction/equipment UI, real input. No before comparison for the new feature. Not a natural formal-region route, real-device performance, player or listening acceptance.",
              "audio_policy": "Original Godot game audio captured via Dummy driver at 48k stereo; listening and hardware sound remain unverified."}
    started = time.monotonic()
    try:
        with (target / "capture.log").open("w") as log, contextlib.redirect_stdout(Tee(sys.stdout, log)):
            output = run_engine(command, 300)
        report["engine_exit_code"] = 0
        if re.search(r"SCRIPT ERROR:|SHADER ERROR:|ERROR:", output):
            raise RuntimeError("Actual movie emitted an engine error")
        matches = re.findall(r"^GEAR MOVIE: ([1-9]\d*) frames, ([1-9]\d*) assertions, 0 failures$", output, re.M)
        if len(matches) != 1:
            raise RuntimeError("Movie did not produce exact successful completion")
        trace = json.loads((target / "trace.json").read_text())
        frames, checks = map(int, matches[0])
        if trace["failures"] or trace["checks"] != checks or len(trace["frames"]) != frames:
            raise RuntimeError("Native completion and actual trace disagree")
        if not any(e["kind"] == "key" and e["key"] == "D" and e["pressed"] for e in trace["input_events"]):
            raise RuntimeError("No real D movement input was recorded")
        if not any(e["kind"] == "key" and e["key"] == "Space" and e["pressed"] for e in trace["input_events"]):
            raise RuntimeError("No real jump input was recorded")
        if len(trace["checkpoints"]) != 8:
            raise RuntimeError("Continuous acquisition/equip/unequip/upgrade phase set is incomplete")
        if inventory() != before:
            raise RuntimeError("Source changed during continuous capture; this run remains rejected")
        with (target / "encode.log").open("w") as log:
            subprocess.run(["ffmpeg", "-y", "-i", str(target / "raw.avi"),
                            "-c:v", "libx264", "-crf", "20", "-pix_fmt", "yuv420p",
                            "-c:a", "aac", "-ar", "48000", "-ac", "2", "-movflags", "+faststart",
                            str(target / "movie.mp4")], stdout=subprocess.DEVNULL, stderr=log,
                           check=True, timeout=150)
        media = json.loads(subprocess.check_output(["ffprobe", "-v", "error", "-show_streams",
                                                    "-show_format", "-of", "json", str(target / "movie.mp4")], timeout=30))
        video = next(s for s in media["streams"] if s["codec_type"] == "video")
        audio = [s for s in media["streams"] if s["codec_type"] == "audio"]
        if video["avg_frame_rate"] != "60/1" or (video["width"], video["height"]) != (1280, 720):
            raise RuntimeError("Movie is not actual normal60fps 1280x720")
        if len(audio) != 1 or audio[0]["sample_rate"] != "48000" or audio[0]["channels"] != 2:
            raise RuntimeError("Original game audio stereo48k stream is absent")
        images = []
        # Decode after input has finished; no synchronous PNG I/O disturbs TTL.
        for index, phase in enumerate(trace["checkpoints"]):
            if index < 4:
                continue
            frame = max(0, int(phase["drawn_frame"]) + 45)
            image = target / ("phase_%02d.png" % index)
            subprocess.run(["ffmpeg", "-y", "-i", str(target / "movie.mp4"),
                            "-vf", f"select=eq(n\\,{frame})", "-frames:v", "1", str(image)],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True, timeout=30)
            images.append({"path": image.name, "sha256": sha(image), "movie_frame": frame,
                           "phase": phase["phase"], "mapping": "post-draw engine frame +45; explanatory nearby rendered frame"})
        report.update(status="development_captured" if args.development else "captured", frames=frames,
                      assertions=checks, media=media, images=images, source_stable=inventory() == before,
                      artifacts={p.name: sha(p) for p in target.iterdir() if p.is_file()})
        if not report["source_stable"]:
            raise RuntimeError("Source drift after media validation")
        print("PASS: continuous real-input gear movie with clean teardown and stable source")
    except Exception as error:
        report["status"] = "failed"
        report["error"] = type(error).__name__ + ": " + str(error)
        raise
    finally:
        report["wall_seconds"] = time.monotonic() - started
        report["source_after"] = inventory()
        report["source_stable"] = before == report["source_after"]
        (target / "receipt.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        print("Gear movie failed: " + str(error), file=sys.stderr)
        sys.exit(1)
