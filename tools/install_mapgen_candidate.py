#!/usr/bin/env python3
"""Install/verify the locked upstream data-only addon; never launch Godot."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import tempfile

from verify_mapgen_reference import extract_original_protocol

ROOT = Path(__file__).resolve().parents[1]
RELEASE_HEAD = "93c5221a9708d079c2864f3c14b415e81bb5de07"
SOURCE_COMMIT = "508b558e8a9925862e8a26c20fea008b9a772007"
ARCHIVE_SHA256 = "9ea87854c96cf7c2189b4c6ad25a8056454a3150721bead79c335aca8678acd0"
ARCHIVE_URL = ("https://raw.githubusercontent.com/zhipijun1996/map-gen/" + RELEASE_HEAD +
               "/godot_candidate/releases/0.3.0/mapgen-godot-candidate-0.3.0.zip")
MODULE_SHA256 = "5ad5a7871941b2c1ffa759b18f7b1e80f2fe7e571b72f95d1e0ef26031f08723"
CATALOG_SHA256 = "307b3c02c08d6f9abd58ef10bfe0716709bc8260db49a2a2c21d36980330be7a"
REQUEST_SHA256 = "3c81d878d5f508a141a9e44c1f116a5b76966d7bb8da6c02da69aa7a42192d9a"
CONFIG_SHA256 = "aafd76336c23ff144b94368f3290114cd3ae7be812dedbcd8a50ca610102f89a"
IMPLEMENTATION = "mapgen/gdscript-candidate-0.3.0"
ADDON_SHA256 = {
    "candidate_cursor.gd": "1a8ce925ab0d0e35232950618a83af334e9e780e6b61a49600277f6d38280fca",
    "content_transform.gd": "80ab9f4e58ceedb754c6062996e0e4a4f36a9542e7c54206639d7760ce92e2f2",
    "data_json.gd": "b4746054f87f8f8207c63b24f2fd42c0d0e6f7b8859dc925d0ba1928089699a6",
    "decimal64.gd": "a1c39dc62d62f8191a6d306942b2f549e674e09212970f8bd4a44153ed8e8109",
    "final_pipeline.gd": "7613f27656b6be9dd6bec771a0ee40cb67aa7c0f1d8de7ab630ede39471d448b",
    "generation_job.gd": "7ccb6cd915f02081f391c95cea40fed06789df21d7519ea943533f668c044f46",
    "geometry.gd": "a86179cffc4820d774b398362098a4cc4158edaaffc55eda6992817672850a9e",
    "module_archive.gd": "c4b74177688308e6f8ccddd6d54b42bf22763e846843651faa1e99880c0aafae",
    "numeric.gd": "af1d58403d38687de902e4ded6770aa9972e91a9ea75e2ab5e92f98d41f90f7e",
    "prepared_library.gd": "7640c2a43b61db7ec4d10b22f861fbf2299088cb560585c2c3225c2039192ce3",
    "protocol.gd": "24921a0bfe641fb5741a23696d04db5d31e71d2468914c539cffcc06ce0a6f23",
    "python_rng.gd": "6b70397a8f8f7dbfd2ba9f2c49101c9e5174e22fc4b761e1e97c07c6a61964d4",
    "runtime_export.gd": "5be6d8fd72389acb60efb5651a945e9200a0bc7a15a4a1bff152ab2647311a5c",
    "schema_data.gd": "9fa7335c10c83fe48b07aa29f9d016f0a894441bc199232e4e3a2f3fd086f943",
    "solver.gd": "dc9ab9eb10761cdd251e6267ac7330f831ace168df467c873511e6e8d096131a",
}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def require(ok, message):
    if not ok:
        raise ValueError(message)


def read_payload(archive):
    require(digest(archive.read_bytes()) == ARCHIVE_SHA256, "candidate ZIP SHA mismatch")
    # Shared original extraction protocol; the temporary full bundle is never
    # installed into the game. Only the explicitly selected payload escapes it.
    with tempfile.TemporaryDirectory(prefix="mapgen-candidate-install-") as temporary:
        package, _ = extract_original_protocol(archive, Path(temporary))
        manifest = json.loads((package / "manifest.json").read_text(encoding="utf-8"))
        require(manifest["source"]["commit"] == SOURCE_COMMIT, "manifest actual source mismatch")
        require(manifest["package"] == {"name":"mapgen-godot-candidate-0.3.0", "version":"0.3.0",
                "algorithm":"stable-v2", "implementation":IMPLEMENTATION}, "candidate identity mismatch")
        require(manifest["runtime_target"] == "godot-standard-gdscript" and
                manifest["readiness"]["production_ready"] is False, "candidate readiness mismatch")
        actual = {p.relative_to(package).as_posix() for p in package.rglob("*") if p.is_file()}
        require(actual == set(manifest["files"]) | {"manifest.json"}, "candidate file inventory mismatch")
        for name, expected in manifest["files"].items():
            require(digest((package / name).read_bytes()) == expected, "candidate member SHA mismatch:" + name)
        addon_files = {"addons/mapgen/" + name:sha for name,sha in ADDON_SHA256.items()}
        require({n:h for n,h in manifest["files"].items() if n.startswith("addons/mapgen/")} == addon_files,
                "candidate addon member inventory mismatch")
        require(manifest["module_lock"]["sha256"] == MODULE_SHA256 and
                manifest["module_lock"]["catalog_sha256"] == CATALOG_SHA256, "module lock mismatch")
        payload = {name:(package / name).read_bytes() for name in addon_files}
        data_sources = {
            "resources/mapgen/module-pack-1.1.0.zip": (manifest["module_zip_ref"], MODULE_SHA256),
            "resources/mapgen/conformance_request.json": ("tests/request.json", REQUEST_SHA256),
            "resources/mapgen/generator_config.json": ("tests/config.json", CONFIG_SHA256),
        }
        for target,(source,expected) in data_sources.items():
            data = (package / source).read_bytes()
            require(digest(data) == expected, "locked data SHA mismatch:" + source)
            payload[target] = data
        # This exact release contains no LICENSE/COPYING/NOTICE leaf. Refuse a
        # changed assumption rather than omit new attribution in a future pin.
        notices = [n for n in manifest["files"] if Path(n).name.upper().startswith(("LICENSE", "COPYING", "NOTICE"))]
        require(not notices, "upstream attribution leaf requires explicit installation mapping")
        config = {
            "version":"0.3.0", "algorithm":"stable-v2", "implementation":IMPLEMENTATION,
            "release_head":RELEASE_HEAD, "source_commit":SOURCE_COMMIT,
            "archive":{"url":ARCHIVE_URL,"sha256":ARCHIVE_SHA256},
            "module_package":{"version":"1.1.0","path":"res://resources/mapgen/module-pack-1.1.0.zip",
                              "sha256":MODULE_SHA256,"catalog_sha256":CATALOG_SHA256},
            "conformance":{"purpose":"upstream 930001 consistency inputs; not a host ability grant",
                "request":{"path":"res://resources/mapgen/conformance_request.json","sha256":REQUEST_SHA256},
                "config":{"path":"res://resources/mapgen/generator_config.json","sha256":CONFIG_SHA256}},
            "addon_files":addon_files, "readiness":manifest["readiness"], "license_files":notices,
        }
        payload["config/mapgen_candidate.json"] = (json.dumps(config,ensure_ascii=False,indent=2) + "\n").encode("utf-8")
        return payload


def apply(command, archive, target):
    target = target.resolve()
    payload = read_payload(archive.resolve())
    # Preflight every destination before writing anything. Existing differences
    # never get silently overwritten, even by a repeat installation.
    for name,data in payload.items():
        path = target / name
        require(not path.is_symlink() and path.resolve().is_relative_to(target), "unsafe install destination:" + name)
        if path.exists():
            require(path.is_file() and path.read_bytes() == data, "installed file differs; refusing overwrite:" + name)
        elif command == "verify":
            raise ValueError("installed file missing:" + name)
    addon = target / "addons/mapgen"
    if addon.exists():
        for path in addon.rglob("*"):
            require(not path.is_symlink(), "unexpected addon symlink:" + path.relative_to(target).as_posix())
            if path.is_dir():
                continue
            name = path.relative_to(target).as_posix()
            generated_uid = name.endswith(".gd.uid") and name[:-4] in payload
            require(not path.is_symlink() and (name in payload or generated_uid), "unexpected addon file:" + name)
    installed, unchanged = [], []
    for name,data in payload.items():
        path = target / name
        if path.exists():
            unchanged.append(name)
        elif command == "install":
            path.parent.mkdir(parents=True,exist_ok=True)
            with path.open("xb") as stream:
                stream.write(data)
            installed.append(name)
        require(path.read_bytes() == data, "installed bytes mismatch:" + name)
    return {"command":command,"target":str(target),"installed":installed,"unchanged":unchanged,
            "files":{name:digest(data) for name,data in payload.items()},
            "candidate_archive_sha256":ARCHIVE_SHA256,"release_head":RELEASE_HEAD,
            "source_commit":SOURCE_COMMIT,"godot_run":False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command",choices=("install","verify"))
    parser.add_argument("--archive",type=Path,required=True,help="explicit locked original upstream ZIP")
    parser.add_argument("--target",type=Path,default=ROOT,help="project root (defaults to this tool's checkout)")
    args = parser.parse_args()
    try:
        print(json.dumps(apply(args.command,args.archive,args.target),ensure_ascii=False,indent=2))
        return 0
    except (OSError,ValueError,KeyError) as exc:
        print(str(exc),file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
