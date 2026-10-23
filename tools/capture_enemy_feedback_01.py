#!/usr/bin/env python3
"""Capture four real EnemyFeedback01 fixtures; run unchanged on baseline/candidate."""
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
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--variant", choices=("before", "after"), required=True,
                        help="Label only. Baseline/candidate source selection is external and recorded.")
    parser.add_argument("--seed", default="enemy-feedback-01")
    parser.add_argument("--compare-trace", type=Path)
    args = parser.parse_args()
    folder = args.output.resolve()
    folder.mkdir(parents=True, exist_ok=False)
    source = harness.git_metadata()
    report = {"task": "ENEMY-FEEDBACK-01", "variant": args.variant, "seed": args.seed,
              "status": "running", "source": source,
              "driver_sha256": digest(ROOT / "tools/enemy_feedback_01_capture.gd"),
              "scope": "Four explicit spawn fixtures, not a campaign playthrough; original AI and accepted projectile damage.",
              "conditions": {"resolution": [1280, 720], "fps": 60, "camera": {"center": [600, 420], "zoom": 2},
                             "case_frames": 300, "shots_at_case_frames": [50, 110, 170, 230], "pause_at": [70, 85],
                             "renderer": "gl_compatibility/software GPU", "input": "real Router aim/release; no HP/feedback calls"},
              "user_acceptance": "unverified", "device_acceptance": "unverified"}
    env = os.environ.copy()
    env["LIBGL_ALWAYS_SOFTWARE"] = "1"
    display = None
    started = time.monotonic()
    try:
        if not env.get("DISPLAY"):
            candidate = Path(os.environ.get("GUNMAN_TOOLCHAIN_ROOT", str(ROOT.parent / "toolchains"))) / "xvfb/usr/bin/Xvfb"
            binary = shutil.which("Xvfb") or (str(candidate) if candidate.is_file() else None)
            if not binary:
                raise RuntimeError("Xvfb required for actual Godot pixels")
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
        avi = folder / (args.variant + ".avi")
        movie = folder / (args.variant + ".mp4")
        trace_path = folder / (args.variant + ".json")
        command = ["bash", "tools/godot.sh", "--path", ".", "--rendering-method", "gl_compatibility",
                   "--write-movie", str(avi), "--fixed-fps", "60", "--script", "tools/enemy_feedback_01_capture.gd",
                   "--", "--variant=" + args.variant, "--seed=" + args.seed, "--trace=" + str(trace_path)]
        report["command"] = command
        result = harness.run_check({"argv": command, "timeout_seconds": 240,
                                    "success_pattern": r"^ENEMY FEEDBACK CAPTURE: 1200 frames; four cases; 12 projectile HP commits; 4 deaths$"},
                                   folder / (args.variant + ".log"), ROOT, env)
        report["execution"] = result
        if result["status"] != "passed":
            raise RuntimeError("Actual Godot recording failed: " + result["status"])
        trace = json.loads(trace_path.read_text())
        if trace["failures"] or len(trace["frames"]) != 1200 or len(trace["cases"]) != 4:
            raise RuntimeError("Incomplete actor cases or frame trace")
        for case in trace["cases"]:
            if len(case["events"]) != 3 or case["deaths"] != 1 or [e["HP"] for e in case["events"]] != [2, 1, 0]:
                raise RuntimeError("Missing real nonlethal/lethal projectile commits")
        subprocess.run(["ffmpeg", "-y", "-i", str(avi), "-c:v", "libx264", "-crf", "20", "-pix_fmt", "yuv420p", "-c:a", "aac", str(movie)],
                       check=True, stdout=subprocess.DEVNULL, stderr=(folder / "encode.log").open("wb"), timeout=90)
        media = json.loads(subprocess.check_output(["ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(movie)], timeout=30))
        video = next(s for s in media["streams"] if s["codec_type"] == "video")
        audio = next(s for s in media["streams"] if s["codec_type"] == "audio")
        if not (video["avg_frame_rate"] == "60/1" and video["width"] == 1280 and video["height"] == 720
                and audio["sample_rate"] == "48000" and audio["channels"] == 2 and 20 <= float(media["format"]["duration"]) <= 22):
            raise RuntimeError("Continuous 20-second pixels/stereo audio missing")
        report.update(mp4_sha256=digest(movie), avi_sha256=digest(avi), trace_sha256=digest(trace_path), media=media)
        if args.compare_trace:
            baseline = json.loads(args.compare_trace.read_text())
            # Original event IDs contain per-process object IDs; compare actual
            # gameplay state and event timing, retaining both raw originals.
            fields = ("frame", "case", "local_frame", "paused", "player_position", "player_velocity", "enemy_position", "enemy_velocity", "HP", "state")
            project = lambda value: [{k: row[k] for k in fields} for row in value["frames"]]
            report["same_gameplay_frames"] = project(baseline) == project(trace)
            report["comparison_differences"] = [] if report["same_gameplay_frames"] else ["Actual gameplay frames differ; do not claim identical-input causal improvement until investigated."]
            report["compared_trace_sha256"] = digest(args.compare_trace)
        report["source_stable"] = source == harness.git_metadata()
        if not report["source_stable"]:
            raise RuntimeError("Source changed during recording; preserve failed evidence")
        report["status"] = "passed"
        print("ENEMY FEEDBACK MOVIE: real 20-second engine movie, stereo audio, 12 HP commits and provenance saved")
    except BaseException as exc:
        report.update(status="failed", error=str(exc))
        raise
    finally:
        report["seconds"] = time.monotonic() - started
        (folder / "report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
        if display:
            display.terminate()
            try:
                display.wait(timeout=5)
            except subprocess.TimeoutExpired:
                display.kill()
                display.wait()


if __name__ == "__main__":
    main()
