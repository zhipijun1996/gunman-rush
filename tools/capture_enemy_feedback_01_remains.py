#!/usr/bin/env python3
"""Record accepted death and a 3.5-second corpse hold in a named rendering chain."""
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


def gameplay_projection(trace):
    fields = ("frame", "case", "local_frame", "paused", "player_position", "player_velocity", "enemy_position", "enemy_velocity", "HP", "state")
    return [{key: row[key] for key in fields} for row in trace["frames"]]


def event_projection(trace):
    # Object IDs vary between engine processes. Retain original IDs in raw
    # traces; compare actual timing and applied HP, not generated process IDs.
    return [{"definition": case["definition"], "events": [{key: event[key] for key in ("frame", "amount", "HP", "epoch", "terminal")} for event in case["events"]],
             "inputs": case["inputs"], "shots": case["shots"], "deaths": case["deaths"]} for case in trace["cases"]]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--variant", choices=("before", "after"), required=True,
                        help="Label only. Run unchanged driver against the intended source externally.")
    parser.add_argument("--seed", default="enemy-feedback-01-remains")
    parser.add_argument("--chain", choices=("underworld", "legacy"), default="underworld")
    parser.add_argument("--expect-remains", action="store_true",
                        help="Require a visible, settled, stationary final 3.5s per case; validation only.")
    parser.add_argument("--compare-trace", type=Path)
    parser.add_argument("--expect-disappear", action="store_true", help="Require an accepted death visual, then a fully invisible final tail (v5 user direction).")
    args = parser.parse_args()
    folder = args.output.resolve()
    folder.mkdir(parents=True, exist_ok=False)
    source = harness.git_metadata()
    report = {"task": "ENEMY-FEEDBACK-01", "version": "v8-authored-frames", "variant": args.variant, "seed": args.seed, "chain": args.chain,
              "status": "running", "source": source, "driver_sha256": digest(ROOT / "tools/enemy_feedback_01_remains_capture.gd"),
              "scope": "Two explicit spawn fixtures in the named rendering chain with actual AI, nonlethal/lethal shots and a long corpse hold; no campaign/device claim.",
              "conditions": {"resolution": [1280, 720], "fps": 60, "playback_speed": 1,
                             "camera": {"center": [575, 440], "zoom": 2.5}, "case_frames": 780, "total_trace_frames": 1560,
                             "definitions": ["resources/enemies/plains_charger.tres", "resources/enemies/plains_diver.tres"],
                             "player_spawn": [480, 482], "enemy_spawn": [[640, 484], [640, 430]], "floor_top": 500,
                             "shots_at_case_frames": [50, 110, 170, 230], "pause_at": [70, 85], "stable_visible_tail_frames": 210,
                             "renderer": "gl_compatibility/software GPU", "input": "real Router aim/release; no HP, movement or feedback injection"},
              "expect_remains": args.expect_remains, "expect_disappear": args.expect_disappear, "user_acceptance": "unverified", "device_acceptance": "unverified"}
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
                   "--write-movie", str(avi), "--fixed-fps", "60", "--script", "tools/enemy_feedback_01_remains_capture.gd",
                   "--", "--variant=" + args.variant, "--seed=" + args.seed, "--trace=" + str(trace_path), "--chain=" + args.chain]
        if args.expect_remains:
            command.append("--expect-remains")
        if args.expect_disappear:
            command.append("--expect-disappear")
        report["command"] = command
        result = harness.run_check({"argv": command, "timeout_seconds": 300,
                                    "success_pattern": r"^ENEMY REMAINS CAPTURE: 1560 frames; two cases; 6 projectile HP commits; 2 deaths$"},
                                   folder / (args.variant + ".log"), ROOT, env)
        report["execution"] = result
        if result["status"] != "passed":
            raise RuntimeError("Actual Godot recording failed: " + result["status"])
        trace = json.loads(trace_path.read_text())
        if trace["failures"] or len(trace["frames"]) != 1560 or len(trace["cases"]) != 2:
            raise RuntimeError("Incomplete actor cases or frame trace")
        for case in trace["cases"]:
            if len(case["events"]) != 3 or case["deaths"] != 1 or [event["HP"] for event in case["events"]] != [2, 1, 0]:
                raise RuntimeError("Missing actual nonlethal/lethal projectile commits")
            observation_frames = (case["case"] + 1) * 780 - case["events"][-1]["frame"]
            if observation_frames <= 180:
                raise RuntimeError("Less than three seconds of continuous post-death observation")
            case["post_death_observation_frames"] = observation_frames
            if args.expect_remains and case["stable_visible_tail_frames"] != 210:
                raise RuntimeError("No visible settled corpse held stationary for the final 3.5 seconds")
            if args.expect_disappear and (case.get("invisible_tail_frames") != 210 or not case.get("accepted_death_visual_seen")):
                raise RuntimeError("No accepted death visual followed by a fully invisible final 3.5 seconds")
        report["case_observations"] = [{key: case[key] for key in ("definition", "post_death_observation_frames", "stable_visible_tail_frames", "tail_observation")} for case in trace["cases"]]
        subprocess.run(["ffmpeg", "-y", "-i", str(avi), "-c:v", "libx264", "-crf", "20", "-pix_fmt", "yuv420p", "-c:a", "aac", str(movie)],
                       check=True, stdout=subprocess.DEVNULL, stderr=(folder / "encode.log").open("wb"), timeout=90)
        media = json.loads(subprocess.check_output(["ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(movie)], timeout=30))
        video = next(stream for stream in media["streams"] if stream["codec_type"] == "video")
        audio = next(stream for stream in media["streams"] if stream["codec_type"] == "audio")
        if not (video["avg_frame_rate"] == "60/1" and video["width"] == 1280 and video["height"] == 720
                and audio["sample_rate"] == "48000" and audio["channels"] == 2 and 26 <= float(media["format"]["duration"]) <= 28):
            raise RuntimeError("Continuous normal-speed 26-second pixels/stereo audio missing")
        report.update(mp4_sha256=digest(movie), avi_sha256=digest(avi), trace_sha256=digest(trace_path), media=media)
        if args.compare_trace:
            baseline = json.loads(args.compare_trace.read_text())
            report["same_gameplay_frames"] = gameplay_projection(baseline) == gameplay_projection(trace)
            report["same_actual_inputs_and_events"] = event_projection(baseline) == event_projection(trace)
            comparable = report["same_gameplay_frames"] and report["same_actual_inputs_and_events"]
            report["comparison_differences"] = [] if comparable else ["Actual gameplay frames or accepted inputs/events differ. Do not claim an identical-condition causal visual comparison until investigated."]
            report["compared_trace_sha256"] = digest(args.compare_trace)
        report["source_stable"] = source == harness.git_metadata()
        if not report["source_stable"]:
            raise RuntimeError("Source changed during recording; preserve failed evidence")
        report["status"] = "passed"
        print("ENEMY REMAINS MOVIE: real 26-second engine movie, raw stereo audio, 6 HP commits and long death hold saved")
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
