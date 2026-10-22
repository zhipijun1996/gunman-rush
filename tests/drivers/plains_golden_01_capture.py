"""Record one actual A/B Motor journey, with source guard and normal speed MP4."""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import selectors
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]


def snapshot():
    paths = [ROOT / "project.godot", ROOT / "tools/godot.sh"]
    for folder in ("scripts", "scenes", "resources", "config", "assets"):
        paths.extend(p for p in (ROOT / folder).rglob("*") if p.is_file())
    paths.extend((ROOT / "tests/drivers").glob("plains_golden_01*"))
    return {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(set(paths)) if p.is_file()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidate", choices=("A", "B"), required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    folder = (ROOT / args.output).resolve()
    if not folder.is_relative_to(ROOT / "build/plains_golden_01") or folder.exists():
        raise ValueError("Use a new task build directory; preserve failed originals")
    folder.mkdir(parents=True)
    report = {"candidate": args.candidate, "status": "failed", "source_commit": subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(), "source_before": snapshot(),
        "seed": "plains-golden-01/review-01", "device_acceptance": "unverified",
        "scope": "real Router/Motor journey; not full campaign, art, fun or device acceptance"}
    env = os.environ.copy()
    env.update(LIBGL_ALWAYS_SOFTWARE="1", LP_NUM_THREADS="1")
    display = None
    started = time.monotonic()
    try:
        binary = Path(os.environ.get("GUNMAN_TOOLCHAIN_ROOT", "/workspace/toolchains")) / "xvfb/usr/bin/Xvfb"
        with (folder / "display.log").open("w") as log:
            display = subprocess.Popen([str(binary), "-displayfd", "1", "-screen", "0", "1280x720x24", "-nolisten", "tcp", "-ac"],
                                       stdout=subprocess.PIPE, stderr=log, env=env)
        with selectors.DefaultSelector() as ready:
            ready.register(display.stdout, selectors.EVENT_READ)
            if not ready.select(15):
                raise RuntimeError("Xvfb readiness timeout")
            number = display.stdout.readline().decode().strip()
        if not number.isdigit():
            raise RuntimeError("Invalid Xvfb display")
        env["DISPLAY"] = ":" + number
        argv = ["bash", "tools/godot.sh", "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy",
                "--fixed-fps", "60", "--path", ".", "--write-movie", str(folder / "gameplay.avi"),
                "--script", "tests/drivers/plains_golden_01_motor.gd", "--", "--candidate=" + args.candidate,
                "--output=res://" + (folder / "motor.json").relative_to(ROOT).as_posix()]
        report["argv"] = argv
        with Path(os.environ.get("GUNMAN_GODOT_LOCK", "/workspace/toolchains/godot-verification.lock")).open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            with (folder / "runtime.log").open("w") as log:
                process = subprocess.run(argv, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=180)
        report["exit_code"] = process.returncode
        log = (folder / "runtime.log").read_text()
        if process.returncode or re.search(r"SCRIPT ERROR:|Parse Error:|SHADER ERROR:|ERROR:|ObjectDB.*leaked|resources? still in use", log):
            raise RuntimeError("Native movie journey failed; original runtime log retained")
        trace = json.loads((folder / "motor.json").read_text())
        if not trace["success"] or not trace["audio_drained"]:
            raise RuntimeError("Motor journey did not complete cleanly")
        video = folder / "gameplay.mp4"
        encode = ["ffmpeg", "-y", "-v", "error", "-i", str(folder / "gameplay.avi"), "-c:v", "libx264",
                  "-preset", "fast", "-crf", "22", "-pix_fmt", "yuv420p", "-c:a", "aac", "-movflags", "+faststart", str(video)]
        subprocess.run(encode, check=True, cwd=ROOT, timeout=60)
        report["encode_argv"] = encode
        report["probe"] = json.loads(subprocess.check_output(["ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(video)], text=True))
        report["source_after"] = snapshot()
        if report["source_before"] != report["source_after"]:
            raise RuntimeError("Source changed during movie; do not relabel evidence")
        report["source_stable"] = True
        report["mp4_sha256"] = hashlib.sha256(video.read_bytes()).hexdigest()
        report["mp4_bytes"] = video.stat().st_size
        report["status"] = "passed"
    except Exception as error:
        report["error"] = str(error)
    finally:
        if display is not None:
            display.terminate()
            display.wait(timeout=5)
        report["seconds"] = round(time.monotonic() - started, 3)
        (folder / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({k: report.get(k) for k in ("candidate", "status", "exit_code", "source_stable", "seconds", "error")}))
    if report["status"] != "passed":
        raise SystemExit(1)


if __name__ == "__main__":
    main()
