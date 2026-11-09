#!/usr/bin/env python3
"""Safe opt-in importer for the detached ChatGPT room-art ZIP.

Does not alter the main Godot project or overwrite existing repo files.
"""
import argparse
import hashlib
import json
import sys
from pathlib import Path
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[2]
ARCHIVE_PREFIX = "godot-room-art-cloud/"
ALLOWED = ("art/world-art-v2/", "tools/art_bundle.py")
MAX_BYTES = 40 * 1024 * 1024

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--dry-run", action="store_true", help="Inspect (default)")
    group.add_argument("--apply", action="store_true", help="Write files after checks")
    args = parser.parse_args()
    if not args.archive.is_file():
        parser.error("archive file not found")
    staged = []
    with ZipFile(args.archive) as z:
        bad = z.testzip()
        if bad: raise SystemExit("Corrupted member: " + bad)
        names = set(z.namelist())
        manifest_name = ARCHIVE_PREFIX + "bundle-manifest.json"
        if manifest_name not in names: raise SystemExit("bundle manifest missing")
        manifest = json.loads(z.read(manifest_name))
        if manifest.get("asset_version", "v2-47-depth-expansion") != "v2-47-depth-expansion":
            raise SystemExit("Unexpected room art bundle version")
        expected = {x["path"]: x for x in manifest["files"]}
        for info in z.infolist():
            name = info.filename
            if info.is_dir(): continue
            if not name.startswith(ARCHIVE_PREFIX): raise SystemExit("Unsafe archive prefix")
            path = name[len(ARCHIVE_PREFIX):]
            rel = Path(path)
            if rel.is_absolute() or ".." in rel.parts: raise SystemExit("Unsafe archive path")
            if path not in expected: continue
            if not (path.startswith(ALLOWED[0]) or path == ALLOWED[1]): continue
            if info.file_size > MAX_BYTES: raise SystemExit("Oversized member")
            data = z.read(info)
            if hashlib.sha256(data).hexdigest() != expected[path]["sha256"]:
                raise SystemExit("Hash mismatch " + path)
            dst = ROOT / path
            if dst.exists() and hashlib.sha256(dst.read_bytes()).digest() != hashlib.sha256(data).digest():
                raise SystemExit("Existing different file: " + str(dst))
            staged.append((dst, data))
    total = sum(len(x[1]) for x in staged)
    print(f"Validated {len(staged)} files ({total} bytes).")
    if not args.apply:
        print("Dry run: no files written. Pass --apply to import.")
        return
    for dst, data in staged:
        dst.parent.mkdir(parents=True, exist_ok=True)
        if not dst.exists(): dst.write_bytes(data)
    print("Imported. Verify art/world-art-v2/README.md and run relevant tests.")

if __name__ == "__main__":
    main()
