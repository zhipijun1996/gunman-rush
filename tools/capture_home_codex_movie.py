#!/usr/bin/env python3
"""Capture one continuous actual Home codex/notes/carry/equipment route.

Exclusive native/GL lease required. KnownB11 ownership,50notes and two Home
positions are disclosed fixtures. Original full source guard and budgets remain.
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

DRIVER = "tests/home_codex/home_codex_movie.gd"
DISCLOSURE = "已知B11/音符50/家园站位为测试初始化，非自然掉落"
PHASES = {"formal_known_reward","reward_committed","return_home","home_relics",
          "unknown","discovered","unlocked","selected","departure",
          "carried_in_bag","backpack","equipped","removed","result"}
SCOPE = ("Continuous actual DemoApp formal knownB11 RewardService acquisition/toast, "
         "original journey/end/Home/relicsW/codex unlock and carry native UI, original "
         "Home departure into a new formal run, oneLv1inactivebag/nativeequip/unequip. "
         "Known reward,50notes and two Home actor positions are explicit setup; not "
         "natural random drops/traversal, physical device or listening acceptance. "
         "No direct discovery/unlock/select/HP writes. Isolated memory-only profile.")


def validate_trace(data, frames, checks):
    if data.get("schema") != "home-codex-native-movie-v1" or data.get("fixture_note") != DISCLOSURE:
        raise RuntimeError("Wrong actual Home codex trace identity/disclosure")
    rows=data["frames"]
    if data["failures"] or data["checks"] != checks or len(rows) != frames or checks < 55:
        raise RuntimeError("Native completion marker/required checks/observations disagree")
    if any(b["drawn_frame"]<=a["drawn_frame"] for a,b in zip(rows,rows[1:])):
        raise RuntimeError("Actual post-draw observations are not monotonic")
    if any(r["fixture_note"] != DISCLOSURE for r in rows):
        raise RuntimeError("Continuous fixture disclosure disappeared")
    points=data["checkpoints"]
    if len(points) != len(PHASES) or {p["id"] for p in points} != PHASES:
        raise RuntimeError("Continuous original reward/Home/codex/carry/equipment phases incomplete")
    events=data["input_events"]
    rewards=[e for e in events if e["kind"]=="explicit_known_reward_fixture"]
    if len(rewards)!=1 or rewards[0]["id"]!="B11":
        raise RuntimeError("Only the disclosed one original knownB11 reward fixture is allowed")
    notes=[e for e in events if e["kind"]=="explicit_notes_fixture"]
    if len(notes)!=1 or notes[0]["amount"]!=50 or not data["notes_fixture_result"].get("accepted"):
        raise RuntimeError("Original single50note setup receipt is missing")
    poses=[e for e in events if e["kind"]=="explicit_home_position_fixture"]
    if [p["slot"] for p in poses] != ["relics","departure"]:
        raise RuntimeError("Exactly the two disclosed original Home positions are allowed")
    if any(e["kind"] in {"explicit_training_fixture","explicit_cache_position_fixture"} for e in events):
        raise RuntimeError("This Home movie must not create training targets/platforms or change chests")
    receipts=data["ownership_receipts"]
    if len(receipts)!=1 or receipts[0]["status"]!=0 or receipts[0]["item_id"]!="B11" or not receipts[0]["instance_id"]:
        raise RuntimeError("Known acquisition lacks its actual committed RewardService receipt")
    if receipts[0]["run_id"]!=data["first_run"] or "B11" not in receipts[0]["meta_after_original_observer"]["discovered_items"]:
        raise RuntimeError("Discovery is not tied to the original current-run acquisition observer")
    if data["first_run"]==data["second_run"] or not data["first_run"] or not data["second_run"]:
        raise RuntimeError("Actual end/Home/new-departure run boundary is missing")
    profiles={s["label"]:s for s in data["profile_steps"]}
    if set(profiles)!={"discovered_from_committed_reward","native_unlock","native_select_carry","final_permanent_state"}:
        raise RuntimeError("Actual profile transition snapshots incomplete")
    discovered=profiles["discovered_from_committed_reward"]["snapshot"]
    if discovered["discovered_items"] != ["B11"] or discovered["unlocked_home_items"] or discovered["notes"]!=50:
        raise RuntimeError("Known acquisition must discover onlyB11 without unlocking/spending")
    final=data["final_meta"]
    delivery=data["delivery"]
    if final["discovered_items"] != ["B11"] or final["unlocked_home_items"] != ["B11"] or final["selected_home_item"]!="B11":
        raise RuntimeError("Final authoritative permanent selection differs from native UI route")
    if delivery["notes_before"]!=50 or delivery["unlock_price"]<=0 or delivery["notes_after"]!=50-delivery["unlock_price"] or final["notes"]!=delivery["notes_after"]:
        raise RuntimeError("Original configured notes debit or free carry-selection semantics changed")
    actual=list(profiles["final_permanent_state"]["actual_backend_receipts"].values())
    for kind in ["home_unlock","home_select","item_discovery"]:
        found=[r for r in actual if r["kind"]==kind]
        if len(found)!=1 or found[0]["item_id"]!="B11":
            raise RuntimeError("Actual backend transaction identity missing or duplicated: "+kind)
    carry=delivery["carry"]
    if len(carry)!=1 or carry[0]["id"]!="B11" or carry[0]["level"]!=1 or carry[0]["equipped"] or not carry[0]["source"].startswith("home_carry/") or carry[0]["instance"]==receipts[0]["instance_id"]:
        raise RuntimeError("New run Home carry must be one new inactiveLv1instance with its original source")
    manifests=delivery["run_manifest"].get("stages",[])
    grants=[s["outputs"]["home_item_carry"] for s in manifests if "home_item_carry" in s.get("outputs",{})]
    if len(grants)!=1 or grants[0]["definition_id"]!="B11" or grants[0]["instance_id"]!=carry[0]["instance"] or grants[0]["level"]!=1 or grants[0]["equipped"]:
        raise RuntimeError("Original RunManifest does not confirm exactly one inactive Home grant")
    if (delivery["base_hp_max"],delivery["equipped_hp_max"],delivery["removed_hp_max"])!=(5,6,5):
        raise RuntimeError("Actual native B11 equipment maxHP5→6→5 transaction differs")
    if delivery["equipped_hp_current"]!=5 or delivery["removed_hp_current"]!=5:
        raise RuntimeError("Native equipment switching granted free currentHP")
    unknown=[r for r in rows if r["phase"]=="unknown"]
    if not unknown or not all(r.get("codex_opened") and r.get("paused") and r.get("home_input_blocked") and r.get("codex_focused")=="B03" for r in unknown):
        raise RuntimeError("Unknown detail was not shown in the actual paused blocking Home UI")
    if len([e for e in events if e["kind"]=="key" and e["key"]=="W" and e["pressed"]])!=2:
        raise RuntimeError("Actual relics/departure nativeW inputs are missing")
    if not any(e["kind"]=="mouse" and e["pressed"] for e in events):
        raise RuntimeError("Native UI pointer input is absent")
    return {"notes_price":delivery["unlock_price"],"notes_after":final["notes"],
            "max_hp":[5,6,5],"current_hp":[5,5],"phase_count":len(points),
            "physical_device_and_listening":"UNVERIFIED"}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output",required=True)
    parser.add_argument("--source-commit",default="HEAD")
    parser.add_argument("--display",default=":101")
    parser.add_argument("--development",action="store_true")
    parser.add_argument("--plan",action="store_true")
    args=parser.parse_args()
    target=Path(args.output).resolve()
    if not target.is_relative_to(ROOT/"build") or target.exists():
        raise RuntimeError("Use a NEW directory below build; keep prior captures/failures")
    commit=git("rev-parse",args.source_commit+"^{commit}")
    selectors=["project.godot","export_presets.cfg",*FOLDERS]
    dirty=git("diff","--name-only",commit,"--",*selectors).splitlines()
    untracked=git("ls-files","--others","--exclude-standard","--",*selectors).splitlines()
    if not args.development and (dirty or untracked):
        raise RuntimeError("Final capture requires committed frozen producers/runtime: "+", ".join(dirty+untracked))
    trace="res://"+(target/"trace.json").relative_to(ROOT).as_posix()
    argv=["--path",".","--rendering-method","gl_compatibility","--audio-driver","Dummy",
          "--resolution","1280x720","--write-movie",str(target/"raw.avi"),"--fixed-fps","60",
          "--script",DRIVER,"--","--trace="+trace]
    if args.plan:
        print(json.dumps({"argv":argv,"source_commit":commit,"development":args.development,"scope":SCOPE,"executed":False},ensure_ascii=False,indent=2));return
    target.mkdir(parents=True)
    os.environ["DISPLAY"]=args.display
    os.environ["LIBGL_ALWAYS_SOFTWARE"]="1"
    os.environ.setdefault("LP_NUM_THREADS","1")
    before=inventory()
    required={DRIVER,"tools/capture_home_codex_movie.py","tests/item_v5_movie.gd",
              "scripts/demo/demo_app.gd","scripts/demo/home_scene.gd","scripts/ui/home_item_codex.gd",
              "scripts/meta/meta_progression.gd","scripts/meta/home_item_catalog.gd","config/home_items.json",
              "scripts/rewards/reward_service.gd","scripts/builds/equipment_service.gd",
              "scripts/ui/demo_menu.gd","scripts/ui/item_card.gd","scripts/ui/item_presentation.gd",
              "scripts/input/input_router.gd","scripts/input/keyboard_mouse_adapter.gd"}
    if not required.issubset(before): raise RuntimeError("Original full source guard misses a real Home producer/runtime/UI dependency")
    report={"schema":"home-codex-native-capture-v1","status":"failed","source_commit":commit,"head":git("rev-parse","HEAD"),
            "development":args.development,"dirty_paths":dirty+untracked,"scope":SCOPE,"source_before":before,
            "argv":["bash","tools/godot.sh",*argv],"engine_exit_code":None,
            "audio_policy":"Original game48k stereo viaDummybackend; physical output/listening acceptance unverified"}
    started=time.monotonic()
    try:
        with (target/"capture.log").open("w") as log,contextlib.redirect_stdout(Tee(sys.stdout,log)):
            output=run_engine(argv,300)
        report["engine_exit_code"]=0
        if re.search(r"SCRIPT ERROR:|SHADER ERROR:|(?m:^ERROR:)|ObjectDB.*leaked|resources? still in use at exit",output):
            raise RuntimeError("Actual Home movie emitted an engine error or native leak")
        matches=re.findall(r"^HOME CODEX MOVIE: ([1-9]\d*) frames, ([1-9]\d*) assertions, 0 failures$",output,re.M)
        if len(matches)!=1: raise RuntimeError("Missing exact successful Home movie completion marker")
        frames,checks=map(int,matches[0]);data=json.loads((target/"trace.json").read_text())
        observed=validate_trace(data,frames,checks)
        if inventory()!=before: raise RuntimeError("Production source drifted during native recording")
        with (target/"encode.log").open("w") as log:
            subprocess.run(["ffmpeg","-y","-i",str(target/"raw.avi"),"-r","60","-fps_mode","cfr",
                            "-c:v","libx264","-crf","20","-pix_fmt","yuv420p","-c:a","aac","-ar","48000","-ac","2",
                            "-movflags","+faststart",str(target/"movie.mp4")],check=True,stdout=subprocess.DEVNULL,stderr=log,timeout=150)
        media=json.loads(subprocess.check_output(["ffprobe","-v","error","-show_streams","-show_format","-of","json",str(target/"movie.mp4")],timeout=30))
        video=next(s for s in media["streams"] if s["codec_type"]=="video");audio=[s for s in media["streams"] if s["codec_type"]=="audio"]
        if video["codec_name"]!="h264" or video["avg_frame_rate"]!="60/1" or (video["width"],video["height"])!=(1280,720):
            raise RuntimeError("Actual output is not1280x720 H264 normal60fps")
        if len(audio)!=1 or audio[0]["codec_name"]!="aac" or audio[0]["sample_rate"]!="48000" or audio[0]["channels"]!=2:
            raise RuntimeError("Original game48k stereo audio is absent")
        seconds=float(media["format"]["duration"])
        if not 20<=seconds<=35: raise RuntimeError("Continuous Home movie must last20–35normal seconds")
        images=[]
        for point in data["checkpoints"]:
            movie_frame=max(0,int(point["drawn_frame"])-1+30)
            path=target/(point["id"]+".png")
            subprocess.run(["ffmpeg","-y","-i",str(target/"movie.mp4"),"-vf",f"select=eq(n\\,{movie_frame})","-frames:v","1",str(path)],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=30)
            if not path.is_file(): raise RuntimeError("Actual observation frame is absent: "+point["id"])
            images.append({"path":path.name,"sha256":sha(path),"movie_frame":movie_frame,"movie_time_s":movie_frame/60,"phase":point["id"]})
        report.update(status="development_captured" if args.development else "captured",frames=frames,assertions=checks,seconds=seconds,observed=observed,media=media,images=images,artifacts={p.name:sha(p) for p in target.iterdir() if p.is_file()})
        if inventory()!=before: raise RuntimeError("Production source drifted during actual media validation")
        print("PASS: continuous actual Home codex/notes/carry/equipment movie; explicit fixtures, original audio and stable sources")
    except Exception as error:
        report["status"]="failed";report["error"]=type(error).__name__+": "+str(error);raise
    finally:
        report["wall_seconds"]=time.monotonic()-started
        report["source_after"]=inventory()
        report["source_stable"]=before==report["source_after"]
        (target/"receipt.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n")

if __name__=="__main__":
    try: main()
    except (OSError,RuntimeError,subprocess.SubprocessError) as error:
        print("Home codex movie failed: "+str(error),file=sys.stderr);sys.exit(1)
