#!/usr/bin/env python3
"""Capture the continuous first-eight/three-VFX actual formal art golden.

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

DRIVER = "tests/item_art_golden_movie.gd"
SCOPE = (
    "Continuous actual title/Home/original departure/formal Plains/cache/native "
    "inventory. Eight distinct golden icons use an original cache or disclosed "
    "known RewardService fixtures. Explicit cache-position and high-HP training "
    "platform/target/camera setup; no playerHP/resonance injection. Final expansion only explicitly initializes quoted coins via original RunWallet ledger, not natural earnings. "
    "Actual P24/G15/P14 loadout, five primary hit receipts naturally fund35 "
    "resonance, nativeR opposite authored flywheels and three patrols. Actual "
    "native swap to G16/P14, ten more primary hits fund70, nativeR costs65 and "
    "three configured0.9D pulses commit realHP with separate cast/impact art. "
    "First8/threeVFX golden, not full72art/naturalroute/physicaldevice/listening "
    "or human acceptance; no matched before movie."
)
GOLDEN_IDS = {"B01", "B03", "B11", "P24", "P14", "G14", "G16", "N01"}
BASE_FIXTURES = {"B33", "P24", "G15", "P14"}
PHASES = {
    "title", "home_walk", "departure", "plains", "cache_fixture", "cache_choice",
    "backpack", "fixture_loadout", "equipped", "training", "primary_charge",
    "companions", "flywheels", "result", "golden_swap", "judgment_equipped",
    "judgment_charge", "judgment_cast", "golden_result",
    "equipment_retraction", "hp_equipped", "hp_removing", "hp_removed", "gear_upgrade_fixture", "gear_expanded",
}


def authored(row, kind, origin):
    return [e for e in row.get("entities", []) if e["kind"] == kind
            and e.get("artist", {}).get("origin") == origin
            and e["artist"].get("clip") and e["artist"].get("art_draws", 0) > 0]


def validate_trace(data, frames, checks):
    if data.get("schema") != "item-art-golden-native-movie-v1":
        raise RuntimeError("Wrong actual golden movie trace identity")
    observed = data["frames"]
    if data["failures"] or data["checks"] != checks or len(observed) != frames or checks < 110:
        raise RuntimeError("Native golden trace, strict marker and required assertions disagree")
    points = data["checkpoints"]
    if {p["id"] for p in points} != PHASES or len(points) != len(PHASES):
        raise RuntimeError("Actual formal entry/P24/G16 golden phases are incomplete")
    events = data["input_events"]
    known = [e for e in events if e["kind"] == "explicit_known_reward_fixture"]
    known_ids = {e["id"] for e in known}
    if len(known) != len(known_ids) or not BASE_FIXTURES <= known_ids <= (BASE_FIXTURES | GOLDEN_IDS):
        raise RuntimeError("Known rewards do not match the disclosed original-service fixture scope")
    if len([e for e in events if e["kind"] == "explicit_cache_position_fixture"]) != 1:
        raise RuntimeError("Actual formal route must retain exactly one disclosed cache-position fixture")
    training = [e for e in events if e["kind"] == "explicit_training_fixture"]
    if len(training) != 1 or training[0].get("resources_granted") is not False:
        raise RuntimeError("Missing disclosed real hurtbox/platform setup or resource-injection refusal")
    icons = data["golden_icons"]
    if len(icons) != 8 or {e["id"] for e in icons} != GOLDEN_IDS:
        raise RuntimeError("Eight golden definitions did not resolve actual independent common UI resources")
    if any(not e["icon_key"].startswith("item_") or not e["source"].startswith("res://assets/items/v5/") or not e["instance"] for e in icons):
        raise RuntimeError("Golden icons lack actual registered resources and owned instances")
    if len({(e["source"], tuple(e["region"])) for e in icons}) != 8:
        raise RuntimeError("Golden icons reuse a renamed source region")
    if not any(e["kind"] == "native_detail_wheel" for e in events):
        raise RuntimeError("Native detail scrolling input is missing")
    for key in ("D", "W"):
        if not any(e["kind"] == "key" and e["key"] == key and e["pressed"] for e in events):
            raise RuntimeError("Missing actual native " + key + " input")
    r_presses = [e for e in events if e["kind"] == "key" and e["key"] == "R" and e["pressed"]]
    if len(r_presses) != 2:
        raise RuntimeError("Golden route must use exactly two native independent R presses")
    primary = data["primary_receipts"]
    if len(primary) != 15 or len({(r["session"], r["packet"]) for r in primary}) != 15:
        raise RuntimeError("Actual five-plus-ten distinct successful primary packets are missing")
    if any(not p["target"] for p in primary):
        raise RuntimeError("Primary receipts lack actual damageable identities")
    if not any(row.get("formal_region") for row in observed):
        raise RuntimeError("Actual capture never enters the formal consumer")
    if any(b["drawn_frame"] <= a["drawn_frame"] for a, b in zip(observed, observed[1:])):
        raise RuntimeError("Actual post-draw observations are not monotonic")
    fixture_start = next(p["video_frame"] for p in points if p["id"] == "fixture_loadout")
    if not all("测试初始化" in r["fixture_note"] for r in observed if r["video_frame"] > fixture_start):
        raise RuntimeError("Known-item/training setup disclosure disappears from the actual film")
    twins = []
    for row in observed:
        wheels = authored(row, "flywheel", "P24")
        if len(wheels) == 2 and math.fsum(x*y for x, y in zip(wheels[0]["direction"], wheels[1]["direction"])) < -.9999:
            twins.append(row)
    # Entity draw counters remain nonzero while an overlay pauses the stage.
    # Select an actual unobscured world observation, never a menu screenshot
    # merely because three previously drawn bodies still exist underneath it.
    patrols = [r for r in observed if len(authored(r, "small_drone", "P14")) == 3
               and r["phase"] == "companions" and not r["paused"] and not r["menu"]]
    pulses = [r for r in observed if authored(r, "pulse", "G16")]
    if not twins or not patrols or not pulses:
        raise RuntimeError("Actual post-draw trace lacks authored twin rotor/three patrol/judgment entity draws")
    if not any(int(r.get("artist", {}).get("view", {}).get("art_draw_calls", 0)) > 0 for r in observed):
        raise RuntimeError("Actual effect-view authored texture draw counter never advanced")
    damage = [r for r in data["damage_receipts"] if r["derived"] and r["damage"] > 0]
    if {r["target"] for r in damage if "/P24/" in r["event"]} != {"movie_fixture/target0", "movie_fixture/target1"}:
        raise RuntimeError("Real opposite flywheels did not commit HP on both actual hurtboxes")
    if not any("/P14/" in r["event"] for r in damage):
        raise RuntimeError("Actual patrol HP receipts are absent")
    judgment = data["judgment"]
    if not (judgment["energy_before"] == 70 and judgment["cost"] == 65 and judgment["energy_after"] == 5 and judgment["pulse_count"] == 3):
        raise RuntimeError("Actual second-active resource transaction differs from the declared70-minus65 flow")
    actual = judgment["damage_receipts"]
    if len(actual) != 3 or any(r["target"] != "movie_fixture/target1" or not math.isclose(r["damage"], judgment["ratio_D_each"]*judgment["base_damage_D"], rel_tol=1e-6, abs_tol=1e-6) for r in actual):
        raise RuntimeError("Configured G16 D ratios do not match the actual three positive-HP receipts")
    if len(judgment["cast_cues"]) != 3 or len(judgment["impact_cues"]) != 3:
        raise RuntimeError("Judgment cast/actual reception cues are not independently represented")
    successful = {r["event"] for r in damage}
    for origin in ("P24", "P14", "G16"):
        impacts = [c for c in data["art_cues"] if c["kind"] == "item_committed_impact" and c["origin"] == origin]
        if not impacts or any(not c["clip"] or c["event_id"] not in successful for c in impacts):
            raise RuntimeError("Reception art lacks its actual positive-HP receipt: " + origin)
    old_final = [r for r in observed if r["phase"] == "result"]
    final = [r for r in observed if r["phase"] == "golden_result"]
    if not old_final or any(r["resonance"] != 0 or set(r["equipped"]) != {"P24", "G15", "P14"} for r in old_final):
        raise RuntimeError("First actual golden final state differs from the original35-cost flow")
    if not final or any(r["resonance"] != 5 or set(r["equipped"]) != {"G16", "P14"} or r["gear"]["used"] != 7 for r in final):
        raise RuntimeError("Second actual golden loadout/resources do not remain consistent")
    delivery = data["equipment_delivery"]
    funding = [e for e in events if e["kind"] == "explicit_upgrade_coin_fixture"]
    if len(funding) != 1 or funding[0]["amount"] != delivery["price"] or funding[0]["after"]-funding[0]["before"] != delivery["price"]:
        raise RuntimeError("Final upgrade coin setup is missing, undisclosed or inconsistent")
    if not (delivery["equipped_hp_max"] > delivery["base_hp_max"] == delivery["removed_hp_max"] and delivery["capacity_after"] == delivery["capacity_before"]+2 and delivery["coins_before_purchase"]-delivery["coins_after_purchase"] == delivery["price"]):
        raise RuntimeError("Native HP equip/unload or exact capacity purchase did not commit")
    hp_equipped_rows = [r for r in observed if r["phase"] == "hp_equipped"]
    hp_removed_rows = [r for r in observed if r["phase"] == "hp_removed"]
    if not hp_equipped_rows or any(set(r["equipped"]) != {"B11"} or r["hp_max"] != delivery["equipped_hp_max"] or r["hp"] != delivery["hp_current"] for r in hp_equipped_rows):
        raise RuntimeError("Actually drawn HP-equipped trace lacks real B11 maximum or grants free health")
    if not hp_removed_rows or any(r["equipped"] or r["hp_max"] != delivery["base_hp_max"] or r["hp"] != delivery["hp_current"] for r in hp_removed_rows):
        raise RuntimeError("Actually drawn HP-unloaded trace retains item effects or grants free health")
    upgrade_rows = [r for r in observed if r["phase"] == "gear_expanded"]
    if not upgrade_rows or any(r["equipped"] or r["gear"]["capacity"] != delivery["capacity_after"] or "非自然收益" not in r["fixture_note"] for r in upgrade_rows):
        raise RuntimeError("Final upgrade displays stale effects, wrong capacity or undisclosed coin setup")
    if not data["final_artist"]["library"]["valid"] or data["final_artist"]["library"]["last_error"]:
        raise RuntimeError("Golden resource registry has a missing-art diagnosis")
    # Select an already drawn, visibly present rotor frame, not the old early
    # entity-presence sample. Independent reviewers still inspect the pixels.
    return {"twins": twins[min(6, len(twins)-1)], "patrols": patrols[len(patrols)//2],
            "judgment": pulses[min(4, len(pulses)-1)]}


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
    required = {DRIVER, "tools/capture_item_art_golden.py", "game/application/demo_app.gd",
                "game/loadout/effects/item_runtime.gd", "game/loadout/effects/item_active_effects.gd", "tests/item_v5_movie.gd",
                "game/loadout/effects/item_art_library.gd", "game/loadout/effects/item_effect_view.gd",
                "game/loadout/effects/item_v5_entity.gd", "config/item_v5_art.json",
                "config/item_v5_authoring.json", "assets/items/v5/manifest.json",
                "game/loadout/effects/item_companion_effects.gd", "game/loadout/effects/item_v5_entity.gd",
                "config/items_v5.json", "config/item_v5_runtime.json", "config/item_v5_entities.json",
                "game/presentation/ui/demo_menu.gd", "game/presentation/ui/stage_reward_modal.gd",
                "game/presentation/ui/item_shop_modal.gd", "game/presentation/ui/item_v5_shop_presenter.gd",
                "game/player/player_controller.gd", "game/combat/projectiles/player_projectile.gd",
                "game/combat/damage/frame_damage_policy.gd", "game/platform/input/input_router.gd",
                "game/platform/input/keyboard_mouse_adapter.gd"}
    if not required.issubset(before):
        raise RuntimeError("Original source guard does not cover all real producer/runtime/UI dependencies")
    report = {"schema": "item-art-golden-capture-v1", "source_commit": commit,
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
        matches = re.findall(r"^ITEM ART GOLDEN MOVIE: ([1-9]\d*) frames, ([1-9]\d*) assertions, 0 failures$", output, re.M)
        if len(matches) != 1:
            raise RuntimeError("Actual recording lacks its one exact successful completion marker")
        frames, checks = map(int, matches[0])
        data = json.loads((target / "trace.json").read_text())
        art_samples = validate_trace(data, frames, checks)
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
        if not 35 <= seconds <= 60:
            raise RuntimeError("Actual continuous golden recording must last 35–60 seconds")
        samples = [(p["id"], p, 18 if p["id"] == "fixture_loadout" else 25)
                   for p in data["checkpoints"] if p["id"] in {
                       "title", "home_walk", "departure", "cache_choice", "backpack",
                       "fixture_loadout", "equipped", "training", "result",
                       "judgment_equipped", "judgment_cast", "golden_result", "hp_equipped", "hp_removed", "gear_expanded"}]
        samples.extend((name, point, 0) for name, point in art_samples.items())
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
        print("PASS: actual formal item-art golden movie, disclosed setup fixtures, original audio, strict clean exit and stable sources")
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
        print("Item art golden movie failed: " + str(error), file=sys.stderr)
        sys.exit(1)
