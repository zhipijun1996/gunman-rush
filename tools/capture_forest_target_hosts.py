"""Capture source-bound runtime target-host fixtures; never label them route proof."""
import argparse
import contextlib
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import time
import zipfile

from run_forest_depth_region import inventory, import_inventory_guard
from run_tests import run_engine

ROOT = Path(__file__).resolve().parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--seed", default="forest-depth-00")
    parser.add_argument("--map", type=int, choices=(1, 2), default=1)
    parser.add_argument("--group", choices=("root_hint", "fallen_fork", "spiral_crown", "gate_pull", "guardian_pair", "queen_rib", "hollow_elbow"), default="fallen_fork")
    parser.add_argument("--display", default=":99")
    args = parser.parse_args()
    output = args.output.resolve()
    if not output.is_relative_to(ROOT / "build") or output.exists():
        parser.error("Use a fresh folder below build; preserve earlier observations")
    output.mkdir(parents=True)
    record = {
        "scope": "native formal App, initial segment observation fixtures; no traversal/device/player approval",
        "layout": "forest-fruit-routes-v14", "group": args.group, "seed": args.seed, "map": args.map, "status": "failed",
        "head": subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip(),
        "dirty_paths": subprocess.check_output(["git", "status", "--porcelain", "--untracked-files=all"], text=True).splitlines(),
    }
    started = time.monotonic()
    before_import = inventory()
    error = None
    before = None
    try:
        # Native class registration is sequential and precedes the frozen capture.
        with (output / "import.log").open("w") as stream, contextlib.redirect_stdout(stream):
            run_engine(["--headless", "--path", ".", "--editor", "--quit"], 90)
        before = inventory()
        record["import_guard"] = import_inventory_guard(before_import, before)
        if not record["import_guard"]["passed"]:
            raise RuntimeError("Import changed non-generated source")
        record["source_before"] = before
        record["engine"] = subprocess.check_output(["bash", "tools/godot.sh", "--version"], text=True).strip()
        # Preserve the exact development source delta, including untracked files.
        patch = subprocess.check_output(["git", "diff", "--binary", "HEAD", "--", "scripts", "scenes", "resources", "config", "shaders", "assets", "tests", "tools", "project.godot"])
        new_names = subprocess.check_output(["git", "ls-files", "--others", "--exclude-standard", "--", "scripts", "scenes", "resources", "config", "shaders", "assets", "tests", "tools"], text=True).splitlines()
        with zipfile.ZipFile(output / "source-delta.zip", "w", zipfile.ZIP_DEFLATED) as archive:
            archive.writestr("tracked.patch", patch)
            for name in new_names:
                archive.write(ROOT / name, "untracked/" + name)
        record["source_delta_sha256"] = sha(output / "source-delta.zip")
        command = ["--path", ".", "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy",
                   "--max-fps", "60", "--script", "tools/capture_forest_target_hosts.gd", "--",
                   "--seed=" + args.seed, "--map=" + str(args.map), "--group=" + args.group,
                   "--output=res://" + output.relative_to(ROOT).as_posix()]
        record["command"] = shlex.join(["bash", "tools/godot.sh", *command])
        record["environment"] = {"DISPLAY": args.display, "LIBGL_ALWAYS_SOFTWARE": "1", "LP_NUM_THREADS": "1"}
        os.environ.update(record["environment"])
        with (output / "native.log").open("w") as stream, contextlib.redirect_stdout(stream):
            native = run_engine(command, 120)
        data = json.loads((output / "report.json").read_text())
        expected_count = 1 if args.group == "root_hint" else 3
        if (not re.search(rf"^FOREST TARGET HOSTS: {expected_count} observations / 0 failures$", native, re.M)
                or data.get("failures") or len(data.get("observations", [])) != expected_count
                or any(row.get("layout") != "forest-fruit-routes-v14" or row.get("map") != args.map or not row.get("grounded") or not row.get("manifest_unchanged") for row in data["observations"])):
            raise RuntimeError("Incomplete or wrong-context native observations")
        record.update(status="passed", exit_code=0)
    except BaseException as exc:
        error = exc
        record["error"] = repr(exc)
    finally:
        after = inventory()
        record["source_after"] = after
        record["source_stable"] = before is not None and before == after
        if not record["source_stable"]:
            record["status"] = "failed"
            error = error or RuntimeError("Source changed during native capture")
        record["seconds"] = time.monotonic() - started
        record["artifacts"] = [{"path": str(p.relative_to(ROOT)), "sha256": sha(p), "bytes": p.stat().st_size}
                               for p in sorted(output.iterdir()) if p.is_file()]
        (output / "source-binding.json").write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")
    if error:
        raise error
    print("PASS: source-bound native target hosts; observation fixtures only")


if __name__ == "__main__":
    main()
