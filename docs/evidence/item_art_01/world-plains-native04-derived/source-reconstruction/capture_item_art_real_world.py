#!/usr/bin/env python3
"""Original-engine supplementary real-world art capture, exclusive lease required.

No new engine framework or longer budgets. All production source folders use the
original capture_run_gear inventory. Both committed producers are additionally
hashed explicitly and remain covered by the original full source guard.
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

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from capture_run_gear import FOLDERS, git, inventory, sha
from run_tests import run_engine
from run_underworld_home_tests import Tee

DRIVER = "tests/item_art_real_world_movie.gd"
WATERMARK = "美术验证：道具/共鸣/站位为测试初始化"
SCOPE = ("Actual current formal Plains/Forest map1, original EnemyActor AI, real "
         "terrain, original saw/thorns, normal original camera and HUD. Disclosed "
         "known item/equipment, one35/65resonance grant, one initial pose. Actual "
         "native R/pointer-aim/jump inputs. No fake targets/floor/enemyHP writes/AI overrides. "
         "Supplemental visual world clip, not natural progression/device/listening acceptance.")


def validate(data, frames, checks, region, *, probe=False):
    if data.get("schema") != "item-art-real-world-v1" or data.get("region") != region:
        raise RuntimeError("Wrong trace identity or region")
    if data.get("failures") or data["checks"] != checks or len(data["frames"]) != frames:
        raise RuntimeError("Native completion marker and actual trace disagree")
    setup = data["setup"]
    if setup.get("natural_progression") is not False or setup.get("watermark") != WATERMARK:
        raise RuntimeError("Disclosed fixture boundary is absent")
    if setup.get("training_objects_created") != 0 or setup.get("enemy_or_hazard_mutations") != 0:
        raise RuntimeError("This supplement forbids replacement targets/terrain/AI fixtures")
    if probe:
        return {"candidates": len(setup["candidates"]), "observations": "candidate probe only, no art motion acceptance"}
    if setup.get("player_pose_assignments") != 1 or not setup.get("selected"):
        raise RuntimeError("Exactly one collision-validated initial pose is required")
    required = {"P24", "G15", "P14"} if region == "plains" else {"G16", "P14"}
    rewards = [e for e in data["input_events"] if e["kind"] == "explicit_known_reward_fixture"]
    if {e["id"] for e in rewards} != required or len(rewards) != len(required):
        raise RuntimeError("Original reward fixtures differ from declared sample loadout")
    grant = 35 if region == "plains" else 65
    if setup.get("energy_before_fixture") != 0 or setup.get("energy_granted") != grant or setup.get("energy_after_fixture") != grant:
        raise RuntimeError("Only the one disclosed initial resonance grant is allowed")
    start, end = data["world_begin_drawn"], data["world_end_drawn"]
    observations = [r for r in data["frames"] if start < r["drawn_frame"] <= end]
    if not 600 <= end-start <= 900 or not observations:
        raise RuntimeError("Observed world segment must be10–15 normal60fps seconds")
    if any(r["fixture_note"] != WATERMARK or r["paused"] or not r["formal_region"] for r in observations):
        raise RuntimeError("World clip lost its disclosure/actual playing state")
    if any(r.get("application_focus") is not True for r in observations):
        raise RuntimeError("Focus loss invalidates native action evidence")
    if len({(r["session"],r["actor_epoch"],r["stage_epoch"]) for r in observations}) != 1:
        raise RuntimeError("A death/environment return/stage replacement invalidates this candidate")
    if any("movie_fixture" in r["target"] for r in data["damage_receipts"]):
        raise RuntimeError("Forbidden training fixture target observed")
    originals = {a["target"] for a in setup["initial_actors"]}
    selected = setup["selected"]["target"]
    if selected not in originals:
        raise RuntimeError("Selected receiver is not an original EnemyActor")
    damaging = [r for r in data["damage_receipts"] if r["damage"] > 0 and r["derived"]]
    if not damaging or any(r["target"] not in originals for r in damaging):
        raise RuntimeError("Authored hit presentation needs actual original EnemyActor HP loss")
    live = [a for r in observations for a in r["targets"] if not a["terminal"]]
    if not live or any(not a["physics_enabled"] or not a["collision_layer"] for a in live):
        raise RuntimeError("Live original enemies must retain active AI/collision")
    if not any(r["hazards"] for r in observations):
        raise RuntimeError("No original visible hazard observations")
    active = "P24" if region == "plains" else "G16"
    authored = [(r,e) for r in observations for e in r.get("entities", [])
                if e.get("artist",{}).get("origin") == active and e["artist"].get("art_draws",0) > 0]
    patrol = [(r,e) for r in observations for e in r.get("entities", [])
              if e.get("artist",{}).get("origin") == "P14" and e["artist"].get("art_draws",0) > 0]
    if not authored or not patrol:
        raise RuntimeError("Actual post-draw sample active/patrol art is absent")
    events = {r["event"] for r in damaging}
    impacts = [c for c in data["art_cues"] if c["kind"] == "item_committed_impact" and c["origin"] in {active,"P14"}]
    if not impacts or any(not c["clip"] or c["event_id"] not in events for c in impacts):
        raise RuntimeError("Impact art is not backed by a real positive-HP EnemyActor receipt")
    r_presses = [e for e in data["input_events"] if e["kind"] == "key" and e["key"] == "R" and e["pressed"]]
    if len(r_presses) != 1:
        raise RuntimeError("The sample requires exactly one original native R activation")
    return {"first_active_draw":authored[0][0]["drawn_frame"],
            "last_active_draw":authored[-1][0]["drawn_frame"],
            "first_patrol_draw":patrol[0][0]["drawn_frame"],
            "actual_damage_receipts":damaging,"actual_impacts":impacts,
            "world_frames":end-start,
            "qualitative_review":"UNVERIFIED: inspect real pixels/motion for player, telegraphs, hazards, landings and UI; source counters do not sign occlusion"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output",required=True)
    parser.add_argument("--region",choices=["plains","thorn_forest"],required=True)
    parser.add_argument("--seed")
    parser.add_argument("--source-commit",default="HEAD")
    parser.add_argument("--display",default=":101")
    parser.add_argument("--development",action="store_true")
    parser.add_argument("--probe",action="store_true")
    parser.add_argument("--plan",action="store_true")
    args = parser.parse_args()
    target = Path(args.output).resolve()
    if not target.is_relative_to(ROOT / "build") or target.exists():
        raise RuntimeError("Use a NEW directory under build; preserve prior failures")
    commit = git("rev-parse",args.source_commit+"^{commit}")
    selectors = ["project.godot","export_presets.cfg",*FOLDERS]
    dirty = git("diff","--name-only",commit,"--",*selectors).splitlines()
    untracked = git("ls-files","--others","--exclude-standard","--",*selectors).splitlines()
    if not args.development and (dirty or untracked):
        raise RuntimeError("Final source must be clean/committed: "+", ".join(dirty+untracked))
    seed = args.seed or ("level-design-v2-baseline/08" if args.region == "plains" else "forest-depth-hollow-00")
    trace = "res://"+(target/"trace.json").relative_to(ROOT).as_posix()
    argv = ["--path",".","--rendering-method","gl_compatibility","--audio-driver","Dummy",
            "--resolution","1280x720","--write-movie",str(target/"raw.avi"),"--fixed-fps","60",
            "--script",DRIVER,"--","--trace="+trace,"--region="+args.region,"--seed="+seed]
    if args.probe: argv.append("--probe")
    if args.plan:
        print(json.dumps({"argv":argv,"source_commit":commit,"development":args.development,
                          "scope":SCOPE,"executed":False},ensure_ascii=False,indent=2))
        return
    target.mkdir(parents=True)
    os.environ["DISPLAY"] = args.display
    os.environ["LIBGL_ALWAYS_SOFTWARE"] = "1"
    os.environ.setdefault("LP_NUM_THREADS","1")
    before = inventory()
    # Both promoted producer files are covered by original FOLDERS inventory.
    # Retain their explicit identities as well as the whole-source snapshot.
    producers = {p.relative_to(ROOT).as_posix():sha(p) for p in [ROOT/DRIVER,Path(__file__).resolve()]}
    report = {"schema":"item-art-real-world-capture-v1","status":"failed","source_commit":commit,
              "head":git("rev-parse","HEAD"),"producer_inputs":producers,"development":args.development,
              "dirty_paths":dirty+untracked,"scope":SCOPE,"region":args.region,"seed":seed,
              "source_before":before,"argv":["bash","tools/godot.sh",*argv],
              "audio_policy":"Original game Dummy backend stereo48k; physical sound/listening unverified"}
    started = time.monotonic()
    try:
        with (target/"capture.log").open("w") as log, contextlib.redirect_stdout(Tee(sys.stdout,log)):
            output = run_engine(argv,300)
        report["engine_exit_code"] = 0
        if re.search(r"SCRIPT ERROR:|SHADER ERROR:|(?m:^ERROR:)|ObjectDB.*leaked|resources? still in use at exit",output):
            raise RuntimeError("Engine error or live native resource leak")
        matches = re.findall(r"^ITEM ART REAL WORLD: ([1-9]\d*) frames, ([1-9]\d*) assertions, 0 failures$",output,re.M)
        if len(matches) != 1: raise RuntimeError("Missing exact native successful completion marker")
        frames, checks = map(int,matches[0])
        data = json.loads((target/"trace.json").read_text())
        samples = validate(data,frames,checks,args.region,probe=args.probe)
        if inventory() != before: raise RuntimeError("Original full source inventory drifted")
        if any(sha(ROOT/p) != digest for p,digest in producers.items()):
            raise RuntimeError("Committed producer changed during capture")
        report.update(samples=samples,frames=frames,assertions=checks)
        if not args.probe:
            start = max(0,data["world_begin_drawn"])
            end = data["world_end_drawn"]
            # Exact continuous actual frame range; original audio uses the same
            # sample-time interval. Full raw movie/trace remain as setup evidence.
            vf = f"trim=start_frame={start}:end_frame={end},setpts=PTS-STARTPTS"
            af = f"atrim=start={start/60}:end={end/60},asetpts=PTS-STARTPTS"
            with (target/"encode.log").open("w") as log:
                subprocess.run(["ffmpeg","-y","-i",str(target/"raw.avi"),"-vf",vf,"-af",af,
                                "-c:v","libx264","-crf","20","-pix_fmt","yuv420p","-c:a","aac",
                                "-ar","48000","-ac","2","-movflags","+faststart",str(target/"world.mp4")],
                               stdout=subprocess.DEVNULL,stderr=log,check=True,timeout=150)
            media = json.loads(subprocess.check_output(["ffprobe","-v","error","-show_streams","-show_format","-of","json",str(target/"world.mp4")],timeout=30))
            video = next(s for s in media["streams"] if s["codec_type"] == "video")
            audio = [s for s in media["streams"] if s["codec_type"] == "audio"]
            if video["codec_name"] != "h264" or video["avg_frame_rate"] != "60/1" or (video["width"],video["height"]) != (1280,720):
                raise RuntimeError("Actual derivative is not H264 normal60fps1280x720")
            if len(audio)!=1 or audio[0]["sample_rate"]!="48000" or audio[0]["channels"]!=2:
                raise RuntimeError("Original game stereo48k audio is absent")
            if not 10 <= float(media["format"]["duration"]) <= 15.1:
                raise RuntimeError("Actual continuous world segment duration is outside10–15s")
            images=[]
            for name,draw in [("active",samples["first_active_draw"]+6),("world_observe",end-60)]:
                clip_frame = max(0,min(end-start-1,draw-1-start))
                path=target/(name+".png")
                subprocess.run(["ffmpeg","-y","-i",str(target/"world.mp4"),"-vf",f"select=eq(n\\,{clip_frame})","-frames:v","1",str(path)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,check=True,timeout=30)
                if not path.exists(): raise RuntimeError("Actual observation frame absent")
                images.append({"path":path.name,"sha256":sha(path),"world_video_frame":clip_frame,"original_drawn_frame":draw})
            report.update(media=media,images=images,segment={"original_start_frame":start,"original_end_exclusive":end,"frames":end-start,"continuous":True})
        report["status"] = "probe_captured" if args.probe else ("development_captured" if args.development else "captured")
        report["artifacts"] = {p.name:sha(p) for p in target.iterdir() if p.is_file()}
        print("PASS: real formal world supplement; qualitative art review remains separate")
    except Exception as error:
        report["error"] = type(error).__name__+": "+str(error)
        raise
    finally:
        report["wall_seconds"] = time.monotonic()-started
        report["source_after"] = inventory()
        report["source_stable"] = before == report["source_after"]
        (target/"receipt.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n")

if __name__ == "__main__":
    try: main()
    except (OSError,RuntimeError,subprocess.SubprocessError) as error:
        print("Real-world art capture failed: "+str(error),file=sys.stderr)
        sys.exit(1)
