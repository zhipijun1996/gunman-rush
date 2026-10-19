#!/usr/bin/env python3
"""Check the isolated style experiment's actual export closure and carry licenses.

This complements the existing build/check_web_bundle tools. It does not grant
full release, aesthetic, audio or physical-device acceptance.
"""
import argparse
import gzip
import hashlib
import io
import json
import re
import shutil
import subprocess
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
ROOT = REPO / "assets/style_exploration"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def relative(path):
    return path.relative_to(REPO).as_posix()


def source_files():
    """Exclude provenance PNGs, retain original sheets used by live fallbacks."""
    return sorted(path for path in ROOT.rglob("*") if path.is_file()
                  and "generated" not in path.relative_to(ROOT).parts
                  and not ("source" in path.relative_to(ROOT).parts and path.suffix == ".png")
                  and path.suffix in {".png", ".json", ".tres", ".txt", ".md"})


def resource(pack, name):
    if name in pack.entries:
        return pack.read(name)
    remap = pack.read(name + ".remap").decode()
    match = re.search(r'^path="res://([^"\n]+)"$', remap, re.MULTILINE)
    if not match:
        raise ValueError("Resource has no usable export remap: " + name)
    return pack.read(match.group(1))


def check_pack(pack_path):
    from check_web_bundle import Pack, texture_import_targets

    pack = Pack(pack_path)
    checked = {"json": [], "texture": [], "resource": [], "license": []}
    for source in source_files():
        name = relative(source)
        if source.suffix == ".png":
            imported = pack.read(name + ".import").decode()
            targets = texture_import_targets(imported)
            local_import = source.with_suffix(source.suffix + ".import")
            if not targets or not local_import.is_file():
                raise ValueError("Texture lacks imported derivatives: " + name)
            local_targets = texture_import_targets(local_import.read_text())
            for key, target in targets.items():
                if local_targets.get(key) != target or pack.read(target) != (REPO / target).read_bytes():
                    raise ValueError("Texture import bytes differ: " + name)
            checked["texture"].append(name)
        elif source.suffix in {".json", ".txt", ".md"}:
            if pack.read(name) != source.read_bytes():
                raise ValueError("Raw metadata/license differs: " + name)
            if source.suffix == ".json":
                json.loads(pack.read(name))
            checked["json" if source.suffix == ".json" else "license"].append(name)
        else:
            resource(pack, name)
            checked["resource"].append(name)
    for directory in ("scripts/style_exploration", "scenes/style_exploration"):
        for source in sorted((REPO / directory).rglob("*")):
            if source.suffix in {".gd", ".gdshader", ".tscn"}:
                resource(pack, relative(source))
                checked["resource"].append(relative(source))
    for name in pack.entries:
        if name.startswith("assets/style_exploration/") and "/generated/" in name:
            raise ValueError("Provenance-only generated image leaked into pack: " + name)
    return checked


def reconstruct_pack(bundle):
    """Restore exact exported bytes after chunk-only transport through Git."""
    bundle = bundle.resolve()
    info = json.loads((bundle / "build-info.json").read_text())
    pack_name = info["pack"]
    if not isinstance(pack_name, str) or Path(pack_name).name != pack_name or not re.fullmatch(r"index\.[0-9a-f]{12}\.pck", pack_name):
        raise ValueError("Unsafe or unexpected pack name")
    if pack_name != "index." + str(info["build_id"]) + ".pck":
        raise ValueError("Pack filename differs from build ID")
    worker = (bundle / "index.cache-sw.js").read_text()
    match = re.search(r"^const RESOURCE_MAP = (.*);$", worker, re.MULTILINE)
    if not match:
        raise ValueError("Missing canonical cache resource map")
    record = json.loads(match.group(1))[pack_name]
    expected = record["sha256"]
    if not re.fullmatch(r"[0-9a-f]{64}", expected) or expected[:12] != info["build_id"]:
        raise ValueError("Pack digest and build ID disagree")
    amount = record["bytes"]
    if type(amount) is not int or not 0 < amount <= 1024 ** 3 or amount != info["pack_bytes"]:
        raise ValueError("Pack size is inconsistent or exceeds bound")
    target = bundle / pack_name
    existed = target.is_file()
    if existed:
        if target.stat().st_size != amount or digest(target) != expected:
            raise ValueError("Existing full PCK differs from cache contract")
    else:
        partial = target.with_suffix(".pck.reconstructing")
        partial.unlink(missing_ok=True)
        current = hashlib.sha256()
        total = 0
        try:
            with partial.open("xb") as output:
                for chunk in record["chunks"]:
                    size = chunk["bytes"]
                    checksum = chunk["sha256"]
                    if type(size) is not int or not 0 < size <= 512 * 1024 or not re.fullmatch(r"[0-9a-f]{64}", checksum):
                        raise ValueError("Invalid chunk byte/hash contract")
                    if chunk["url"] != "chunks/" + checksum + ".gz":
                        raise ValueError("Chunk URL differs from its content address")
                    source = (bundle / chunk["url"]).resolve()
                    if not source.is_relative_to(bundle):
                        raise ValueError("Chunk escapes bundle directory")
                    compressed = source.read_bytes()
                    if len(compressed) != chunk["gzip_bytes"]:
                        raise ValueError("Compressed chunk byte count differs")
                    with gzip.GzipFile(fileobj=io.BytesIO(compressed)) as archive:
                        data = archive.read(size + 1)
                    if len(data) != size or hashlib.sha256(data).hexdigest() != checksum:
                        raise ValueError("Chunk content SHA256/length differs")
                    total += len(data)
                    if total > amount:
                        raise ValueError("Chunks exceed expected pack length")
                    output.write(data)
                    current.update(data)
            if total != amount or current.hexdigest() != expected:
                raise ValueError("Reconstructed PCK SHA256/length differs")
            partial.replace(target)
        except BaseException:
            partial.unlink(missing_ok=True)
            raise
    return {"scope": "exact PCK reconstruction for static Pages transport",
            "source_commit": info["source_commit"], "build_id": info["build_id"],
            "pack": pack_name, "pack_bytes": amount, "pack_sha256": expected,
            "reconstructed": not existed, "failed": 0}


def copy_licenses(bundle):
    destination = bundle / "style-licenses"
    if destination.exists():
        shutil.rmtree(destination)
    files = []
    for source in sorted(ROOT.glob("*/source/licenses/*")):
        if not source.is_file():
            continue
        target = destination / source.relative_to(ROOT)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        files.append({"path": target.relative_to(bundle).as_posix(), "sha256": digest(target),
                      "bytes": target.stat().st_size})
    destination.mkdir(parents=True, exist_ok=True)
    (destination / "index.json").write_text(json.dumps(files, ensure_ascii=False, indent=2) + "\n")
    return files


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("preflight", "check-bundle", "licenses", "reconstruct-pack"))
    parser.add_argument("--bundle", type=Path, default=REPO / "build/web")
    parser.add_argument("--commit")
    parser.add_argument("--candidate", action="store_true", help="Explicitly label an unfrozen candidate")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    if args.command == "reconstruct-pack":
        encoded = json.dumps(reconstruct_pack(args.bundle), indent=2) + "\n"
        if args.output:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(encoded)
        print(encoded, end="")
        return
    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=REPO, text=True).strip()
    if args.commit and args.commit != commit:
        raise ValueError("Requested commit is not checkout HEAD")
    result = {"scope": "isolated style export closure, not full release acceptance",
              "source_commit": commit, "candidate": args.candidate, "command": args.command}
    if args.command == "preflight":
        result["files"] = [{"path": relative(p), "sha256": digest(p), "bytes": p.stat().st_size}
                           for p in source_files()]
        result["missing_imports"] = [relative(p) for p in source_files()
                                     if p.suffix == ".png" and not p.with_suffix(".png.import").is_file()]
        if result["missing_imports"]:
            raise ValueError("Import required before export: " + str(result["missing_imports"]))
    elif args.command == "licenses":
        result["licenses"] = copy_licenses(args.bundle)
    else:
        info = json.loads((args.bundle / "build-info.json").read_text())
        if info["source_commit"] != commit:
            raise ValueError("Bundle metadata source does not match checkout HEAD")
        pack = args.bundle / info["pack"]
        result.update(build_id=info["build_id"], pack=info["pack"], pack_sha256=digest(pack),
                      checked=check_pack(pack))
        if result["pack_sha256"][:12] != info["build_id"]:
            raise ValueError("Bundle build ID does not match actual PCK hash")
    result["failed"] = 0
    encoded = json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(encoded)
    print(encoded, end="")


if __name__ == "__main__":
    main()
