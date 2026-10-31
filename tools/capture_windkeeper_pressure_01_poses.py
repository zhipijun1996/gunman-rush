#!/usr/bin/env python3
"""Capture explicitly controlled Windkeeper art-review poses through real GL.

Run the normal editor import before freezing source, then run this producer only
while holding the project's single Godot/GL lease. The 60 raw PNGs are not a
natural fight, actual bridge transition, damage route or device acceptance.
"""
from pathlib import Path
import argparse
import json
import os
import re
import selectors
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import harness


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    folder = args.output.resolve() if args.output.is_absolute() else (ROOT / args.output).resolve()
    if folder.exists():
        raise RuntimeError("Use a fresh output directory; previous evidence is never overwritten")
    folder.parent.mkdir(parents=True, exist_ok=True)
    before = harness.source_inventory()
    source = harness.git_metadata()
    env = os.environ.copy()
    env["LIBGL_ALWAYS_SOFTWARE"] = "1"
    display = display_log = None
    native_log = folder.parent / (folder.name + "-native.log")
    try:
        if not env.get("DISPLAY"):
            candidate = Path(os.environ.get("GUNMAN_TOOLCHAIN_ROOT", str(ROOT.parent / "toolchains"))) / "xvfb/usr/bin/Xvfb"
            binary = shutil.which("Xvfb")
            if not binary and candidate.is_file():
                binary = str(candidate)
            if not binary:
                raise RuntimeError("Xvfb or a live DISPLAY is required for actual GL pixels")
            display_log = (folder.parent / (folder.name + "-display.log")).open("wb")
            display = subprocess.Popen(
                [binary, "-displayfd", "1", "-screen", "0", "1280x720x24", "-nolisten", "tcp", "-ac"],
                stdout=subprocess.PIPE, stderr=display_log,
            )
            with selectors.DefaultSelector() as selector:
                selector.register(display.stdout, selectors.EVENT_READ)
                if not selector.select(30):
                    raise RuntimeError("Xvfb startup timeout")
                number = display.stdout.readline().decode().strip()
            if not number.isdigit():
                raise RuntimeError("Invalid Xvfb display number")
            env["DISPLAY"] = ":" + number
        command = [
            "bash", "tools/godot.sh", "--path", ".", "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy",
            "--script", "tools/windkeeper_pressure_01/pose_review.gd", "--", "--output=" + str(folder),
        ]
        execution = harness.run_check({
            "argv": command,
            "timeout_seconds": 180,
            "success_pattern": r"^WINDKEEPER PRESSURE POSE REVIEW: 60 GPU screenshots; 2 resolutions; 0 failures$",
        }, native_log, ROOT, env)
        engine_errors = re.findall(r"(?m)^SCRIPT ERROR:.*$|^ERROR:.*$|^.*RID allocations.*leaked.*$", native_log.read_text(errors="replace"))
        after = harness.source_inventory()
        source_after = harness.git_metadata()
        stable = before == after and source == source_after
        passed = execution["status"] == "passed" and stable and not engine_errors
        report = {
            "status": "passed" if passed else "failed",
            "source": source, "source_after": source_after,
            "source_files_before": before, "source_files_after": after,
            "source_stable": stable, "execution": execution, "native_engine_errors": engine_errors,
            "scope": "Actual formal map2 GL pixels of disclosed paused pose/Actor/camera fixtures. PhaseIII has no bridge transition or support proof. No natural wholefight, evasion, damage, death, mobile-device or hardware-performance approval.",
        }
        (folder.parent / (folder.name + "-source-report.json")).write_text(json.dumps(report, indent=2) + "\n")
        print(json.dumps({"status": report["status"], "source_stable": stable, "native_engine_errors": len(engine_errors), "output": str(folder)}))
        if not passed:
            raise RuntimeError("Pose capture failed; original log and source report retained")
    finally:
        if display is not None:
            if display.poll() is None:
                display.terminate()
            try:
                display.wait(timeout=5)
            except subprocess.TimeoutExpired:
                display.kill()
                display.wait()
            if display.stdout is not None:
                display.stdout.close()
        if display_log is not None:
            display_log.close()


if __name__ == "__main__":
    main()
