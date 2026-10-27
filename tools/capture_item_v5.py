#!/usr/bin/env python3
"""Capture the continuous formal V5 native input/transaction demonstration.

An exclusive root engine/GL lease is required. The actual producer shows every
setup fixture on screen and in its trace. No matched before movie exists.
"""
from pathlib import Path
import argparse
import contextlib
import json
import math
import os
import re
import subprocess
import sys
import time

from capture_run_gear import ROOT, FOLDERS, git, inventory, sha
from run_tests import run_engine
from run_underworld_home_tests import Tee

DRIVER = "tests/item_v5_movie.gd"
SCOPE = (
    "Continuous actual Godot 60fps title -> playable Home movement -> original "
    "departure -> formal Plains -> native cache/reward/backpack. Exactly one "
    "disclosed cache-position fixture; known RewardService fixtures "
    "B33/P24/G15/P14 (B33 removed before combat); visible real high-HP training "
    "targets/platform and camera framing fixture. Native mouse equipment and "
    "P24 active selection; five actual primary hit receipts naturally fund 35 "
    "resonance; native R creates opposite flywheels, three patrol companions "
    "commit derived damage without resonance gain. No player HP, wallet or "
    "resonance injection. Not a natural full-route/Boss clear. No matched before "
    "movie. Software GL does not establish device/player/listening acceptance."
)
PHASES = {
    "title", "home_walk", "departure", "plains", "cache_fixture", "cache_choice",
    "backpack", "fixture_loadout", "equipped", "training", "primary_charge",
    "companions", "flywheels", "result",
}


def validate_trace(data, frames, checks):
    if data.get("schema") != "item-v5-formal-native-movie-v1":
        raise RuntimeError("Wrong native movie trace identity")
    if data["failures"] or data["checks"] != checks or len(data["frames"]) != frames or checks < 60:
        raise RuntimeError("Native trace, strict marker and required assertions disagree")
    points = data["checkpoints"]
    if {p["id"] for p in points} != PHASES or len(points) != len(PHASES):
        raise RuntimeError("Actual continuous formal entry and item demonstration phases are incomplete")
    events = data["input_events"]
    cache = [e for e in events if e["kind"] == "explicit_cache_position_fixture"]
    known = [e for e in events if e["kind"] == "explicit_known_reward_fixture"]
    training = [e for e in events if e["kind"] == "explicit_training_fixture"]
    if len(cache) != 1 or len(known) != 4 or {e["id"] for e in known} != {"B33", "P24", "G15", "P14"}:
        raise RuntimeError("Actual cache/known reward setup fixtures differ from the disclosed scope")
    if len(training) != 1 or training[0].get("resources_granted") is not False:
        raise RuntimeError("Missing disclosed training fixture or resource-injection refusal")
    for code in ("D", "W", "R"):
        if not any(e["kind"] == "key" and e["key"] == code and e["pressed"] for e in events):
            raise RuntimeError("Missing actual native " + code + " input")
    if not any(e["kind"] == "native_detail_wheel" for e in events):
        raise RuntimeError("Native detail scrolling gesture was not observed")
    primary = data["primary_receipts"]
    if len(primary) != 5 or len({(r["session"], r["packet"]) for r in primary}) != 5:
        raise RuntimeError("Five distinct actual successful primary packets were not recorded")
    if not all(r["target"] for r in primary):
        raise RuntimeError("Primary receipts lack real target identities")
    observed = data["frames"]
    if not any(row.get("formal_region") for row in observed):
        raise RuntimeError("Actual capture never enters the formal consumer")
    if any(b["drawn_frame"] <= a["drawn_frame"] for a, b in zip(observed, observed[1:])):
        raise RuntimeError("Trace lacks monotonic actual post-draw frame observations")
    fixture_start = next(p["video_frame"] for p in points if p["id"] == "fixture_loadout")
    if not all("测试初始化" in row["fixture_note"] for row in observed if row["video_frame"] > fixture_start):
        raise RuntimeError("Initialized item/target fixture stops being disclosed on screen")
    twins = []
    for row in observed:
        wheels = [e for e in row.get("entities", []) if e["kind"] == "flywheel"]
        if len(wheels) == 2:
            a, b = (w["direction"] for w in wheels)
            if math.fsum(x*y for x, y in zip(a, b)) < -.9999:
                twins.append(row)
    if not twins:
        raise RuntimeError("Actual drawn frame trace never shows two opposite live flywheels")
    damage = data["damage_receipts"]
    if not any(r["derived"] and "/P14/" in r["event"] and r["damage"] > 0 for r in damage):
        raise RuntimeError("Actual companion derived HP receipt is absent")
    wheel_targets = {r["target"] for r in damage if r["derived"] and "/P24/" in r["event"] and r["damage"] > 0}
    if wheel_targets != {"movie_fixture/target0", "movie_fixture/target1"}:
        raise RuntimeError("Opposite flywheels lack actual HP receipts on both real targets")
    final = [r for r in observed if r["phase"] == "result"]
    if not final or any(r["resonance"] != 0 or set(r["equipped"]) != {"P24", "G15", "P14"} for r in final):
        raise RuntimeError("Final real loadout/resonance state disagrees with the demonstration")
    return twins[0]


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
        raise RuntimeError("Use a NEW directory beneath build; retain every earlier capture")
    commit = git("rev-parse", args.source_commit + "^{commit}")
    selectors = ["project.godot", "export_presets.cfg", *FOLDERS]
    dirty = git("diff", "--name-only", commit, "--", *selectors).splitlines()
    untracked = git("ls-files", "--others", "--exclude-standard", "--", *selectors).splitlines()
    if not args.development and (dirty or untracked):
        raise RuntimeError("Final capture requires committed frozen sources: " + ", ".join(dirty + untracked))
    trace_uri = "res://" + (target / "trace.json").relative_to(ROOT).as_posix()
    argv = ["--path", ".", "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy",
            "--resolution", "1280x720", "--write-movie", str(target / "raw.avi"),
            "--fixed-fps", "60", "--script", DRIVER, "--", "--trace=" + trace_uri]
    if args.plan:
        print(json.dumps({"source_commit": commit, "argv": argv, "scope": SCOPE,
                          "development": args.development, "executed": False}, ensure_ascii=False, indent=2))
        return
    target.mkdir(parents=True)
    os.environ["DISPLAY"] = args.display
    os.environ["LIBGL_ALWAYS_SOFTWARE"] = "1"
    os.environ.setdefault("LP_NUM_THREADS", "1")
    # The original full inventory includes producer + runner + all scripts,
    # runtime configs, modals, resources and actual presentation consumers.
    # Build outputs are excluded; a changed source rejects the whole attempt.
    before = inventory()
    required = {DRIVER, "tools/capture_item_v5.py", "scripts/demo/demo_app.gd",
                "scripts/items/v5/item_runtime.gd", "scripts/items/v5/item_active_effects.gd",
                "scripts/items/v5/item_companion_effects.gd", "scripts/items/v5/item_v5_entity.gd",
                "config/items_v5.json", "config/item_v5_runtime.json", "config/item_v5_entities.json",
                "scripts/ui/demo_menu.gd", "scripts/ui/stage_reward_modal.gd",
                "scripts/ui/item_shop_modal.gd", "scripts/items/v5/item_v5_shop_presenter.gd",
                "scripts/player/player_controller.gd", "scripts/combat/player_projectile.gd",
                "scripts/damage/frame_damage_policy.gd", "scripts/input/input_router.gd",
                "scripts/input/keyboard_mouse_adapter.gd"}
    if not required.issubset(before):
        raise RuntimeError("Original source guard does not cover all real producer/runtime/UI dependencies")
    report = {"schema": "item-v5-formal-capture-v1", "source_commit": commit,
              "head": git("rev-parse", "HEAD"), "development": args.development,
              "dirty_paths": dirty + untracked, "argv": ["bash", "tools/godot.sh", *argv],
              "source_before": before, "status": "failed", "engine_exit_code": None,
              "source_stable": False, "scope": SCOPE, "before_movie": "unavailable",
              "audio_policy": "Original Godot stereo48k audio via Dummy backend. Hardware sound/listening acceptance unverified."}
    started = time.monotonic()
    try:
        with (target / "capture.log").open("w") as log, contextlib.redirect_stdout(Tee(sys.stdout, log)):
            output = run_engine(argv, 300)
        report["engine_exit_code"] = 0
        if re.search(r"SCRIPT ERROR:|SHADER ERROR:|(?m:^ERROR:)|ObjectDB.*leaked|resources? still in use at exit", output):
            raise RuntimeError("Actual recording emitted an engine error or leaked live native resources")
        matches = re.findall(r"^ITEM V5 MOVIE: ([1-9]\d*) frames, ([1-9]\d*) assertions, 0 failures$", output, re.M)
        if len(matches) != 1:
            raise RuntimeError("Actual recording lacks its one exact successful completion marker")
        frames, checks = map(int, matches[0])
        data = json.loads((target / "trace.json").read_text())
        twin_frame = validate_trace(data, frames, checks)
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
        if video["codec_name"] != "h264" or video["avg_frame_rate"] != "60/1" or (video["width"], video["height"]) != (1280, 720):
            raise RuntimeError("Movie is not actual H264 normal60fps 1280x720")
        if len(audio) != 1 or audio[0]["codec_name"] != "aac" or audio[0]["sample_rate"] != "48000" or audio[0]["channels"] != 2:
            raise RuntimeError("Original game stereo48k AAC audio stream is absent")
        seconds = float(media["format"]["duration"])
        if not 25 <= seconds <= 60:
            raise RuntimeError("Actual continuous recording must last 25–60 seconds")
        samples = [(p["id"], p, 30) for p in data["checkpoints"]
                   if p["id"] in {"title", "home_walk", "departure", "cache_choice", "backpack", "equipped", "training", "companions", "result"}]
        samples.append(("opposite_flywheels", twin_frame, 0))
        images = []
        for name, point, offset in samples:
            # Godot reports one-based completed draw count after frame_post_draw;
            # the writer's frame index is zero based. Images come from MP4 frames,
            # never a synthetic montage or a second rendering session.
            media_frame = max(0, int(point["drawn_frame"])-1+offset)
            image_path = target / (name + ".png")
            subprocess.run(["ffmpeg", "-y", "-i", str(target / "movie.mp4"),
                            "-vf", f"select=eq(n\\,{media_frame})", "-frames:v", "1", str(image_path)],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True, timeout=30)
            if not image_path.is_file():
                raise RuntimeError("Actual movie observation frame is absent: " + name)
            nearest = min(data["frames"], key=lambda row: abs(row["drawn_frame"]-(media_frame+1)))
            images.append({"path": image_path.name, "sha256": sha(image_path), "movie_frame": media_frame,
                           "movie_time_s": media_frame/60, "actual_trace_drawn_frame": nearest["drawn_frame"],
                           "trace_phase": nearest["phase"], "mapping": "post-draw completed count minus one, plus declared observation offset"})
        report.update(status="development_captured" if args.development else "captured", frames=frames,
                      assertions=checks, seconds=seconds, media=media, images=images,
                      source_stable=inventory() == before,
                      artifacts={p.name: sha(p) for p in target.iterdir() if p.is_file()})
        if not report["source_stable"]:
            raise RuntimeError("Source drift after actual media validation")
        print("PASS: actual V5 formal native movie, disclosed setup fixtures, original audio, strict clean exit and stable sources")
    except Exception as error:
        report["status"] = "failed"
        report["error"] = type(error).__name__ + ": " + str(error)
        raise
    finally:
        report["wall_seconds"] = time.monotonic()-started
        report["source_after"] = inventory()
        report["source_stable"] = before == report["source_after"]
        (target / "receipt.json").write_text(json.dumps(report, ensure_ascii=False, indent=2)+"\n")


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        print("Item V5 movie failed: " + str(error), file=sys.stderr)
        sys.exit(1)
