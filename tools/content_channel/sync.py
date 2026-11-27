#!/usr/bin/env python3
"""Import a checked, immutable content release. The running game never uses HTTP.

contract.py is the byte-for-byte producer contract. Change it at the producer,
then synchronize both consumers together; do not independently fork its rules.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import sys
import tempfile
from urllib.error import URLError
from urllib.parse import urljoin, urlsplit, unquote
from urllib.request import HTTPRedirectHandler, Request, build_opener

from contract import (
    ContractError, canonical_bytes, load_json_bytes, sha256_bytes,
    safe_relative_path, validate_latest, validate_manifest, validate_upgrade,
)

ORIGIN = "https://clock-world-explorer-1117.zhipijun1996.chatgpt.site"
CHANNEL_PATH = "/exports/channel-v1/"
LATEST_URL = ORIGIN + CHANNEL_PATH + "latest.json"
MAX_CONTENT = 16 * 1024 * 1024
MAX_METADATA = 1024 * 1024
ROOT = Path(__file__).resolve().parents[2]
DEFAULT_DEST = ROOT / "production/config/imported_world"
SHA = re.compile(r"^[0-9a-f]{64}$")


def require(test: bool, message: str) -> None:
    if not test:
        raise ContractError(message)


def approved_url(url: str) -> str:
    parsed = urlsplit(url)
    require(parsed.scheme == "https" and parsed.netloc == urlsplit(ORIGIN).netloc,
            "source_origin_not_allowed")
    require(not parsed.query and not parsed.fragment and not parsed.username and not parsed.password,
            "source_url_invalid")
    decoded = unquote(parsed.path)
    require(parsed.path == decoded and "\\" not in decoded and decoded.startswith(CHANNEL_PATH),
            "source_path_not_allowed")
    safe_relative_path(decoded[len(CHANNEL_PATH):])
    return url


class SameOriginRedirects(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        approved_url(newurl)
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def fetch(url: str, limit: int) -> bytes:
    approved_url(url)
    opener = build_opener(SameOriginRedirects())
    try:
        with opener.open(Request(url, headers={"User-Agent": "clock-world-content-import/1"}), timeout=20) as response:
            approved_url(response.url)
            raw = response.read(limit + 1)
    except (URLError, TimeoutError, OSError) as error:
        raise ContractError(f"content_download_failed: {error}") from error
    require(len(raw) <= limit, "content_download_too_large")
    return raw


def metadata(raw: bytes) -> dict:
    require(len(raw) <= MAX_METADATA, "metadata_too_large")
    value = load_json_bytes(raw)
    require(isinstance(value, dict), "metadata_object_required")
    return value


def read_release(manifest_path: Path) -> tuple[dict, bytes, bytes, str]:
    manifest_path = manifest_path.resolve(strict=True)
    manifest_raw = manifest_path.read_bytes()
    manifest = metadata(manifest_raw)
    descriptor = manifest.get("bundle")
    require(isinstance(descriptor, dict), "manifest_bundle_object_required")
    payload_path = safe_relative_path(descriptor.get("path", ""))
    require(payload_path == "content.json", "bundle_path_must_be_content_json")
    content_path = (manifest_path.parent / payload_path).resolve(strict=True)
    require(content_path.parent == manifest_path.parent, "local_bundle_path_escape")
    require(content_path.stat().st_size <= MAX_CONTENT, "content_too_large")
    raw = content_path.read_bytes()
    bundle = validate_manifest(manifest, raw)
    return bundle, manifest_raw, raw, "local-package"


def read_remote(manifest_url: str | None) -> tuple[dict, bytes, bytes, str]:
    latest = None
    if manifest_url is None:
        latest = metadata(fetch(LATEST_URL, MAX_METADATA))
        validate_latest(latest)
        manifest_url = urljoin(LATEST_URL, safe_relative_path(latest["manifest"]["path"]))
    approved_url(manifest_url)
    manifest_raw = fetch(manifest_url, MAX_METADATA)
    if latest is not None:
        require(len(manifest_raw) == latest["manifest"]["size_bytes"], "manifest_size_mismatch")
        require(sha256_bytes(manifest_raw) == latest["manifest"]["sha256"], "manifest_hash_mismatch")
    manifest = metadata(manifest_raw)
    descriptor = manifest.get("bundle")
    require(isinstance(descriptor, dict), "manifest_bundle_object_required")
    relative = safe_relative_path(descriptor.get("path", ""))
    require(relative == "content.json", "bundle_path_must_be_content_json")
    bundle_url = urljoin(manifest_url, relative)
    raw = fetch(bundle_url, MAX_CONTENT)
    bundle = validate_manifest(manifest, raw)
    expected = f"{CHANNEL_PATH}releases/{manifest['bundle']['sha256']}/manifest.json"
    require(urlsplit(manifest_url).path == expected, "immutable_manifest_path_mismatch")
    if latest is not None:
        for field in ("world_id", "content_version", "source_model_sha256"):
            require(latest[field] == manifest[field], f"latest_{field}_mismatch")
        require(latest["bundle_sha256"] == manifest["bundle"]["sha256"], "latest_bundle_hash_mismatch")
    return bundle, manifest_raw, raw, manifest_url


def safe_local(root: Path, relative: str) -> Path:
    relative = safe_relative_path(relative)
    resolved = (root / relative).resolve()
    require(resolved.is_relative_to(root.resolve()), "installed_path_escape")
    return resolved


def installed(dest: Path) -> tuple[dict, dict] | None:
    lock_path = dest / "current.lock.json"
    if not lock_path.exists():
        return None
    lock = metadata(lock_path.read_bytes())
    require(lock.get("format") == "clock-world-content-lock" and lock.get("schema_version") == 1,
            "lock_format_unsupported")
    sha = lock.get("bundle_sha256", "")
    require(isinstance(sha, str) and bool(SHA.fullmatch(sha)), "lock_hash_invalid")
    require(lock.get("manifest_path") == f"releases/{sha}/manifest.json", "lock_manifest_path_invalid")
    require(lock.get("content_path") == f"releases/{sha}/content.json", "lock_content_path_invalid")
    bundle, _, raw, _ = read_release(safe_local(dest, lock["manifest_path"]))
    require(sha256_bytes(raw) == sha, "lock_bundle_hash_mismatch")
    for field in ("world_id", "content_version", "source_model_sha256"):
        require(lock.get(field) == bundle.get(field), f"lock_{field}_mismatch")
    return lock, bundle


def check_bindings(bundle: dict, bindings_path: Path) -> None:
    if not bindings_path.exists():
        return
    bindings = metadata(bindings_path.read_bytes())
    require(bindings.get("format") == "clock-world-runtime-bindings" and bindings.get("schema_version") == 1,
            "bindings_format_unsupported")
    require(bindings.get("world_id") == bundle["world_id"], "bindings_world_mismatch")
    sections = {"rooms": "rooms", "npcs": "npcs", "enemy_species": "enemy_species",
                "equipment_effects": "equipment", "event_triggers": "events"}
    for section, table in sections.items():
        rows = bindings.get(section)
        require(isinstance(rows, dict), f"bindings_{section}_object_required")
        indexed = {row["id"]: row for row in bundle["data"][table]}
        for identifier, row in rows.items():
            require(identifier in indexed and isinstance(row, dict), f"binding_unknown_id:{section}:{identifier}")
            if section == "rooms":
                resource = row.get("document_path", "")
                require(isinstance(resource, str) and resource.startswith(("res://rooms/", "res://tests/")), "room_binding_path_invalid")
                relative = safe_relative_path(resource[6:])
                require(relative.endswith(".json"), "room_binding_document_required")
                path = safe_local(ROOT / "production", relative)
                require(path.is_file(), f"room_binding_missing:{identifier}")
                document = load_json_bytes(path.read_bytes())
                require(document.get("schema") == 3 and document.get("room_id") == identifier,
                        f"room_binding_identity_mismatch:{identifier}")
                status = row.get("status")
                require(status in ("authored", "placeholder", "integration_test"), "room_binding_status_required")
                require(document.get("reception", False) is (status == "placeholder"), "room_reception_status_mismatch")
                if status in ("authored", "placeholder"):
                    directory = "rooms/world/receivers" if status == "placeholder" else "rooms/world"
                    require(relative == f"{directory}/{identifier}.json", "room_binding_path_invalid")
                    check_room_construction(document, indexed[identifier], status, rows)
                check_room_content_links(document, bundle, bindings)


def check_room_construction(document: dict, room: dict, status: str, bindings: dict) -> None:
    """Only the installed rooms constrain a release's new construction data."""
    rid = room["id"]
    authoring = room.get("authoring")
    construction = authoring.get("construction") if isinstance(authoring, dict) else None
    require(isinstance(construction, dict), f"room_construction_required:{rid}")
    scale = construction.get("scale")
    require(isinstance(scale, dict) and scale.get("isotropic") is True and scale.get("x") == scale.get("y") == 300,
            f"room_construction_scale_invalid:{rid}")
    bounds = construction.get("bounds_world")
    require(isinstance(bounds, list) and len(bounds) == 4 and document.get("bounds") == bounds,
            f"room_construction_bounds_mismatch:{rid}")
    doors = construction.get("doors")
    exits = document.get("exits", {})
    require(isinstance(doors, list) and isinstance(exits, dict), f"room_construction_doors_invalid:{rid}")
    openings = {d["id"]: d for d in doors if isinstance(d, dict) and d.get("kind") == "physical" and "id" in d}
    if status == "authored":
        require(openings.keys() <= exits.keys(), f"room_construction_door_missing:{rid}")
    else:
        expected = {key for key, door in openings.items()
                    if bindings.get(door.get("other_room"), {}).get("status") == "authored"}
        require(exits.keys() == expected and expected, f"room_reception_exits_mismatch:{rid}")
    for key, gate in exits.items():
        if key not in openings and isinstance(gate, dict) and "span" not in gate:
            continue  # Interior transitions are site interactions.
        label = f"room_construction_opening_mismatch:{rid}/{key}"
        opening = openings.get(key, {})
        endpoints = opening.get("opening_world")
        require(opening.get("axis") in ("h", "v") and isinstance(endpoints, list) and len(endpoints) == 2,
                label)
        require(isinstance(gate, dict) and all(isinstance(pair, list) and len(pair) == 2
                and all(type(value) in (int, float) for value in pair)
                for pair in [*endpoints, gate.get("point"), gate.get("span")]), label)
        along = 0 if opening["axis"] == "h" else 1
        normal = 1 - along
        require(abs(gate["point"][normal] - endpoints[0][normal]) <= .01
                and all(abs(gate["span"][i] - endpoints[i][along]) <= .01 for i in (0, 1)), label)


def check_room_content_links(document: dict, bundle: dict, bindings: dict) -> None:
    """Keep installed room references valid when switching the content lock.

    Authored entities select registered profiles directly. Planning groups,
    suggested counts and room membership impose no restrictions here.
    """
    refs = document.get("content_bindings", {})
    require(isinstance(refs, dict) and set(refs) <= {"enemy_instances"},
            "room_content_bindings_invalid")
    links = refs.get("enemy_instances", {})
    entities = document.get("entities")
    species_bindings = bindings.get("enemy_species")
    require(isinstance(links, dict) and isinstance(entities, dict), "room_enemy_bindings_invalid")
    require(isinstance(species_bindings, dict), "bindings_enemy_species_object_required")
    profiles = {row["id"]: row for row in bundle["data"]["enemy_drop_profiles"]}
    species_ids = {row["id"] for row in bundle["data"]["enemy_species"]}
    for instance_id, link in links.items():
        require(isinstance(link, dict) and set(link) == {"species_id", "drop_profile_id"},
                f"room_enemy_binding_invalid:{instance_id}")
        species_id, profile_id = link["species_id"], link["drop_profile_id"]
        require(isinstance(species_id, str) and species_id in species_ids,
                f"room_enemy_species_unknown:{instance_id}")
        require(isinstance(profile_id, str) and profile_id in profiles,
                f"room_enemy_drop_profile_unknown:{instance_id}")
        require(profiles[profile_id]["species_id"] == species_id,
                f"room_enemy_drop_species_mismatch:{instance_id}")
        entity = entities.get(instance_id)
        mapped = species_bindings.get(species_id)
        require(isinstance(entity, dict) and isinstance(mapped, dict)
                and isinstance(entity.get("definition_id"), str)
                and entity["definition_id"].startswith("enemy.")
                and entity["definition_id"] == mapped.get("definition_id"),
                f"room_enemy_definition_mismatch:{instance_id}")
    encounters = {row["id"]: row for row in bundle["data"]["encounters"]}
    assigned = set()
    exclusive = set()
    sites = document.get("sites", {})
    require(isinstance(sites, dict), "room_sites_invalid")
    for key, site in sites.items():
        if not key.startswith("enc_"):
            continue
        encounter = encounters.get(key, {})
        require(encounter.get("room") == document["room_id"] and isinstance(site, dict),
                f"encounter_room_mismatch:{key}")
        waves = site.get("waves")
        require(isinstance(waves, list) and waves, f"encounter_waves_required:{key}")
        members = set()
        for wave in waves:
            require(isinstance(wave, list) and wave, f"encounter_empty_wave:{key}")
            for member in wave:
                require(isinstance(member, str) and member not in assigned, f"encounter_member_invalid:{key}")
                entity = entities.get(member)
                require(isinstance(entity, dict) and str(entity.get("definition_id", "")).startswith("enemy.")
                        and entity["definition_id"] != "enemy.chime_target", f"encounter_enemy_required:{member}")
                assigned.add(member)
                members.add(member)
        purse = site.get("victory_only", [])
        require(isinstance(purse, list), f"encounter_purse_invalid:{key}")
        for member in purse:
            require(isinstance(member, str) and member in members and member not in links,
                    f"encounter_purse_member_invalid:{member}")
            exclusive.add(member)

    for instance_id, entity in entities.items():
        require(isinstance(entity, dict), f"room_entity_invalid:{instance_id}")
        if entity.get("definition_id") == "enemy.chime_target":
            require(instance_id not in links, f"practice_target_drop_not_allowed:{instance_id}")
        elif str(entity.get("definition_id", "")).startswith("enemy."):
            require(instance_id in links or instance_id in exclusive, f"room_enemy_unbound:{instance_id}")


def make_lock(manifest: dict, source: str) -> dict:
    sha = manifest["bundle"]["sha256"]
    return {"format": "clock-world-content-lock", "schema_version": 1,
            "world_id": manifest["world_id"], "content_version": manifest["content_version"],
            "source_model_sha256": manifest["source_model_sha256"], "bundle_sha256": sha,
            "manifest_path": f"releases/{sha}/manifest.json", "content_path": f"releases/{sha}/content.json",
            "source_manifest": source}


def atomic_write(path: Path, raw: bytes) -> None:
    fd, temporary = tempfile.mkstemp(prefix=".write-", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(raw)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def import_release(bundle: dict, manifest_raw: bytes, raw: bytes, source: str,
                   dest: Path, dry_run: bool = False, rollback: bool = False) -> dict:
    dest = dest.resolve()
    manifest = metadata(manifest_raw)
    bundle = validate_manifest(manifest, raw)
    check_bindings(bundle, dest / "bindings.json")
    current = installed(dest)
    sha = manifest["bundle"]["sha256"]
    if current is not None and current[0]["bundle_sha256"] != sha and not rollback:
        validate_upgrade(current[1], bundle, current[0]["bundle_sha256"])
    result = {"ok": True, "changed": current is None or current[0]["bundle_sha256"] != sha,
              "check_only": dry_run, "world_id": bundle["world_id"], "content_version": bundle["content_version"],
              "bundle_sha256": sha, "counts": manifest["counts"],
              "required_bindings": len(bundle["required_bindings"])}
    if dry_run or not result["changed"]:
        return result
    dest.mkdir(parents=True, exist_ok=True)
    lease_path = dest / ".import.lock"
    try:
        lease = os.open(lease_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    except FileExistsError as error:
        raise ContractError("import_already_running") from error
    stage = None
    try:
        os.close(lease)
        # Re-read after taking the lease so simultaneous imports cannot overwrite
        # a newer pointer based on a stale comparison.
        locked_current = installed(dest)
        require((locked_current or ({},))[0].get("bundle_sha256") == (current or ({},))[0].get("bundle_sha256"),
                "current_content_changed_retry")
        releases = dest / "releases"
        releases.mkdir(exist_ok=True)
        release = releases / sha
        if release.exists():
            _, existing_manifest, existing_raw, _ = read_release(release / "manifest.json")
            require(existing_manifest == manifest_raw and existing_raw == raw, "immutable_release_conflict")
        else:
            stage = Path(tempfile.mkdtemp(prefix=".import-", dir=releases))
            atomic_write(stage / "content.json", raw)
            atomic_write(stage / "manifest.json", manifest_raw)
            os.replace(stage, release)
            stage = None
        atomic_write(dest / "current.lock.json", canonical_bytes(make_lock(manifest, source)))
    finally:
        if stage is not None:
            shutil.rmtree(stage)
        lease_path.unlink(missing_ok=True)
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    inputs = parser.add_mutually_exclusive_group()
    inputs.add_argument("--manifest", help="Immutable HTTPS manifest URL from the configured Site")
    inputs.add_argument("--package", type=Path, help="Local manifest.json from a downloaded release")
    inputs.add_argument("--rollback", help="SHA256 of an already imported release")
    parser.add_argument("--check", action="store_true", help="Validate and show the proposed update without writing")
    parser.add_argument("--expect-sha", help="Reject a discovered release unless it has this SHA256")
    parser.add_argument("--dest", type=Path, default=DEFAULT_DEST, help=argparse.SUPPRESS)
    args = parser.parse_args(argv)
    try:
        if args.rollback:
            require(bool(SHA.fullmatch(args.rollback)), "rollback_hash_invalid")
            bundle, manifest_raw, raw, source = read_release(args.dest / "releases" / args.rollback / "manifest.json")
            source = "installed-release"
        elif args.package:
            bundle, manifest_raw, raw, source = read_release(args.package)
        else:
            bundle, manifest_raw, raw, source = read_remote(args.manifest)
        if args.expect_sha:
            require(sha256_bytes(raw) == args.expect_sha, "requested_content_hash_mismatch")
        result = import_release(bundle, manifest_raw, raw, source, args.dest, args.check, bool(args.rollback))
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0
    except (ContractError, OSError, KeyError, TypeError, ValueError) as error:
        print(json.dumps({"ok": False, "error": str(error)}, ensure_ascii=False), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
