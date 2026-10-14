"""Run real Godot consumer assertions and a separately executed broken Sprite."""
import hashlib
import json
import re
import subprocess
import tempfile
from pathlib import Path

import harness
import level_formal
from run_tests import run_engine, REPO


def main():
    base = REPO / "build/level_autonomy/golden"
    base.mkdir(parents=True, exist_ok=True)
    folder = Path(tempfile.mkdtemp(prefix="run_", dir=base))
    run_engine(["--headless", "--path", ".", "--editor", "--quit"], 90)
    before = level_formal.source_files()
    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=REPO, text=True).strip()
    report = {"source_commit": commit, "source_files": before, "status": "failed", "scope": "actual paused formal consumer technical golden; deliberately broken real Sprite must exit 1; no live enemy/player/device acceptance", "runs": []}
    try:
        for negative in (False, True):
            name = "floating_negative" if negative else "positive"
            output = folder / (name + ".json")
            command = ["bash", "tools/godot.sh", "--headless", "--fixed-fps", "60", "--path", ".", "--script", "tests/plains_autonomy_slice_runner.gd", "--", "--output=" + str(output)]
            if negative:
                command.append("--deliberate-floating-prop=20")
            log = folder / (name + ".log")
            result = harness.run_check({"argv": command, "timeout_seconds": 120, "success_pattern": r"^PLAINS AUTONOMY GOLDEN: [1-9]\d* assertions, 0 failures$"}, log, REPO)
            text = log.read_text()
            data = json.loads(output.read_text())
            valid = (result["exit_code"] == 1 and data["failures"] == 3 and re.search(r"^PLAINS AUTONOMY NEGATIVE: actual sprite floating rejected by bounds, foot and collider$", text, re.MULTILINE)) if negative else (result["status"] == "passed" and data["failures"] == 0 and data["assertions"] > 0)
            if re.search(r"SCRIPT ERROR:|Parse Error:|SHADER ERROR:|ERROR: Failed to load script", text):
                valid = False
            report["runs"].append({"command": command, "process": result, "expected_exit_code": 1 if negative else 0, "expected_rejection": negative, "validated": bool(valid), "output": str(output.relative_to(REPO)), "output_sha256": hashlib.sha256(output.read_bytes()).hexdigest(), "log": str(log.relative_to(REPO)), "log_sha256": hashlib.sha256(log.read_bytes()).hexdigest()})
            if not valid:
                raise RuntimeError(f"{name}: actual consumer/expected rejection failed; evidence retained in {folder}")
            if not negative:
                print(re.search(r"^PLAINS AUTONOMY GOLDEN: .*", text, re.MULTILINE).group(0), flush=True)
        if before != level_formal.source_files():
            raise RuntimeError("Actual source changed during golden")
        report["status"] = "passed"
        print("PLAINS AUTONOMY REAL NEGATIVE: exit 1 with three actual floating-sprite violations; " + str(folder.relative_to(REPO)), flush=True)
        return 0
    finally:
        (folder / "receipt.json").write_text(json.dumps(report, indent=2) + "\n")
        print("PLAINS AUTONOMY RECEIPT: " + str((folder / "receipt.json").relative_to(REPO)), flush=True)


if __name__ == "__main__":
    raise SystemExit(main())
