"""Actual native H-only forest prototype and real-node/capability counterexamples."""
import argparse
from datetime import datetime, timezone
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import uuid

import harness
from level_design import engine_log_matches, source_files
from level_design_contracts import validate_forest_h_slice
from level_region_context import build_region_context

ROOT = Path(__file__).resolve().parents[1]
DEV_UIDS = ("scripts/demo/thorn_forest_h_slice.gd.uid", "tests/forest_h_slice_runner.gd.uid")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


# Actual source consumers, including untracked scenes and script UID loads.
# Engine/Git caches are derived indexes, not runtime source consumers.
UID_BINARY_CONSUMER_SUFFIXES = {".res", ".scn", ".pck", ".zip"}
UID_CONSUMER_SUFFIXES = {".gd", ".tscn", ".tres", ".gdshader", ".gdshaderinc", ".shader", ".glsl",
                         ".cs", ".godot", ".cfg", ".json", ".gdextension", ".py", ".sh"}


def preserve_new_unreferenced_uids(root, existed_before, tracked_paths, destination):
    """Remove only known/new/untracked UID after actual source reference absence is established."""
    outcomes = []
    candidates = {p: (root / p).read_bytes() for p in DEV_UIDS
                  if (root / p).is_file() and not existed_before.get(p) and p not in tracked_paths}
    references = {p: [] for p in candidates}
    unknown = []
    def enumeration_failed(error):
        # os.walk otherwise silently skips scandir failures (including its root),
        # so UID reference absence would never have been established.
        failed = Path(error.filename) if error.filename else root
        try:
            failed = failed.relative_to(root)
        except ValueError:
            pass
        unknown.append("directory enumeration failed: " + str(failed) + " (" + type(error).__name__ + ")")

    if candidates:
        for directory, dirs, files in os.walk(root, followlinks=False, onerror=enumeration_failed):
            dirs[:] = [d for d in dirs if d not in {".git", ".godot", "__pycache__"}]
            for name in dirs:
                if (Path(directory) / name).is_symlink():
                    unknown.append(str((Path(directory) / name).relative_to(root)))
            for name in files:
                consumer = Path(directory) / name
                if (consumer.is_symlink() and not consumer.exists()) or consumer.suffix in UID_BINARY_CONSUMER_SUFFIXES:
                    unknown.append(str(consumer.relative_to(root)))
                    continue
                if consumer.suffix not in UID_CONSUMER_SUFFIXES:
                    continue
                try:
                    content = consumer.read_bytes()
                except OSError:
                    unknown.append(str(consumer.relative_to(root)))
                    continue
                for relative, original in candidates.items():
                    uid = original.strip()
                    if uid and uid in content:
                        references[relative].append(consumer.relative_to(root).as_posix())
    for relative, original in candidates.items():
        path = root / relative
        if references[relative] or unknown or not original.strip():
            outcomes.append({"path": relative, "removed": False,
                             "reason": "runtime source reference or unreferenced condition not established",
                             "references": sorted(references[relative]), "unreadable_or_unresolved": sorted(unknown)})
            continue
        archive = destination / relative
        archive.parent.mkdir(parents=True, exist_ok=True)
        archive.write_bytes(original)
        if path.read_bytes() != original:
            outcomes.append({"path": relative, "removed": False, "reason": "sidecar changed during guard"})
            continue
        outcomes.append({"path": relative, "removed": True, "sha256": sha(archive), "archive": str(archive),
                         "reason": "new untracked known Godot sidecar; no tracked/untracked runtime source reference; parent explicitly authorized evidence-preserving cleanup"})
        path.unlink()
    return outcomes


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--engine-lock", type=Path, default=Path(os.environ.get("GUNMAN_ENGINE_LOCK", ROOT / "build/verification/engine.lock")))
    parser.add_argument("--skip-import", action="store_true", help="Only after this exact source successfully imported")
    args = parser.parse_args()
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S") + "_" + uuid.uuid4().hex[:8]
    folder = (args.output_dir or ROOT / "build/forest_h_slice" / stamp).resolve()
    if not folder.is_relative_to(ROOT / "build") or folder.exists():
        raise ValueError("Each actual CLI run needs a unique repository build directory")
    folder.mkdir(parents=True)
    uids_before = {p: (ROOT / p).exists() for p in DEV_UIDS}
    tracked = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT).decode().split("\0")
    args.engine_lock.parent.mkdir(parents=True, exist_ok=True)
    context = build_region_context("thorn_forest")
    assert context["design"]["stage"]["value"] == "S2" and context["design"]["gate"]["alternatives"] == [["H"]]
    sources = source_files(ROOT)
    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    summary = {"schema_version": 1, "scope": "actual_Godot_development_H_only_forest_prototype_not_formal_opening",
               "source_commit": commit, "engine_lock": str(args.engine_lock.resolve()), "started_at": stamp,
               "region_authority": context["design"]["gate"], "cases": [], "status": "running"}
    write(folder / "summary.json", summary)
    started = time.monotonic()
    try:
        with args.engine_lock.open("a") as engine_lock:
            fcntl.flock(engine_lock, fcntl.LOCK_EX)
            summary["lock_acquired_at_utc"] = datetime.now(timezone.utc).isoformat()
            if not args.skip_import:
                config = {"argv": ["bash", "tools/godot.sh", "--headless", "--path", ".", "--editor", "--quit"],
                          "timeout_seconds": 90, "success_pattern": "Godot Engine v4\\.7\\.2"}
                summary["import"] = harness.run_check(config, folder / "import.log")
                if summary["import"]["status"] != "passed":
                    raise RuntimeError("Native editor import failed; original log retained")
            for case in ("positive", "missing-anchor", "no-hook"):
                destination = folder / case
                destination.mkdir()
                capture = destination / "capture.json"
                log = capture.with_suffix(".log")
                command = ["bash", "tools/godot.sh", "--headless", "--fixed-fps", "60", "--path", ".", "--script",
                           "tests/forest_h_slice_runner.gd", "--", "--case=" + case, "--source-commit=" + commit,
                           "--output=res://" + capture.relative_to(ROOT).as_posix()]
                result = harness.run_check({"argv": command, "timeout_seconds": 60,
                                           "success_pattern": r"^REGION PRODUCTION: [1-9]\d* assertions, 0 failures$"}, log)
                receipt = {"schema_version": 1, "scope": "actual_godot_process", **result, "command": command,
                           "source_commit": commit, "source_files": sources, "log_sha256": sha(log),
                           "capture": capture.relative_to(ROOT).as_posix(), "capture_sha256": sha(capture) if capture.is_file() else None}
                write(capture.with_suffix(".invocation.json"), receipt)
                if not capture.is_file():
                    raise RuntimeError(case + ": native producer did not write capture")
                data = json.loads(capture.read_text())
                text = log.read_text(errors="replace")
                errors = validate_forest_h_slice(data)
                if not engine_log_matches(data.get("engine"), text) or re.search(r"SCRIPT ERROR:|Parse Error:|SHADER ERROR:", text):
                    raise RuntimeError(case + ": native engine/log invalid")
                if source_files(ROOT) != sources:
                    raise RuntimeError("Native source changed during capture; evidence not fresh")
                expected = (case == "positive" and result["status"] == "passed" and result["exit_code"] == 0 and not errors
                            or case != "positive" and result["exit_code"] == 1 and bool(errors) and bool(data.get("failures")))
                summary["cases"].append({"case": case, **result, "capture": str(capture.relative_to(ROOT)),
                                         "capture_sha256": sha(capture), "validation_errors": errors,
                                         "expected_outcome_observed": expected, "ticks": len(data.get("observations", []))})
                if not expected:
                    raise RuntimeError(case + ": actual native outcome violated slice contract")
            summary["status"] = "passed"
        print("PASS: forest H-only native prototype positive and actual removed-anchor/no-H negatives")
        print("Evidence: " + str(folder / "summary.json"))
        return 0
    except Exception as error:
        summary.update(status="failed", error=str(error))
        print("Forest slice failed: " + str(error), file=sys.stderr)
        return 1
    finally:
        summary["generated_uid_cleanup"] = preserve_new_unreferenced_uids(ROOT, uids_before, tracked, folder / "generated_uids")
        summary["seconds"] = round(time.monotonic() - started, 3)
        write(folder / "summary.json", summary)


if __name__ == "__main__":
    raise SystemExit(main())
