#!/usr/bin/env python3
"""Development-only locked reference verification; never updates game resources."""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import stat
import subprocess
import sys
import time
import zipfile

UPSTREAM_HEAD = "0d338c2309d4e17bd8e9b128f745eb93938e99b2"
ARCHIVE_SHA256 = "25f05861b68a99eee1e9d588eb2cab761e30c85b7cc109b0536292fcc98867f6"
ARCHIVE_URL = ("https://raw.githubusercontent.com/zhipijun1996/map-gen/" + UPSTREAM_HEAD +
               "/reference_package/releases/0.2.0/mapgen-python-reference-0.2.0.zip")
HOST_MEMBERS = ("map.json", "content/M16.json", "content/M18.json", "content/M21.json")


def sha(data):
    return hashlib.sha256(data).hexdigest()


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + "\n", encoding="utf-8")


def extract_original_protocol(archive, destination):
    # Exact safety/one-root extraction rules from upstream head's
    # tests/reference/validate_release.py. No new map/content protocol here.
    with zipfile.ZipFile(archive) as z:
        names = z.namelist()
        if len(names) != len(set(names)):
            raise ValueError("duplicate ZIP member")
        for info in z.infolist():
            path = PurePosixPath(info.filename)
            if path.is_absolute() or ".." in path.parts or "\\" in info.filename or stat.S_ISLNK(info.external_attr >> 16):
                raise ValueError("unsafe ZIP member")
        roots = {n.split("/")[0] for n in names}
        if len(roots) != 1:
            raise ValueError("expected one ZIP root")
        inventory = [{"path":info.filename, "bytes":info.file_size, "sha256":sha(z.read(info))}
                     for info in z.infolist() if not info.is_dir()]
        z.extractall(destination)
    return destination / next(iter(roots)), inventory


def verify(archive, host, out):
    archive, host, out = archive.resolve(), host.resolve(), out.resolve()
    # All mutations are confined to the new evidence directory.
    if out.exists():
        raise ValueError("refusing to overwrite evidence output")
    if out == host or host in out.parents:
        raise ValueError("evidence output must be outside host resources")
    digest = sha(archive.read_bytes())
    if digest != ARCHIVE_SHA256:
        raise ValueError("outer ZIP hash mismatch")
    original_host = {name:(host / name).read_bytes() for name in HOST_MEMBERS}
    out.mkdir(parents=True)
    receipt = {"archive_url":ARCHIVE_URL,"upstream_head":UPSTREAM_HEAD,
               "archive_sha256":digest,"host_data":str(host),"commands":[],"comparisons":[]}
    try:
        package, inventory = extract_original_protocol(archive, out / "extracted")
        save(out / "zip-members.json", inventory)
        manifest = json.loads((package / "manifest.json").read_text(encoding="utf-8"))
        dependency = package / manifest["module_zip_ref"]
        work = out / "unrelated-working-directory"
        work.mkdir()
        env = {k:v for k,v in os.environ.items() if k not in ("PYTHONPATH", "PYTHONHOME")}
        # Invoke the shipped verifier/replayer verbatim in isolated stdlib mode.
        for operation in ("verify", "replay"):
            command = [sys.executable, "-B", "-I", "-S", str(package / "reference.py"), operation,
                       "--case", "all", "--module-zip", str(dependency)]
            started = time.monotonic()
            process = subprocess.run(command, cwd=work, env=env, capture_output=True, text=True, timeout=120)
            (out / (operation + ".stdout.log")).write_text(process.stdout, encoding="utf-8")
            (out / (operation + ".stderr.log")).write_text(process.stderr, encoding="utf-8")
            row = {"argv":command,"cwd":str(work),"exit_code":process.returncode,
                   "elapsed_seconds":time.monotonic()-started}
            receipt["commands"].append(row)
            if process.returncode:
                raise ValueError("shipped reference.py " + operation + " rejected; see retained logs")
            row["upstream_receipt"] = json.loads(process.stdout)
        sample = next(item for item in manifest["samples"] if item["id"] == "success")
        sample_root = package / sample["path"]
        for name in HOST_MEMBERS:
            expected, actual = (sample_root / name).read_bytes(), original_host[name]
            receipt["comparisons"].append({"path":name,"reference_sha256":sha(expected),
                "host_sha256":sha(actual),"reference_bytes":len(expected),"host_bytes":len(actual),
                "byte_equal":expected == actual})
        receipt.update({"package_source":manifest["source"],"runtime_target":manifest["runtime_target"],
            "readiness":manifest["readiness"],"package":manifest["package"],
            "request_config_lock_sha256":{name:sha((sample_root / name).read_bytes())
                for name in ("request.json","config.json","module-lock.json","provenance.json")},
            "verified_file_hashes":manifest["files"],"zip_members":len(inventory),
            "host_resources_unchanged":all((host / n).read_bytes() == data for n,data in original_host.items()),
            "godot_run":False,"game_python_or_zip_copied":False})
        if not receipt["host_resources_unchanged"]:
            raise ValueError("host resources changed during verification")
        if not all(row["byte_equal"] for row in receipt["comparisons"]):
            raise ValueError("reference/host file bytes differ; no host file was updated")
        receipt["development_check_passed"] = True
        save(out / "receipt.json", receipt)
        return receipt
    except Exception as exc:
        receipt.update({"development_check_passed":False,"error":{"type":type(exc).__name__,"message":str(exc)}})
        save(out / "receipt.json", receipt)
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path, required=True)
    parser.add_argument("--host-data", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    try:
        result = verify(args.archive, args.host_data, args.out)
        print(json.dumps({"development_check_passed":True,"compared_files":len(result["comparisons"]),
                          "receipt":str(args.out / "receipt.json")}, ensure_ascii=False))
        return 0
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
