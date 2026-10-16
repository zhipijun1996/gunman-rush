"""Actual two-map static-family consumer; no visual-quality claims."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

import level_formal

ROOT = Path(__file__).resolve().parents[1]


def run():
    folder = Path(tempfile.mkdtemp(prefix="directed-space-", dir=ROOT / "build"))
    env = os.environ.copy()
    env["LP_NUM_THREADS"] = "1"
    producer = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    # A newly integrated class_name is absent from a cold editor cache. Import
    # before freezing the actual runtime inventory, rather than relying on a
    # specialist worktree's previous interactive editor session.
    import_command = ["bash", "tools/godot.sh", "--headless", "--path", ".", "--editor", "--quit"]
    imported = subprocess.run(import_command, cwd=ROOT, env=env, capture_output=True, text=True, timeout=120)
    import_log = folder / "import.log"
    import_log.write_text(imported.stdout + imported.stderr)
    import_passed = (imported.returncode == 0 and not re.search(
        r"SCRIPT ERROR:|Parse Error:|SHADER ERROR:|ERROR: Failed to load script", import_log.read_text()))
    if not import_passed:
        (folder / "report.json").write_text(json.dumps({"status":"failed", "phase":"cold_import",
            "command":import_command, "exit_code":imported.returncode, "log":str(import_log.relative_to(ROOT))},indent=2)+"\n")
        print("DIRECTED SPACE SUITE: failed", folder.relative_to(ROOT))
        return 1
    source_before = level_formal.source_files()
    runs = []
    for consumer_mode in ("legacy", "default"):
        consumer_env = env.copy()
        consumer_env["PLAINS_LEGACY_WOODLAND_FIXTURE"] = "1" if consumer_mode == "legacy" else "0"
        if consumer_mode == "legacy":
            consumer_env["PLAINS_HIGHLAND_PILOT"] = "0"
        else:
            consumer_env.pop("PLAINS_HIGHLAND_PILOT", None)
        for negative in (False, True):
            label = consumer_mode + ("_negative" if negative else "_positive")
            capture = folder / (label + ".json")
            command = ["bash", "tools/godot.sh", "--headless", "--path", ".", "--script",
                       "tests/plains_directed_space_runner.gd", "--", "--output=" + str(capture)]
            if negative:
                command.append("--prove-failure")
                command.append("--single-seed")
            result = subprocess.run(command, cwd=ROOT, env=consumer_env, capture_output=True, text=True, timeout=240)
            log = folder / (label + ".log")
            log.write_text(result.stdout + result.stderr)
            data = json.loads(capture.read_text()) if capture.exists() else {}
            passed = (result.returncode == (1 if negative else 0)
                      and data.get("assertions", 0) >= 50
                      and data.get("failures") == (1 if negative else 0)
                      and re.search(r"^DIRECTED SPACE: [1-9]\d* assertions, [01] failures$", log.read_text(), re.M)
                      and not re.search(r"SCRIPT ERROR:|Parse Error:|SHADER ERROR:|ERROR: Failed to load script", log.read_text()))
            if consumer_mode == "default":
                passed = passed and data.get("consumer_mode") == "default_stopped_woodland_with_limited_highland"
            runs.append({"consumer_mode":consumer_mode, "environment":{name:consumer_env.get(name) for name in
                         ("PLAINS_LEGACY_WOODLAND_FIXTURE", "PLAINS_HIGHLAND_PILOT")},
                         "negative": negative, "passed": bool(passed), "exit_code": result.returncode,
                         "command": command, "capture": str(capture.relative_to(ROOT)),
                         "log": str(log.relative_to(ROOT)), "log_sha256": hashlib.sha256(log.read_bytes()).hexdigest(),
                         "assertions": data.get("assertions"), "failures": data.get("failures")})
            if not passed:
                break
        if not runs[-1]["passed"]:
            break
    source_after = level_formal.source_files()
    source_stable = (source_before == source_after
                     and producer == hashlib.sha256(Path(__file__).read_bytes()).hexdigest())
    report = {"status": "passed" if len(runs) == 4 and all(r["passed"] for r in runs) and source_stable else "failed",
              "producer_sha256": producer, "import": {"command":import_command,"exit_code":imported.returncode,
                  "log":str(import_log.relative_to(ROOT)),"log_sha256":hashlib.sha256(import_log.read_bytes()).hexdigest()}, "runs": runs,
              "source_before": source_before, "source_after": source_after, "source_stable": source_stable,
              "scope": "Actual integration/counterexamples; no source-bound film or visual acceptance"}
    (folder / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print("DIRECTED SPACE SUITE:", report["status"], folder.relative_to(ROOT))
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(run())
