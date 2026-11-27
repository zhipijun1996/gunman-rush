#!/usr/bin/env python3
"""Exercise the content producer/consumer boundary without writing project data.

Run against the checked-in locked release. Pass --site-root to additionally compare
the producer's current source and validator. All import attempts use temp folders.
This checks a content channel; it does not certify rooms as physically playable.
"""
from __future__ import annotations

import argparse
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def load(path):
    return json.loads(path.read_text(encoding="utf-8"))


def encoded(value):
    return (json.dumps(value, ensure_ascii=False, sort_keys=True,
                       separators=(",", ":"), allow_nan=False) + "\n").encode()


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def by_id(rows, key="id"):
    return {row[key]: row for row in rows}


def fields_equal(source, exported, fields, label):
    for field in fields:
        if field in source:
            require(source[field] == exported.get(field), f"{label}: lost or changed {field}")


def source_preserved(source, bundle):
    """Compare game-relevant facts to the authoring source, not exporter code."""
    data = bundle["data"]
    mappings = (("rooms", "rooms", "id"), ("doors", "doors", "id"),
                ("reward_assignments", "rewards", "reward_key"),
                ("event_interactions", "events", "event"),
                ("encounters", "encounters", "id"),
                ("story_dialogues", "dialogues", "id"),
                ("side_quests", "quests", "id"),
                ("equipment_catalog", "equipment", "id"),
                ("shop_offers", "shops", "id"),
                ("coin_caches", "coin_caches", "id"),
                ("enemy_groups", "enemy_groups", "id"))
    for source_key, table, key in mappings:
        require({row[key] for row in source[source_key]} == {row["id"] for row in data[table]},
                f"{table}: identities differ from current source")
    require([row["id"] for row in source["story_dialogues"]]
            == [row["id"] for row in data["dialogues"]],
            "dialogue order changed the later-match priority tie rule")
    rooms = by_id(data["rooms"])
    for row in source["rooms"]:
        target = rooms[row["id"]]
        fields_equal(row, target, ("region", "map_layer", "default_zone", "zones", "zone_links"), row["id"])
        for field in ("polygon", "label_anchor"):
            require(row["navigation"][field] == target["navigation"][field],
                    f"{row['id']}: planning {field} changed")
    doors = by_id(data["doors"])
    for row in source["doors"]:
        fields_equal(row, doors[row["id"]],
                     ("a", "b", "requires", "one_way_from", "unlock_flag", "zone_by_room",
                      "connection_type", "door", "entrances", "minimum_abilities",
                      "first_open_room", "first_open_zone", "first_route_requires"), row["id"])
    rewards = by_id(data["rewards"])
    for row in source["reward_assignments"]:
        fields_equal(row, rewards[row["reward_key"]],
                     ("room", "zone", "reward_key", "reward_kind", "formal_item_id", "catalog_id",
                      "catalog_equipment_id", "source_type", "existing_world_event", "growth_grants",
                      "equipment_level", "quantity", "requires", "completion_requires",
                      "permanent_unique", "automatic_on_room_entry"), row["reward_key"])
    events = by_id(data["events"])
    for row in source["event_interactions"]:
        target = events[row["event"]]
        fields_equal(row, target, ("event", "room", "zone", "reward_key", "requires", "visible_requires",
                                  "interaction_sites", "interaction_kind", "automatic_on_entry",
                                  "permanent", "coin_reward", "label", "action"), row["event"])
        require([(line.get("speaker"), line.get("text")) for line in row.get("dialogue", [])]
                == [(line.get("speaker"), line.get("text")) for line in target.get("dialogue", [])],
                f"{row['event']}: dialogue text changed")
    table_fields = {
        "encounters": ("room", "zone", "requires", "minimum_abilities", "completion_flag", "coin_reward"),
        "dialogues": ("room", "zone", "speaker", "requires", "excludes", "lines", "priority"),
        "quests": ("accept_event", "completion_event", "steps", "optional", "clues_before_accept"),
        "equipment": ("load", "max_level", "upgrade_prices", "effect_levels", "exclusive_group", "gate_rule"),
        "shops": ("npc_id", "reward_key", "price", "requires"),
        "coin_caches": ("room", "zone", "amount", "requires", "completion_requires", "one_time"),
        "enemy_groups": ("room", "zone", "requires", "completion_requires", "coin_reward", "respawn", "fixed_drop_tier"),
    }
    for source_key, table, key in mappings:
        if table not in table_fields:
            continue
        targets = by_id(data[table])
        for row in source[source_key]:
            target = targets[row[key]]
            fields_equal(row, target, table_fields[table], f"{table}:{row[key]}")
            if table == "enemy_groups":
                require([(r["name"], r["count"], r["coin_each"]) for r in row["enemies"]]
                        == [(r["name"], r["count"], r["coin_each"]) for r in target["enemies"]],
                        f"{row['id']}: planning estimates or individual drops changed")
    species = by_id(data["enemy_species"])
    source_profiles = {(enemy["name"], group["fixed_drop_tier"], enemy["coin_each"])
                       for group in source["enemy_groups"] for enemy in group["enemies"]}
    exported_profiles = {(species[profile["species_id"]]["name"], profile["tier"], profile["coin_each"])
                         for profile in data["enemy_drop_profiles"]}
    # Retained profiles may have no current planning group; every active source
    # species/tier/coin tuple must still survive in the independent catalog.
    require(source_profiles <= exported_profiles, "independent drop profiles lost source species/tier/coin values")
    require(len(exported_profiles) == len(data["enemy_drop_profiles"]), "drop profile identities duplicate the same profile")
    growth_fields = ("starting_weapons", "shared_attack", "shared_skill", "branch_upgrades", "exchanges",
                     "workshop_rooms", "branch_workshop_rooms", "gear_delivery_rooms", "workshop_zones")
    fields_equal(source["growth_economy"], data["growth"], growth_fields, "growth")
    fields_equal(source["transport_plan_11"], data["transport"],
                 ("stations", "rest_only_rooms", "rest_zones"), "transport")
    source_endings = source["ending_requirements"]
    endings = by_id(data["endings"])
    for ending_id, row in source_endings.items():
        fields_equal(row, endings[ending_id], ("target", "requires", "requires_explicit_terminal_interaction"), ending_id)
        fields_equal(source["ending_scenes"][ending_id], endings[ending_id], ("title", "paragraphs", "aftermath"), ending_id)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--game-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--site-root", type=Path)
    parser.add_argument("--package", type=Path, help="Override source manifest.json")
    args = parser.parse_args(argv)
    game_root = args.game_root.resolve()
    importer = game_root / "tools/content_channel/sync.py"
    require(importer.is_file(), "game importer is missing")
    package = args.package
    if package is None and args.site_root:
        channel = args.site_root.resolve() / "dist/exports/channel-v1"
        package = channel / load(channel / "latest.json")["manifest"]["path"]
    if package is None:
        installed = game_root / "production/config/imported_world"
        package = installed / load(installed / "current.lock.json")["manifest_path"]
    package = package.resolve()
    manifest = load(package)
    raw = (package.parent / "content.json").read_bytes()
    bundle = json.loads(raw)
    results = []

    if args.site_root:
        site_root = args.site_root.resolve()
        producer_contract = (site_root / "tools/content_channel/contract.py").read_bytes()
        consumer_contract = (game_root / "tools/content_channel/contract.py").read_bytes()
        require(producer_contract == consumer_contract, "producer/consumer validator drift")
        model_raw = (site_root / "dist/data/world.json").read_bytes()
        require(digest(model_raw) == bundle["source_model_sha256"], "package is not the current Site model")
        source_preserved(json.loads(model_raw), bundle)
        results.append("current_source_semantics_and_shared_validator")

    require(bundle["rules"]["enemy_counts"] == "room_authored_planning_reference"
            and bundle["rules"]["enemy_group_total"] == "derived_planning_estimate_only"
            and bundle["rules"]["enemy_composition"] == "room_authored_from_registered_profiles",
            "enemy instance count or composition is not owned by the authored game room")
    profiles = by_id(bundle["data"]["enemy_drop_profiles"])
    require(profiles, "drop profile tests need a registered economic profile")
    for group in bundle["data"]["enemy_groups"]:
        for enemy in group["enemies"]:
            profile = profiles[enemy["drop_profile_id"]]
            require((enemy["species_id"], group["fixed_drop_tier"], enemy["coin_each"])
                    == (profile["species_id"], profile["tier"], profile["coin_each"]),
                    f"{group['id']}: planning member disagrees with its independent drop profile")
    results.append("independent_drop_profiles_and_advisory_room_budgets")

    sys.path.insert(0, str(importer.parent))
    from sync import check_room_content_links, ContractError
    registry = load(game_root / "production/config/imported_world/bindings.json")
    encounter = bundle["data"]["encounters"][0]
    test_opponent = {"definition_id": "enemy.test_opponent"}
    site = {"waves": [["opponent"]], "victory_only": ["opponent"]}
    fixture = {"room_id": encounter["room"], "sites": {encounter["id"]: site},
               "entities": {"target": {"definition_id": "enemy.chime_target"}, "opponent": test_opponent}}
    check_room_content_links(fixture, bundle, registry)
    site["victory_only"].clear()
    try:
        check_room_content_links(fixture, bundle, registry)
    except ContractError as error:
        require(str(error) == "room_enemy_unbound:opponent", str(error))
    else:
        raise AssertionError("a wave member without a species or victory purse was accepted")
    results.append("practice_targets_and_declared_encounter_purses")


    with tempfile.TemporaryDirectory(prefix="clock-content-check-") as temporary:
        base = Path(temporary)
        destination = base / "installed"

        def run(manifest_path=package, *, ok=True, extra=(), dest=destination):
            cmd = [sys.executable, str(importer), "--package", str(manifest_path), "--dest", str(dest), *extra]
            result = subprocess.run(cmd, cwd=game_root, text=True, capture_output=True, timeout=45)
            require((result.returncode == 0) == ok,
                    f"unexpected import result ({result.returncode}): {result.stdout}{result.stderr}")
            stream = result.stdout if ok else result.stderr
            try:
                payload = json.loads(stream)
            except json.JSONDecodeError as exc:
                raise AssertionError(f"importer returned non-JSON: {stream}") from exc
            require(payload.get("ok") is ok, f"unexpected status: {payload}")
            return payload

        checked = run(extra=("--check",))
        require(checked["changed"] and not destination.exists(), "dry run changed the destination")
        results.append("dry_run_is_read_only")
        first = run()
        require(first["changed"] and first["bundle_sha256"] == digest(raw), "first import lost source identity")
        lock_path = destination / "current.lock.json"
        original_lock = lock_path.read_bytes()
        lock_stamp = lock_path.stat().st_mtime_ns
        again = run()
        require(not again["changed"] and lock_path.read_bytes() == original_lock
                and lock_path.stat().st_mtime_ns == lock_stamp, "same release was not idempotent")
        results.append("valid_import_and_idempotence")

        def repack(name, changed_bundle=None, *, raw_override=None, manifest_change=None):
            candidate = deepcopy(bundle) if changed_bundle is None else changed_bundle
            content = encoded(candidate) if raw_override is None else raw_override
            description = deepcopy(manifest)
            description["bundle"]["sha256"] = digest(content)
            description["bundle"]["size_bytes"] = len(content)
            for key in ("world_id", "content_version", "source_model_sha256", "schema_version"):
                description[key] = candidate[key]
            description["counts"] = {key: len(candidate["data"][key]) for key in manifest["counts"]}
            if manifest_change:
                manifest_change(description)
            folder = base / name
            folder.mkdir()
            (folder / "content.json").write_bytes(content)
            (folder / "manifest.json").write_bytes(encoded(description))
            return folder / "manifest.json"

        live_registry = game_root / "production/config/imported_world/bindings.json"
        registered = load(live_registry)["rooms"]
        staged = base / "bound"
        staged.mkdir()
        (staged / "bindings.json").write_bytes(live_registry.read_bytes())
        run(dest=staged)
        staged_lock = (staged / "current.lock.json").read_bytes()
        candidate = deepcopy(bundle)
        receiver = next(key for key, binding in registered.items() if binding["status"] == "placeholder")
        by_id(candidate["data"]["rooms"])[receiver]["authoring"]["construction"]["bounds_world"][2] += 32
        error = run(repack("changed-receiver-envelope", candidate), dest=staged, ok=False)
        require(error["error"] == f"room_construction_bounds_mismatch:{receiver}"
                and (staged / "current.lock.json").read_bytes() == staged_lock,
                "an incompatible receiver displaced the playable release")
        results.append("active_room_bindings_and_atomic_receiver_geometry_rejection")

        def rejected(name, mutate=None, *, raw_override=None, manifest_change=None):
            candidate = deepcopy(bundle)
            if mutate:
                mutate(candidate)
            damaged = repack(name, candidate, raw_override=raw_override, manifest_change=manifest_change)
            reply = run(damaged, ok=False)
            require(lock_path.read_bytes() == original_lock, f"{name}: rejected update changed lock")
            return reply["error"]

        rejected("bad-hash", manifest_change=lambda row: row["bundle"].update(sha256="0" * 64))
        rejected("malformed-bundle-descriptor", manifest_change=lambda row: row.update(bundle=[]))
        rejected("bad-schema", lambda row: row.update(schema_version=999))
        rejected("duplicate-room", lambda row: row["data"]["rooms"].append(deepcopy(row["data"]["rooms"][0])))
        rejected("dangling-door", lambda row: row["data"]["doors"][0].update(a="missing_room"))
        rejected("unknown-condition", lambda row: row["data"]["doors"][0].update(requires=["missing_flag"]))
        rejected("wrong-gold-total", lambda row: row["data"]["enemy_groups"][0].update(coin_reward=-1))
        rejected("dangling-drop-profile", lambda row: row["data"]["enemy_groups"][0]["enemies"][0]
                 .update(drop_profile_id="missing_drop_profile"))
        rejected("unknown-drop-species", lambda row: row["data"]["enemy_drop_profiles"][0]
                 .update(species_id="missing_enemy_species"))
        rejected("negative-profile-drop", lambda row: row["data"]["enemy_drop_profiles"][0].update(coin_each=-1))

        def mismatched_profile(row):
            profile = row["data"]["enemy_drop_profiles"][0]
            profile["coin_each"] += 1

        def mismatched_profile_tier(row):
            profile = row["data"]["enemy_drop_profiles"][0]
            profile["tier"] = 1 + max(item["tier"] for item in row["data"]["enemy_drop_profiles"]
                                      if item["species_id"] == profile["species_id"])

        def duplicate_profile_pair(row):
            profile = deepcopy(row["data"]["enemy_drop_profiles"][0])
            profile["id"] += "_duplicate"
            row["data"]["enemy_drop_profiles"].append(profile)

        rejected("mismatched-planning-profile-drop", mismatched_profile)
        rejected("mismatched-planning-profile-tier", mismatched_profile_tier)
        rejected("duplicate-drop-profile-pair", duplicate_profile_pair)
        rejected("path-escape", manifest_change=lambda row: row["bundle"].update(path="../content.json"))
        duplicate_raw = raw.replace(b'"format":', b'"format":"duplicate", "format":', 1)
        require(duplicate_raw != raw, "format field missing in fixture")
        rejected("duplicate-json-key", raw_override=duplicate_raw)

        def invalid_quest(row):
            quest = row["data"]["quests"][0]
            completed = next(event for event in row["data"]["events"] if event["id"] == quest["completion_event"])
            completed["requires"].remove(quest["accept_event"])

        rejected("missing-quest-acceptance", invalid_quest)

        def invalid_upgrade(row):
            item = next(item for item in row["data"]["equipment"] if item["max_level"] > 1)
            item["upgrade_prices"]["2"] = -1

        rejected("negative-upgrade-price", invalid_upgrade)

        def invalid_shortcut(row):
            door = next(door for door in row["data"]["doors"] if door.get("one_way_from"))
            door["unlock_flag"] = "missing_shortcut_flag"

        def invalid_mouth(row):
            door = next(door for door in row["data"]["doors"] if door["connection_type"] == "physical")
            door["door"]["fixed"] = None

        rejected("unknown-shortcut-flag", invalid_shortcut)
        rejected("invalid-physical-mouth", invalid_mouth)
        results.append("corrupt_and_invalid_updates_keep_previous_lock")

        def remove_identity(row):
            require(row["data"]["observer_hints"], "stable-ID test needs an observer hint")
            row["data"]["observer_hints"].pop()

        rejected("undeclared-identity-deletion", remove_identity)

        def rename_nested_zone(row):
            room = next(room for room in row["data"]["rooms"] if room["zones"])
            previous_id = room["zones"][0]["id"]
            replacement_id = previous_id + "_renamed"

            def replace(value):
                if isinstance(value, dict):
                    return {key: replace(item) for key, item in value.items()}
                if isinstance(value, list):
                    return [replace(item) for item in value]
                return replacement_id if value == previous_id else value

            row["data"] = replace(row["data"])

        rejected("undeclared-nested-zone-rename", rename_nested_zone)

        def rename_drop_profile(row):
            profile = row["data"]["enemy_drop_profiles"][0]
            previous_id = profile["id"]
            profile["id"] += "_renamed"
            for group in row["data"]["enemy_groups"]:
                for enemy in group["enemies"]:
                    if enemy["drop_profile_id"] == previous_id:
                        enemy["drop_profile_id"] = profile["id"]

        rejected("undeclared-drop-profile-rename", rename_drop_profile)
        results.append("stable_id_deletions_require_migration")

        valid_update = deepcopy(bundle)
        valid_update["content_version"] = "channel-verification-economy-change"
        valid_update["data"]["shops"][0]["price"] += 1
        tuned_profile = valid_update["data"]["enemy_drop_profiles"][0]
        tuned_profile["coin_each"] += 1
        for group in valid_update["data"]["enemy_groups"]:
            for enemy in group["enemies"]:
                if enemy["drop_profile_id"] == tuned_profile["id"]:
                    enemy["coin_each"] = tuned_profile["coin_each"]
            group["coin_reward"] = sum(enemy["count"] * enemy["coin_each"] for enemy in group["enemies"])
        update_path = repack("valid-economy-update", valid_update)
        proposed = run(update_path, extra=("--check",))
        require(proposed["changed"] and lock_path.read_bytes() == original_lock, "update check changed lock")
        lease = destination / ".import.lock"
        lease.write_text("test owner\n")
        run(update_path, ok=False)
        require(lock_path.read_bytes() == original_lock and lease.exists(), "import disturbed another owner's lease")
        lease.unlink()
        changed = run(update_path)
        require(changed["changed"] and lock_path.read_bytes() != original_lock, "compatible economy change did not import")
        changed_content = load(destination / load(lock_path)["content_path"])
        require(by_id(changed_content["data"]["enemy_drop_profiles"])[tuned_profile["id"]]["coin_each"]
                == tuned_profile["coin_each"], "drop tuning did not keep its stable profile identity")
        require((destination / "releases" / digest(raw) / "content.json").read_bytes() == raw,
                "updating content altered the old immutable release")
        rollback = subprocess.run([sys.executable, str(importer), "--rollback", digest(raw), "--dest", str(destination)],
                                  cwd=game_root, text=True, capture_output=True, timeout=45)
        require(rollback.returncode == 0, f"explicit rollback failed: {rollback.stdout}{rollback.stderr}")
        require(load(lock_path)["bundle_sha256"] == digest(raw), "rollback selected the wrong release")
        results.append("compatible_economy_update_lease_and_explicit_rollback")

        foreign = subprocess.run([sys.executable, str(importer), "--manifest",
                                  "https://example.invalid/exports/channel-v1/releases/x/manifest.json",
                                  "--dest", str(destination)], cwd=game_root, text=True, capture_output=True, timeout=10)
        require(foreign.returncode != 0 and "source_origin_not_allowed" in foreign.stderr,
                "foreign source was not rejected before fetching")
        results.append("foreign_source_rejected")

    print(json.dumps({"ok": True, "checks": results, "bundle_sha256": digest(raw),
                      "scope": "content fidelity, validated import, atomic version lock; no controller or room playability claim"},
                     ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AssertionError, OSError, KeyError, ValueError, subprocess.SubprocessError) as error:
        print(json.dumps({"ok": False, "error": str(error)}, ensure_ascii=False), file=sys.stderr)
        raise SystemExit(1)
