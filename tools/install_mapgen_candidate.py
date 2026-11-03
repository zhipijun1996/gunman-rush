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
RELEASE_HEAD = 'c35871446cc0a3939e1a38171435f42cdc64a359'
SOURCE_COMMIT = '8eefdbd140ce10defe1570ab8eefb6729382f8b3'
ARCHIVE_SHA256 = 'f5c84e5e51dff01d16429783b957c0d5214056b9d2fea47a830baac12ecedb4e'
ARCHIVE_URL = 'https://raw.githubusercontent.com/zhipijun1996/map-gen/c35871446cc0a3939e1a38171435f42cdc64a359/runtime_packages/releases/0.4.1/mapgen-godot-candidate-0.4.1.zip'
MODULE_SHA256 = '5ad5a7871941b2c1ffa759b18f7b1e80f2fe7e571b72f95d1e0ef26031f08723'
CATALOG_SHA256 = '307b3c02c08d6f9abd58ef10bfe0716709bc8260db49a2a2c21d36980330be7a'
REQUEST_SHA256 = '3c81d878d5f508a141a9e44c1f116a5b76966d7bb8da6c02da69aa7a42192d9a'
CONFIG_SHA256 = '65998d9fede6df44f832cde7bb1e368f09eb092aa3f31c9a5fbb9f7c34ea8062'
IMPLEMENTATION = 'mapgen/gdscript-candidate-0.4.1'
LOCK_SHA256 = 'b4c93a5043c1dbe2535f81a5c814bcc1f437e1cf2023d7c37c59c4874fa8a971'
GEARS_REQUEST_SHA256 = '1594181d4d48a419bb26e920a609a559e10e06dbe7bf6d485a1fc26aca745021'
GEARS_REQUEST_PATH = 'resources/mapgen/gears_request_930007.json'
GEARS_CONFORMANCE = {'purpose': 'original upstream 930007 mechanism input; not a host ability grant', 'request': {'path': 'res://resources/mapgen/gears_request_930007.json', 'sha256': '1594181d4d48a419bb26e920a609a559e10e06dbe7bf6d485a1fc26aca745021'}, 'config': {'path': 'res://resources/mapgen/generator_config.json', 'sha256': '65998d9fede6df44f832cde7bb1e368f09eb092aa3f31c9a5fbb9f7c34ea8062'}, 'source': {'included_in_candidate_archive': True, 'archive_member': 'samples/gears-930007/request.json', 'release_head': 'c35871446cc0a3939e1a38171435f42cdc64a359', 'source_commit': '8eefdbd140ce10defe1570ab8eefb6729382f8b3', 'repository_path': 'validation/runtime-reward-B/replay/inputs/validation-930007/request.json', 'url': 'https://raw.githubusercontent.com/zhipijun1996/map-gen/c35871446cc0a3939e1a38171435f42cdc64a359/validation/runtime-reward-B/replay/inputs/validation-930007/request.json', 'git_blob_sha': '4a0c53500bd941bc40f3654c43eebfe7196e911c'}}
ADDON_SHA256 = {
    "candidate_cursor.gd": "b692da22a4b42be6c2c65b44ea04fca88d5c9cd50bf4aaa3bf29bf526cb50d08",
    "content_transform.gd": "80ab9f4e58ceedb754c6062996e0e4a4f36a9542e7c54206639d7760ce92e2f2",
    "data_json.gd": "cef6a962ae33d5d03aa29b57ca35fcef104a07f7a2de636122e3b32cb8d0ea9c",
    "decimal64.gd": "a1c39dc62d62f8191a6d306942b2f549e674e09212970f8bd4a44153ed8e8109",
    "derived_library.gd": "7517199725d96c39bad82c134d2acb3719fa98bfae170ecb74516890696e43d8",
    "final_pipeline.gd": "c44fe36078a4cea5b20541f38c564e143ba4eaafbf6eb6edcf5bbb67d2ceb587",
    "generation_job.gd": "effe3467aced7b978dbc9e2ccfc1492da5e7f8fd0087df066b30264cf12e3e8e",
    "geometry.gd": "a86179cffc4820d774b398362098a4cc4158edaaffc55eda6992817672850a9e",
    "module_archive.gd": "44c075d69db506ced4a2241e8205775a226861234786d43272633c1e7ba46742",
    "numeric.gd": "af1d58403d38687de902e4ded6770aa9972e91a9ea75e2ab5e92f98d41f90f7e",
    "preload_job.gd": "3ea6be476d84262c83c536c943c170a80dd0884bfc441e60bb5fe43b6fc34e68",
    "prepared_library.gd": "f572fe0f4811b1b116140e108a7a9dbc4d6e3b509df220feea66b8af2146cbaa",
    "protocol.gd": "5bf7d2db7914ab3396dc8b18be6ac48e379bab2dfefacfc45b48d522b94b40a4",
    "python_rng.gd": "6b70397a8f8f7dbfd2ba9f2c49101c9e5174e22fc4b761e1e97c07c6a61964d4",
    "reward_clearance.gd": "f1946c2e0bb5fc7c3b6d6229030cd548bc5540a3160a652a5121bd35baf24a02",
    "runtime_export.gd": "5be6d8fd72389acb60efb5651a945e9200a0bc7a15a4a1bff152ab2647311a5c",
    "schema_data.gd": "5afce308ab7a030f120973cd7ba948580b5f8a29e6ef7ff8f012e98360a19f62",
    "solver.gd": "377ce3893488acd51e67df22b9277904e0fe8dbc8267ec1767b4a0732794d562",
    "work_gate.gd": "fec67bc46e091be2d7919003aa0e525c0112772beab12ac82e6da1fcf41e4079"
}
# Immediate predecessor pin: metadata in the target cannot authorize these bytes.
PREVIOUS_LOCK_SHA256 = '09c2c213e1d0311a0d8417595201c262d3ab32dca23616b779e30d2ca5dffb62'
PREVIOUS_ADDON_SHA256 = {
    "candidate_cursor.gd": "1a8ce925ab0d0e35232950618a83af334e9e780e6b61a49600277f6d38280fca",
    "content_transform.gd": "80ab9f4e58ceedb754c6062996e0e4a4f36a9542e7c54206639d7760ce92e2f2",
    "data_json.gd": "cef6a962ae33d5d03aa29b57ca35fcef104a07f7a2de636122e3b32cb8d0ea9c",
    "decimal64.gd": "a1c39dc62d62f8191a6d306942b2f549e674e09212970f8bd4a44153ed8e8109",
    "final_pipeline.gd": "c44fe36078a4cea5b20541f38c564e143ba4eaafbf6eb6edcf5bbb67d2ceb587",
    "generation_job.gd": "522d9cfa4a56ca08d3e721a1ba58b40974be2e27e983f2381f63ec3e3250d5ac",
    "geometry.gd": "a86179cffc4820d774b398362098a4cc4158edaaffc55eda6992817672850a9e",
    "module_archive.gd": "44c075d69db506ced4a2241e8205775a226861234786d43272633c1e7ba46742",
    "numeric.gd": "af1d58403d38687de902e4ded6770aa9972e91a9ea75e2ab5e92f98d41f90f7e",
    "preload_job.gd": "64c129d7bca5c894db3d76e5f73141bd2406f6df7812290d71c6d1535d37ca1f",
    "prepared_library.gd": "f572fe0f4811b1b116140e108a7a9dbc4d6e3b509df220feea66b8af2146cbaa",
    "protocol.gd": "87629cf89bd5d34fc1bea8a4d43de1d2a19348b6104d29f0ae01d36c937c6ad4",
    "python_rng.gd": "6b70397a8f8f7dbfd2ba9f2c49101c9e5174e22fc4b761e1e97c07c6a61964d4",
    "reward_clearance.gd": "f1946c2e0bb5fc7c3b6d6229030cd548bc5540a3160a652a5121bd35baf24a02",
    "runtime_export.gd": "5be6d8fd72389acb60efb5651a945e9200a0bc7a15a4a1bff152ab2647311a5c",
    "schema_data.gd": "5afce308ab7a030f120973cd7ba948580b5f8a29e6ef7ff8f012e98360a19f62",
    "solver.gd": "96e1ea947ed7864843ac0b72765d2957b75357f6677472513667fe9e142b401f",
    "work_gate.gd": "fec67bc46e091be2d7919003aa0e525c0112772beab12ac82e6da1fcf41e4079"
}

# Keep the original authenticated 0.3.0 upgrade path and its exact pin.
LEGACY_LOCK_SHA256 = 'd8271d473686fd1e7b0bcfab280aa2940777eb1eaa02478b80909cb8eecae92f'
LEGACY_CONFIG_SHA256 = 'aafd76336c23ff144b94368f3290114cd3ae7be812dedbcd8a50ca610102f89a'
LEGACY_ADDON_SHA256 = {
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
    "solver.gd": "dc9ab9eb10761cdd251e6267ac7330f831ace168df467c873511e6e8d096131a"
}

def digest(data):
    return hashlib.sha256(data).hexdigest()


def require(ok, message):
    if not ok:
        raise ValueError(message)


def managed_path(root, name, message):
    # Check lexical components before resolving: an internal symlink can resolve
    # inside root while still redirecting a managed directory to an alias.
    path = root
    for component in Path(name).parts:
        path = path / component
        require(not path.is_symlink(), message + name)
    require(path.resolve().is_relative_to(root.resolve()), message + name)
    return path


def additional_payload():
    # Preserve the exact original host input; the new ZIP also carries this
    # identical request, checked independently in read_payload below.
    path = managed_path(ROOT, GEARS_REQUEST_PATH, "unsafe additional input:")
    data = path.read_bytes()
    require(digest(data) == GEARS_REQUEST_SHA256, "additional upstream input SHA mismatch:" + GEARS_REQUEST_PATH)
    return {GEARS_REQUEST_PATH:data}


def read_payload(archive):
    require(digest(archive.read_bytes()) == ARCHIVE_SHA256, "candidate ZIP SHA mismatch")
    # Shared original extraction protocol; the temporary full bundle is never
    # installed into the game. Only the explicitly selected payload escapes it.
    with tempfile.TemporaryDirectory(prefix="mapgen-candidate-install-") as temporary:
        package, _ = extract_original_protocol(archive, Path(temporary))
        manifest = json.loads((package / "manifest.json").read_text(encoding="utf-8"))
        require(manifest["source"]["commit"] == SOURCE_COMMIT, "manifest actual source mismatch")
        require(manifest["package"] == {"version":"0.4.1", "algorithm":"stable-v3-reward-space",
                "implementation":IMPLEMENTATION}, "candidate identity mismatch")
        require(manifest["runtime_target"] == "godot-standard-gdscript" and
                manifest["readiness"]["production_ready"] is False, "candidate readiness mismatch")
        actual = {p.relative_to(package).as_posix() for p in package.rglob("*") if p.is_file()}
        require(actual == set(manifest["files"]) | {"manifest.json"}, "candidate file inventory mismatch")
        for name, expected in manifest["files"].items():
            require(digest((package / name).read_bytes()) == expected, "candidate member SHA mismatch:" + name)
        addon_files = {"addons/mapgen/" + name:sha for name,sha in ADDON_SHA256.items()}
        require({n:h for n,h in manifest["files"].items() if n.startswith("addons/mapgen/")} == addon_files,
                "candidate addon member inventory mismatch")
        require(manifest["module_package"] == {"version":"1.1.0", "sha256":MODULE_SHA256,
                "compatibility":"exact SHA; source ZIP required even with derived data"},
                "module lock mismatch")
        payload = {name:(package / name).read_bytes() for name in addon_files}
        data_sources = {
            "resources/mapgen/module-pack-1.1.0.zip": ("tests/dependencies/modules.zip", MODULE_SHA256),
            "resources/mapgen/conformance_request.json": ("tests/request.json", REQUEST_SHA256),
            "resources/mapgen/generator_config.json": ("tests/config.json", CONFIG_SHA256),
        }
        for target,(source,expected) in data_sources.items():
            data = (package / source).read_bytes()
            require(digest(data) == expected, "locked data SHA mismatch:" + source)
            payload[target] = data
        original_gears = additional_payload()
        require((package / "samples/gears-930007/request.json").read_bytes() == original_gears[GEARS_REQUEST_PATH],
                "candidate gears input differs from original host request")
        payload.update(original_gears)
        # This exact release contains no LICENSE/COPYING/NOTICE leaf. Refuse a
        # changed assumption rather than omit new attribution in a future pin.
        notices = [n for n in manifest["files"] if Path(n).name.upper().startswith(("LICENSE", "COPYING", "NOTICE"))]
        require(not notices, "upstream attribution leaf requires explicit installation mapping")
        config = {
            "version":"0.4.1", "algorithm":"stable-v3-reward-space", "implementation":IMPLEMENTATION,
            "release_head":RELEASE_HEAD, "source_commit":SOURCE_COMMIT,
            "archive":{"url":ARCHIVE_URL,"sha256":ARCHIVE_SHA256},
            "module_package":{"version":"1.1.0","path":"res://resources/mapgen/module-pack-1.1.0.zip",
                              "sha256":MODULE_SHA256,"catalog_sha256":CATALOG_SHA256},
            "conformance":{"purpose":"upstream 930001 consistency inputs; not a host ability grant",
                "request":{"path":"res://resources/mapgen/conformance_request.json","sha256":REQUEST_SHA256},
                "config":{"path":"res://resources/mapgen/generator_config.json","sha256":CONFIG_SHA256}},
            "addon_files":addon_files, "derived_cache":manifest["derived_cache"],
            "readiness":manifest["readiness"], "license_files":notices,
            "gears_conformance":GEARS_CONFORMANCE,
        }
        payload["config/mapgen_candidate.json"] = (json.dumps(config,ensure_ascii=False,indent=2) + "\n").encode("utf-8")
        return payload


def installed_hashes():
    # Pin the complete approved config bytes as well as its actual dependencies;
    # editing the config's own advertised hashes cannot approve altered code.
    return {**{"addons/mapgen/" + name:sha for name,sha in ADDON_SHA256.items()},
            "resources/mapgen/module-pack-1.1.0.zip":MODULE_SHA256,
            "resources/mapgen/conformance_request.json":REQUEST_SHA256,
            "resources/mapgen/generator_config.json":CONFIG_SHA256,
            "config/mapgen_candidate.json":LOCK_SHA256,
            GEARS_REQUEST_PATH:GEARS_REQUEST_SHA256}


def legacy_hashes():
    return {**{"addons/mapgen/" + name:sha for name,sha in LEGACY_ADDON_SHA256.items()},
            "resources/mapgen/module-pack-1.1.0.zip":MODULE_SHA256,
            "resources/mapgen/conformance_request.json":REQUEST_SHA256,
            "resources/mapgen/generator_config.json":LEGACY_CONFIG_SHA256,
            "config/mapgen_candidate.json":LEGACY_LOCK_SHA256}


def previous_hashes():
    """Complete fixed 0.4.0 installation, including the original gears input."""
    return {**{"addons/mapgen/" + name:sha for name,sha in PREVIOUS_ADDON_SHA256.items()},
            "resources/mapgen/module-pack-1.1.0.zip":MODULE_SHA256,
            "resources/mapgen/conformance_request.json":REQUEST_SHA256,
            "resources/mapgen/generator_config.json":CONFIG_SHA256,
            "config/mapgen_candidate.json":PREVIOUS_LOCK_SHA256,
            GEARS_REQUEST_PATH:GEARS_REQUEST_SHA256}


def upgrade(archive, target):
    """Explicit authenticated predecessor -> 0.4.1; check all paths before writes."""
    target = target.resolve()
    payload = read_payload(archive.resolve())
    hashes = {name:digest(data) for name,data in payload.items()}
    require(hashes == installed_hashes(), "approved installed payload pin mismatch")
    current_lock = managed_path(target, "config/mapgen_candidate.json", "unsafe install destination:")
    if current_lock.is_file() and not current_lock.is_symlink() and digest(current_lock.read_bytes()) == LOCK_SHA256:
        preflight(target, hashes, True)
        receipt = report("upgrade",target,[],list(hashes),hashes,True)
        receipt.update({"already_current":True,"replaced":[],"upgraded_from":None})
        return receipt
    previous = previous_hashes()
    from_version = "0.4.0"
    # Select a fixed complete pin by raw lock bytes, never by advertised version.
    # The older supported 0.3 path retains its original full-byte validation.
    if not current_lock.is_file() or digest(current_lock.read_bytes()) != previous["config/mapgen_candidate.json"]:
        previous = legacy_hashes()
        from_version = "0.3.0"
    # A missing/tampered/mixed version cannot qualify via edited metadata.
    preflight(target, previous, True)
    for name in hashes.keys() - previous.keys():
        path = managed_path(target, name, "unsafe install destination:")
        require(not path.exists(), "upgrade destination already exists:" + name)
    installed, unchanged, replaced = [], [], []
    for name,data in payload.items():
        path = target / name
        if path.exists() and path.read_bytes() == data:
            unchanged.append(name)
            continue
        existed = path.exists()
        path.parent.mkdir(parents=True,exist_ok=True)
        # Stage each complete byte sequence before its atomic destination swap.
        temporary = None
        try:
            with tempfile.NamedTemporaryFile(dir=path.parent,prefix="."+path.name+".",delete=False) as stream:
                temporary = Path(stream.name)
                stream.write(data)
            temporary.replace(path)
        finally:
            if temporary is not None:
                temporary.unlink(missing_ok=True)
        (replaced if existed else installed).append(name)
    preflight(target, hashes, True)
    receipt = report("upgrade",target,installed,unchanged,hashes,True)
    receipt.update({"upgraded_from":{"version":from_version,"config_sha256":previous["config/mapgen_candidate.json"]},
                    "replaced":replaced,"already_current":False})
    return receipt


def preflight(target, hashes, require_all):
    # Shared by archive install/verify and offline installed-byte verification.
    # Inspect every destination before an install writes its first missing file.
    for name,expected in hashes.items():
        path = managed_path(target, name, "unsafe install destination:")
        if path.exists():
            require(path.is_file() and digest(path.read_bytes()) == expected,
                    "installed file differs; refusing overwrite:" + name)
        elif require_all:
            raise ValueError("installed file missing:" + name)
    addon = target / "addons/mapgen"
    if addon.exists():
        for path in addon.rglob("*"):
            require(not path.is_symlink(), "unexpected addon symlink:" + path.relative_to(target).as_posix())
            if path.is_dir():
                continue
            name = path.relative_to(target).as_posix()
            generated_uid = name.endswith(".gd.uid") and name[:-4] in hashes
            require(name in hashes or generated_uid, "unexpected addon file:" + name)


def report(command, target, installed, unchanged, hashes, archive_checked):
    return {"command":command,"target":str(target),"installed":installed,"unchanged":unchanged,
            "files":hashes,"candidate_archive_sha256":ARCHIVE_SHA256,
            "candidate_archive_checked":archive_checked,"release_head":RELEASE_HEAD,
            "source_commit":SOURCE_COMMIT,"godot_run":False,
            "additional_inputs":{GEARS_REQUEST_PATH:GEARS_CONFORMANCE["source"]}}


def apply(command, archive, target):
    target = target.resolve()
    payload = read_payload(archive.resolve())
    hashes = {name:digest(data) for name,data in payload.items()}
    require(hashes == installed_hashes(), "approved installed payload pin mismatch")
    preflight(target, hashes, command == "verify")
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
    return report(command, target, installed, unchanged, hashes, True)


def verify_installed(target):
    target = target.resolve()
    hashes = installed_hashes()
    preflight(target, hashes, True)
    # This verifies the installed files, not a nonexistent CI archive. The
    # archive digest in the receipt remains an explicitly unchecked source pin.
    return report("verify-installed", target, [], list(hashes), hashes, False)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command",choices=("install","verify","verify-installed","upgrade"))
    parser.add_argument("--archive",type=Path,help="required for install/verify/upgrade of the original upstream ZIP")
    parser.add_argument("--target",type=Path,default=ROOT,help="project root (defaults to this tool's checkout)")
    args = parser.parse_args()
    if args.command == "verify-installed" and args.archive is not None:
        parser.error("verify-installed does not use --archive")
    if args.command != "verify-installed" and args.archive is None:
        parser.error("install/verify/upgrade require --archive")
    try:
        if args.command == "verify-installed":
            result = verify_installed(args.target)
        elif args.command == "upgrade":
            result = upgrade(args.archive,args.target)
        else:
            result = apply(args.command,args.archive,args.target)
        print(json.dumps(result,ensure_ascii=False,indent=2))
        return 0
    except (OSError,ValueError,KeyError) as exc:
        print(str(exc),file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
