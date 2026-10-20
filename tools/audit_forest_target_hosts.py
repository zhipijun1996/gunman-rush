"""Audit twenty actual default App target assemblies against the original corpus; no route/art claim."""
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
    parser.add_argument("--reference", type=Path, default=ROOT / "build/forest_revision04/corpus80-final-W6")
    args = parser.parse_args()
    output = args.output.resolve()
    if not output.is_relative_to(ROOT / "build") or output.exists():
        parser.error("Use a fresh folder below build; preserve earlier observations")
    output.mkdir(parents=True)
    record = {
        "scope": "twenty actual default App runtime assemblies, no route/aesthetic/player approval",
        "layout": "forest-fruit-routes-v14", "reference": str(args.reference.resolve()), "status": "failed",
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
        command = ["--headless", "--fixed-fps", "60", "--path", ".", "--script", "tools/audit_forest_target_hosts.gd", "--",
                   "--reference=" + str(args.reference.resolve()),
                   "--output=res://" + output.relative_to(ROOT).as_posix()]
        record["command"] = shlex.join(["bash", "tools/godot.sh", *command])
        with (output / "native.log").open("w") as stream, contextlib.redirect_stdout(stream):
            native = run_engine(command, 120)
        data = json.loads((output / "report.json").read_text())
        if (not re.search(r"^FOREST TARGET HOST AUDIT: 20 App cases / 0 failures$", native, re.M)
                or data.get("failures") or len(data.get("cases", [])) != 20
                or any(not row.get("passed") or not row.get("manifest_unchanged") or not row.get("original_manifest_canonical_equal") for row in data["cases"])):
            raise RuntimeError("Incomplete or failed twenty actual App assemblies")
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
    print("PASS: twenty actual default App assemblies; no route or visual admission")


if __name__ == "__main__":
    main()
