#!/usr/bin/env python3
"""Capture an uncut actual Windkeeper App fight with a disclosed legal-input bot.

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

DRIVER = "tools/windkeeper_pressure_01_capture.gd"


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def trace_findings(trace):
    """Summarize actual observations; chapter plans never prove coverage."""
    rows = trace.get("frames", [])
    events = trace.get("events", [])
    shots = trace.get("shots", [])
    injuries = [event for event in events if event.get("event") == "actual_player_injury"]
    chapters = []
    names = {
        "actual_entry_activation": "formal map2 entry and autonomous intro",
        "windkeeper_phase": "actual structural phase transition",
        "windkeeper_death": "actual lethal hit and mechanical failure",
        "windkeeper_death_impact": "actual collapse impact / coins released",
        "windkeeper_death_final": "actual settled harmless remains",
        "all_actual_boss_coins_claimed": "actual physical coin pickup complete",
        "actual_player_injury": "actual accepted player injury",
    }
    for event in events:
        label = names.get(event.get("event"))
        if label:
            chapters.append({"label": label, "frame": event["frame"],
                             "movie_frame": event["movie_frame"],
                             "seconds": event["movie_seconds"], "event": event})
    states = [event for event in events if event.get("event") == "state"]
    moves = {}
    for name in ("stomp", "lunge", "sweep", "gust", "seeds", "platform"):
        actual = [row for row in rows if row.get("state") == name]
        moves[name] = {"observed": bool(actual), "first_movie_frame": actual[0]["movie_process_frame"] if actual else None,
                       "actual_frames": len(actual)}
        if actual:
            group = int(actual[0].get("group", -1))
            warnings = [event for event in states if event.get("group") == group
                        and event.get("state") == name + "_warning"
                        and event["movie_seconds"] <= actual[0]["movie_seconds"]]
            start = warnings[-1]["movie_seconds"] if warnings else actual[0]["movie_seconds"]
            end = next((event["movie_seconds"] for event in states
                        if event["movie_seconds"] > actual[0]["movie_seconds"] and event.get("state") != name),
                       actual[-1]["movie_seconds"])
            chapters.append({"label": "actual " + name + " / preparation and execution",
                             "seconds": start, "end_seconds": end, "group": group,
                             "frame": actual[0]["frame"], "movie_frame": actual[0]["movie_process_frame"]})
    groups = []
    two_shots = []
    third_shots = []
    for identity in sorted({int(row.get("group", 0)) for row in rows} - {0}):
        observations = [row for row in rows if int(row.get("group", 0)) == identity]
        if not observations:
            continue
        plan = observations[0].get("group_plan", {})
        attacks = plan.get("attacks", [])
        recoveries = [row for row in observations if row.get("state") == "recover"]
        actual_shots = [shot for shot in shots if int(shot.get("group", -1)) == identity]
        countershots = [shot for shot in actual_shots if shot.get("state") == "recover"]
        following = [row for row in rows if recoveries and row["movie_process_frame"] > recoveries[-1]["movie_process_frame"]]
        next_attack = next((row for row in following if row.get("state") in moves), None)
        record = {"group": identity, "phase": observations[0].get("phase"), "plan": plan,
                  "attacks_in_frozen_plan": len(attacks), "observed_states": list(dict.fromkeys(row.get("state") for row in observations)),
                  "start_seconds": observations[0]["movie_seconds"],
                  "recovery_start_seconds": recoveries[0]["movie_seconds"] if recoveries else None,
                  "recovery_end_seconds": recoveries[-1]["movie_seconds"] if recoveries else None,
                  "actual_countershots": countershots,
                  "next_attack_state_onset_seconds": next_attack["movie_seconds"] if next_attack else None,
                  "injuries": [event for event in injuries if event.get("group") == identity],
                  "interpretation": "Attack-state onset is an observation, not exact threat arrival. Evasion and retreat must be assessed from the full frame positions and actual hit results."}
        groups.append(record)
        if len(attacks) >= 2 and recoveries:
            chapters.append({"label": "actual complete " + str(len(attacks)) + "-attack group / final recovery",
                             "seconds": observations[0]["movie_seconds"], "end_seconds": recoveries[-1]["movie_seconds"],
                             "group": identity, "phase": record["phase"]})
        if len(countershots) >= 2:
            two_shots.append(record)
        if len(countershots) >= 3:
            third = countershots[2]
            actual_third = {"group": identity, "shot": third,
                            "recovery_seconds_after_actual_third": max(0, recoveries[-1]["movie_seconds"] - third["movie_frame"] / 60) if recoveries else None,
                            "following_injuries": [event for event in injuries if 0 <= event["movie_frame"] - third["movie_frame"] <= 150],
                            "next_attack_state_onset_seconds": record["next_attack_state_onset_seconds"],
                            "causality": "A following injury is not proof that third-shot timing alone caused it; inspect position, existing recoil and subsequent inputs."}
            third_shots.append(actual_third)
            chapters.append({"label": "actual third recovery shot / " + trace.get("pilot", ""),
                             "seconds": third["movie_frame"] / 60, "movie_frame": third["movie_frame"], "group": identity})
    holds = [row for row in trace.get("inputs", []) if row.get("action") == "stationary_observation_end"]
    pressure = []
    for hold in holds:
        end = hold["movie_frame"]
        selected = [row for row in rows if end - round(hold.get("held_seconds", 0) * 60) <= row["movie_process_frame"] <= end]
        if selected:
            start, finish = selected[0], selected[-1]
            pressure.append({"hold": hold, "actual_player_x_displacement": finish["player_position"][0] - start["player_position"][0],
                             "actual_boss_x_displacement": finish["boss_position"][0] - start["boss_position"][0],
                             "initial_gap": abs(start["boss_position"][0] - start["player_position"][0]),
                             "final_gap": abs(finish["boss_position"][0] - finish["player_position"][0]),
                             "seconds": start["movie_seconds"], "end_seconds": finish["movie_seconds"]})
            chapters.append({"label": "initial stationary player / actual active Boss approach",
                             "seconds": start["movie_seconds"], "end_seconds": finish["movie_seconds"]})
    return {"chapters": chapters, "moves": moves,
            "all_six_attacks_observed": all(item["observed"] for item in moves.values()),
            "actual_phases": sorted({int(row.get("phase", 0)) for row in rows}),
            "all_three_phases_observed": {1, 2, 3}.issubset({int(row.get("phase", 0)) for row in rows}),
            "group_observations": groups, "two_attack_groups": [item for item in groups if item["attacks_in_frozen_plan"] == 2],
            "three_attack_groups": [item for item in groups if item["attacks_in_frozen_plan"] == 3],
            "two_shot_groups": two_shots, "third_shot_observations": third_shots,
            "stationary_pressure": pressure, "injuries": injuries,
            "active_extra_requests": [item for item in trace.get("inputs", []) if item.get("action") == "active_extra_shot"],
            "actual_ground_attack_phase_shots": [shot for shot in shots if shot.get("grounded") and shot.get("state") in ["approach","turn","stomp_warning","seeds_warning","gust_warning","sweep_warning","platform_warning"]],
            "input_profile_scope": "Attack-phase extra shots are part of active2's disclosed strategy; this does not prove cautious2 victory or the two-shot window.",
            "final_metrics": trace.get("combat_metrics", {}),
            "player_hp_final": rows[-1].get("player_HP") if rows else None,
            "wallet_delta": trace.get("wallet_delta")}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--seed", default="windkeeper-pressure-01")
    parser.add_argument("--pilot", choices=("cautious2", "greed3", "active2"), default="cautious2")
    parser.add_argument("--max-battle-seconds", type=float, default=240)
    parser.add_argument("--timeout-seconds", type=int, default=900,
                        help="This wrapper's own bounded wall-clock budget; no harness changes")
    parser.add_argument("--retain-avi", action="store_true")
    parser.add_argument("--diagnostic-headless", action="store_true",
                        help="Fast actual App/legal-input gameplay trace only; no GPU, PCM or movie evidence")
    args = parser.parse_args()
    if not 10 <= args.max_battle_seconds <= 600 or not 60 <= args.timeout_seconds <= 3600:
        parser.error("Battle bound must be 10..600s and process timeout 60..3600s")
    folder = args.output.resolve()
    folder.mkdir(parents=True, exist_ok=False)
    source = harness.git_metadata()
    before = harness.source_inventory()
    report = {"task": "WINDKEEPER-PRESSURE-01", "status": "running", "source": source,
              "source_files_before": before, "driver_sha256": digest(ROOT / DRIVER),
              "pilot_sha256": digest(ROOT / "tools/windkeeper_pressure_01/legal_input_pilot.gd"),
              "scope": "One uncut exact formal map2 encounter through existing public DemoApp.start_debug_region plains2. Debug entry is disclosed, not natural campaign progression. One initial precombat player position; thereafter only normal Router/mouse inputs. No encounter, HP, resource, RNG, clock or camera injection.",
              "human_play_acceptance": False, "listening_acceptance": False,
              "device_acceptance": "unverified", "pilot": args.pilot,
              "input_profile": "active2: additional guarded ground shots in attack preparation plus at-most-two final-recovery shots; does not prove cautious2 victory/two-shot safety" if args.pilot == "active2" else args.pilot + ": recovery-shot review",
              "diagnostic_headless": args.diagnostic_headless}
    (folder / "source-before.json").write_text(json.dumps({"source": source, "files": before}, ensure_ascii=False, indent=2) + "\n")
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
        report["command"] = command
        execution = harness.run_check({"argv": command, "timeout_seconds": args.timeout_seconds,
                                       "success_pattern": r"^WINDKEEPER PRESSURE REVIEW: complete; frames=\d+; hits=\d+; groups=\d+; failures=0$"},
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
            if not findings["all_six_attacks_observed"]:
                errors.append("Natural encounter did not show all six actual move executions")
            if not findings["all_three_phases_observed"]:
                errors.append("Natural encounter did not show all three phases")
            if not findings["two_attack_groups"] or not findings["three_attack_groups"]:
                errors.append("Actual double/triple attack-group coverage is incomplete")
            if not findings["two_shot_groups"]:
                errors.append("No actual two-shot recovery counterattack observed")
            if args.pilot == "greed3" and not findings["third_shot_observations"]:
                errors.append("Requested greedy pilot recorded no actual third recovery shot")
            if args.pilot == "active2":
                extras = findings["active_extra_requests"]
                if not extras or not findings["actual_ground_attack_phase_shots"]:
                    errors.append("active2 recorded no guarded attack-phase extra shots")
                if len({item["interval_start"] for item in extras}) != len(extras):
                    errors.append("active2 submitted more than one extra shot in an approach/warning interval")
                recovery_requests = {}
                for item in trace.get("inputs", []):
                    if item.get("action") == "shoot_release" and item.get("actual_state") == "recover" and item.get("submitted"):
                        identity = item.get("group", -1)
                        recovery_requests[identity] = recovery_requests.get(identity, 0) + 1
                if any(count > 2 for count in recovery_requests.values()):
                    errors.append("active2 requested more than two final-recovery shots in a group")
            if not any(abs(item["actual_player_x_displacement"]) < 8 and item["initial_gap"]-item["final_gap"] > 25 for item in findings["stationary_pressure"]):
                errors.append("Stationary observation did not show meaningful active Boss approach")
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
        print("WINDKEEPER MOVIE FAILED; attempt retained: " + "; ".join(errors), file=sys.stderr)
        return 1
    print(("WINDKEEPER HEADLESS DIAGNOSTIC: gameplay complete; NO MEDIA/GPU PROOF; " + str(trace_path)) if args.diagnostic_headless else ("WINDKEEPER MOVIE: complete actual uncut encounter; " + str(folder / "review.mp4")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
