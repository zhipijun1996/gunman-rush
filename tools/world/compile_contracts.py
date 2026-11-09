#!/usr/bin/env python3
"""Compile construction contracts for the fixed-world structural graybox.

The canonical section graph owns progression.  This compiler owns the proposed
scene interfaces, adjustable world-unit envelopes and camera/encounter briefs.
It does not claim a collision, jump, combat or human-readability playtest.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
from collections import Counter, defaultdict
from pathlib import Path

from spatial import room_space, contains_rect

ROOT = Path(__file__).resolve().parents[2]
ABILITIES = {"H", "W", "D", "Q"}
OPPOSITE = {"left": "right", "right": "left", "up": "down", "down": "up"}
VIEWPORT = [1280, 720]
WORKING_VIEW = [800, 450]
CAMERA_PROFILES = {
    "bounded_follow": {"name": "双轴范围跟随", "behavior": "分轴缓冲与动作响应；相机中心约束独立于物理碰撞。"},
    "horizontal_follow": {"name": "横向跟随", "behavior": "限制普通Y，手动查看许可独立。"},
    "vertical_follow": {"name": "纵向跟随", "behavior": "限制普通X，持续爬升和快速下落及时跟随。"},
    "fixed_arena": {"name": "固定场地", "behavior": "固定或有限跟随，不自动缩放；Boss默认禁用查看。"},
}

# C/T are construction ceilings on ordinary routes, not compulsory pressure in
# every room.  Boss peaks are specified separately.
REGION_DIFFICULTY = {
    "P": {"name": "风铃平原", "front": [1, 1], "deep": [2, 2], "optional": [3, 3], "attack": [5, 9], "rhythm": "教程、小站和多方向探索；主体长期保持轻松。"},
    "F": {"name": "荆棘森林", "front": [1, 2], "deep": [2, 3], "optional": [4, 4], "attack": [5, 13], "rhythm": "地面战斗与树冠机动分层，W教学宽容。"},
    "M": {"name": "蕈灯地穴", "front": [1, 2], "deep": [2, 2], "optional": [3, 4], "attack": [5, 9], "rhythm": "弹菇与H逐步组合，取得D前不用D。"},
    "S": {"name": "萤雾沼泽", "front": [1, 1], "deep": [2, 2], "optional": [3, 3], "attack": [9, 13], "rhythm": "干岸、绕路和装备选择，不用持续扣血替代平台设计。"},
    "Y": {"name": "风蚀峡谷", "front": [1, 2], "deep": [2, 3], "optional": [3, 4], "attack": [5, 13], "rhythm": "纵向机动与风口判断，战斗放在稳定宽台。"},
    "I": {"name": "霜镜冰川", "front": [2, 2], "deep": [3, 3], "optional": [4, 4], "attack": [9, 13], "rhythm": "入口缓冲后再组合攀升，精密冰峰放支路。"},
    "C": {"name": "月影墓园", "front": [1, 1], "deep": [2, 2], "optional": [4, 3], "attack": [5, 9], "rhythm": "地面战斗、剧情与短墓室分岔承担缓冲。"},
    "K": {"name": "月冠古堡", "front": [2, 1], "deep": [3, 2], "optional": [4, 3], "attack": [9, 13], "rhythm": "庭院厅堂与守卫战，Q前兼容W和D两路。"},
    "G": {"name": "齿轮工城", "front": [2, 2], "deep": [3, 2], "optional": [4, 4], "attack": [5, 13], "rhythm": "工房安全休整，街区战斗与机械观察交替。"},
    "N": {"name": "回声矿井", "front": [1, 1], "deep": [2, 2], "optional": [3, 3], "attack": [5, 13], "rhythm": "扭曲矿道、矿腔与爆破捷径；钻机支段单列压力。"},
    "E": {"name": "熔火腹地", "front": [3, 2], "deep": [3, 3], "optional": [4, 4], "attack": [9, 13], "rhythm": "短热区与稳定平台战斗交替；HDQ无W首访成立。"},
    "T": {"name": "根脉圣殿", "front": [1, 2], "deep": [2, 2], "optional": [4, 3], "attack": [5, 13], "rhythm": "HW早访与开阔圣殿舒展节奏，双卫独立可选。"},
    "R": {"name": "沉水遗迹", "front": [2, 1], "deep": [3, 2], "optional": [4, 3], "attack": [9, 13], "rhythm": "干燥回廊、废墟战斗与上下层探索，无新增游泳前提。"},
    "A": {"name": "破碎浮岛", "front": [2, 2], "deep": [3, 3], "optional": [4, 4], "attack": [13, 17], "rhythm": "普通结局机动高潮，接落台与本段重试明确。"},
    "V": {"name": "星桥天门", "front": [2, 2], "deep": [2, 2], "optional": [4, 3], "attack": [13, 17], "rhythm": "远景、线索与真相收束，沿途不持续增加精密平台。"},
    "Z": {"name": "世界钟心", "front": [2, 1], "deep": [3, 3], "optional": [5, 4], "attack": [17, 21], "rhythm": "门厅安全预览，顶部组合熟悉机制；王/神另列Boss峰值。"},
}

# Explicit encounter-dependent working envelopes.  These are chosen for this
# game's movement scale; they are not claimed to be Hollow Knight pixel sizes.
# combat width/height, working view width, camera, pressure peak, attack range,
# and specific geometry constraint.
BOSS_WORK = {
    "P_WINDKEEPER": (768, 384, 896, "fixed_arena", 2, [5, 5], "ground_duel", "基础移动可避开全部强制招式；H在胜利后才取得。"),
    "P_BELLSTRIDER": (1280, 480, 1024, "bounded_follow", 3, [5, 9], "patrol_high_weakpoint", "上方风铃弱点需留可读射击高度，巡行/转身距离与两枪窗口共同标定。"),
    "F_RANGER": (896, 432, 1024, "fixed_arena", 3, [5, 9], "ranged_duel", "飞刃去回程均可读；基础枪和H成立，不要求W或手里剑。"),
    "F_QUEEN": (960, 704, 1120, "bounded_follow", 4, [5, 13], "wall_layer_arena", "树冠墙面换边与地面缓冲共存，HW成立，不要求D/Q。"),
    "M_MOTHER": (896, 576, 1152, "fixed_arena", 3, [5, 9], "bounce_spore_arena", "弹菇和孢子落点先可视，H与一次跳足够，不能以D进场。"),
    "S_SNAIL": (1120, 560, 1152, "bounded_follow", 3, [9, 13], "dry_islands_arena", "高台与排液口均有稳定落点；HW或HD两种首访均可战。"),
    "Y_HOWLER": (1280, 544, 1024, "bounded_follow", 3, [5, 13], "wind_charge_arena", "低中两层避冲，换风方向提前读，HW即可战。"),
    "I_MIRROR": (960, 704, 1120, "bounded_follow", 4, [9, 13], "delayed_layer_arena", "延迟挥击和安全层同时能观察，HWD换层有固定台。"),
    "C_DUELIST": (768, 400, 896, "fixed_arena", 4, [5, 13], "compact_blade_duel", "短安全区与回刃路径清楚，HW或HD成立，不用Q。"),
    "C_FUNERAL": (960, 480, 1056, "fixed_arena", 3, [5, 9], "pendulum_court", "丧钟扫击与地面站位互相配合；灯装读纹，不用Q破盾。"),
    "K_KNIGHT": (960, 448, 1056, "fixed_arena", 3, [9, 13], "gunline_duel", "Q获得前的普通反冲可避全部招式；W/D两路线分别检查。"),
    "G_OVERSEER": (1152, 704, 1152, "bounded_follow", 4, [9, 13], "two_lane_factory", "错相生产线各有稳定地面；W或D均可换层，不要求Q。"),
    "N_WAREHOUSE": (896, 432, 1024, "fixed_arena", 3, [5, 9], "bomb_marker_court", "地面爆点可预读，基础枪/H可战，炸弹与D均非前置。"),
    "N_DRILL": (704, 1280, 896, "bounded_follow", 4, [5, 13], "bent_vertical_rail", "分层支台承接钻机出入，炸弹岩壳窗口与普通枪露芯分开。"),
    "E_FURNACE": (1152, 640, 1152, "bounded_follow", 4, [9, 13], "two_level_phase_furnace", "Q只处理相位光幕；熔岩仍伤害。HDQ无W成立，连续Q间有2秒节奏/等待台。"),
    "T_ROOT": (960, 640, 1120, "bounded_follow", 3, [5, 13], "root_wall_court", "HW可早访，根索和平台节拍后有两枪窗口，不用D/Q。"),
    "T_TWINS": (960, 448, 1056, "fixed_arena", 4, [9, 17], "alternating_pair_court", "双卫严格交错；两敌算一场，避免同步随机封全部站位。"),
    "R_FERRYMAN": (1120, 608, 1152, "bounded_follow", 3, [9, 13], "slow_floating_platforms", "HD跨固定安全台，移动平台变化不改变玩家物理。"),
    "A_COLOSSUS": (1536, 768, 1280, "bounded_follow", 4, [13, 17], "bridge_chain_platforms", "换台后能稳定输出/等待Q，失败回本段，不连续掉层。"),
    "V_GATEKEEPER": (1024, 512, 1120, "fixed_arena", 4, [13, 17], "star_track_court", "星轨次序预演，HWD处理；不要求奖励断契棱针。"),
    "Z_KING": (1280, 608, 1280, "fixed_arena", 4, [17, 21], "final_gun_pendulum_court", "枪线/钟摆/相位交替，王战与神战独立，稳定落点供Q节奏。"),
    "Z_DEITY": (1536, 960, 1280, "bounded_follow", 5, [17, 21], "phase_constellation_arena", "阶段化平台和可视轨迹时间异象，不改变玩家基础物理；每段独立回落区。"),
}


def read_json(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def write_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def dnf(value):
    if value is None or value == []:
        return [[]]
    if isinstance(value, str):
        return [[value]]
    return [list(value)] if value and isinstance(value[0], str) else copy.deepcopy(value)


def terms(value):
    return {t for group in dnf(value) for t in group}


def and_dnf(a, b):
    rows = []
    for x in dnf(a):
        for y in dnf(b):
            z = list(dict.fromkeys(x + y))
            if not any(set(v).issubset(z) for v in rows):
                rows = [v for v in rows if not set(z).issubset(v)] + [z]
    return rows


def snap(x, step=16):
    return int(round(x / step) * step)


def clamp(x, low, high):
    return max(low, min(high, x))


def room_aspect(room):
    p = room["polygon"]
    w = max(v[0] for v in p) - min(v[0] for v in p)
    h = max(v[1] for v in p) - min(v[1] for v in p)
    return w / max(1, h)


def coarse_outline(room, extent):
    p = room["polygon"]
    x0, y0 = min(v[0] for v in p), min(v[1] for v in p)
    dx = max(v[0] for v in p) - x0
    dy = max(v[1] for v in p) - y0
    pts = [[snap((x - x0) / max(1, dx) * extent[0]), snap((y - y0) / max(1, dy) * extent[1])] for x, y in p]
    try:
        from shapely.geometry import Polygon
        poly = Polygon(pts)
        if not poly.is_valid:
            poly = poly.buffer(0)
        if poly.geom_type != "Polygon":
            poly = max(poly.geoms, key=lambda v: v.area)
        poly = poly.simplify(24, preserve_topology=True)
        pts = [[round(x, 1), round(y, 1)] for x, y in list(poly.exterior.coords)[:-1]]
    except ImportError:
        pts = [q for i, q in enumerate(pts) if i == 0 or q != pts[i - 1]]
    return pts


def sections_of(room):
    value = room.get("sections", [{"id": "main", "kind": "main"}])
    return copy.deepcopy(list(value.values()) if isinstance(value, dict) else value)



def required_reserved_areas(entry):
    """Reserve interface volumes independently of the decorative map outline.

    These are working rectangles, not an auto-generated walkable mesh.  Only
    the support slabs are solid; motion/headroom/foyer volumes must be usable.
    Their section bindings prevent a convenient connector from bypassing an
    authored ability fixture.
    """
    areas = []
    room_id = entry["room_id"]
    _, _, width, height = entry["world_geometry"]["bounds_world_units"]
    for door in entry["doors"]:
        did, side, sid = door["id"], door["direction"], door["section"]
        x, y = door["position_candidate"]["local_world_units"]
        landing = door["landing_contract"]
        px, py, pw, ph = landing["platform_candidate_rect_world_units"]
        sx, sy = landing["entry_position_world_units"]
        tx, ty = landing["safe_standing_position_world_units"]
        if side == "left":
            throat = [x, y - 96, 96, 128]
            floor = [x, y, 96, 32]
        elif side == "right":
            throat = [x - 96, y - 96, 96, 128]
            floor = [x - 96, y, 96, 32]
        elif side == "up":
            throat = [x - 48, y, 96, 112]
            floor = None
        else:
            throat = [x - 48, y - 112, 96, 112]
            floor = None
        common = {
            "section": sid, "door_ref": did, "must_be_in_usable_room_envelope": True,
            "can_require_expanding_visual_outline": True,
            "candidate_geometry_status": "施工占位；允许与门/平台一起成组调整，调整后重验外框与分区。",
        }
        rows = [
            ("interface_inner_throat", throat, "门洞内侧通行/支撑带；外侧由成对目标房的预留带负责。", "traversable_with_authored_ground_support"),
            ("landing_support", [px, py, pw, ph], "必须保留的真实安全落脚台；不得用虚拟grounded状态替代。", "required_solid_ground"),
            ("landing_headroom", [px, py - 128, pw, 128], "安全台上方净空；不放地形伤害、敌人或自动战斗触发线。", "required_clear_and_hazard_free"),
            ("entry_motion_volume", [min(sx, tx) - 32, min(sy, ty) - 48,
                                     abs(sx - tx) + 64, abs(sy - ty) + 66],
             "入口到真实落点的动作占位包络；与安全台相接，实际轨迹和时长须实机测定。", "body_motion_clear_except_authored_ground_contacts"),
        ]
        if floor:
            rows.append(("walk_door_threshold_support", floor, "左右步行门从房界到入口台之间连续承重，不能在门洞内留下48单位小坑。", "required_solid_ground"))
        for kind, rect, meaning, collision in rows:
            areas.append({
                **common, "id": f"reserved:{did}:{kind}", "kind": kind,
                "rect_world_units": rect, "meaning": meaning, "collision_intent": collision,
                "connector_requirement": {
                    "owner_room": room_id, "from_door": did, "to_section": sid,
                    "real_in_room_connection_required": True,
                    "geometry": "与入口台及所属分区以真实前廊/转角/阶梯连接；不允许从轮廓缺口瞬移到主体。",
                    "ability_boundaries": "不得跨过internal_routes中的环境阻隔；入口预览只能先接本入口分区。",
                    "exact_path_status": "前廊走向随分区地形落位；本矩形不授权自动直连主房中心。",
                },
            })
        door["required_reserved_area_refs"] = [a["id"] for a in areas if a.get("door_ref") == did]
    if entry.get("boss_arena"):
        arena = entry["boss_arena"]
        areas.append({
            "id": f"reserved:{room_id}:boss_combat", "kind": "boss_combat",
            "section": entry["boss"]["encounter_section"], "boss_ref": arena["boss_id"],
            "rect_world_units": arena["combat_bounds_world_units"],
            "must_be_in_usable_room_envelope": True, "can_require_expanding_visual_outline": True,
            "collision_intent": "arena_envelope_with_authored_platforms_not_one_filled_collision_polygon",
            "meaning": "完整容纳本场竞技区；入口前庭和落脚台在该矩形外，战斗触发线位于前廊之后。",
            "connector_requirement": {
                "owner_room": room_id, "real_in_room_connection_required": True,
                "geometry": "前庭经所属分区真实到达战闸；分区能力障碍在前庭/接续路实现，不能自动落地即跨过。",
                "battle_activation": "真实进入战斗触发线才激活；不得在入口过渡、落脚或交通到达时触发。",
            },
            "candidate_geometry_status": "每场候选竞技矩形，具体平台/攻击/视野由该Boss灰盒校准。",
        })
    return areas


def main_difficulty(room, boss):
    r = REGION_DIFFICULTY[room["region"]]
    role = room.get("primary_role")
    deep = role in {"gated_rear_or_connector", "landmark_or_objective", "optional_branch"}
    c, t = r["deep" if deep else "front"]
    if role == "rest_or_service" or room.get("play_mode") == "safe":
        c, t = 0, 0
    if room["id"] in {"P-R01", "G-R01", "Z-R01", "Z-R13"}:
        c, t = 0, 0
    if room["id"] == "F-R10":
        c, t = 0, 1
    if boss:
        c, t = 0, min(1, t)
    return {
        "main_C": c, "main_T": t,
        "ordinary_route_scope": "本房普通通路/前庭的第一轮制作上限，不要求每段填满；Boss另列。",
        "optional_peak_C": r["optional"][0] if role == "optional_branch" else None,
        "optional_peak_T": r["optional"][1] if role == "optional_branch" else None,
        "boss_peak_C": BOSS_WORK[boss["id"]][4] if boss else None,
        "status": "首轮制作目标；未经过实机平衡或玩家测试。",
    }


def derive_local_main_conditions(room):
    routes = room.get("internal_routes", [])
    arrivals = [dnf(r.get("requires")) for r in routes if r.get("to_section") == "main"]
    if not arrivals:
        return [[]]
    flattened = [v for x in arrivals for v in x]
    result = []
    for row in sorted(flattened, key=len):
        if not any(set(v).issubset(row) for v in result):
            result.append(row)
    return result


def first_visit_samples(path):
    if not path.exists():
        return {}
    d = read_json(path)
    out = defaultdict(list)
    replays = d.get("replays", [])
    if isinstance(replays, dict):
        replays = list(replays.values())
    for replay in replays:
        if str(replay.get("id", "")).startswith("D_"):
            continue
        states = replay.get("first_subject_visit_states", [])
        if isinstance(states, dict):
            states = list(states.values())
        for row in states:
            rid = row.get("room", row.get("room_id"))
            if rid:
                out[rid].append({"route_id": replay.get("id"), **copy.deepcopy(row)})
    return out


def build(canonical, construction, replay_path):
    rooms = {r["id"]: r for r in canonical["rooms"]}
    inputs = {r["room_id"]: r for r in construction["rooms"]}
    pairs = {p["edge_id"]: p for p in construction["door_pairs"]}
    edges = canonical["connections"]
    bosses = {b.get("room_id", b.get("physical_room")): b for b in canonical.get("boss_plan", {}).get("bosses", [])}
    actions = {a["id"]: a for a in canonical.get("actions", [])}
    by_room = defaultdict(list)
    for a in actions.values():
        by_room[a.get("room_id")].append(a)
    npc_by_room = defaultdict(list)
    for npc in canonical.get("npcs", []):
        npc_by_room[npc.get("room_id", npc.get("production_room_id"))].append(npc)
    shortcut_by_id = {s["id"]: s for s in canonical.get("shortcuts", [])}
    memory_by_room = defaultdict(list)
    for m in canonical.get("memory_gates", []):
        rid = m.get("observed_from_room", m.get("preview_room", m.get("room_id")))
        if rid:
            memory_by_room[rid].append(m)
    samples = first_visit_samples(replay_path)
    audit, doors_by_room = [], defaultdict(list)
    edge_by_id = {e["id"]: e for e in edges}
    for e in edges:
        pair = copy.deepcopy(pairs[e["id"]])
        sides = [pair["construction_sides"][e["a"]], pair["construction_sides"][e["b"]]]
        audit.append(pair)
        for idx, rid in enumerate([e["a"], e["b"]]):
            target = e["b"] if idx == 0 else e["a"]
            section = e.get("a_section" if idx == 0 else "b_section", "main")
            target_section = e.get("b_section" if idx == 0 else "a_section", "main")
            direct = e.get("direction", "both")
            allowed = direct in (None, "both") or direct in ("a_to_b", "a->b") and idx == 0 or direct in ("b_to_a", "b->a") and idx == 1
            requirement = dnf(e.get("effective_door_requires", e.get("requires")))
            assert not terms(requirement) & ABILITIES, (e["id"], requirement)
            side = sides[idx]
            door = {
                "id": f"{e['id']}:{rid}", "edge_id": e["id"], "room_id": rid,
                "section": section, "target_room": target, "target_section": target_section,
                "target_scene": f"res://world/regions/{rooms[target]['region']}/rooms/{target}.tscn",
                "target_door_id": f"{e['id']}:{target}", "target_spawn": f"spawn:{e['id']}:{target}",
                "direction": side, "target_direction": OPPOSITE[side],
                "traversal_direction": direct, "outbound_allowed": bool(allowed),
                "requires": requirement, "condition_format": "OR of AND; empty inner group is true",
                "gate": {
                    "kind": "persistent_shortcut" if e["id"] in shortcut_by_id else "item_story_or_operation_gate" if any(requirement) else "open_passage",
                    "ability_check_forbidden": True,
                    "physical_blocker_required": bool(any(requirement)),
                    "closed_behavior": "仅真正的道具/剧情/机关门以可见实体反馈封闭；H/W/D/Q环境阻隔在房内路线。",
                    "equipment_checks": sorted(t for t in terms(requirement) if t.startswith("eq_")),
                },
                "transition": {
                    "type": "walk_horizontal" if side in ("left", "right") else "jump_up_autoland" if side == "up" else "drop_down_safe_platform",
                    "load_only_target_room": True, "target_spawn_explicit": True,
                    "camera_ready_before_control_return": True,
                    "arrival_policy": "由目标入口landing_contract决定，不沿用全门虚拟落地重置。",
                    "upward_control_takeover": side == "up",
                    "upward_handover": "自动短跳至目标入口旁实际平台、真实着地后归还控制" if side == "up" else None,
                    "downward_safe_floor_guaranteed": side == "down",
                    "q_cooldown_reset": False, "q_landing_rearm_only_after_real_ground_contact": True,
                    "rest_cycle_reset": False, "heal_hp": False, "enemy_reset": False,
                    "prevent_immediate_bounce_back": True,
                    "commit_persistent_transactions_before_unload": True,
                    "spatial_exception": pair["spatial_exception"],
                },
                "coordinate_audit_ref": e["id"],
                "connector_owner_room": rid if rid in pair["connector_owner_rooms"] else None,
                "connector_intent": "在本房内设置可步行转角/楼层接续廊，承接旧图端点至新接口；相机区随通路过渡。" if rid in pair["connector_owner_rooms"] else None,

            }
            doors_by_room[rid].append(door)

    result_rooms = []
    for rid, room in rooms.items():
        source = inputs[rid]
        boss = bosses.get(rid)
        extent, shape_class, rationale = source["extent"], source["shape_class"], source["rationale"]
        w, h = extent
        space = room_space(source.get("space_rects", [] if source.get("implemented") else [[0, 0, w, h]]), extent)
        sections = sections_of(room)
        section_ids = {s["id"] for s in sections}
        doors = doors_by_room[rid]
        geometry = {d["id"]: d for d in source["doors"]}
        for door in doors:
            door.update(copy.deepcopy(geometry[door["id"]]))
        spawn_list = copy.deepcopy(source["entry_spawns"])
        profile = source["camera"]["profile"]
        local_sections = []
        for i, s in enumerate(sections):
            item = copy.deepcopy(s)
            entry_d = next((d for d in doors if d["section"] == s["id"]), None)
            if s.get("kind") == "entrance_preview" and entry_d:
                anchor = entry_d["landing_contract"]["safe_standing_position_world_units"]
            elif s["id"] == "main":
                anchor = [snap(w * .5), snap(h * .65)]
            else:
                anchor = [snap(w * (.3 + .12 * (i % 4))), snap(h * (.3 + .1 * (i % 3)))]
            item["construction_anchor_world_units"] = anchor
            item["construction_geometry_status"] = "分区锚点工作值；精确可走多边形与隔断形状在该房灰盒实现。"
            item["camera_zone_ref"] = None  # Gameplay sections do not imply camera zones.
            item["interface_refs"] = [d["id"] for d in doors if d["section"] == s["id"]]
            local_sections.append(item)
        section_lookup = {s["id"]: s for s in local_sections}
        internal_routes = copy.deepcopy(room.get("internal_routes", []))
        for route in internal_routes:
            req = terms(route.get("requires"))
            route["runtime_invisible_ability_check_forbidden"] = True
            route["construction_fixture_types"] = [
                {"H": "hook_anchor_gap", "W": "climbable_wall_rise", "D": "double_jump_reach", "Q": "phase_light_curtain"}[a]
                for a in ("H", "W", "D", "Q") if a in req
            ]
            route["mechanism_policy"] = "房内环境真实实现requires，数据只用于规划/模拟。非能力剧情条件使用可见机关/道具门。"
            route["checkpoint_entry_section"] = route["from_section"]
            route["reset_after_terrain_failure"] = "return_to_actual_attempt_entry; default1HP, tagged_heavy2HP; HP0 goes to death"
            if "Q" in req:
                route["q_fixture_contract"] = {
                    "barrier": "light_curtain_only", "solid_hazards_remain_damaging": True,
                    "weapon_for_pass_test": "initial_gun", "cooldown_seconds": 2.0,
                    "multiple_q_requires": "真实落脚且自然经过2秒或可安全等待；切房不清CD。",
                    "physics_status": "待Godot实测；能力图通过不代表光幕厚度/2秒节奏已验收。",
                }

        interactions = []
        for i, a in enumerate(by_room.get(rid, [])):
            sid = a.get("section_id", a.get("section", "main"))
            assert sid in section_ids, (rid, a["id"], sid, section_ids)
            pos = section_lookup[sid]["construction_anchor_world_units"]
            interactions.append({
                "action_ref": a["id"], "type": a.get("type"), "section": sid,
                "implementation_host_ref": "interaction:" + a["id"], "one_host_per_action_id": True,
                "reward_ref": a.get("reward_ref", a.get("reward_id")), "requires": dnf(a.get("requires")),
                "grants": a.get("grants", []), "inventory_grants": a.get("inventory_grants", {}),
                "consumes": a.get("consumes", {}), "inventory_transfer": a.get("inventory_transfer"),
                "receipt_id": a.get("receipt_id"), "repeat": a.get("repeat", False),
                "persistent": a.get("persistent", True),
                "trigger": {"tutorial":"accepted_player_action", "automatic_landmark":"actual_arrival_with_requirements", "boss_defeat":"actual_boss_victory"}.get(a.get("type"), "explicit_player_interaction"),
                "arriving_does_not_grant": a.get("type") != "automatic_landmark",
                "physical_access": "实际到达绑定分区并满足条件。" if a.get("type") == "automatic_landmark" else "按action类型完成真实操作/战斗或接触交互点；加载房间不能代替。",
                "position_candidate_world_units": [int(clamp(pos[0] + (i % 3 - 1) * 48, 64, w - 64)), pos[1]],
                "atomic_save": "验证资格/库存→唯一收据→消耗与发放同事务→保存；死亡和重载不重复发奖。",
                "placement_status": "可交互占位；精确站位随本分区地形细化。",
            })
        npcs = []
        for i, n in enumerate(npc_by_room.get(rid, [])):
            sid = n.get("section_id", "main")
            npcs.append({"npc_ref": n["id"], "name": n.get("name", n.get("display_name", n["id"])), "section": sid,
                         "availability": n.get("availability", {}), "services": n.get("services", []),
                         "stock_refs": [s["id"] for s in canonical.get("shop_inventory", []) if s.get("merchant_id", s.get("npc_id")) == n["id"]],
                         "position_candidate_world_units": [snap(w * (.32 + .24 * i)), snap(h * .72)],
                         "explicit_interaction": True, "service_does_not_rest": True})
        rest_sid = room.get("rest_section_id", "main")
        rift_sid = room.get("rift_section_id", "main")
        rest = {"enabled": bool(room.get("rest_point")), "id": "rest:" + rid if room.get("rest_point") else None,
                "section": rest_sid, "position_candidate_world_units": section_lookup[rest_sid]["construction_anchor_world_units"] if room.get("rest_point") else None,
                "activation": "explicit_rest_interaction", "set_death_respawn": True, "heal_hp": True,
                "reset_regular_enemies": True, "advance_rest_cycle": True,
                "allow_loadout_change_after_rest": True, "services_and_rifts_are_not_rest": True,
                "loadout_action_refs": source.get("rest", {}).get("loadout_action_refs", [])}
        rift_action = next((a for a in by_room.get(rid, []) if a["id"].startswith("activate_rift_")), None)
        rift = {"enabled": bool(room.get("rift_machine")), "action_ref": rift_action["id"] if rift_action else None,
                "section": rift_action.get("section_id", rift_sid) if rift_action else rift_sid,
                "requires": dnf(rift_action.get("requires")) if rift_action else [[]],
                "destination_must_be_actually_activated": True, "transition_type": "interact_transport",
                "arrival_spawn": "rift_spawn:" + rid if room.get("rift_machine") else None,
                "position_candidate_world_units": [snap(w * .72), snap(h * .72)] if room.get("rift_machine") else None,
                "explicit_dialogue_style_interaction": True, "teleport_does_not_rest_or_change_loadout": True,
                "q_cooldown_reset": False}
        shortcuts = []
        for s in canonical.get("shortcuts", []):
            aid = s.get("open_action_id", s.get("action_id", s.get("open_action", s.get("action_ref"))))
            # The canonical action is the single physical switch host.
            if not aid:
                aid = next((a["id"] for a in by_room.get(rid, []) if a.get("type") == "shortcut" and s["id"].replace("-", "_") in a["id"]), None)
            a = actions.get(aid, {})
            s_room = a.get("room_id", s.get("open_from_room", s.get("operator_room", s.get("switch_room"))))
            if s_room != rid:
                continue
            shortcuts.append({"shortcut_ref": s["id"], "action_ref": aid,
                              "section": a.get("section_id", "main"), "requires": dnf(a.get("requires")),
                              "after_open_requires": dnf(edge_by_id.get(s["id"], {}).get("requires", s.get("requires_after_open"))),
                              "one_physical_switch_host": True, "no_duplicate_near_side_switch": True,
                              "rest_or_death_does_not_close": True})
        challenge_entries = []
        for cp in source.get("terrain_failure", {}).get("challenge_entries", []):
            cp = copy.deepcopy(cp)
            approach = next((d for d in doors if d["id"] == cp.get("approach_door")), None)
            cp["section"] = approach["section"] if approach else "main"
            cp["entry_side"] = cp["section"]
            cp["damage_hp_default"] = 1
            cp["heavy_terrain_damage_hp"] = 2
            cp["q_cooldown_reset"] = False
            challenge_entries.append(cp)
        actual_boss_req = construction["boss_first_visit"].get(boss["id"]) if boss else None
        first = {
            "minimum_legal_state_dnf": actual_boss_req,
            "minimum_legal_state_scope": "原Boss声明的可首访战斗配置，入口预览可更早；完整可达性以现行分区模拟为准。" if boss else "普通房不另造第二套能力门：合法抵达以canonical分区路线定义；下列是局部条件和已回放的具体首访样本。",
            "local_main_access_conditions_dnf": derive_local_main_conditions(room),
            "recommended_attack_range": BOSS_WORK[boss["id"]][5] if boss else REGION_DIFFICULTY[room["region"]]["attack"],
            "recommended_attack_is_not_a_gate": True,
            "route_first_subject_visit_samples": samples.get(rid, []),
            "samples_are_exhaustive_minimum_proof": False,
            "default_weapon_supported": "gun",
            "minimum_observed_ability_sets": sorted({tuple(row.get("abilities", [])) for row in samples.get(rid, [])}),
        }
        entry = {
            "room_id": rid, "region": room["region"], "name": room["name"],
            "scene_ref": source["scene_ref"], "scene_ref_status": "planned_new_scene_path; not already implemented",
            "purpose": room.get("purpose"), "role": room.get("primary_role"), "role_zh": room.get("primary_role_zh"),
            "route_class": room.get("route_class"), "play_mode": room.get("play_mode"),
            "macro_anchor_ref": room.get("parent_anchor"), "exploration_guidance": room.get("exploration_guidance", []),
            "footprint_reference": {"source_shape": room.get("shape"), "source_polygon": room["polygon"], "source_aspect_ratio": round(room_aspect(room), 4),
                                    "use": "世界地图相对位置和形态意图；可调整场景局部形状，保留拓扑、门ID与分区绑定。"},
            "world_geometry": {"bounds_world_units": [0, 0, w, h], "shape_class": shape_class,
                               "outline_candidate_local": space["outline"] if source.get("implemented") else coarse_outline(room, extent),
                               "space_rects": space["rects"], "boundary": space["boundary"],
                               "status": "authored_room_envelope" if source.get("implemented") else "adjustable_construction_candidate_not_physics_validated",
                               "rationale": rationale, "authoring_grid_world_units": 16,
                               "grid_is_convenience_not_ability_envelope": True,
                               "screen_reference": {"viewport_px": VIEWPORT, "working_view_world_units": WORKING_VIEW, "working_zoom": 1.6, "zoom_status": "正式基准；特殊场景仅显式配置"},
                               "collision_outline_status": "已施工房的实体外边界与地图共用space_rects并集，按实际门口切开；内部地形仍由手工场景拥有。" if source.get("implemented") else "未施工粗轮廓不是碰撞数据。",
                               "required_reserved_areas": [],
                               "usable_envelope_contract": "实际可用包络必须包含required_reserved_areas的全部矩形并按其collision_intent区分净空与实地；候选多边形不包含这些区域时扩展/重画轮廓，以真实内部前廊连接所属分区，不能瞬移或跨过能力阻隔。",
                               "minimum_scale_invariants": "保持当前玩家24×36碰撞体与运动参数；若读取仓库已有改动，以实际控制器校准并同步全部房，不逐房偷偷改玩家。"},
            "size_budget": {"candidate_extent_world_units": extent, "candidate_extent_screens_at_working_zoom": [round(w / 800, 3), round(h / 450, 3)],
                            "status": "世界单位工作包络；像素比例/镜头与地形仍需首批样房验证，非世界图等比像素。"},
            "camera": copy.deepcopy(source["camera"]),
            "difficulty": main_difficulty(room, boss), "first_visit": first,
            "sections": local_sections, "internal_routes": internal_routes,
            "doors": doors, "entry_spawns": spawn_list,
            "terrain_failure": {"damage_hp_default": 1, "heavy_terrain_damage_hp": 2, "heavy_example": "lava",
                                "challenge_entries": challenge_entries, "default_anchor": "本次实际进入方向的挑战入口；没有分段时为本入口安全台。",
                                "on_hp_zero": "last_actual_rest_point; tutorial_initial_spawn_before_first_rest",
                                "hp_restore": False, "enemy_reset": False, "rest_cycle_reset": False, "q_cooldown_reset": False,
                                "single_damage_transaction": True, "per_approach_independent": True,
                                "intentional_downward_door_is_not_terrain_failure": True},
            "rest": rest, "rift": rift, "npcs": npcs,
            "shop_stock_refs": source.get("shop_stock_refs", []), "reward_refs": room.get("reward_ids", []),
            "clock_action_refs": room.get("clock_actions", []), "interactions": interactions,
            "shortcut_operators": shortcuts,
            "remembered_gates": memory_by_room.get(rid, []),
            "save_scope": copy.deepcopy(source.get("save_scope", {})),
            "acceptance": [
                "门ID/目标spawn/分区与canonical一致；普通门无H/W/D/Q资格检查。",
                "预览入口只进入绑定分区，未越过房内环境路线不能调用深部交互或使用其他出口。",
                "左右步行、上跳实际侧台落地、下落安全台按成对接口成立；接续廊不暗中跨过能力障碍。",
                "分区内挑战按当前控制器施工；声明能力约束不产生运行时无形墙。",
                "地形失败1/2HP、HP0死亡、Q2秒与实体危险过滤一致；普通反冲和射速不受Q冷却限制。",
                "唯一奖励/事件有唯一实体与事务保存；休息、交通、对话与换房的状态边界分开。",
                "镜头相机区和落脚在实机可读；候选尺寸与这些检查未执行前不标记房间完成。",
                "required_reserved_areas全部纳入实际可用包络；净空、真实支撑和竞技区按各自意图施工，不能直接把地图粗轮廓作为封闭碰撞边界。",
            ],
        }
        auxiliary = []
        if rest["enabled"]:
            auxiliary.append({"id": "rest_spawn:" + rid, "kind": "rest_respawn", "section": rest_sid,
                              "position_candidate_world_units": rest["position_candidate_world_units"], "only_after_actual_rest": True})
        if rift["enabled"]:
            auxiliary.append({"id": rift["arrival_spawn"], "kind": "rift_arrival", "section": rift["section"],
                              "position_candidate_world_units": rift["position_candidate_world_units"], "arrival_is_not_rest": True})
        if rid == "P-R03":
            auxiliary.append({"id": "tutorial_start:P-R03", "kind": "campaign_start", "section": "main", "position_candidate_world_units": [144, h - 128]})
        entry["auxiliary_spawns"] = auxiliary
        if boss:
            bwork = BOSS_WORK[boss["id"]]
            bw, bh, vw, _, _, _, archetype, constraint = bwork
            b = copy.deepcopy(source.get("boss", {}))
            b["encounter_requirements"] = dnf(actions.get(boss.get("defeat_action"), {}).get("requires"))
            b["encounter_section"] = actions.get(boss.get("defeat_action"), {}).get("section_id", "main")
            b["entry_flow"] = ["进入来向安全区并看见场地", "按房内路线真实到达战斗触发线", "跨线开战后关闭战闸", "实际胜利写永久Boss结果", "战后交互领取唯一奖励或修钟"]
            if b.get("retry_plan"):
                b["retry_plan"]["qualification_scope"] = "旧房间数作定位参考；现行分区和实机秒数重新验收。"
                b["retry_plan"]["retry_path_contract"] = "已实际休息点至战前触发线有安全熟路；物品门按状态，能力由真实已掌握路线通行。"
            entry["boss"] = b
            entry["boss_arena"] = {
                "boss_id": boss["id"], "name": boss.get("name", boss.get("working_name")),
                "archetype": archetype, "combat_bounds_world_units": [320, 288, bw, bh],
                "combat_bounds_exclude": ["entry_foyers", "post_victory_reward_area", "transport_or_rest_niches"],
                "working_view_world_units": [vw, round(vw * 9 / 16, 3)],
                "working_camera_zoom": round(1280 / vw, 5), "camera_profile": profile,
                "status": "encounter_specific_candidate_not_measured_or_HK_pixel_copy",
                "first_visit_loadout": first,
                "mechanic_constraints": constraint,
                "safe_attack_window_shots": 2, "greedy_attack_window_shots": 3,
                "attack_packet": "ordinary_gun=B; triple_total=1.5B; laser_one_shot_total=1.5B",
                "hp_status": "由首访攻击档与目标命中数形成独立Boss数据；不在结构房尺寸里硬编码最终血量。",
                "battle_occupants_and_timing_status": "敌人具体站位、招式、2枪窗口与平台细节在该场灰盒中实现验证。",
            }
        if rid == "G-R01":
            entry["service_specific_contract"] = "武器匠在本房；工房放行来自G-R03，见匠交互才获得smith状态；首次进入熔火保留该剧情联锁。"
        if boss and source.get("boss_arena_override"):
            entry["boss_arena"].update(copy.deepcopy(source["boss_arena_override"]))
        entry["world_geometry"]["required_reserved_areas"] = required_reserved_areas(entry)
        result_rooms.append(entry)

    contracts = {
        "schema": "gunman-rush.room-graybox-contracts.v07",
        "status": "可开始全世界结构灰盒的施工合同；候选尺寸、镜头、动作与战斗尚需实机校准。",
        "canonical_source": "config/world/world.json",
        "canonical_normalized_json_sha256": hashlib.sha256(json.dumps(canonical, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()).hexdigest(),
        "canonical_normalized_json_hash_method": "json_utf8_ensure_ascii_false_sort_keys_separators_no_whitespace",
        "authorities": {"progression_and_permanence": "config/world/world.json", "scene_interface_and_working_geometry": "config/world/construction.json", "gameplay_rules": "docs/bible/", "physical_passability": "actual_Godot_graybox_validation_not_abstract_graph"},
        "coordinate_and_scale_contract": {
            "scene_units": "Godot world units; no global 128-pixel Block requirement",
            "world_map_is_not_uniform_scene_pixel_scale": True,
            "world_geometry_values_are_adjustable_working_values": True,
            "current_player_baseline": {"collision_world_units": [24, 36], "ground_speed_world_units_per_second": 260, "viewport_px": VIEWPORT,
                                        "reference": "main基础参数2026-11-06审阅；施工从仓库实际控制器读取，不在房间内重定义。"},
            "ordinary_camera_zoom": {"config": "config/world/player.json:camera.zoom", "policy": "统一基准，显式例外，不自动适配房间大小。"},
            "door_orientation_authority": "本合同direction/target_direction成对；地图接廊端点为示意，归一转向由connector_owner_room承担。",
            "camera_room_boundary_policy": "仅当前房可见；多边形使用多个相机区，不机械套整房外接矩形。",
        },
        "initial_state": {"room": "P-R03", "section": "main", "spawn": "tutorial_start:P-R03", "tokens": ["gun"], "first_regular_rest": "P-R01"},
        "requirements_grammar": "OR of AND groups. H/W/D/Q belong only to authored internal_routes; door requirements contain actual items/story/operations.",
        "global_runtime_contract": {
            "physics": "ordinary_world_uses_existing_controller_parameters",
            "regional_time_theme": "art_music_enemies_environment_not_player_physics",
            "terrain_damage": {"ordinary": 1, "tagged_heavy": 2, "heavy_example": "lava", "hp_zero_precedes_retry": True},
            "Q": {"cooldown_seconds": 2.0, "cooldown_starts_at": "actual_Q_activation", "requires_landing_qualification": True,
                  "protects_against": ["enemy_contact_and_attacks", "phase_light_curtains"],
                  "does_not_protect_against": ["thorns", "gears", "lava", "poison_water", "solid_geometry"],
                  "does_not_delay": ["ordinary_shooting", "ordinary_recoil"],
                  "reset_cooldown_on_transition": False, "reset_cooldown_on_terrain_retry": False},
            "transport": {"trigger": "explicit_interaction", "arrival_is_not_rest": True},
            "clock_repair": {"primary_change": ["visuals", "BGM", "ambient_sound", "time_theme"], "route_change": ["permanent_shortcuts", "easier_old_routes"], "dedicated_challenge_layout_unchanged": True},
        },
        "global_save_contract": {
            **copy.deepcopy(canonical.get("graybox_global", {})),
            "loadout_save_policy": "保存最终负荷与装备集合；换装边界与环境装备重新装回规则以本节loadout为准。",
        },
        "region_difficulty_catalog": REGION_DIFFICULTY,
        "difficulty_scale": {"C": "战斗压力0安全至5顶级挑战", "T": "平台压力0安全至5独立高手挑战", "ratings_are": "第一轮制作上限与相对节奏，不是测量分数", "ordinary_route_avoids_T5": True},
        "camera_profile_catalog": CAMERA_PROFILES,
        "build_phases": [
            "创建共用房间基础场景、三种普通转场和交互式交通；保留玩家运动参数。",
            "首批样房校准镜头、门台、地形1/2HP与Q2秒/危险过滤，冻结可复用接口。",
            "按本合同创建全部当前房间结构，填入真实门与分区、能力挑战占位、休息/NPC/Boss/奖励事件占位；物理能力锁不能退化为隐藏布尔门。",
            "沿A/B/C/D路线验证本体探索、交互与永久存档，记录实际失败/重试成本。",
            "逐房完善具体平台、敌人、Boss动作、奖励袋、美术与声音；不因打磨重排永久ID。",
        ],
        "rooms": result_rooms,
        "global_runtime_actions": [copy.deepcopy(a) for a in actions.values() if a.get("room_id") == "@current"],
        "global_runtime_action_contract": "换装遵守既有休息区权限；交通/普通安全台不暗开新换装规则。卸下可重新装备，当前装备与拥有状态分开。",
        "door_coordinate_audit": audit,
        "validation_scope": {"schema_and_references": True, "section_route_simulation": "由simulation单独生成报告", "physics_or_jump_envelopes": False, "camera_visibility_playtest": False, "combat_balance": False, "human_wayfinding_or_memory": False},
        "shop_policy": copy.deepcopy(construction.get("shop_policy", {})),
        "all_unique_reward_registry_source": "config/world/world.json",
    }
    return contracts


def audit_contracts(data, canonical):
    rooms = {r["room_id"]: r for r in data["rooms"]}
    doors = {d["id"]: d for r in data["rooms"] for d in r["doors"]}
    spawns = {s["id"] for r in data["rooms"] for s in r["entry_spawns"]}
    issues = []
    for rid, r in rooms.items():
        sec = {s["id"] for s in r["sections"]}
        bx, by, bw, bh = r["world_geometry"]["bounds_world_units"]
        reserved = r["world_geometry"]["required_reserved_areas"]
        space = {"rects": r["world_geometry"]["space_rects"]}
        if not reserved:
            issues.append({"kind": "missing_reserved_areas", "room": rid})
        reserved_ids = {a["id"] for a in reserved}
        if len(reserved_ids) != len(reserved):
            issues.append({"kind": "duplicate_reserved_area", "room": rid})
        for area in reserved:
            x, y, w, h = area["rect_world_units"]
            if not (w > 0 and h > 0 and x >= bx and y >= by and x + w <= bx + bw and y + h <= by + bh):
                issues.append({"kind": "reserved_area_outside_outer_bounds", "room": rid, "area": area["id"], "rect": area["rect_world_units"]})
            if r["world_geometry"]["status"] == "authored_room_envelope" and not contains_rect(space, [x,y,w,h]):
                issues.append({"kind":"reserved_area_outside_physical_space", "room":r["room_id"], "area":area["id"]})
            if area["section"] not in sec:
                issues.append({"kind": "reserved_area_invalid_section", "room": rid, "area": area["id"]})
            if r.get("boss_arena") and area.get("door_ref"):
                ax, ay, aw, ah = r["boss_arena"]["combat_bounds_world_units"]
                if min(x + w, ax + aw) > max(x, ax) and min(y + h, ay + ah) > max(y, ay):
                    issues.append({"kind": "boss_entry_reserved_area_overlaps_combat", "room": rid, "area": area["id"]})
        for d in r["doors"]:
            pair = doors.get(d["target_door_id"])
            if not pair or pair["target_door_id"] != d["id"]:
                issues.append({"kind": "unpaired_door", "id": d["id"]})
            if pair and pair["direction"] != OPPOSITE[d["direction"]]:
                issues.append({"kind": "nonopposite_door", "id": d["id"]})
            if d["target_spawn"] not in spawns:
                issues.append({"kind": "missing_spawn", "id": d["id"]})
            if d["section"] not in sec or d["target_section"] not in {s["id"] for s in rooms[d["target_room"]]["sections"]}:
                issues.append({"kind": "invalid_door_section", "id": d["id"]})
            if terms(d["requires"]) & ABILITIES:
                issues.append({"kind": "ability_gate_on_door", "id": d["id"]})
            if not d.get("required_reserved_area_refs") or any(ref not in reserved_ids for ref in d["required_reserved_area_refs"]):
                issues.append({"kind": "door_missing_reserved_area_ref", "id": d["id"]})
        for a in r["interactions"]:
            if a["section"] not in sec:
                issues.append({"kind": "invalid_action_section", "id": a["action_ref"]})
            if terms(a["requires"]) & ABILITIES:
                issues.append({"kind": "hidden_ability_action_gate", "id": a["action_ref"]})
        for route in r["internal_routes"]:
            if route["from_section"] not in sec or route["to_section"] not in sec:
                issues.append({"kind": "invalid_internal_route", "id": route["id"]})
        if r["camera"]["profile"] not in CAMERA_PROFILES:
            issues.append({"kind": "unknown_camera", "room": rid})
        if not all(0 <= r["difficulty"][k] <= 5 for k in ["main_C", "main_T"]):
            issues.append({"kind": "invalid_difficulty", "room": rid})
        for key in ["rest", "rift"]:
            if r[key]["enabled"] and r[key]["section"] not in sec:
                issues.append({"kind": "invalid_service_section", "room": rid, "service": key})
        for n in r["npcs"]:
            if n["section"] not in sec:
                issues.append({"kind": "invalid_npc_section", "room": rid, "npc": n["npc_ref"]})
            if not n.get("name"):
                issues.append({"kind": "missing_npc_display_name", "room": rid, "npc": n["npc_ref"]})
        for s in r["shortcut_operators"]:
            if s.get("action_ref") not in {a["action_ref"] for a in r["interactions"]}:
                issues.append({"kind": "shortcut_without_single_bound_host", "room": rid, "shortcut": s["shortcut_ref"]})
            if s.get("section") not in sec:
                issues.append({"kind": "invalid_shortcut_section", "room": rid, "shortcut": s["shortcut_ref"]})
    canonical_actions = {a["id"] for a in canonical.get("actions", []) if a.get("room_id") != "@current"}
    host_refs = [a["action_ref"] for r in rooms.values() for a in r["interactions"]]
    data["counts"] = {
        "rooms": len(rooms), "connections": len(canonical["connections"]), "doors": len(doors),
        "entry_spawns": len(spawns), "sections": sum(len(r["sections"]) for r in rooms.values()),
        "internal_routes": sum(len(r["internal_routes"]) for r in rooms.values()),
        "rest_points": sum(r["rest"]["enabled"] for r in rooms.values()),
        "rifts": sum(r["rift"]["enabled"] for r in rooms.values()),
        "boss_arenas": sum("boss_arena" in r for r in rooms.values()),
        "npc_placements": sum(len(r["npcs"]) for r in rooms.values()),
        "actions": len(host_refs) + len(data["global_runtime_actions"]),
        "shortcut_operators": sum(len(r["shortcut_operators"]) for r in rooms.values()),
        "challenge_approach_entries": sum(len(r["terrain_failure"]["challenge_entries"]) for r in rooms.values()),
        "normalized_door_pairs": sum(a["normalization_required"] for a in data["door_coordinate_audit"]),
        "rooms_with_route_first_visit_samples": sum(bool(r["first_visit"]["route_first_subject_visit_samples"]) for r in rooms.values()),
        "required_reserved_areas": sum(len(r["world_geometry"]["required_reserved_areas"]) for r in rooms.values()),
    }
    validation = {
        "room_count_matches_source": len(rooms) == len(canonical["rooms"]),
        "room_ids_match_canonical": set(rooms) == {r["id"] for r in canonical["rooms"]},
        "two_doors_per_connection": len(doors) == 2 * len(canonical["connections"]),
        "unique_entry_spawn_ids": len(spawns) == sum(len(r["entry_spawns"]) for r in rooms.values()),
        "all_interaction_hosts_once": len(host_refs) == len(set(host_refs)) and set(host_refs) == canonical_actions,
        "all_rest_points_match": data["counts"]["rest_points"] == sum(bool(r.get("rest_point")) for r in canonical["rooms"]),
        "all_rifts_match": data["counts"]["rifts"] == sum(bool(r.get("rift_machine")) for r in canonical["rooms"]),
        "all_bosses_have_distinct_design_briefs": data["counts"]["boss_arenas"] == 22,
        "all_shortcut_operators_bound_once": data["counts"]["shortcut_operators"] == len(canonical.get("shortcuts", [])),
        "npc_stock_refs_match_registry": sorted(x for r in rooms.values() for n in r["npcs"] for x in n["stock_refs"]) == sorted(s["id"] for s in canonical.get("shop_inventory", [])),
        "nonuniform_boss_working_envelopes": len({tuple(r["boss_arena"]["combat_bounds_world_units"][2:]) for r in rooms.values() if "boss_arena" in r}) > 10,
        "service_rooms_pressure_zero": all(r["difficulty"]["main_C"] == 0 and r["difficulty"]["main_T"] == 0 for r in rooms.values() if r["role"] == "rest_or_service"),
        "all_interfaces_sections_actions_valid": not issues,
        "ordinary_routes_have_no_T5": all(r["difficulty"]["main_T"] < 5 for r in rooms.values()),
        "all_reserved_areas_inside_outer_bounds": not any(i["kind"] in {"reserved_area_outside_outer_bounds", "missing_reserved_areas", "duplicate_reserved_area", "reserved_area_invalid_section", "door_missing_reserved_area_ref"} for i in issues),
        "boss_entry_reservations_outside_combat": not any(i["kind"] == "boss_entry_reserved_area_overlaps_combat" for i in issues),
        "first_visit_samples_match_canonical_version": not data["first_visit_replay_source"]["file_sha256"] or data["first_visit_replay_source"]["canonical_sha256"] == data["canonical_sha256"],
    }
    data["validation"] = validation
    data["validation_issues"] = issues
    return {"schema": "gunman-rush.contract-audit.v04", "checks": validation, "passed": all(validation.values()), "issues": issues,
            "counts": data["counts"], "limits": "只验证合同字段、引用、方向成对、预留矩形在外框内及Boss入口/竞技区分离；不证明实际碰撞、跳跃、镜头、难度或人类回忆。"}


def compile_contracts(world_path, construction_path, replay_path):
    world = read_json(world_path)
    contracts = build(world, read_json(construction_path), replay_path)
    contracts["canonical_sha256"] = hashlib.sha256(world_path.read_bytes()).hexdigest()
    contracts["canonical_hash_method"] = "raw_file_bytes_sha256"
    replay_source = read_json(replay_path) if replay_path.exists() else {}
    contracts["first_visit_replay_source"] = {
        "path": "../simulation/route-replays-v04.json",
        "canonical_sha256": replay_source.get("source_world_sha256"),
        "file_sha256": hashlib.sha256(replay_path.read_bytes()).hexdigest() if replay_path.exists() else None,
        "included_routes": "A/B/C实际通关示例；D工程回归遍历不作为自然首访样本。",
    }
    report = audit_contracts(contracts, world)
    return contracts, report
