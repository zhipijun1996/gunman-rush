"""Deterministically import the user-provided V5 workbook without Office dependencies.

The original ZIP is archived verbatim. The snapshot preserves all worksheets,
cells, types, formulas, cached values and XML-part hashes. Only the active-item
rows and atomic H-column proposals become runtime data; historical/deleted rows
are not executable. Formula-backed editable runtime cells are rejected because a
cached Excel value is not a recalculation engine.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
import math
from pathlib import Path, PurePosixPath
import re
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parents[1]
ARCHIVE = "docs/evidence/item_v5_01/source/items-v5-original.xlsx"
SNAPSHOT = "docs/evidence/item_v5_01/source/workbook-snapshot.json"
CONFIG = "config/items_v5.json"
SYNERGIES = "config/item_v5_synergies.json"
ORIGINAL_SHA256 = "222d7dd49918ab613d5430a03fcc07f45bce1fbaa89ba6ea072c5a21174b545f"
ORIGINAL_BYTES = 107499
_ORIGINAL_SCHEMA_CACHE = None
MAIN = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
REL = "http://schemas.openxmlformats.org/package/2006/relationships"
DOC_REL = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
NS = {"m": MAIN}
ID = re.compile(r"(?:B|P|G)\d{2}|N0[12]")
TEXT_PARAMETER_KEYS = {"weapon_family", "exclude_weapon_family", "mode", "resource_pickup_mask"}
INTEGER_PARAMETER_KEYS = {
    "max_extra_pierce", "chain_targets", "small_drone_count", "max_temp_drones", "max_large_drones",
    "max_active_traps", "max_target_hits", "projectile_count_multiplier", "pulse_count", "break_on_hits",
    "hits_for_one_barrier", "barrier_grant", "shared_barrier_cap", "map_start_barrier", "shield_per_trigger",
    "max_bonus_kills_per_map", "free_rerolls_per_map", "max_uses_per_map", "max_triggers_per_unique_map",
    "uses_per_map", "evolution_levels", "projectile_blocks_per_cooldown", "requires_full_hp", "level_cap",
    "unique_per_attack_packet", "first_equip_current_hp_ratio_convert", "locked_until_run_end",
    "forced_failure_immunity", "auto_collect_reward_objects", "lose_coins_on_damage",
}
ZERO_PARAMETER_KEYS = {
    "world_time_scale_while_air_aiming", "normal_healing_multiplier", "forced_failure_immunity",
    "auto_collect_reward_objects", "lose_coins_on_damage", "max_extra_pierce", "chain_targets",
    "small_drone_count", "max_temp_drones", "max_large_drones", "max_active_traps", "free_rerolls_per_map",
    "max_bonus_kills_per_map", "max_uses_per_map", "uses_per_map", "evolution_levels",
    "singularity_pull_duration_add_s", "coyote_time_add_s", "invulnerable_add_s",
}

# These numbers occur explicitly in the workbook text but were not duplicated
# into its atomic H sheet. Cell provenance remains separate from H parameters.
TEXT_PARAMETERS = {
    "B05": {"minimum_total_cooldown_multiplier": (0.65, "N")},
    "B23": {"cooldown_s": (6, "L")},
    "P12": {"target_cooldown_s": (2, "N")},
    "P02": {"minimum_skill_cost": (15, "N")},
    "B15": {"cooldown_s": (7, "L")},
    "B24": {"cooldown_s": (3, "L")},
    "P16": {"cooldown_s": (12, "Q")},
    "P20": {"cooldown_s": (12, "Q")},
    "G06": {"cooldown_s": (1.5, "L")},
    "P24": {"cooldown_s": (12, "L")},
    "P25": {"cooldown_s": (10, "L")},
}

# Original text is always preserved; these are explicit L/H-over-stale-column
# resolutions, not unrecorded edits to the uploaded workbook.
TEXT_RESOLUTIONS = {
    "G01": {"description": ("同目标7秒", "同目标6秒"), "reason": "L7秒与H target_cooldown_s=6冲突，以H为准"},
    "G16": {"description": ("各0.60D", "各0.90D"), "reason": "L旧0.60D与H damage_ratio_D_each=0.9冲突，以H为准"},
    "B06": {"limits": ("每次腾空最多返还12时间能量", "每次腾空返还上限按Lv为20/30/40时间能量"), "reason": "N旧12与H各级20/30/40冲突，以H为准"},
    "P05": {"trigger": ("当前HP≤最大HP的30%", "当前HP≤最大HP的40%"), "reason": "M旧30%与L/H40%冲突，以L/H为准"},
    "P15": {"trigger": ("实际消耗共鸣累计40", "实际消耗共鸣累计45"), "reason": "M旧40与L/H45冲突，以L/H为准"},
    "B16": {"limits": ("同图金币上限16", "本图额外击杀金币上限8"), "reason": "N旧16与H每次1/前8次冲突，以H为准"},
    "G10": {"limits": ("每图最多16金币", "每图最多12额外金币"), "reason": "N旧16与L/H每次2/前6次冲突，以L/H为准"},
    "P29": {"trigger": ("主弹命中钩索标记的敌人", "玩家主动攻击合法命中"), "prerequisite": ("钩索已解锁", "任意玩家主动攻击"), "reason": "M/O旧钩索限定与L明确通用主动攻击冲突，以最终L为准"},
    "B22": {"trigger": ("磁吸遥爆雷生效", "炸弹家族及其升级形态的爆炸"), "prerequisite": ("磁吸遥爆雷 Lv2", "炸弹家族（基础炸弹／磁吸雷／磁暴雷及合法升级）"), "reason": "M/O旧单支武器限定与L/H三种炸弹家族冲突，以L/H为准"},
    "G03": {"trigger": ("受伤后持续20秒未再受伤", "已装备时首次进入唯一新地图"), "reason": "M旧脱战触发与L/H新图回血冲突，以最终L/H为准"},
    "P10": {"description": ("技能触发生成3秒腐蚀云", "主动技能后5秒内首次主攻命中生成3秒腐蚀云"), "reason": "L缩略技能触发按M及H primed_window_s=5明确为技能后首次主攻命中"},
}


def encoded(value: object) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def read_workbook(path: Path) -> dict:
    raw = path.read_bytes()
    with zipfile.ZipFile(path) as archive:
        strings = []
        if "xl/sharedStrings.xml" in archive.namelist():
            strings = ["".join(n.text or "" for n in row.findall(".//m:t", NS))
                       for row in ET.fromstring(archive.read("xl/sharedStrings.xml")).findall("m:si", NS)]
        relation_root = ET.fromstring(archive.read("xl/_rels/workbook.xml.rels"))
        relations = {r.attrib["Id"]: r.attrib["Target"] for r in relation_root.findall(f"{{{REL}}}Relationship")}
        workbook = ET.fromstring(archive.read("xl/workbook.xml"))
        sheets = []
        for sheet in workbook.findall("m:sheets/m:sheet", NS):
            target = relations[sheet.attrib[f"{{{DOC_REL}}}id"]]
            member = target.lstrip("/") if target.startswith("/") else "xl/" + target
            if ".." in PurePosixPath(member).parts or not member.startswith("xl/"):
                raise ValueError("Worksheet relationship escapes the workbook")
            source = archive.read(member)
            rows = []
            for row in ET.fromstring(source).findall("m:sheetData/m:row", NS):
                cells = {}
                for cell in row.findall("m:c", NS):
                    value = cell.find("m:v", NS)
                    raw_value = value.text if value is not None else None
                    kind = cell.get("t", "n")
                    if kind == "s":
                        text = strings[int(raw_value)]
                    elif kind == "inlineStr":
                        text = "".join(n.text or "" for n in cell.findall("m:is//m:t", NS))
                    else:
                        text = raw_value or ""
                    formula = cell.find("m:f", NS)
                    cells[cell.attrib["r"]] = {"type": kind, "text": text, "raw_value": raw_value,
                        "formula": None if formula is None else formula.text,
                        "attributes": dict(cell.attrib)}
                rows.append({"row": int(row.attrib["r"]), "attributes": dict(row.attrib), "cells": cells})
            sheets.append({"name": sheet.attrib["name"], "member": member,
                           "xml_sha256": hashlib.sha256(source).hexdigest(), "rows": rows})
    return {"schema_version": 1, "original_filename": "道具v5.xlsx", "archive": ARCHIVE,
            "archive_sha256": hashlib.sha256(raw).hexdigest(), "archive_bytes": len(raw),
            "original_archive_sha256": ORIGINAL_SHA256, "original_archive_bytes": ORIGINAL_BYTES,
            "current_source_sha256": hashlib.sha256(raw).hexdigest(), "current_source_bytes": len(raw), "sheets": sheets}


def cells(row: dict) -> dict:
    return {re.sub(r"\d", "", reference): value["text"] for reference, value in row["cells"].items() if value["text"]}


def find_sheet(snapshot: dict, prefix: str) -> dict:
    found = [sheet for sheet in snapshot["sheets"] if sheet["name"].startswith(prefix)]
    if len(found) != 1:
        raise ValueError(f"Expected exactly one {prefix} sheet")
    return found[0]


def literal(row: dict, column: str):
    record = row["cells"].get(f"{column}{row['row']}")
    if record is None or record["formula"] is not None:
        raise ValueError(f"Missing or formula-backed editable cell {column}{row['row']}")
    text = record["text"]
    if record["type"] in ("s", "inlineStr", "str"):
        return text
    try:
        value = float(text)
    except ValueError as error:
        raise ValueError(f"Invalid numeric editable cell {column}{row['row']}") from error
    if not math.isfinite(value):
        raise ValueError("Non-finite runtime parameter")
    return int(value) if value.is_integer() else value


def resolved_text(id: str, field: str, replacement: str, params: dict) -> str:
    """Keep known stale-text repairs tied to H, including later H edits."""
    if id == "G01" and field == "description":
        return f"同目标{params['target_cooldown_s']:g}秒"
    if id == "G16" and field == "description":
        return f"各{params['damage_ratio_D_each']:.2f}D"
    if id == "B06" and field == "limits":
        return "每次腾空返还上限按Lv为" + "/".join(f"{v:g}" for v in params["airtime_refund_cap_by_level"]) + "时间能量"
    if id == "P05" and field == "trigger":
        return f"当前HP≤最大HP的{params['hp_ratio_threshold'] * 100:g}%"
    if id == "P15" and field == "trigger":
        return f"实际消耗共鸣累计{params['combat_energy_spent_threshold']:g}"
    if id in {"B16", "G10"} and field == "limits":
        return f"每图最多{params['bonus_coin_per_kill'] * params['max_bonus_kills_per_map']:g}额外金币"
    if id == "P10" and field == "description":
        return f"主动技能后{params['primed_window_s']:g}秒内首次主攻命中生成{params['cloud_duration_s']:g}秒腐蚀云"
    return replacement


def original_parameter_schema() -> dict:
    """Required keys come from the frozen source, not the mutable input snapshot."""
    global _ORIGINAL_SCHEMA_CACHE
    source = ROOT / ARCHIVE
    raw = source.read_bytes()
    if len(raw) != ORIGINAL_BYTES or hashlib.sha256(raw).hexdigest() != ORIGINAL_SHA256:
        raise ValueError("Original V5 attachment changed; refusing to rebaseline required parameters")
    # Recheck actual archive bytes on every call. Only reuse schema derived from
    # that exact immutable source, not from a mutable proposal under validation.
    if _ORIGINAL_SCHEMA_CACHE is not None:
        return _ORIGINAL_SCHEMA_CACHE
    original = read_workbook(source)
    result = {}
    for row in find_sheet(original, "01 ")["rows"]:
        c = cells(row)
        if not ID.fullmatch(c.get("B", "")):
            continue
        original_keys = set(json.loads(c["U"]))
        atomic_keys = {cells(p)["E"] for p in find_sheet(original, "03 ")["rows"] if cells(p).get("A") == c["B"]}
        if original_keys != atomic_keys:
            raise ValueError("Frozen source atomic/schema disagreement")
        result[c["B"]] = {"atomic_keys": frozenset(atomic_keys), "all_keys": frozenset(original_keys | set(TEXT_PARAMETERS.get(c["B"], {}))), "max_level": int(c["K"])}
    _ORIGINAL_SCHEMA_CACHE = result
    return result


def parameter_contract(parameters: dict, required: frozenset) -> dict:
    positive, integer, zero = [], [], []
    modes = {}
    for key in sorted(required):
        base = key.removesuffix("_by_level")
        if base in TEXT_PARAMETER_KEYS:
            if base == "resource_pickup_mask":
                modes[key] = ["coin", "meta_note", "health_pickup", "energy_pickup"]
            else:
                modes[key] = ["THROW_ONLY" if base == "mode" else "BOMB"]
            continue
        if base in INTEGER_PARAMETER_KEYS:
            integer.append(key)
        # Match parameter words: the letters "ratio" also occur inside
        # "duration", which must never make a zero-duration divisor legal.
        allow_zero = base in ZERO_PARAMETER_KEYS or "_ratio" in base or "_multiplier" in base
        if base in {"max_target_hits", "projectile_count_multiplier", "pulse_count", "hits_for_one_barrier"}:
            allow_zero = False
        (zero if allow_zero else positive).append(key)
    return {"required_keys": sorted(required), "positive_keys": positive, "integer_keys": integer,
            "zero_allowed_keys": zero, "text_modes": modes, "reject_unknown_keys": True,
            "schema_source_sha256": ORIGINAL_SHA256}


def validate_parameter_contract(parameters: dict, contract: dict, max_level: int) -> None:
    if set(parameters) != set(contract["required_keys"]):
        raise ValueError("Missing or unknown runtime parameter")
    for key, raw in parameters.items():
        if key in contract["text_modes"]:
            if not isinstance(raw, str) or not raw:
                raise ValueError("Invalid text parameter")
            values = raw.split("|") if key == "resource_pickup_mask" else [raw]
            if any(value not in contract["text_modes"][key] for value in values):
                raise ValueError("Unsupported text mode")
            continue
        values = raw if key.endswith("_by_level") else [raw]
        if key.endswith("_by_level") and (not isinstance(raw, list) or len(raw) != max_level):
            raise ValueError("Wrong parameter level array")
        for value in values:
            if type(value) not in (int, float) or not math.isfinite(value) or value < 0:
                raise ValueError("Invalid numeric runtime parameter")
            if key in contract["positive_keys"] and value <= 0:
                raise ValueError("Runtime duration/radius/budget must be positive")
            if key in contract["integer_keys"] and value != math.floor(value):
                raise ValueError("Runtime count must be an integer")


def build_catalog(snapshot: dict) -> dict:
    schema = original_parameter_schema()
    active_sheet = find_sheet(snapshot, "01 ")
    review_sheet = find_sheet(snapshot, "02 ")
    parameter_sheet = find_sheet(snapshot, "03 ")
    growth_sheet = find_sheet(snapshot, "04 ")
    active = [(row, cells(row)) for row in active_sheet["rows"] if ID.fullmatch(cells(row).get("B", ""))]
    reviews = [cells(row) for row in review_sheet["rows"] if ID.fullmatch(cells(row).get("B", ""))]
    if len(active) != 72 or len(reviews) != 93:
        raise ValueError("V5 must retain 72 active and all 93 review rows")
    ids = [c["B"] for _, c in active]
    if len(set(ids)) != len(ids) or len({c["B"] for c in reviews}) != 93:
        raise ValueError("Duplicate stable ID")
    deleted = [c["B"] for c in reviews if c.get("L") == "否"]
    allowed = {c["B"] for c in reviews if c.get("L") == "是"}
    if len(deleted) != 21 or set(ids) != allowed or set(ids).intersection(deleted):
        raise ValueError("Active/deleted review mismatch")
    if Counter(c["D"] for _, c in active) != {"蓝色": 29, "紫色": 28, "金色": 15}:
        raise ValueError("Unexpected V5 rarity count")
    params = {id: {} for id in ids}
    sources = {id: {} for id in ids}
    seen = set()
    for row in parameter_sheet["rows"]:
        c = cells(row)
        if not ID.fullmatch(c.get("A", "")):
            continue
        id, key, level = c["A"], c["E"], c["F"]
        if id not in params or (id, key, level) in seen:
            raise ValueError("Unknown or duplicate atomic parameter")
        seen.add((id, key, level))
        value = literal(row, "H")
        if key in TEXT_PARAMETER_KEYS:
            if not isinstance(value, str) or not value:
                raise ValueError("Expected a nonempty parameter mode")
            if key in {"weapon_family", "exclude_weapon_family"} and value != "BOMB":
                raise ValueError("Unknown V5 weapon family")
            if key == "mode" and value != "THROW_ONLY":
                raise ValueError("V5 only supports the approved single throw mode")
            if key == "resource_pickup_mask" and not set(value.split("|")).issubset({"coin", "meta_note", "health_pickup", "energy_pickup"}):
                raise ValueError("Resource magnet cannot collect reward or shop objects")
        elif type(value) not in (int, float) or value < 0:
            raise ValueError("Expected a nonnegative finite numeric parameter")
        reference = f"{parameter_sheet['name']}!H{row['row']}"
        if level.isdigit():
            if level not in ("1", "2", "3") or not key.endswith("_by_level"):
                raise ValueError("Invalid level parameter")
            values = params[id].setdefault(key, [None, None, None])
            values[int(level) - 1] = value
            sources[id].setdefault(key, [None, None, None])[int(level) - 1] = reference
        else:
            if key in params[id] or key.endswith("_by_level"):
                raise ValueError("Ambiguous parameter shape")
            params[id][key] = value
            sources[id][key] = reference
    items, conflicts = [], []
    for row, c in active:
        id, level = c["B"], int(literal(row, "K"))
        if id not in schema or set(params[id]) != schema[id]["atomic_keys"] or level != schema[id]["max_level"]:
            raise ValueError("Current input changed required parameter keys or approved level schema")
        if level not in (1, 3) or not params[id]:
            raise ValueError("Missing item parameters or invalid level cap")
        for key, value in params[id].items():
            if key.endswith("_by_level") and (level != 3 or len(value) != level or None in value):
                raise ValueError("Incomplete level parameters")
        original_parameters = json.loads(c["U"])
        if original_parameters != params[id]:
            conflicts.append({"stable_id": id, "kind": "01_snapshot_vs_03_H", "source_cell": f"{active_sheet['name']}!U{row['row']}", "resolution": "03H优先", "snapshot": original_parameters, "atomic": params[id].copy()})
        for key, (value, column) in TEXT_PARAMETERS.get(id, {}).items():
            if key in params[id]:
                raise ValueError("Text supplement would override an atomic H parameter")
            params[id][key] = value
            sources[id][key] = f"{active_sheet['name']}!{column}{row['row']}（原文明确值，03未列）"
        contract = parameter_contract(params[id], schema[id]["all_keys"])
        validate_parameter_contract(params[id], contract, level)
        item = {"stable_id": id, "display_name": c["C"],
                "rarity": {"蓝色": "BLUE", "紫色": "PURPLE", "金色": "GOLD"}[c["D"]],
                "gear_cost": literal(row, "G"), "shop_price": literal(row, "I"), "max_level": level,
                "description": c["L"], "trigger": c.get("M", ""), "limits": c.get("N", ""), "prerequisite": c.get("O", ""),
                "effect_parameters": params[id], "parameter_contract": contract, "parameter_sources": sources[id], "source_row": row["row"],
                "source_mechanism_text": c["L"], "source_trigger_text": c.get("M", ""),
                "source_limits_text": c.get("N", ""), "source_prerequisite_text": c.get("O", ""),
                "source_snapshot_parameters": original_parameters}
        if type(item["gear_cost"]) is not int or not 1 <= item["gear_cost"] <= 5 or type(item["shop_price"]) is not int or item["shop_price"] <= 0:
            raise ValueError("Invalid independent gear cost or price")
        resolution = TEXT_RESOLUTIONS.get(id, {})
        for field, change in resolution.items():
            if field == "reason":
                continue
            before, after = change
            if before not in item[field]:
                raise ValueError(f"Resolution source drift: {id}/{field}")
            item[field] = item[field].replace(before, resolved_text(id, field, after, params[id]))
        if resolution:
            conflicts.append({"stable_id": id, "kind": "stale_text", "source_row": row["row"], "resolution": resolution["reason"]})
        items.append(item)
    upgraded = {item["stable_id"] for item in items if item["max_level"] == 3}
    growth = {cells(row).get("A") for row in growth_sheet["rows"] if ID.fullmatch(cells(row).get("A", ""))}
    if upgraded != growth or len(upgraded) != 16:
        raise ValueError("Detailed active and growth sheets must agree on the 16 upgradeable items")
    conflicts.append({"kind": "summary_upgrade_count", "source_cell": "00 策划总览!C22", "resolution": "概述‘16件原图鉴+新增’隐含17，但00统计、01逐件K及04唯一ID一致16；只给逐件批准的16件升级，不发明第17件"})
    return {"schema_version": 1, "catalog_version": 5,
            "source": {"archive": ARCHIVE, "sha256": ORIGINAL_SHA256, "bytes": ORIGINAL_BYTES,
                       "original_sha256": ORIGINAL_SHA256, "current_source_sha256": snapshot["archive_sha256"], "current_source_bytes": snapshot["archive_bytes"],
                       "snapshot": SNAPSHOT, "snapshot_sha256": hashlib.sha256(encoded(snapshot)).hexdigest(),
                       "parameter_authority": "03 数值参数 H列，01G负荷／01I价格；L最终机制优先于过期M/O",
                       "user_parameter_authorization": "按03H当前建议参数实现、保持可调（2026-10-27本轮用户回复）",
                       "balance_acceptance": "unverified"},
            "items": items, "deleted_ids": deleted,
            "text_parameter_supplements": {id: {key: value for key, (value, _) in values.items()} for id, values in TEXT_PARAMETERS.items()},
            "upgradeable_count": len(upgraded), "conflicts": conflicts}


def build_synergies(snapshot: dict, catalog: dict) -> dict:
    """Preserve all historical recipes, enabling only the nine approved bases."""
    sheet = find_sheet(snapshot, "05 ")
    active = {item["stable_id"]: item for item in catalog["items"]}
    deleted = set(catalog["deleted_ids"])
    synergies = {}
    conflicts = []
    for row in sheet["rows"]:
        c = cells(row)
        id = c.get("A", "")
        if not re.fullmatch(r"S\d{2}", id):
            continue
        if id in synergies:
            raise ValueError("Duplicate synergy ID")
        members = [value.strip() for value in c["B"].split("+")]
        if len(members) != 2 or len(set(members)) != 2 or any(value not in active and value not in deleted for value in members):
            raise ValueError("Invalid synergy members")
        enabled = c["D"].startswith("有效")
        if enabled and any(member not in active for member in members):
            raise ValueError("An enabled recipe references a deleted item")
        status = "enabled_unverified" if enabled else "pending_redesign" if c["D"] == "待重设计" else "disabled_deleted_item"
        if status == "disabled_deleted_item" and not any(member in deleted for member in members):
            raise ValueError("Deleted-recipe status lacks a deleted member")
        synergies[id] = {
            "enabled": enabled, "required_items": members, "status": status,
            "parameters": {}, "parameter_sources": {}, "mechanism_text": c["E"],
            "safety_text": c["F"], "source": {"worksheet": sheet["name"], "row": row["row"], "cells": c},
        }
    if set(synergies) != {f"S{n:02}" for n in range(1, 17)}:
        raise ValueError("All sixteen original synergy records must be preserved")
    if Counter(value["status"] for value in synergies.values()) != {"enabled_unverified": 9, "pending_redesign": 3, "disabled_deleted_item": 4}:
        raise ValueError("Synergy status counts must remain 9/3/4")

    explicit = {
        "S02": {"max_drones_per_marked_target": (2, "F")},
        "S09": {"intercept_cooldown_multiplier": (0.9, "E")},
        "S10": {"recovery_threshold": (5, "E"), "skill_cost_credit": (5, "E")},
        "S15": {"once_per_owned_instance": (True, "F"), "after_repair_retrigger": (False, "F")},
    }
    for id, values in explicit.items():
        target = synergies[id]
        for key, (value, column) in values.items():
            target["parameters"][key] = value
            target["parameter_sources"][key] = f"{sheet['name']}!{column}{target['source']['row']}"
    # The user chose atomic H values over conflicting old prose: never restore
    # the historical S13 1.2 total or the S07 obsolete purse cap of sixteen.
    target = synergies["S13"]
    target["parameters"]["total_damage_budget_multiplier"] = active["G15"]["effect_parameters"]["total_damage_budget_multiplier"]
    target["parameter_sources"]["total_damage_budget_multiplier"] = active["G15"]["parameter_sources"]["total_damage_budget_multiplier"]
    target["safety_text"] = "总伤害预算×%g、共享同一技能冷却和一次共鸣扣除" % target["parameters"]["total_damage_budget_multiplier"]
    conflicts.append({"synergy_id": "S13", "source_cell": f"{sheet['name']}!F18", "original_text": target["source"]["cells"]["F"], "resolution": "总预算采用用户授权的G15原子H值；不叠乘旧1.2联动"})
    target = synergies["S07"]
    target["safety_text"] = "仅改变已成立金币拾取的表现，不复制金币；本图额外金币预算继续由B16唯一参数决定"
    conflicts.append({"synergy_id": "S07", "source_cell": f"{sheet['name']}!F12", "original_text": target["source"]["cells"]["F"], "resolution": "原16与当前B16每次1金币／前8次冲突，联动不改变当前B16预算"})
    return {
        "schema_version": 1, "catalog_version": 5,
        "source": {"archive": ARCHIVE, "sha256": ORIGINAL_SHA256, "original_sha256": ORIGINAL_SHA256,
                   "current_source_sha256": snapshot["archive_sha256"], "snapshot": SNAPSHOT,
                   "worksheet": sheet["name"], "parameter_authority": "05联动明确机制；冲突数值按用户授权的03H优先",
                   "implementation_acceptance": "unverified", "balance_acceptance": "unverified"},
        "synergies": synergies, "counts": {"enabled": 9, "pending_redesign": 3, "disabled_deleted_item": 4},
        "implementation_candidates": [{"synergy_id": "S09", "parameter": "visual_scale_multiplier", "value": None,
                                       "status": "unspecified_by_workbook", "scope": "仅外观扩大；具体倍率由实施候选配置确定，不改碰撞或拦截半径，不冒称用户数值"}],
        "conflicts": conflicts,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=ROOT / ARCHIVE)
    parser.add_argument("--output", type=Path, default=ROOT / CONFIG)
    parser.add_argument("--snapshot", type=Path, default=ROOT / SNAPSHOT)
    parser.add_argument("--synergies", type=Path, default=ROOT / SYNERGIES)
    parser.add_argument("--check", action="store_true", help="Verify exact generated bytes without modifying any file")
    args = parser.parse_args()
    snapshot = read_workbook(args.source)
    catalog = build_catalog(snapshot)
    synergies = build_synergies(snapshot, catalog)
    for path, value in ((args.snapshot, snapshot), (args.output, catalog), (args.synergies, synergies)):
        expected = encoded(value)
        if args.check:
            if not path.is_file() or path.read_bytes() != expected:
                raise SystemExit(f"V5 import drift: {path}")
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(expected)
    print(f"ITEM V5 IMPORT: passed; 72 active, 21 deleted, {catalog['upgradeable_count']} upgradeable; source {snapshot['archive_sha256']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
