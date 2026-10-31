#!/usr/bin/env python3
"""Record the actual formal Home/Plains pause inventory consumer.

The visible cache-position fixture is explicitly classified; native UI actions
still enter through the production reward/equipment services. This producer
uses the existing strict engine runner and original source-inventory helper.
"""
from pathlib import Path
import argparse
import contextlib
import json
import os
import re
import subprocess
import sys
import time

from capture_run_gear import ROOT, FOLDERS, git, inventory, sha
from run_tests import run_engine
from run_underworld_home_tests import Tee

DRIVER = "tests/run_gear_formal_movie.gd"
SCOPE = (
    "Actual native title -> playable Home -> natural Home departure -> ordinary "
    "formal Plains -> native pause backpack/pages/icon selection/equip/unequip. "
    "Exactly one visible cache-position fixture approaches the original formal "
    "cache; not a natural cache platforming route or Boss completion. No coins, "
    "items, health, enemy state or reward settlement are injected. No matched "
    "before movie; software-GL capture does not establish device/player acceptance."
)


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
        raise RuntimeError("Use a NEW directory beneath build; retain prior captures")
    commit = git("rev-parse", args.source_commit + "^{commit}")
    selectors = ["project.godot", "export_presets.cfg", *FOLDERS]
    dirty = git("diff", "--name-only", commit, "--", *selectors).splitlines()
    untracked = git("ls-files", "--others", "--exclude-standard", "--", *selectors).splitlines()
    if not args.development and (dirty or untracked):
        raise RuntimeError("Final capture requires committed frozen sources: " + ", ".join(dirty + untracked))
    trace = "res://" + (target / "trace.json").relative_to(ROOT).as_posix()
    argv = ["--path", ".", "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy",
            "--resolution", "1280x720", "--write-movie", str(target / "raw.avi"),
            "--fixed-fps", "60", "--script", DRIVER, "--", "--trace=" + trace]
    if args.plan:
        print(json.dumps({"source_commit":commit, "argv":argv, "scope":SCOPE,
                          "development":args.development, "executed":False}, indent=2))
        return
    target.mkdir(parents=True)
    os.environ["DISPLAY"] = args.display
    os.environ["LIBGL_ALWAYS_SOFTWARE"] = "1"
    os.environ.setdefault("LP_NUM_THREADS", "1")
    before = inventory()
    report = {"schema":"run-gear-formal-capture-v1", "source_commit":commit,
              "head":git("rev-parse", "HEAD"), "development":args.development,
              "dirty_paths":dirty + untracked, "argv":["bash", "tools/godot.sh", *argv],
              "source_before":before, "status":"failed", "engine_exit_code":None,
              "source_stable":False, "scope":SCOPE,
              "audio_policy":"Original Godot audio via Dummy backend, stereo48k; listening and hardware sound unverified."}
    started = time.monotonic()
    try:
        with (target / "capture.log").open("w") as log, contextlib.redirect_stdout(Tee(sys.stdout, log)):
            output = run_engine(argv, 300)
        report["engine_exit_code"] = 0
        if re.search(r"SCRIPT ERROR:|SHADER ERROR:|ERROR:", output):
            raise RuntimeError("Actual formal recording emitted an engine error")
        matches = re.findall(r"^FORMAL GEAR MOVIE: ([1-9]\d*) frames, ([1-9]\d*) assertions, 0 failures$", output, re.M)
        if len(matches) != 1:
            raise RuntimeError("Formal recording lacks exact successful completion")
        data = json.loads((target / "trace.json").read_text())
        frames, checks = map(int, matches[0])
        if data["failures"] or data["checks"] != checks or len(data["frames"]) != frames:
            raise RuntimeError("Actual trace and native completion disagree")
        fixture = [e for e in data["input_events"] if e["kind"] == "explicit_cache_position_fixture"]
        if len(fixture) != 1 or not any("fixture" in p["phase"] for p in data["checkpoints"]):
            raise RuntimeError("Cache-position fixture must be exactly one and visible")
        if not any(e["kind"] == "key" and e["key"] == "D" and e["pressed"] for e in data["input_events"]):
            raise RuntimeError("No real Home locomotion input was recorded")
        if not any(f.get("formal_region") for f in data["frames"]):
            raise RuntimeError("The actual recording never entered the formal game")
        if len(data["checkpoints"]) != 10:
            raise RuntimeError("Actual formal entry/pause/pages/acquisition/selection/equip/unequip phases are incomplete")
        if inventory() != before:
            raise RuntimeError("Source changed during capture; retain this rejected attempt")
        with (target / "encode.log").open("w") as log:
            subprocess.run(["ffmpeg", "-y", "-i", str(target / "raw.avi"),
                            "-c:v", "libx264", "-crf", "20", "-pix_fmt", "yuv420p",
                            "-c:a", "aac", "-ar", "48000", "-ac", "2", "-movflags", "+faststart",
                            str(target / "movie.mp4")], stdout=subprocess.DEVNULL, stderr=log,
                           check=True, timeout=150)
        media = json.loads(subprocess.check_output(["ffprobe", "-v", "error", "-show_streams", "-show_format",
                                                    "-of", "json", str(target / "movie.mp4")], timeout=30))
        video = next(s for s in media["streams"] if s["codec_type"] == "video")
        audio = [s for s in media["streams"] if s["codec_type"] == "audio"]
        if video["avg_frame_rate"] != "60/1" or (video["width"], video["height"]) != (1280, 720):
            raise RuntimeError("Recording is not actual normal60fps 1280x720")
        if len(audio) != 1 or audio[0]["sample_rate"] != "48000" or audio[0]["channels"] != 2:
            raise RuntimeError("Original stereo48k game audio stream is absent")
        images = []
        for index in [0, 1, 2, 3, 4, 7, 8, 9]:
            phase = data["checkpoints"][index]
            media_frame = max(0, int(phase["drawn_frame"]) + 30)
            image = target / ("phase_%02d.png" % index)
            subprocess.run(["ffmpeg", "-y", "-i", str(target / "movie.mp4"),
                            "-vf", f"select=eq(n\\,{media_frame})", "-frames:v", "1", str(image)],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True, timeout=30)
            if not image.is_file(): raise RuntimeError("Actual movie phase image is absent")
            images.append({"path":image.name, "sha256":sha(image), "movie_frame":media_frame,
                           "phase":phase["phase"], "mapping":"Actual post-draw engine frame +30"})
        report.update(status="development_captured" if args.development else "captured", frames=frames,
                      assertions=checks, media=media, images=images, source_stable=inventory() == before,
                      artifacts={p.name:sha(p) for p in target.iterdir() if p.is_file()})
        if not report["source_stable"]: raise RuntimeError("Source drift after media validation")
        print("PASS: actual formal game backpack movie, explicit cache fixture, strict clean exit and stable sources")
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
        print("Formal gear movie failed: " + str(error), file=sys.stderr)
        sys.exit(1)
