#!/usr/bin/env python3
"""Capture real three-tier chest transactions or explicit six-state region galleries.

Requires the exclusive native/GL lease. Original full source inventory and native
300s/encode150s budgets are unchanged. Failures/raw captures are retained.
"""
from pathlib import Path
import argparse,contextlib,json,os,re,subprocess,sys,time
from capture_run_gear import ROOT,FOLDERS,git,inventory,sha
from run_tests import run_engine
from run_underworld_home_tests import Tee
DRIVER="tests/chest_art/chest_art_movie.gd"
CLAIM_DISCLOSURE="宝箱站位/镜头为测试初始化；正式原箱领取，非自然路线"
GALLERY_DISCLOSURE="六态仅美术显示初始化；非自然箱子分布或领取"
TIERS=("medium","high","region_top")
SCOPE=("Actual original formal chestIDs and tiers, original nativeW/reward buttons, "
       "COMMITTED ownership/coin receipts and original scene reload. Only actor "
       "positions/original observation_focus camera are initialized. No HP/AI/coins/"
       "tier/RNG rescue. Separate gallery mode creates explicitly visual-only nodes/"
       "rows, never natural all-tier spawn or rewards. Static closed/open poses, "
       "not an opening-animation/physical-device/listening acceptance claim.")


def phases(mode):
    if mode=="gallery": return {"gallery_1280x720","gallery_960x540"}
    tiers=TIERS if mode=="plains" else ("high",)
    return {"plains_ready" if mode=="plains" else "forest_ready","reload_ready",
            *(t+"_"+s for t in tiers for s in ("closed","offer","open","reloaded"))}


def target(row,identifier):
    found=[c for c in row["chests"] if c["id"]==identifier]
    if len(found)!=1: raise RuntimeError("Original chestID missing/duplicated in actual observation")
    return found[0]


def validate(data,frames,checks,mode,region):
    if data.get("schema")!="chest-art-native-movie-v1" or data.get("mode")!=mode:
        raise RuntimeError("Wrong actual chest trace/mode")
    rows=data["frames"];points=data["checkpoints"]
    minimum=65 if mode=="plains" else 25 if mode=="forest" else 20
    if data["failures"] or data["checks"]!=checks or len(rows)!=frames or checks<minimum:
        raise RuntimeError("Actual completion marker/required assertions/post-draw observations disagree")
    if len(points)!=len(phases(mode)) or {p["id"] for p in points}!=phases(mode):
        raise RuntimeError("Missing or duplicate original post-draw checkpoints")
    if mode=="plains" and len(points)!=14: raise RuntimeError("Three-tier formal movie requires all14actual post-draw phases")
    by_draw={r["drawn_frame"]:r for r in rows}
    for p in points:
        if not p.get("observed_post_draw") or p["drawn_frame"] not in by_draw or by_draw[p["drawn_frame"]]["phase"]!=p["id"]:
            raise RuntimeError("A completion checkpoint lacks its actual same-phase post-draw frame")
    if any(b["drawn_frame"]<=a["drawn_frame"] for a,b in zip(rows,rows[1:])):
        raise RuntimeError("Post-draw observations are not monotonic")
    disclosure=GALLERY_DISCLOSURE if mode=="gallery" else CLAIM_DISCLOSURE
    if data["fixture_note"]!=disclosure or any(r["fixture_note"]!=disclosure for r in rows):
        raise RuntimeError("Explicit position/gallery disclosure disappeared")
    if not data["art"].get("valid") or data["art"]["rgba8_bytes"]>data["art"]["budget_bytes"]:
        raise RuntimeError("Actual admitted chest registry/unchanged separate atlas budget failed")
    if mode=="gallery":
        images=data["gallery_images"]
        if len(images)!=2 or {tuple(i["viewport"]) for i in images}!={(1280,720),(960,540)}:
            raise RuntimeError("Both actual gallery viewports are required")
        if data["committed_receipts"] or data["final_owned"]:
            raise RuntimeError("Visual gallery must not fabricate chest ownership/claims")
        for image in images:
            if not image.get("visual_only") or not image["original_manifest_unchanged"] or image["actual_reward_receipts"]!=0:
                raise RuntimeError("Gallery fixture crossed the original Manifest/reward boundary")
            poses=image["poses"]
            if {(p["tier"],p["claimed_visual_fixture"]) for p in poses}!={(t,s) for t in TIERS for s in (False,True)} or len(poses)!=6:
                raise RuntimeError("All six explicit visual poses are required")
            for tier in TIERS:
                factors={p["factor"] for p in poses if p["tier"]==tier}
                if len(factors)!=1: raise RuntimeError("Same-tier closed/open must preserve the original common scale")
            if any(p["actual_renderer"]!=("ChestArtLayer" if region=="thorn_forest" else "Sprite2D") for p in poses):
                raise RuntimeError("Gallery bypassed the real regional rendering consumer")
        return {"gallery_screens":images,"claim_scope":"visual fixture only; no natural all-tier claim"}
    cases=data["cases"];receipts=data["committed_receipts"]
    expected=3 if mode=="plains" else 1
    if len(cases)!=expected or len(receipts)!=expected or len(data["selected_ids"])!=expected:
        raise RuntimeError("Actual original chest transactions are missing/duplicated")
    if [c["tier"] for c in cases]!=(list(TIERS) if mode=="plains" else ["high"]):
        raise RuntimeError("Actual natural tiers differ from declared main/Forest scope")
    expected_suffixes=("plains/chest/medium_0","plains/chest/high","plains/chest/region_top") if mode=="plains" else ("outer_cross_cache",)
    for case,suffix in zip(cases,expected_suffixes):
        identifier=case["id"];receipt=case["receipt"]
        if not identifier.endswith(suffix) or receipt["event_id"]!=identifier+"/claim" or receipt["status"]!=0 or receipt["chest_id"]!=identifier or not receipt["instance_id"]:
            raise RuntimeError("Original COMMITTED reward receipt does not match the actual chest/choice")
        if case["after"]["wallet"]-case["before"]["wallet"]!=case["configured_coins"]:
            raise RuntimeError("Original configured chest coin credit changed")
        owned=[o for o in case["after"]["owned"] if o["instance"]==receipt["instance_id"]]
        if len(owned)!=1 or owned[0]["id"]!=receipt["item_id"]:
            raise RuntimeError("Actual accepted chest receipt lacks real inventory ownership")
        for suffix_state,claimed in (("closed",False),("offer",False),("open",True),("reloaded",True)):
            phase=case["tier"]+"_"+suffix_state
            observed=[r for r in rows if r["phase"]==phase]
            if not observed: raise RuntimeError("Actual required chest state is absent: "+phase)
            for row in observed:
                chest=target(row,identifier)
                if chest["claimed"]!=claimed or chest["in_claim_ledger"]!=claimed:
                    raise RuntimeError("Completion label was applied before actual chest/ledger state")
                if suffix_state=="offer" and (not row["paused"] or not row["reward_opened"]):
                    raise RuntimeError("Offer phase lacks the actual blocking original reward modal")
                if claimed and row["drawn_frame"]<=receipt["drawn_frame"]:
                    raise RuntimeError("Open art was labeled before accepted original ownership")
                if mode=="plains":
                    actual=chest.get("actual_sprite",{})
                    if not actual.get("visible") or not actual.get("managed") or not actual.get("matches_actual_state_texture") or not actual.get("material_is_original") or actual.get("state")!=("open" if claimed else "closed") or actual.get("modulate")!=[1,1,1,1]:
                        raise RuntimeError("Actual formal Sprite2D diverges from the accepted source/state")
                elif not row.get("forest_layer",{}).get("bound_original_rows") or not row["forest_layer"]["material_is_original"]:
                    raise RuntimeError("Default Forest chest layer lost its original row/material binding")
    baseline=data["reload_state"]
    if data["final_wallet"]!=baseline["wallet"] or data["final_owned"]!=baseline["owned"] or receipts!=baseline["receipts"]:
        raise RuntimeError("Original reload/revisit duplicated coins, items or accepted receipts")
    poses=[e for e in data["input_events"] if e["kind"]=="explicit_chest_position_camera_fixture"]
    if len(poses)!=expected*2 or any(e["id"] not in data["selected_ids"] for e in poses):
        raise RuntimeError("Exactly one per-chest setup/reload-review position is allowed")
    if len([e for e in data["input_events"] if e["kind"]=="key" and e["key"]=="W" and e["pressed"]])!=expected:
        raise RuntimeError("Original nativeW interaction input count differs")
    if data["final_hp"]<=0: raise RuntimeError("Actual actor did not survive the original chest route")
    return {"actual_chest_ids":data["selected_ids"],"real_receipts":receipts,"checkpoint_count":len(points),
            "pixel_motion_device_listening":"Independent visual/motion review and physical device/listening acceptance remain separate"}


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--mode",choices=["plains","forest","gallery"],default="plains")
    p.add_argument("--region",choices=["plains","thorn_forest"],default="plains")
    p.add_argument("--output",required=True);p.add_argument("--source-commit",default="HEAD")
    p.add_argument("--display",default=":101");p.add_argument("--development",action="store_true");p.add_argument("--plan",action="store_true")
    args=p.parse_args();target_dir=Path(args.output).resolve()
    if not target_dir.is_relative_to(ROOT/"build") or target_dir.exists(): raise RuntimeError("Use a NEW build directory; preserve every previous attempt")
    commit=git("rev-parse",args.source_commit+"^{commit}")
    selectors=["project.godot","export_presets.cfg",*FOLDERS]
    dirty=git("diff","--name-only",commit,"--",*selectors).splitlines()
    untracked=git("ls-files","--others","--exclude-standard","--",*selectors).splitlines()
    if not args.development and (dirty or untracked): raise RuntimeError("Final capture needs committed frozen sources: "+", ".join(dirty+untracked))
    trace="res://"+(target_dir/"trace.json").relative_to(ROOT).as_posix()
    argv=["--path",".","--rendering-method","gl_compatibility","--audio-driver","Dummy","--resolution","1280x720"]
    if args.mode!="gallery":argv.extend(["--write-movie",str(target_dir/"raw.avi"),"--fixed-fps","60"])
    argv.extend(["--script",DRIVER,"--","--trace="+trace,"--mode="+args.mode,"--region="+args.region])
    if args.mode=="gallery":argv.append("--gallery-dir=res://"+target_dir.relative_to(ROOT).as_posix())
    if args.plan:
        print(json.dumps({"argv":argv,"source_commit":commit,"development":args.development,"scope":SCOPE,"executed":False},ensure_ascii=False,indent=2));return
    target_dir.mkdir(parents=True)
    os.environ["DISPLAY"]=args.display;os.environ["LIBGL_ALWAYS_SOFTWARE"]="1";os.environ.setdefault("LP_NUM_THREADS","1")
    before=inventory()
    required={DRIVER,"tools/capture_chest_art_movie.py","tests/item_v5_movie.gd","game/presentation/effects/art/chest_art_library.gd","game/presentation/effects/art/chest_art_layer.gd","config/chest_art.json","assets/objects/chests/chest-tiers-v1.source.png","game/world/levels/providers/plains_region_stage.gd","game/world/levels/providers/thorn_forest_region_stage.gd","game/presentation/world/presentation/forest_bible_presentation.gd","game/presentation/world/underworld_plains/underworld_objects.gd","game/application/demo_app.gd","game/rewards/grants/reward_service.gd","game/economy/shops/run_wallet.gd","game/presentation/ui/stage_reward_modal.gd","game/presentation/ui/item_card.gd","game/world/generation/stage_camera_rig.gd","shaders/item_v5_world_sprite.gdshader"}
    if not required.issubset(before):raise RuntimeError("Original full source guard misses a real producer/region/reward/art dependency")
    report={"schema":"chest-art-capture-v1","status":"failed","mode":args.mode,"region":args.region if args.mode=="gallery" else "thorn_forest" if args.mode=="forest" else "plains","source_commit":commit,"head":git("rev-parse","HEAD"),"development":args.development,"dirty_paths":dirty+untracked,"source_before":before,"argv":["bash","tools/godot.sh",*argv],"scope":SCOPE,"engine_exit_code":None,"audio_policy":"Original game48k stereo viaDummybackend on movie captures; physical output/listening acceptance unverified. Gallery PNGs have no audio claim."}
    started=time.monotonic()
    try:
        with (target_dir/"capture.log").open("w") as log,contextlib.redirect_stdout(Tee(sys.stdout,log)):
            output=run_engine(argv,300)
        report["engine_exit_code"]=0
        if re.search(r"SCRIPT ERROR:|SHADER ERROR:|(?m:^ERROR:)|ObjectDB.*leaked|resources? still in use at exit",output):raise RuntimeError("Actual native capture emitted an error or resource leak")
        matches=re.findall(r"^CHEST ART MOVIE: ([1-9]\d*) frames, ([1-9]\d*) assertions, 0 failures$",output,re.M)
        if len(matches)!=1:raise RuntimeError("Missing one exact successful actual completion marker")
        frames,checks=map(int,matches[0]);data=json.loads((target_dir/"trace.json").read_text())
        observed=validate(data,frames,checks,args.mode,args.region)
        if inventory()!=before:raise RuntimeError("Original full production source inventory drifted during recording")
        images=[]
        if args.mode=="gallery":
            for image in data["gallery_images"]:
                image_path=target_dir/image["file"]
                if not image_path.is_file() or sha(image_path)!=image["sha256"]:raise RuntimeError("Actual gallery PNG/hash is missing")
                images.append(image)
        else:
            with (target_dir/"encode.log").open("w") as log:
                subprocess.run(["ffmpeg","-y","-i",str(target_dir/"raw.avi"),"-r","60","-fps_mode","cfr","-c:v","libx264","-crf","20","-pix_fmt","yuv420p","-c:a","aac","-ar","48000","-ac","2","-movflags","+faststart",str(target_dir/"movie.mp4")],check=True,stdout=subprocess.DEVNULL,stderr=log,timeout=150)
            media=json.loads(subprocess.check_output(["ffprobe","-v","error","-show_streams","-show_format","-of","json",str(target_dir/"movie.mp4")],timeout=30))
            video=next(s for s in media["streams"] if s["codec_type"]=="video");audio=[s for s in media["streams"] if s["codec_type"]=="audio"]
            if video["codec_name"]!="h264" or video["avg_frame_rate"]!="60/1" or (video["width"],video["height"])!=(1280,720):raise RuntimeError("Actual movie is not1280x720H264normal60fps")
            if len(audio)!=1 or audio[0]["codec_name"]!="aac" or audio[0]["sample_rate"]!="48000" or audio[0]["channels"]!=2:raise RuntimeError("Original48k stereo game audio is absent")
            seconds=float(media["format"]["duration"])
            if not ((20<=seconds<=35) if args.mode=="plains" else (8<=seconds<=15)):raise RuntimeError("Actual continuous movie exceeded its declared main/Forest duration")
            report.update(media=media,seconds=seconds)
            for point in data["checkpoints"]:
                frame=max(0,int(point["drawn_frame"])-1+12)
                path=target_dir/(point["id"]+".png")
                subprocess.run(["ffmpeg","-y","-i",str(target_dir/"movie.mp4"),"-vf",f"select=eq(n\\,{frame})","-frames:v","1",str(path)],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=30)
                if not path.is_file():raise RuntimeError("Actual checkpoint frame is absent")
                images.append({"path":path.name,"sha256":sha(path),"movie_frame":frame,"movie_time_s":frame/60,"checkpoint_postdraw":point["drawn_frame"],"phase":point["id"]})
        if inventory()!=before:raise RuntimeError("Full source inventory drifted during postprocessing")
        report.update(status="development_captured" if args.development else "captured",frames=frames,assertions=checks,observed=observed,images=images,artifacts={p.name:sha(p) for p in target_dir.iterdir() if p.is_file()})
        print("PASS: actual chest art capture, strict completion/postdraw/source guards; qualitative acceptance remains separate")
    except Exception as error:
        report["status"]="failed";report["error"]=type(error).__name__+": "+str(error);raise
    finally:
        report["wall_seconds"]=time.monotonic()-started;report["source_after"]=inventory();report["source_stable"]=before==report["source_after"]
        (target_dir/"receipt.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n")

if __name__=="__main__":
    try:main()
    except (OSError,RuntimeError,subprocess.SubprocessError) as error:
        print("Chest art capture failed: "+str(error),file=sys.stderr);sys.exit(1)
