"""Clock World content channel v1. Pure stdlib; copied verbatim to consumers.

This validates authored content, not controller reachability or a playable scene.
The SHA identifies exact UTF-8 bytes. Consumers never follow latest at runtime.
"""
from __future__ import annotations

import hashlib
import json
import math
import re
from pathlib import PurePosixPath

FORMAT = "clock-world-content"
MANIFEST_FORMAT = "clock-world-content-manifest"
CHANNEL_FORMAT = "clock-world-content-channel"
SCHEMA_VERSION = 1
WORLD_ID = "clock-world"
TABLES = ("regions", "rooms", "doors", "map_layers", "abilities", "rewards",
          "encounters", "events", "npcs", "speakers", "dialogues", "quests",
          "endings", "equipment", "shops", "coin_caches", "enemy_groups",
          "enemy_species", "enemy_drop_profiles", "observer_hints", "flags")
OBJECTS = ("growth", "transport", "commerce")
STABLE_TABLES = TABLES + ("zones", "stations", "weapon_branches", "exchanges")
SHA = re.compile(r"^[0-9a-f]{64}$")
ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.:/-]{0,159}$")
CONDITION_KEYS = frozenset(("requires", "excludes", "visible_requires", "completion_requires",
                          "minimum_abilities", "reverse_requires", "first_route_requires"))


class ContractError(ValueError):
    pass


def require(ok, message):
    if not ok:
        raise ContractError(message)


def canonical_bytes(value) -> bytes:
    check_json(value)
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False) + "\n").encode("utf-8")


def sha256_bytes(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def load_json_bytes(raw: bytes):
    require(isinstance(raw, bytes), "JSON input must be bytes")
    require(len(raw) <= 32 * 1024 * 1024, "JSON exceeds 32 MiB")
    def pairs(items):
        result = {}
        for k, v in items:
            require(k not in result, f"duplicate JSON key: {k}")
            result[k] = v
        return result
    try:
        value = json.loads(raw.decode("utf-8"), object_pairs_hook=pairs,
                           parse_constant=lambda value: (_ for _ in ()).throw(ContractError(f"nonfinite JSON: {value}")))
    except (UnicodeError, json.JSONDecodeError) as exc:
        raise ContractError(f"invalid UTF-8 JSON: {exc}") from exc
    check_json(value)
    return value


def check_json(value, depth=0):
    require(depth <= 60, "JSON nesting exceeds 60")
    if isinstance(value, dict):
        require(all(isinstance(k, str) for k in value), "JSON keys must be strings")
        for k, v in value.items():
            require(k not in ("__proto__", "prototype", "constructor"), "reserved JSON key")
            check_json(v, depth + 1)
    elif isinstance(value, list):
        for v in value:
            check_json(v, depth + 1)
    elif isinstance(value, float):
        require(math.isfinite(value), "nonfinite number")
    else:
        require(value is None or isinstance(value, (str, int, bool)), "non-JSON value")


def safe_relative_path(value: str) -> str:
    require(isinstance(value, str) and 0 < len(value) < 240, "invalid relative path")
    require(not any(c in value for c in ("\\", ":", "?", "#", "%", "\x00")), "unsafe relative path")
    parts = value.split("/")
    require(all(p and p not in (".", "..") for p in parts) and not value.startswith("/"), "path traversal")
    require(str(PurePosixPath(value)) == value, "noncanonical relative path")
    return value


def _identity(value, label):
    require(isinstance(value, str) and bool(ID.fullmatch(value)), f"invalid {label}: {value!r}")
    return value


def _integer(value, label, minimum=0):
    require(type(value) is int and minimum <= value <= 2**31 - 1, f"invalid {label}")


def _point(value, label):
    require(isinstance(value, list) and len(value) == 2 and all(type(v) in (int, float) and math.isfinite(v) for v in value), f"invalid {label}")


def _envelope(value, expected):
    require(isinstance(value, dict), "envelope must be object")
    require(value.get("format") == expected, "unsupported format")
    require(type(value.get("schema_version")) is int and value["schema_version"] == SCHEMA_VERSION, "unsupported schema_version")
    require(value.get("world_id") == WORLD_ID, "wrong world_id")
    _identity(value.get("content_version"), "content_version")
    require(bool(SHA.fullmatch(str(value.get("source_model_sha256", "")))), "invalid source_model_sha256")


def validate_latest(value):
    check_json(value)
    _envelope(value, CHANNEL_FORMAT)
    require(set(value) == {"format", "schema_version", "world_id", "content_version", "source_model_sha256", "manifest", "bundle_sha256"}, "unsupported latest fields")
    require(bool(SHA.fullmatch(str(value.get("bundle_sha256", "")))), "invalid bundle_sha256")
    descriptor = value.get("manifest")
    _descriptor(descriptor)
    require(descriptor["path"] == f"releases/{value['bundle_sha256']}/manifest.json", "manifest path does not match release")
    return value


def _descriptor(value):
    require(isinstance(value, dict) and set(value) == {"path", "sha256", "size_bytes"}, "invalid file descriptor")
    safe_relative_path(value["path"])
    require(bool(SHA.fullmatch(str(value.get("sha256", "")))), "invalid descriptor hash")
    _integer(value.get("size_bytes"), "size_bytes", 1)
    require(value["size_bytes"] <= 32 * 1024 * 1024, "file exceeds channel limit")


def validate_manifest(manifest, raw_content):
    check_json(manifest)
    _envelope(manifest, MANIFEST_FORMAT)
    require(set(manifest) == {"format", "schema_version", "world_id", "content_version", "source_model_sha256", "bundle", "counts"}, "unsupported manifest fields")
    _descriptor(manifest.get("bundle"))
    require(manifest["bundle"]["path"] == "content.json", "unsupported bundle path")
    require(len(raw_content) == manifest["bundle"]["size_bytes"], "content size mismatch")
    require(sha256_bytes(raw_content) == manifest["bundle"]["sha256"], "content SHA256 mismatch")
    bundle = load_json_bytes(raw_content)
    counts = validate_bundle(bundle)
    require(manifest.get("counts") == counts, "manifest counts mismatch")
    for key in ("world_id", "content_version", "source_model_sha256", "schema_version"):
        require(manifest[key] == bundle[key], f"manifest {key} mismatch")
    return bundle


def validate_bundle(bundle):
    check_json(bundle)
    _envelope(bundle, FORMAT)
    require(set(bundle) == {"format", "schema_version", "world_id", "content_version", "source_model_sha256", "coordinate_system", "rules", "data", "required_bindings", "migration"}, "unsupported bundle fields")
    require(bundle.get("coordinate_system") == {"layout": "planning_units", "collision": False, "gameplay": "room_local_pixels"}, "planning coordinates must not be collision")
    rules = bundle.get("rules")
    require(isinstance(rules, dict) and rules.get("conditions") == {"requires": "all", "excludes": "none", "equipped_prefix": "equipped:"}, "unsupported condition semantics")
    require(rules.get("enemy_gold") == "per_enemy_death_then_pickup", "unsupported enemy gold semantics")
    require(rules.get("enemy_group_total") == "derived_planning_estimate_only", "enemy group totals cannot award currency")
    require(rules.get("enemy_counts") == "room_authored_planning_reference", "enemy counts must remain authoring guidance")
    require(rules.get("enemy_composition") == "room_authored_from_registered_profiles", "enemy composition must remain room authored")
    require(rules.get("ordinary_respawn") == "rest_only", "unsupported respawn semantics")
    require(rules.get("single_use_rewards") is True, "permanent rewards must be single use")
    require(rules.get("save_kind") == "game_owned_not_web_replay", "web replay is not game save")
    data = bundle.get("data")
    require(isinstance(data, dict) and set(data) == set(TABLES + OBJECTS), "data tables mismatch")
    indexed = {}
    for table in TABLES:
        require(isinstance(data[table], list), f"{table} must be array")
        index = {}
        for row in data[table]:
            require(isinstance(row, dict), f"{table} row must be object")
            identity = _identity(row.get("id"), table + ".id")
            require(identity not in index, f"duplicate {table} ID: {identity}")
            index[identity] = row
        indexed[table] = index
    for key in OBJECTS:
        require(isinstance(data[key], dict), f"{key} must be object")
    for key in ("regions", "rooms", "map_layers", "flags"):
        require(indexed[key], f"{key} is empty")
    require("world" in indexed["map_layers"], "missing world map layer")
    rooms = indexed["rooms"]
    zones = {}
    for room in rooms.values():
        require(room.get("region") in indexed["regions"], f"unknown region in {room['id']}")
        require(room.get("map_layer") in indexed["map_layers"], f"unknown layer in {room['id']}")
        nav = room.get("navigation")
        require(isinstance(nav, dict) and isinstance(nav.get("polygon"), list) and len(nav["polygon"]) >= 3, f"missing planning geometry: {room['id']}")
        for pt in nav["polygon"]:
            _point(pt, "polygon vertex")
        _point(nav.get("label_anchor"), "label anchor")
        require(isinstance(room.get("zones"), list) and isinstance(room.get("zone_links"), list), "room sections required")
        local = set()
        for zone in room["zones"]:
            identity = _identity(zone.get("id"), "zone.id")
            require(identity not in zones, f"duplicate zone: {identity}")
            zones[identity] = room["id"]
            local.add(identity)
        require(room.get("default_zone") in local if local else room.get("default_zone") is None, f"invalid default zone: {room['id']}")
        for link in room["zone_links"]:
            require(link.get("from") in local and link.get("to") in local and link["from"] != link["to"], "bad zone link")
            require(not link.get("unlock_flag") and not link.get("one_way_from"), "zone links cannot own permanent gates")

    def place(row, label, required=False):
        if "room" in row:
            require(row["room"] in rooms, f"unknown room for {label}")
            if row.get("zone") is not None:
                require(zones.get(row["zone"]) == row["room"], f"wrong room/zone for {label}")
        else:
            require(not required, f"missing room for {label}")
        if "anchor" in row:
            _point(row["anchor"], label + ".anchor")
        if "interaction_sites" in row:
            require(isinstance(row["interaction_sites"], list) and row["interaction_sites"], "empty interaction sites")
            for site in row["interaction_sites"]:
                place(site, label + ".site", True)

    for table in ("abilities", "rewards", "encounters", "events", "npcs", "dialogues", "coin_caches", "enemy_groups", "observer_hints"):
        for row in data[table]:
            place(row, table + ":" + row["id"], True)
    for door in data["doors"]:
        a, b = door.get("a"), door.get("b")
        require(a in rooms and b in rooms and a != b, f"invalid endpoints: {door['id']}")
        require(door.get("one_way_from") in (None, a, b), "first-open room not endpoint")
        require(not door.get("one_way_from") or bool(door.get("unlock_flag")), "first-open side needs unlock flag")
        if door.get("unlock_flag"):
            require(door["unlock_flag"] in indexed["flags"], "unknown door unlock flag")
        kind = door.get("connection_type")
        require(kind in ("physical", "interior"), "invalid connection_type")
        for room_id, zone_id in door.get("zone_by_room", {}).items():
            require(room_id in (a, b) and (zone_id is None or zones.get(zone_id) == room_id), "invalid door section")
        if kind == "interior":
            require(door.get("door") is None and rooms[a]["map_layer"] != rooms[b]["map_layer"], "invalid interior connection")
            require(set(door.get("entrances", {})) == {a, b}, "interior entrances missing")
            for entrance in door["entrances"].values():
                _point(entrance.get("anchor"), "interior entrance")
        else:
            require(rooms[a]["map_layer"] == rooms[b]["map_layer"], "physical door across map layers")
            mouth = door.get("door")
            require(isinstance(mouth, dict) and mouth.get("axis") in ("h", "v") and all(type(mouth.get(k)) in (int, float) and math.isfinite(mouth[k]) for k in ("fixed", "start", "end")) and mouth["start"] < mouth["end"], "invalid planning door mouth")

    for reward in data["rewards"]:
        require(reward.get("reward_key") == reward["id"], "reward ID alias mismatch")
        require(reward.get("permanent_unique") is True, "nonunique permanent reward")
        if reward.get("quantity") is not None:
            _integer(reward["quantity"], "reward quantity", 1)
        if reward.get("catalog_id") is not None:
            require(reward["catalog_id"] in indexed["equipment"], "unknown equipment reward")
        grants = reward.get("growth_grants", {})
        require(isinstance(grants, dict) and set(grants) <= {"attack_alloy", "skill_core", "lost_gear", "branch_material", "weapon_unlock"}, "unknown growth grant")
        for key in ("attack_alloy", "skill_core", "lost_gear"):
            if key in grants:
                _integer(grants[key], "growth grant amount", 1)
        if "lost_gear" in grants:
            require(grants["lost_gear"] == 1 and bool(re.fullmatch(r"TG[0-9]+", str(reward.get("formal_item_id", "")))), "lost gear identity invalid")
        for key in ("branch_material", "weapon_unlock"):
            if key in grants:
                _identity(grants[key], key)
        for key in ("existing_world_event",):
            if reward.get(key):
                require(reward[key] in indexed["flags"], "unknown reward flag")
    for event in data["events"]:
        require(event.get("event") == event["id"], "event ID alias mismatch")
        require(event["id"] in indexed["flags"], "event flag not declared")
        if event.get("reward_key"):
            require(event["reward_key"] in indexed["rewards"], "unknown event reward")
        _integer(event.get("coin_reward", 0), "event coins")
        for line in event.get("dialogue", []):
            require(line.get("speaker_id") in indexed["speakers"] and isinstance(line.get("text"), str), "invalid event speaker/text")
    for encounter in data["encounters"]:
        require(encounter.get("completion_flag") in indexed["flags"], "unknown encounter flag")
        for reward in encounter.get("reward_refs", []):
            require(reward in indexed["rewards"], "unknown encounter reward")
        _integer(encounter.get("coin_reward", 0), "encounter coins")
    for npc in data["npcs"]:
        require(isinstance(npc.get("services"), list), "NPC services must be list")
    for speaker in data["speakers"]:
        require(speaker.get("kind") in ("npc", "record"), "unknown speaker kind")
        if speaker["kind"] == "npc":
            require(speaker.get("npc_id") in indexed["npcs"], "unknown speaker NPC")
    for dialogue in data["dialogues"]:
        require(dialogue.get("speaker_id") in indexed["speakers"], "unknown dialogue speaker")
        require(isinstance(dialogue.get("lines"), list) and all(isinstance(x, str) for x in dialogue["lines"]), "invalid dialogue lines")
        require(type(dialogue.get("priority")) is int, "dialogue priority missing")
    for quest in data["quests"]:
        require(quest.get("giver_id") in indexed["npcs"], "unknown quest giver")
        require(quest.get("accept_event") in indexed["events"] and quest.get("completion_event") in indexed["events"], "unknown quest event")
        require(isinstance(quest.get("steps"), list) and quest["steps"], "quest steps required")
        step_ids = []
        for step in quest["steps"]:
            require(step.get("event") in indexed["events"], "unknown quest step")
            place(step, "quest step", True)
            event = indexed["events"][step["event"]]
            require(step["room"] == event["room"] and step.get("zone") == event.get("zone"), "quest step place differs from event")
            step_ids.append(step["event"])
        require(len(step_ids) == len(set(step_ids)), "duplicate quest step")
        required = set(indexed["events"][quest["completion_event"]].get("requires", []))
        require({quest["accept_event"], *step_ids} <= required, "quest completion omits its prerequisites")
        require(quest.get("clues_before_accept") is True and quest.get("optional") is True, "unsupported quest policy")
    for ending in data["endings"]:
        require(ending.get("target") in rooms and ending.get("requires_explicit_terminal_interaction") is True, "invalid ending target")
        require(isinstance(ending.get("paragraphs"), list) and ending["paragraphs"], "ending text missing")
    for equipment in data["equipment"]:
        _integer(equipment.get("load"), "equipment load")
        _integer(equipment.get("max_level"), "equipment max level", 1)
        prices = equipment.get("upgrade_prices")
        require(isinstance(prices, dict) and set(prices) == {str(n) for n in range(2, equipment["max_level"] + 1)}, "equipment target-level prices incomplete")
        for price in prices.values():
            _integer(price, "upgrade price", 1)
        require(isinstance(equipment.get("effect_levels"), list) and len(equipment["effect_levels"]) == equipment["max_level"], "equipment effects incomplete")
    for offer in data["shops"]:
        require(offer.get("npc_id") in indexed["npcs"] and offer.get("reward_key") in indexed["rewards"], "unknown shop references")
        require("shop" in indexed["npcs"][offer["npc_id"]]["services"], "NPC cannot sell")
        _integer(offer.get("price"), "shop price", 1)
    for cache in data["coin_caches"]:
        _integer(cache.get("amount"), "coin cache amount", 1)
        require(cache.get("one_time") is True, "coin caches must be single-use")
    profile_pairs = set()
    for profile in data["enemy_drop_profiles"]:
        require(set(profile) == {"id", "species_id", "tier", "coin_each"}, "invalid enemy drop profile fields")
        require(profile.get("species_id") in indexed["enemy_species"], "unknown profile species")
        _integer(profile.get("tier"), "enemy drop tier")
        _integer(profile.get("coin_each"), "profile drop", 1)
        pair = (profile["species_id"], profile["tier"])
        require(pair not in profile_pairs, "duplicate species/tier drop profile")
        profile_pairs.add(pair)
    for group in data["enemy_groups"]:
        require(group.get("respawn") == "rest", "enemy group respawn invalid")
        require(isinstance(group.get("enemies"), list) and group["enemies"], "empty enemy group")
        _integer(group.get("fixed_drop_tier"), "group planning tier")
        total = 0
        for enemy in group["enemies"]:
            require(enemy.get("species_id") in indexed["enemy_species"], "unknown enemy species")
            require(enemy.get("drop_profile_id") in indexed["enemy_drop_profiles"], "unknown enemy drop profile")
            profile = indexed["enemy_drop_profiles"][enemy["drop_profile_id"]]
            require(profile["species_id"] == enemy["species_id"] and profile["tier"] == group["fixed_drop_tier"], "enemy profile species/tier mismatch")
            _integer(enemy.get("count"), "enemy count", 1)
            _integer(enemy.get("coin_each"), "enemy drop", 1)
            require(enemy["coin_each"] == profile["coin_each"], "enemy profile coin mismatch")
            total += enemy["count"] * enemy["coin_each"]
        require(group.get("coin_reward") == total, "enemy group planning total mismatch")
    for ability in data["abilities"]:
        require(ability.get("event") == ability["id"] and ability["id"] in indexed["events"], "unknown ability event")
    def conditions(value):
        if isinstance(value, dict):
            for key, item in value.items():
                if key in CONDITION_KEYS:
                    require(isinstance(item, list) and all(isinstance(x, str) for x in item), f"{key} must be flag list")
                    require(len(item) == len(set(item)), "duplicate condition")
                    for flag in item:
                        if flag.startswith("equipped:"):
                            require(flag[9:] in indexed["equipment"], "unknown equipped requirement")
                        else:
                            require(flag in indexed["flags"], f"unknown condition flag: {flag}")
                else:
                    conditions(item)
        elif isinstance(value, list):
            for item in value:
                conditions(item)
    conditions(data)
    transport = data["transport"]
    require(isinstance(transport.get("stations"), list), "transport stations missing")
    station_ids = set()
    for station in transport["stations"]:
        _identity(station.get("id"), "station ID")
        require(station["id"] not in station_ids, "duplicate station")
        station_ids.add(station["id"])
        place(station, "station", True)
    for room_id in transport.get("rest_only_rooms", []):
        require(room_id in rooms, "unknown rest room")
    for room_id, zone_id in transport.get("rest_zones", {}).items():
        require(zones.get(zone_id) == room_id, "invalid rest zone")
    growth = data["growth"]
    for field in ("workshop_rooms", "branch_workshop_rooms", "gear_delivery_rooms"):
        require(all(x in rooms for x in growth.get(field, [])), f"unknown room: growth.{field}")
    for room_id, zone_id in growth.get("workshop_zones", {}).items():
        require(zones.get(zone_id) == room_id, "invalid workshop zone")
    for exchange in growth.get("exchanges", []):
        place(exchange, "exchange", True)
        require(exchange.get("reward_key") in indexed["rewards"], "unknown exchange reward")
        _identity(exchange.get("id"), "exchange.id")
        for key in ("cost", "requires_lifetime", "requires_balance", "requires_delivered"):
            require(isinstance(exchange.get(key, {}), dict), "invalid exchange resource requirements")
            for amount in exchange.get(key, {}).values():
                _integer(amount, "exchange resource amount")
    weapons = growth.get("weapon_definition_crosswalk", {})
    require(isinstance(weapons, dict) and weapons, "weapon definition crosswalk missing")
    for name in ("shared_attack", "shared_skill"):
        track = growth.get(name)
        require(isinstance(track, dict) and isinstance(track.get("levels"), list) and track["levels"], "growth level track missing")
        levels = track["levels"]
        require([x.get("level") for x in levels] == list(range(len(levels))), "growth levels must be contiguous from zero")
        for level in levels:
            _integer(level.get("cost_to_reach"), "growth level cost")
            if name == "shared_attack":
                _integer(level.get("damage"), "attack damage", 1)
        _integer(track.get("gold_fee", 0), "growth fee")
    recipe_ids = set()
    materials = set()
    for recipe in growth.get("branch_upgrades", []):
        identity = _identity(recipe.get("id"), "branch ID")
        require(identity not in recipe_ids, "duplicate weapon branch")
        recipe_ids.add(identity)
        materials.add(_identity(recipe.get("material"), "branch material"))
        _integer(recipe.get("cost"), "branch cost", 1)
        _integer(recipe.get("gold_fee", 0), "branch gold fee")
        require(recipe.get("requires_weapon") in weapons, "unknown branch weapon")
        require(recipe.get("grant_flag") in indexed["flags"], "unknown branch grant flag")
    require(all(x in weapons for x in growth.get("starting_weapons", [])), "unknown starting weapon")
    exchange_ids = [x["id"] for x in growth.get("exchanges", [])]
    require(len(exchange_ids) == len(set(exchange_ids)), "duplicate exchange ID")
    for reward in data["rewards"]:
        grants = reward.get("growth_grants", {})
        require("weapon_unlock" not in grants or grants["weapon_unlock"] in weapons, "unknown granted weapon")
        require("branch_material" not in grants or grants["branch_material"] in materials, "unknown granted branch material")
    capacity = data["commerce"].get("equipment_capacity", {})
    _integer(capacity.get("initial"), "initial equipment capacity", 1)
    _integer(capacity.get("maximum"), "maximum equipment capacity", capacity["initial"])
    for group in data["commerce"].get("exclusive_groups", []):
        require(isinstance(group, list) and len(group) >= 2 and all(x in indexed["equipment"] for x in group), "invalid exclusive equipment group")
    bindings = bundle.get("required_bindings")
    require(isinstance(bindings, list), "required_bindings must be array")
    binding_tables = {"room": "rooms", "npc": "npcs", "enemy_species": "enemy_species", "equipment_effect": "equipment", "event_trigger": "events"}
    actual = set()
    for binding in bindings:
        require(isinstance(binding, dict) and set(binding) == {"kind", "id"}, "invalid binding declaration")
        kind, identity = binding["kind"], binding["id"]
        require(kind in binding_tables and identity in indexed[binding_tables[kind]], "unknown required binding")
        require((kind, identity) not in actual, "duplicate binding declaration")
        actual.add((kind, identity))
    expected = {(kind, identity) for kind, table in binding_tables.items() for identity in indexed[table]}
    require(actual == expected, "required bindings incomplete")
    migration = bundle.get("migration")
    if migration is not None:
        require(isinstance(migration, dict) and set(migration) == {"from_bundle_sha256", "removals"}, "invalid migration declaration")
        require(bool(SHA.fullmatch(str(migration["from_bundle_sha256"]))), "invalid migration base hash")
        require(isinstance(migration["removals"], list), "migration removals must be array")
        seen = set()
        for removal in migration["removals"]:
            require(isinstance(removal, dict) and set(removal) == {"table", "id", "reason", "replacement_id"}, "invalid removal")
            table, identity = removal["table"], removal["id"]
            require(table in STABLE_TABLES, "invalid removed table")
            _identity(identity, "removed ID")
            require(isinstance(removal["reason"], str) and removal["reason"].strip(), "removal needs reason")
            replacement = removal["replacement_id"]
            require(replacement is None or replacement in identity_sets(bundle)[table], "unknown replacement")
            require((table, identity) not in seen, "duplicate removal")
            seen.add((table, identity))
    return {key: len(data[key]) for key in TABLES}


def identity_sets(bundle):
    data = bundle["data"]
    result = {table: {row["id"] for row in data[table]} for table in TABLES}
    result["zones"] = {zone["id"] for room in data["rooms"] for zone in room["zones"]}
    result["stations"] = {row["id"] for row in data["transport"]["stations"]}
    result["weapon_branches"] = {row["id"] for row in data["growth"].get("branch_upgrades", [])}
    result["exchanges"] = {row["id"] for row in data["growth"].get("exchanges", [])}
    return result


def validate_upgrade(previous_bundle, new_bundle, previous_sha256):
    validate_bundle(previous_bundle)
    validate_bundle(new_bundle)
    require(bool(SHA.fullmatch(str(previous_sha256))), "invalid previous hash")
    removed = set()
    old_sets, new_sets = identity_sets(previous_bundle), identity_sets(new_bundle)
    for table in STABLE_TABLES:
        removed.update((table, identity) for identity in old_sets[table] - new_sets[table])
    migration = new_bundle.get("migration")
    if removed:
        require(migration is not None and migration["from_bundle_sha256"] == previous_sha256, "stable IDs removed without matching migration")
        require({(row["table"], row["id"]) for row in migration["removals"]} == removed, "migration removals do not match deleted IDs")
    elif migration is not None:
        require(not migration["removals"], "migration declares nonexistent deletion")
