#!/usr/bin/env python3
"""Edit the authoring layer without overwriting the frozen workbook catalog.

This tool checks structure and parameter contracts. Godot's ItemCatalogV5 is the
final admission authority; run the item-v5-authoring Harness check after edits.
"""
from __future__ import annotations

import argparse
from copy import deepcopy
from datetime import datetime, timezone
import json
import math
import os
from pathlib import Path
import re
import stat
import sys
import tempfile

from import_items_v5 import parameter_contract, validate_parameter_contract

ROOT = Path(__file__).resolve().parents[1]
IDENTIFIER = re.compile(r"[A-Za-z_][A-Za-z0-9_]*\Z")
TOP = {"schema_version", "metadata", "overrides", "additions", "disabled_ids"}
EDITABLE = {"display_name", "description", "rarity", "gear_cost", "shop_price", "max_level", "definition_version", "effect_parameters", "runtime_metadata"}
META = {"tags", "required_tags", "required_capabilities", "exclusive_tags", "icon_key", "channel", "appearance_weight"}
STATIC = {"max_hp_add", "max_hp_multiplier", "ground_recoil_multiplier", "coyote_time_add_s", "focus_stamina_drain_multiplier", "focus_stamina_recovery_multiplier"}
RESERVED = {"active", "companion", "mark", "projectile_active"}
ADDITION_FIELDS = {"stable_id", "display_name", "description", "rarity", "gear_cost", "shop_price", "max_level", "definition_version", "effect_parameters", "parameter_contract", "runtime_metadata"}
TEXT_MODES = {"weapon_family": {"BOMB"}, "exclude_weapon_family": {"BOMB"}, "mode": {"THROW_ONLY"}, "resource_pickup_mask": {"coin", "meta_note", "health_pickup", "energy_pickup"}}


def pairs(values):
    result = {}
    for key, value in values:
        if key in result:
            raise ValueError(f"Duplicate JSON key: {key}")
        result[key] = value
    return result


def parse_json(value):
    def invalid(token):
        raise ValueError(f"Non-finite JSON value: {token}")
    return json.loads(value, object_pairs_hook=pairs, parse_constant=invalid)


def load(path):
    return parse_json(Path(path).read_text(encoding="utf-8"))


def identifier(value):
    return isinstance(value, str) and IDENTIFIER.fullmatch(value) is not None


def metadata(value):
    if not isinstance(value, dict) or not META <= set(value) or set(value) - META - {"required_weapon_id"}:
        raise ValueError("Incomplete or unknown runtime_metadata field")
    for key in ("tags", "required_tags", "required_capabilities", "exclusive_tags"):
        entries = value[key]
        if not isinstance(entries, list) or any(not identifier(e) for e in entries) or len(set(entries)) != len(entries):
            raise ValueError(f"Invalid metadata array: {key}")
    if "item_v5" not in value["tags"] or not identifier(value["icon_key"]):
        raise ValueError("Metadata requires item_v5 tag and an icon key")
    if value["channel"] not in ("PASSIVE", "ACTIVE", "WEAPON", "GRAPPLE"):
        raise ValueError("Invalid effect channel")
    weight = value["appearance_weight"]
    if type(weight) not in (int, float) or not math.isfinite(weight) or weight < 0:
        raise ValueError("appearance_weight must be finite and nonnegative")
    if "required_weapon_id" in value and value["required_weapon_id"] != "" and not identifier(value["required_weapon_id"]):
        raise ValueError("Invalid required_weapon_id")


def check_parameters(parameters, contract, max_level):
    if not isinstance(contract, dict) or contract.get("reject_unknown_keys") is not True or not isinstance(contract.get("schema_source_sha256"), str) or len(contract["schema_source_sha256"]) != 64:
        raise ValueError("Incomplete parameter contract")
    for field in ("required_keys", "positive_keys", "integer_keys", "zero_allowed_keys"):
        if not isinstance(contract.get(field), list) or any(not isinstance(k, str) for k in contract[field]) or len(set(contract[field])) != len(contract[field]):
            raise ValueError(f"Invalid parameter contract array: {field}")
    modes = contract.get("text_modes")
    if not isinstance(modes, dict) or any(not isinstance(k, str) or not isinstance(v, list) or not v or any(not isinstance(mode, str) for mode in v) for k, v in modes.items()):
        raise ValueError("Invalid parameter text modes")
    required = set(contract["required_keys"])
    classified = contract["positive_keys"] + contract["zero_allowed_keys"] + list(modes)
    if set(parameters) != required or len(classified) != len(set(classified)) or set(classified) != required or not set(contract["integer_keys"]) <= required - set(modes):
        raise ValueError("Parameter contract classifications disagree")
    for key, value in parameters.items():
        if key in TEXT_MODES:
            parts = value.split("|") if isinstance(value, str) and key == "resource_pickup_mask" else [value]
            if not isinstance(value, str) or any(part not in TEXT_MODES[key] for part in parts):
                raise ValueError(f"Unsupported text parameter: {key}")
        else:
            numbers = value if key.endswith("_by_level") and isinstance(value, list) else [value]
            if key in modes or any(type(number) not in (int, float) or not math.isfinite(number) for number in numbers):
                raise ValueError(f"Numeric parameter cannot be reclassified as text: {key}")
    validate_parameter_contract(parameters, contract, max_level)


def validate(document, base):
    """Validate data shape and reusable parameter contracts, never run effects."""
    if not isinstance(document, dict) or set(document) != TOP or type(document["schema_version"]) is not int or document["schema_version"] != 1:
        raise ValueError("Expected authoring schema_version 1 and its five exact fields")
    if not isinstance(document["metadata"], dict) or not isinstance(document["overrides"], dict) or not isinstance(document["additions"], list) or not isinstance(document["disabled_ids"], list):
        raise ValueError("Invalid authoring collections")
    rows = {}
    for row in base["items"]:
        key = row["stable_id"]
        if not identifier(key) or key in rows:
            raise ValueError("Invalid or repeated base ID")
        rows[key] = deepcopy(row)
    if set(document["metadata"]) != set(rows):
        raise ValueError("Metadata must cover exactly the frozen base IDs")
    for key, row in rows.items():
        row["runtime_metadata"] = deepcopy(document["metadata"][key])
    added = set()
    for row in document["additions"]:
        if not isinstance(row, dict) or set(row) - ADDITION_FIELDS:
            raise ValueError("Addition must be a complete static item record")
        key = row.get("stable_id")
        if not identifier(key) or key in rows or key in base["deleted_ids"]:
            raise ValueError("Addition ID is invalid, duplicated or retired")
        rows[key] = deepcopy(row)
        added.add(key)
    for key, patch in document["overrides"].items():
        if key not in rows or not isinstance(patch, dict) or not patch or set(patch) - EDITABLE:
            raise ValueError("Unknown item or override field")
        for field, value in patch.items():
            if field in ("effect_parameters", "runtime_metadata"):
                if not isinstance(value, dict) or not value or set(value) - set(rows[key][field]) - ({"required_weapon_id"} if field == "runtime_metadata" else set()):
                    raise ValueError(f"Unknown {field} key")
                if field == "runtime_metadata":
                    original = rows[key][field]
                    candidate = {**original, **value}
                    metadata(candidate)
                    if candidate["channel"] != original["channel"] or RESERVED.intersection(candidate["tags"]) != RESERVED.intersection(original["tags"]):
                        raise ValueError("Effect channel and reserved role tags belong to the implemented component, not designer overrides")
                rows[key][field].update(deepcopy(value))
            else:
                rows[key][field] = deepcopy(value)
    disabled = document["disabled_ids"]
    if any(not isinstance(key, str) or key not in rows for key in disabled) or len(set(disabled)) != len(disabled):
        raise ValueError("Unknown or repeated disabled ID")
    for key, row in rows.items():
        if key in base["deleted_ids"]:
            raise ValueError("Retired ID cannot be reused")
        for field in ("display_name", "description"):
            if not isinstance(row.get(field), str) or not row[field].strip():
                raise ValueError(f"Missing item {field}: {key}")
        if row.get("rarity") not in ("BLUE", "PURPLE", "GOLD"):
            raise ValueError("Unknown rarity")
        for field, lo, hi in (("gear_cost", 1, 5), ("shop_price", 1, 2147483647), ("max_level", 1, 3), ("definition_version", 1, 2147483647)):
            value = row.get(field, 5 if field == "definition_version" else None)
            if type(value) is not int or not lo <= value <= hi:
                raise ValueError(f"Invalid integer {field}: {key}")
        if row["max_level"] not in (1, 3):
            raise ValueError("max_level must be 1 or 3")
        params = row["effect_parameters"]
        if not isinstance(params, dict) or not params or any(not identifier(p) for p in params):
            raise ValueError("Expected nonempty named effect parameters")
        if any(p.endswith("_by_level") and p.removesuffix("_by_level") in params for p in params):
            raise ValueError("Ambiguous scalar and level parameter")
        check_parameters(params, row["parameter_contract"], row["max_level"])
        metadata(row["runtime_metadata"])
        if key in added:
            if any(p.removesuffix("_by_level") not in STATIC for p in params):
                raise ValueError("New mechanisms need an implemented effect component; additions support static parameters only")
            if row["runtime_metadata"]["channel"] != "PASSIVE" or RESERVED.intersection(row["runtime_metadata"]["tags"]):
                raise ValueError("Static additions cannot advertise active or companion behavior")
        if key in disabled:
            row["runtime_metadata"]["appearance_weight"] = 0
    return rows


def atomic_write(path, document, backup_dir):
    path = Path(path)
    payload = (json.dumps(document, ensure_ascii=False, indent=2, allow_nan=False) + "\n").encode("utf-8")
    path.parent.mkdir(parents=True, exist_ok=True)
    backup = None
    if path.exists():
        backup_dir.mkdir(parents=True, exist_ok=True)
        stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ")
        backup = backup_dir / f"{stamp}-{path.name}.bak"
        backup.write_bytes(path.read_bytes())
    fd, temporary = tempfile.mkstemp(prefix=".item-authoring-", dir=path.parent)
    try:
        if path.exists():
            os.fchmod(fd, stat.S_IMODE(path.stat().st_mode))
        with os.fdopen(fd, "wb") as handle:
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
    return backup


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", type=Path, default=ROOT / "config/items_v5.json")
    parser.add_argument("--authoring", type=Path, default=ROOT / "config/item_v5_authoring.json")
    parser.add_argument("--output", type=Path, help="Write an isolated proposal instead of editing --authoring")
    parser.add_argument("--backup-dir", type=Path, default=ROOT / "build/item_authoring/edits")
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("list")
    commands.add_parser("check")
    for command in ("show", "disable", "enable", "reset"):
        commands.add_parser(command).add_argument("id")
    set_parser = commands.add_parser("set")
    set_parser.add_argument("id")
    set_parser.add_argument("field")
    set_parser.add_argument("value", help="JSON value, including quotes around text")
    add = commands.add_parser("add-static")
    add.add_argument("id")
    add.add_argument("--name", required=True)
    add.add_argument("--params", required=True, help="JSON object of supported static parameters")
    add.add_argument("--gear-cost", type=int, required=True)
    add.add_argument("--price", type=int, required=True)
    add.add_argument("--rarity", choices=("BLUE", "PURPLE", "GOLD"), default="BLUE")
    args = parser.parse_args(argv)
    try:
        base, document = load(args.base), load(args.authoring)
        rows = validate(document, base)
        if args.command == "list":
            print(json.dumps([{"id": key, "name": row["display_name"], "disabled": row["runtime_metadata"]["appearance_weight"] == 0} for key, row in rows.items()], ensure_ascii=False, indent=2))
            return 0
        if args.command == "check":
            print(f"PASS: item authoring structure and parameter contracts ({len(rows)} definitions); full Godot check: item-v5-authoring")
            return 0
        if args.command != "add-static" and args.id not in rows:
            raise ValueError(f"Unknown item: {args.id}")
        if args.command == "show":
            print(json.dumps(rows[args.id], ensure_ascii=False, indent=2))
            return 0
        if args.command == "set":
            path = args.field.split(".")
            if not path or path[0] not in EDITABLE or len(path) > 2 or (len(path) == 2 and path[0] not in ("effect_parameters", "runtime_metadata")):
                raise ValueError("Editable field or parameter path required")
            patch = document["overrides"].setdefault(args.id, {})
            value = parse_json(args.value)
            if len(path) == 2:
                patch.setdefault(path[0], {})[path[1]] = value
            else:
                patch[path[0]] = value
        elif args.command == "disable":
            if args.id not in document["disabled_ids"]:
                document["disabled_ids"].append(args.id)
        elif args.command == "enable":
            document["disabled_ids"] = [key for key in document["disabled_ids"] if key != args.id]
        elif args.command == "reset":
            document["overrides"].pop(args.id, None)
        elif args.command == "add-static":
            params = parse_json(args.params)
            if not isinstance(params, dict) or not params:
                raise ValueError("--params must be a nonempty JSON object")
            document["additions"].append({"stable_id": args.id, "display_name": args.name, "description": f"数据定义的被动属性：{args.name}", "rarity": args.rarity, "gear_cost": args.gear_cost, "shop_price": args.price, "max_level": 3 if any(p.endswith("_by_level") for p in params) else 1, "definition_version": 1, "effect_parameters": params, "parameter_contract": parameter_contract(params, frozenset(params)), "runtime_metadata": {"tags": ["item_v5"], "required_tags": [], "required_capabilities": [], "exclusive_tags": [], "icon_key": "coil", "channel": "PASSIVE", "appearance_weight": 1.0}})
        validate(document, base)
        target = args.output or args.authoring
        if target.resolve() == args.base.resolve():
            raise ValueError("Refusing to overwrite the frozen workbook catalog")
        backup = atomic_write(target, document, args.backup_dir)
        print(json.dumps({"written": str(target), "backup": str(backup) if backup else None, "validation": "structure_and_parameters_only", "next_check": "item-v5-authoring"}, ensure_ascii=False))
        return 0
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f"Item authoring rejected: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
