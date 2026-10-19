"""Targeted art-aware generation contract using the existing strict native host.

This is parameter/consumer evidence, never rendered-art or player admission.
"""
import argparse
import fcntl
import hashlib
import json
import re
import time
from pathlib import Path

from level_formal import source_files
from run_plains_joint_recoil_tests import logged_engine
from run_root_bell_ecology import godot_lock_path

ROOT = Path(__file__).resolve().parents[1]
EXTRA = ("tests/fixtures/root_bell/pre_focus_15_player_tuning.json", "tools/run_plains_art_language_tests.py", "tools/run_plains_joint_recoil_tests.py",
         "tools/run_tests.py", "tools/run_root_bell_ecology.py")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="New evidence directory; defaults to /tmp to avoid filling workspace")
    args = parser.parse_args()
    folder = (args.output or Path("/tmp/plains_art_language") / time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())).resolve()
    folder.mkdir(parents=True, exist_ok=False)
    actual = folder / "actual.json"
    started = time.monotonic()
    report = {"status": "failed", "scope": "Art-language generation, rejection and real installed consumer contracts; not art quality, complete playable region, device or production-pool admission"}
    command = ["--headless", "--path", ".", "--script", "tests/plains_art_language_runner.gd", "--", "--output=" + str(actual)]
    with godot_lock_path(ROOT).open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        before = source_files(EXTRA)
        report["source_before"] = before
        try:
            imported = logged_engine(["--headless", "--path", ".", "--editor", "--quit"], 120, folder / "import.log")
            if re.search(r"(?m)^\s*(?:ERROR:|SCRIPT ERROR:|Parse Error:|SHADER ERROR:)", imported):
                raise RuntimeError("Actual native import error")
            output = logged_engine(command, 180, folder / "native.log")
            if not re.search(r"^PLAINS ART LANGUAGE: [1-9]\d* assertions, 0 failures$", output, re.M):
                raise RuntimeError("Missing complete native art-language contract")
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
