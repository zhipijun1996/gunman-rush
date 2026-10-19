"""Targeted world-first terrain contract using the existing strict native host.

This is parameter/consumer evidence, never rendered-art or player admission.
"""
import argparse
import fcntl
import hashlib
import json
import re
import os
import selectors
import shutil
import subprocess

import harness
import time
from pathlib import Path

from level_formal import source_files
from run_plains_joint_recoil_tests import logged_engine
from run_root_bell_ecology import godot_lock_path

ROOT = Path(__file__).resolve().parents[1]
EXTRA = ("tests/fixtures/root_bell/pre_focus_15_player_tuning.json", "tools/run_plains_world_rebuild_tests.py", "tools/run_plains_joint_recoil_tests.py",
         "tools/run_tests.py", "tools/run_root_bell_ecology.py",
         "tools/plains_world_rebuild_preview.gd",
         "assets/visual_development/plains_world_rebuild/terrain_source.png",
         "assets/visual_development/plains_world_rebuild/terrain_mapping.json",
         "assets/visual_development/plains_world_rebuild/terrain_cliff_v2.png",
         "assets/visual_development/plains_world_rebuild/cliff_mapping_v2.json")


if (ROOT / "assets/visual_development/plains_world_rebuild/environment_source.png").is_file():
    EXTRA += ("assets/visual_development/plains_world_rebuild/environment_source.png",)


# Include every actual candidate image, including retained v1/v2 originals.
EXTRA = tuple(dict.fromkeys(EXTRA + tuple(path.relative_to(ROOT).as_posix()
    for path in sorted((ROOT/"assets/visual_development/plains_world_rebuild").glob("*.png")))))


def capture(folder, route, route_kind="main", variant=0):
    """Use the existing harness process gate and live preview, never a fixture."""
    env = os.environ.copy()
    env.update(LIBGL_ALWAYS_SOFTWARE="1", LP_NUM_THREADS="1", OMP_NUM_THREADS="1")
    env["REGIONAL_SOURCE_COMMIT"] = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    display = None
    report = {"status": "failed", "source_commit": env["REGIONAL_SOURCE_COMMIT"], "variant": variant,
              "scope": "Actual normal follow-camera screenshot and optional input-only route movie; not art, user or device admission"}
    before = source_files(EXTRA)
    report["source_before"] = before
    started = time.monotonic()
    try:
        binary = shutil.which("Xvfb") or str(ROOT.parent / "toolchains/xvfb/usr/bin/Xvfb")
        with (folder / "display.log").open("wb") as display_log:
            display = subprocess.Popen([binary, "-displayfd", "1", "-screen", "0", "1280x720x24", "-nolisten", "tcp", "-ac"], stdout=subprocess.PIPE, stderr=display_log)
            with selectors.DefaultSelector() as selector:
                selector.register(display.stdout, selectors.EVENT_READ)
                if not selector.select(20): raise RuntimeError("Display readiness timeout")
                number = display.stdout.readline().decode().strip()
                if not number.isdigit(): raise RuntimeError("Invalid display readiness")
            env["DISPLAY"] = ":" + number
            command = ["bash", "tools/godot.sh", "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy"]
            movie = folder / "gameplay.avi"
            if route: command += ["--write-movie", str(movie), "--fixed-fps", "60"]
            command += ["--path", ".", "--script", "tools/plains_world_rebuild_preview.gd", "--", "--seed=world-rebuild-01", "--variant=" + str(variant), "--capture-output=" + str(folder / "frames")]
            if route: command += ["--route=" + route_kind]
            report["command"] = command
            result = harness.run_check({"argv": command, "timeout_seconds": 600 if route else 90,
                "success_pattern": r"^PLAINS WORLD REBUILD ROUTE: .*" if route else r"^PLAINS WORLD REBUILD READY: .*"}, folder / "capture.log", ROOT, env)
            report["process"] = result
        data = json.loads((folder / "frames/receipt.json").read_text())
        report["route"] = data["route"]
        if result["status"] != "passed": raise RuntimeError("Actual rendered process failed; retain route failure")
        if route and not data["route"].get("passed", False): raise RuntimeError("Actual input traversal failed")
        for shot in data["screenshots"]:
            path = Path(shot["path"])
            if shot["error"] or not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != shot["sha256"]:
                raise RuntimeError("Actual viewport PNG binding failed")
        if not data["screenshots"]: raise RuntimeError("Missing actual normal-camera image")
        if route:
            with (folder / "encode.log").open("w") as log:
                subprocess.run(["ffmpeg", "-y", "-i", str(movie), "-c:v", "libx264", "-crf", "21", "-pix_fmt", "yuv420p", "-c:a", "aac", str(folder / "gameplay.mp4")], check=True, stdout=subprocess.DEVNULL, stderr=log, timeout=180)
            media = json.loads(subprocess.check_output(["ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(folder / "gameplay.mp4")], timeout=30))
            video = next(row for row in media["streams"] if row["codec_type"] == "video")
            audio = next(row for row in media["streams"] if row["codec_type"] == "audio")
            if video["avg_frame_rate"] != "60/1" or (video["width"], video["height"]) != (1280,720) or int(audio["sample_rate"]) != 48000 or audio["channels"] != 2:
                raise RuntimeError("Actual normal-speed movie format failed")
            report["media"] = media
            movie.unlink()
        if source_files(EXTRA) != before: raise RuntimeError("Source changed during actual render")
        report["status"] = "passed"
    except Exception as exc:
        report["error"] = str(exc)
        raise
    finally:
        if display:
            display.terminate()
            try: display.wait(timeout=5)
            except subprocess.TimeoutExpired: display.kill(); display.wait(timeout=5)
        report["source_after"] = source_files(EXTRA)
        report["elapsed_seconds"] = time.monotonic() - started
        (folder / "report.json").write_text(json.dumps(report, indent=2) + "\n")
        print(folder / "report.json", flush=True)


def trace(folder, route, variant=0):
    """Short real DemoApp/Router feedback without recording or actor relocation."""
    started = time.monotonic()
    before = source_files(EXTRA)
    report = {"status": "failed", "source_before": before, "variant": variant,
              "scope": "Actual headless PlayerMotor/Router traversal; not rendered art or device evidence"}
    command = ["--headless", "--fixed-fps", "60", "--path", ".", "--script", "tools/plains_world_rebuild_preview.gd", "--", "--seed=world-rebuild-01", "--variant="+str(variant), "--route="+route, "--trace-output="+str(folder/"trace")]
    report["command"] = ["bash", "tools/godot.sh", *command]
    try:
        output = logged_engine(command, 120, folder/"trace.log")
        data = json.loads((folder/"trace/receipt.json").read_text())
        report["route"] = data["route"]
        if not data["route"].get("passed",False): raise RuntimeError("Actual headless input route failed")
        if re.search(r"(?m)^\s*(?:ERROR:|SCRIPT ERROR:|Parse Error:|SHADER ERROR:)",output): raise RuntimeError("Actual native route error")
        if source_files(EXTRA) != before: raise RuntimeError("Source changed during headless route")
        report["status"] = "passed"
    except Exception as exc:
        report["error"] = str(exc)
        raise
    finally:
        # Existing strict engine raises on a failed route: keep its actual trace.
        receipt = folder/"trace/receipt.json"
        if receipt.is_file(): report["route"] = json.loads(receipt.read_text())["route"]
        report["source_after"] = source_files(EXTRA)
        report["elapsed_seconds"] = time.monotonic()-started
        (folder/"report.json").write_text(json.dumps(report,indent=2)+"\n")
        print(folder/"report.json",flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="New evidence directory; defaults to /tmp to avoid filling workspace")
    parser.add_argument("--variant", type=int, choices=(0,1), default=0, help="Explicit registered layout; 1 requires first-sample admission")
    parser.add_argument("--route-kind", choices=("main","lower"), default="main", help="Existing normal-camera route to record")
    parser.add_argument("--trace", choices=("main","lower"), help="Cheap actual headless input trace before movies")
    parser.add_argument("--capture", action="store_true", help="Actual first candidate normal-camera image")
    parser.add_argument("--route", action="store_true", help="Actual first candidate input trace and continuous movie")
    args = parser.parse_args()
    folder = (args.output or Path("/tmp/plains_world_rebuild") / time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())).resolve()
    folder.mkdir(parents=True, exist_ok=False)
    actual = folder / "actual.json"
    started = time.monotonic()
    report = {"status": "failed", "variant": args.variant, "scope": "World-first source, rejection and installed collision/painting contracts; not art quality, complete playable region, device or production-pool admission"}
    command = ["--headless", "--path", ".", "--script", "tests/plains_world_rebuild_runner.gd", "--", "--output=" + str(actual), "--variant="+str(args.variant)]
    with godot_lock_path(ROOT).open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if args.trace:
            trace(folder, args.trace, args.variant)
            return
        if args.capture or args.route:
            capture(folder, args.route, args.route_kind, args.variant)
            return
        before = source_files(EXTRA)
        report["source_before"] = before
        try:
            imported = logged_engine(["--headless", "--path", ".", "--editor", "--quit"], 120, folder / "import.log")
            if re.search(r"(?m)^\s*(?:ERROR:|SCRIPT ERROR:|Parse Error:|SHADER ERROR:)", imported):
                raise RuntimeError("Actual native import error")
            output = logged_engine(command, 180, folder / "native.log")
            if not re.search(r"^PLAINS WORLD REBUILD: [1-9]\d* assertions, 0 failures$", output, re.M):
                raise RuntimeError("Missing complete native world-rebuild contract")
            if re.search(r"(?m)^\s*(?:ERROR:|SCRIPT ERROR:|Parse Error:|SHADER ERROR:)", output):
                raise RuntimeError("Actual native error")
            data = json.loads(actual.read_text())
            if data.get("failures") or not data.get("assertions", 0):
                raise RuntimeError("Missing or failed actual native assertions")
            if source_files(EXTRA) != before:
                raise RuntimeError("Source changed during native contract")
            report["status"] = "passed"
        except Exception as exc:
            report["error"] = str(exc)
            raise
        finally:
            report["source_after"] = source_files(EXTRA)
            report["elapsed_seconds"] = time.monotonic() - started
            report["command"] = ["bash", "tools/godot.sh", *command]
            if actual.is_file():
                report["actual_sha256"] = hashlib.sha256(actual.read_bytes()).hexdigest()
            (folder / "report.json").write_text(json.dumps(report, indent=2) + "\n")
            print(folder / "report.json", flush=True)


if __name__ == "__main__":
    main()
