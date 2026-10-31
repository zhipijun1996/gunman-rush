#!/usr/bin/env python3
"""Capture an uncut actual Bellstrider App fight with a disclosed legal-input bot.

No encounter fixtures after the logged initial precombat position. Original
MovieMaker PCM, all-frame trace and failed attempts are preserved for review.
Run only while holding the project's single Godot/GL lease.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import selectors
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import harness
from enemy_all_review_02 import original_audio_statistics

DRIVER = "tools/bellstrider_rework_01_capture.gd"


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def trace_findings(trace):
    """Coverage is inferred from real events, never from planned bot actions."""
    rows = trace.get("frames", [])
    events = trace.get("events", [])
    shots = trace.get("shots", [])
    actual = trace.get("combat_metrics", {})
    chapters = []
    names = {
        "actual_entry_activation": "actual entry and autonomous intro",
        "bellstrider_ring_strike": "actual ground-wave strike",
        "bellstrider_lob_release": "actual lob release",
        "bellstrider_death": "actual terminal damage and death start",
        "bellstrider_death_impact": "actual death impact",
        "bellstrider_death_final": "actual 1.8 second death completion",
        "all_actual_boss_coins_claimed": "actual four-unit coin pickup complete",
        "actual_player_injury": "actual player injury",
        "bellstrider_armour_hit": "actual armour impact / 装甲试射，HP应不变",
    }
    for event in events:
        label = names.get(event.get("event"))
        if event.get("event") == "state" and event.get("state") == "roll":
            label = "actual roll charge"
        if event.get("event") == "bellstrider_group":
            plan = event.get("actual_event", {}).get("plan", {})
            if plan.get("phase") == 2 and plan.get("return_roll"):
                label = "actual phase-two preselected return charge"
        if label:
            chapters.append({"label": label, "frame": event["frame"],
                             "movie_frame": event["movie_frame"],
                             "seconds": event["movie_seconds"], "event": event})
    groups = {}
    for shot in shots:
        groups.setdefault(shot.get("group", -1), []).append(shot)
    injury_rows = [event for event in events if event.get("event") == "actual_player_injury"]
    two_shot_groups = []
    greed = []
    group_observations = []
    for group in sorted({int(row.get("group", 0)) for row in rows} - {0}):
        observations = [row for row in rows if int(row.get("group", 0)) == group]
        recovery_rows = [row for row in observations if row.get("state") == "neck"]
        if not observations:
            continue
        injury = [event for event in injury_rows if event.get("group") == group]
        commits = [event for event in events if event.get("event") == "bellstrider_bell_hit"
                   and event.get("actual_event", {}).get("group") == group]
        recovery_start = recovery_rows[0]["movie_process_frame"] if recovery_rows else None
        later = [row for row in rows if recovery_rows
                 and row["movie_process_frame"] > recovery_rows[-1]["movie_process_frame"]
                 and row.get("state") in ("roll", "rings", "lob")]
        threat = later[0] if later else None
        group_observations.append({"group": group,
                                   "kind": observations[0].get("group_plan", {}).get("kind"),
                                   "start_movie_frame": observations[0]["movie_process_frame"],
                                   "recovery_start_movie_frame": recovery_start,
                                   "actual_injury_events": injury,
                                   "whole_group_evaded_without_HP_loss": not injury and bool(recovery_rows),
                                   "actual_bell_commits": commits,
                                   "next_actual_attack_state_frame": threat["movie_process_frame"] if threat else None,
                                   "next_actual_attack_state": threat.get("state") if threat else None,
                                   "interpretation": "Attack-state onset is observed; exact trajectory arrival and retreat success require the full per-frame positions and visual review."})
    for group, group_shots in groups.items():
        recovery = [shot for shot in group_shots if shot.get("state") in ("neck", "observe")]
        if len(recovery) >= 2:
            two_shot_groups.append({"group": group, "shots": recovery[:2],
                                    "first_to_second_seconds": (recovery[1]["movie_frame"] - recovery[0]["movie_frame"]) / 60})
        if len(recovery) >= 3:
            third = recovery[2]
            injuries = [event for event in injury_rows
                        if 0 <= event["movie_frame"] - third["movie_frame"] <= 150]
            positions = [row for row in rows
                         if 0 <= row["movie_process_frame"] - third["movie_frame"] <= 150]
            chapters.append({"label": "actual third counter-shot / " + trace.get("pilot", "unknown"),
                             "frame": third["frame"], "movie_frame": third["movie_frame"],
                             "seconds": third["movie_frame"] / 60, "shot": third})
            greed.append({"group": group, "third_shot": third,
                          "following_injuries_within_2_5_seconds": injuries,
                          "withdrawal_observations": [{key: row.get(key) for key in
                                                       ("frame", "movie_process_frame", "state", "player_position", "boss_position", "player_HP", "router_axis", "grounded", "pilot_intent", "late_withdraw_remaining")}
                                                      for row in positions[::6]],
                          "outcome": "actual_following_injury" if injuries else "no_injury_observed_in_window",
                          "causality": "temporal observation only; third-shot causality requires visual review"})
    chapters.sort(key=lambda chapter: chapter["movie_frame"])
    modes = {row.get("state") for row in rows}
    return {"chapters": chapters, "two_shot_groups": two_shot_groups,
            "greed_attempts": greed, "actual_fight_seconds": actual.get("fight_seconds"),
            "late_withdraw_intents": [row for row in trace.get("inputs", [])
                                      if row.get("action") in ("intentional_late_withdraw", "late_visible_threat_detected", "late_distance_deadline_evade_attempt", "late_threat_finished_without_distance_deadline")],
            "armour_probe": {"requested": trace.get("review_armour", False),
                             "actual_shot_id": trace.get("armour_probe_actual_shot_id", -1),
                             "actual_armour_events": [event for event in events if event.get("event") == "bellstrider_armour_hit"]},
            "accepted_hits": actual.get("accepted_hits"), "accepted_damage": actual.get("accepted_damage"),
            "groups_started": actual.get("groups_started"), "groups_completed": actual.get("groups_completed"),
            "per_group_observations": group_observations,
            "actual_shots": len(shots), "actual_player_injuries": injury_rows,
            "all_three_attacks_observed": {"roll", "rings", "lob"}.issubset(modes),
            "phase_two_return_observed": any("return charge" in row["label"] for row in chapters),
            "about_20_groups_observed": 18 <= int(actual.get("groups_started", 0)) <= 23,
            "player_hp_final": rows[-1].get("player_HP") if rows else None,
            "wallet_delta": trace.get("wallet_delta")}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--seed", default="bellstrider-rework-01")
    parser.add_argument("--pilot", choices=("cautious2", "greed3", "greed3_late"), default="cautious2")
    parser.add_argument("--max-battle-seconds", type=float, default=180)
    parser.add_argument("--timeout-seconds", type=int, default=900,
                        help="This wrapper's own bounded wall-clock budget; no harness changes")
    parser.add_argument("--retain-avi", action="store_true")
    parser.add_argument("--review-armour", action="store_true",
                        help="One legal grounded armour shot after intro, before first autonomous attack group")
    parser.add_argument("--diagnostic-headless", action="store_true",
                        help="Fast actual App/legal-input gameplay trace only; no GPU, PCM or movie evidence")
    args = parser.parse_args()
    if not 10 <= args.max_battle_seconds <= 600 or not 60 <= args.timeout_seconds <= 3600:
        parser.error("Battle bound must be 10..600s and process timeout 60..3600s")
    folder = args.output.resolve()
    folder.mkdir(parents=True, exist_ok=False)
    source = harness.git_metadata()
    before = harness.source_inventory()
    report = {"task": "BELLSTRIDER-REWORK-01", "status": "running", "source": source,
              "source_files_before": before, "driver_sha256": digest(ROOT / DRIVER),
              "pilot_sha256": digest(ROOT / "tools/bellstrider_01/legal_input_pilot.gd"),
              "scope": "One uncut actual DemoApp/start_plains map1 encounter. Disclosed initial precombat positioning; thereafter automated legal Router movement/jump/shoot and MouseMotion aim. Encounter selection and clocks remain autonomous.",
              "human_play_acceptance": False, "listening_acceptance": False,
              "device_acceptance": "unverified", "pilot": args.pilot,
              "diagnostic_headless": args.diagnostic_headless, "review_armour": args.review_armour}
    env = os.environ.copy()
    env["LIBGL_ALWAYS_SOFTWARE"] = "1"
    display = display_log = None
    started = time.monotonic()
    errors = []
    try:
        if not args.diagnostic_headless and not env.get("DISPLAY"):
            candidate = Path(os.environ.get("GUNMAN_TOOLCHAIN_ROOT", str(ROOT.parent / "toolchains"))) / "xvfb/usr/bin/Xvfb"
            binary = shutil.which("Xvfb") or (str(candidate) if candidate.is_file() else None)
            if not binary:
                raise RuntimeError("Xvfb required for genuine pixels")
            display_log = (folder / "display.log").open("wb")
            display = subprocess.Popen([binary, "-displayfd", "1", "-screen", "0", "1280x720x24", "-nolisten", "tcp", "-ac"], stdout=subprocess.PIPE, stderr=display_log)
            with selectors.DefaultSelector() as selector:
                selector.register(display.stdout, selectors.EVENT_READ)
                if not selector.select(30):
                    raise RuntimeError("Xvfb startup timeout")
                number = display.stdout.readline().decode().strip()
            if not number.isdigit():
                raise RuntimeError("Invalid Xvfb display")
            env["DISPLAY"] = ":" + number
        avi, movie, trace_path = (folder / name for name in ("capture.avi", "review.mp4", "trace.json"))
        command = ["bash", "tools/godot.sh", "--path", "."]
        command += ["--headless"] if args.diagnostic_headless else ["--rendering-method", "gl_compatibility", "--write-movie", str(avi)]
        command += ["--fixed-fps", "60", "--script", DRIVER, "--",
                   "--trace=" + str(trace_path), "--seed=" + args.seed, "--pilot=" + args.pilot,
                   "--max-battle-seconds=" + str(args.max_battle_seconds)]
        if args.diagnostic_headless:
            command.append("--diagnostic-headless")
        if args.review_armour:
            command.append("--review-armour")
        report["command"] = command
        execution = harness.run_check({"argv": command, "timeout_seconds": args.timeout_seconds,
                                       "success_pattern": r"^BELLSTRIDER REWORK REVIEW: complete; frames=\d+; hits=\d+; groups=\d+; failures=0$"},
                                      folder / "capture.log", ROOT, env)
        report["execution"] = execution
        if re.search(r"(?m)^ERROR:|RID allocations.*leaked", (folder / "capture.log").read_text(errors="replace")):
            errors.append("Native engine error in actual encounter; original attempt retained")
        if execution["status"] != "passed":
            errors.append("Godot encounter capture failed; original attempt retained")
        trace = json.loads(trace_path.read_text()) if trace_path.is_file() else {}
        rows = trace.get("frames", [])
        if trace:
            findings = trace_findings(trace)
            report["findings"] = findings
            (folder / "chapters.json").write_text(json.dumps(findings, ensure_ascii=False, indent=2) + "\n")
            report["trace_sha256"] = digest(trace_path)
            if not trace.get("complete") or trace.get("failures"):
                errors.extend(trace.get("failures") or ["Incomplete actual gameplay trace"])
            if not rows or [row["frame"] for row in rows] != list(range(1, len(rows) + 1)):
                errors.append("Active-frame observations are not continuous")
            if not args.diagnostic_headless and trace.get("postdraw_rows", 0) < len(rows) - 2:
                errors.append("Missing actual renderer post-draw observations")
            if any(row.get("time_scale") != 1 for row in rows):
                errors.append("Non-normal game clock observed")
            if not findings["all_three_attacks_observed"]:
                errors.append("Natural run did not show all three attack kinds")
            if not findings["phase_two_return_observed"]:
                errors.append("Natural run did not show a phase-two return charge")
            if args.pilot == "cautious2" and not findings["about_20_groups_observed"]:
                errors.append("Cautious real encounter did not meet about-20-group target")
            if args.review_armour and (findings["armour_probe"]["actual_shot_id"] < 0 or not findings["armour_probe"]["actual_armour_events"]):
                errors.append("Requested legal armour shot or actual armour feedback event missing")
        else:
            errors.append("No actual encounter trace emitted")
        # Encode failed gameplay too: these are honest uncut failed attempts,
        # never hidden by dropping their original media or reusing another run.
        if args.diagnostic_headless:
            report["media_evidence"] = "NONE: headless diagnostic only; no GPU, original PCM, movie, visual or listening claims"
        elif avi.is_file() and avi.stat().st_size > 1024:
            report["original_engine_audio"] = original_audio_statistics(avi, folder)
            with (folder / "encode.log").open("wb") as log:
                subprocess.run(["ffmpeg", "-y", "-i", str(avi), "-c:v", "libx264", "-crf", "20",
                                "-pix_fmt", "yuv420p", "-c:a", "aac", "-movflags", "+faststart", str(movie)],
                               stdout=subprocess.DEVNULL, stderr=log, check=True, timeout=240)
            media = json.loads(subprocess.check_output(["ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(movie)], timeout=30))
            report["media"] = media
            video = next(stream for stream in media["streams"] if stream["codec_type"] == "video")
            audio = next(stream for stream in media["streams"] if stream["codec_type"] == "audio")
            if (video["width"], video["height"], video["avg_frame_rate"], audio["sample_rate"], audio["channels"]) != (1280, 720, "60/1", "48000", 2):
                errors.append("Native 1280x720/60fps/original stereo contract failed")
            if rows and rows[-1]["movie_process_frame"] / 60 > float(media["format"]["duration"]) + .1:
                errors.append("Frame timestamps exceed actual uncut movie duration")
            report.update(mp4_sha256=digest(movie), avi_sha256=digest(avi))
        else:
            errors.append("No finalized original MovieMaker AVI")
        after = harness.source_inventory()
        report["source_files_after"] = after
        report["source_after"] = harness.git_metadata()
        report["external_source_stable"] = before == after and source == report["source_after"]
        report["driver_source_guard"] = trace.get("source_stable", "missing")
        report["source_stable"] = report["external_source_stable"] and trace.get("source_stable") is True
        if not report["external_source_stable"]:
            errors.append("External exact source inventory/git metadata changed during capture/encoding")
        elif trace.get("source_stable") is not True:
            errors.append("External exact source stayed unchanged; driver's independent source guard is missing or failed")
        report["status"] = ("headless_diagnostic_gameplay_complete" if args.diagnostic_headless else "recorded_complete_coverage") if not errors else "failed_attempt_retained"
        # Failed attempts always keep AVI even without --retain-avi.
        if not errors and not args.retain_avi and avi.exists():
            avi.unlink()
        report["raw_avi_retained"] = avi.exists()
        report["trace_frame_count"] = len(rows)
    except BaseException as error:
        errors.append(str(error))
        report["status"] = "failed_attempt_retained"
    finally:
        if "source_files_after" not in report:
            try:
                report["source_files_after"] = harness.source_inventory()
                report["source_after"] = harness.git_metadata()
                report["source_stable"] = before == report["source_files_after"] and source == report["source_after"]
            except Exception as error:
                errors.append("Post-failure source collection failed: " + str(error))
        report["errors"] = errors
        report["seconds"] = time.monotonic() - started
        (folder / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
        if display is not None:
            display.terminate()
            try:
                display.wait(timeout=5)
            except subprocess.TimeoutExpired:
                display.kill()
                display.wait()
        if display_log:
            display_log.close()
    if errors:
        print("BELLSTRIDER MOVIE FAILED; attempt retained: " + "; ".join(errors), file=sys.stderr)
        return 1
    print(("BELLSTRIDER HEADLESS DIAGNOSTIC: gameplay complete; NO MEDIA/GPU PROOF; " + str(trace_path)) if args.diagnostic_headless else ("BELLSTRIDER MOVIE: complete actual uncut encounter; " + str(folder / "review.mp4")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
