"""Game-owned authoring metadata for the mobile review workbench.

Behavior IDs, node scripts and resource defaults are exported by Godot from the
real gameplay registry. This file labels their existing placement fields; it
does not implement gameplay, dialogue or a second level format.
"""
from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path


ENEMY_LABELS = {
    "patrol": "巡逻体", "charger": "冲锋体", "diver": "俯冲体", "hopper": "跃击体",
    "sentry": "单发哨兵", "fan_sentry": "扇射哨兵", "root_bell": "根铃",
    "forest_lantern": "铃囊萤", "forest_seed_sentry": "棘籽哨", "forest_bark_beetle": "树皮甲虫",
    "forest_swing_pod": "吊荚摆锚", "forest_thread_spider": "织棘蛛", "forest_crossbranch": "跨枝移动体",
    "forest_bible_weaver": "圣经织者",
}


def field(key, label, kind, **extra):
    return {"key": key, "label": label, "type": kind, **extra}


def component(component_id, label, category, storage, shape, default, fields=(), **extra):
    return {"id": component_id, "label": label, "category": category, "storage": storage,
            "shape": shape, "default": default, "fields": list(fields), "addable": True,
            "deletable": True, "anchor": "center", **extra}


def translated(*rows):
    return [{"key": key, "type": kind} for key, kind in rows]


def options(*rows):
    return [{"value": value, "label": label} for value, label in rows]


def descriptors(runtime):
    point = field("point", "位置", "point")
    bounds = field("bounds", "范围", "rect", min_size=1)
    identity = field("id", "稳定身份", "text", readonly=True)
    result = []
    for name, label, one_way in [("ground", "实心地形", False), ("one_way", "单向平台", True)]:
        result.append(component(name, label, "地形", "property_array", "rect", [0, 0, 256, 24 if one_way else 64],
                                field="platforms", kind="ground", identity="indexed", anchor="top_left", flags={"one_way": one_way}))
    for name, label, prop, kind, default in [
        ("hazard", "地形危险区", "hazards", "hazard", [0, 0, 160, 32]),
        ("climbable_wall", "实体墙", "climbable_walls", "climbable", [0, 0, 24, 256]),
    ]:
        result.append(component(name, label, "地形", "property_array", "rect", default,
                                field=prop, kind=kind, identity="indexed", anchor="top_left"))
    result.append(component("hook", "钩索锚点", "地形", "property_array", "point", [0, 0],
                            field="hook_points", kind="hook", identity="indexed", size=[24, 24]))
    result.append(component("enemy", "怪物", "怪物", "property_array", "point", {"id": "", "behavior": "patrol", "point": [0, 0]},
                            [identity, point, field("behavior", "怪物种类", "select", options_source="enemies"),
                             field("max_health", "生命值覆盖", "number", min=1, step=1, optional=True,
                                   help="留空使用该怪物正式配置的生命值。")],
                            field="enemy_placements", kind="enemy", identity="id", point_key="point", size=[28, 32],
                            translation_fields=translated(("point", "point")), help="行为与美术使用主游戏的真实物种。"))
    result.append(component("spikes", "荆棘尖刺", "危险", "property_array", "bounds",
                            {"id": "", "bounds": [0, 0, 160, 24], "facing": "up"},
                            [identity, bounds, field("facing", "朝向", "select", options=options(("up", "上"), ("down", "下"), ("left", "左"), ("right", "右")))],
                            field="spike_strips", kind="hazard", identity="id", rect_key="bounds", anchor="top_left",
                            translation_fields=translated(("bounds", "rect"))))
    result.append(component("gear", "轨道齿轮", "危险", "property_array", "point",
                            {"id": "", "point": [0, 0], "travel": [0, 160], "period": 4.8, "phase": 0},
                            [identity, point, field("travel", "轨道半程偏移", "point"),
                             field("period", "往返周期（秒）", "number", min=0.1, step=0.1),
                             field("phase", "起始相位", "number", min=0, max=1, step=0.05),
                             field("drive", "关联移动平台", "select", options_source="moving_platforms", optional=True)],
                            field="gear_obstacles", kind="hazard", identity="id", point_key="point", size=[68, 68],
                            translation_fields=translated(("point", "point")), help="危险半径由正式齿轮组件固定为 34。"))
    result.append(component("bell", "射击铃机关", "机关", "property_array", "point",
                            {"id": "", "bell": [0, 0], "gate": [128, -96, 32, 192], "open_seconds": 3.0},
                            [identity, field("bell", "铃的位置", "point"), field("gate", "门的位置和尺寸", "rect", min_size=1),
                             field("open_seconds", "开启秒数（0为保持）", "number", min=0, step=0.1),
                             field("access_bells", "其他触发铃", "points", optional=True),
                             field("carrier", "控制移动平台", "select", options_source="moving_platforms", optional=True)],
                            field="bell_mechanisms", kind="mechanism", identity="id", point_key="bell", size=[32, 48],
                            translation_fields=translated(("bell", "point"), ("gate", "rect"), ("access_bells", "points"))))
    result.append(component("environment", "环境区域", "危险", "property_array", "bounds",
                            {"id": "", "bounds": [0, 0, 256, 128], "mode": "water"},
                            [identity, bounds, field("mode", "环境类型", "select", options=options(
                                ("water", "水域"), ("thorns", "荆棘"), ("gas", "毒气"), ("dark", "黑暗"), ("phase_light", "相位光障")))],
                            field="environment_zones", kind="zone", identity="id", rect_key="bounds", anchor="top_left",
                            translation_fields=translated(("bounds", "rect"))))
    result.append(component("sign", "告示牌", "叙事", "property_array", "point", {"point": [0, 0], "text": "路标说明"},
                            [point, field("text", "告示文字", "text", multiline=True),
                             field("action_ref", "读取时提交已有动作", "select", options_source="action_refs", optional=True)],
                            field="signs", kind="sign", identity="indexed", point_key="point", anchor="foot", size=[40, 40],
                            translation_fields=translated(("point", "point"))))
    result.append(component("art", "场景装饰", "美术", "property_array", "point", {"asset": "barrel", "point": [0, 0], "layer": -2},
                            [point, field("asset", "美术素材", "select", options_source="art_assets"),
                             field("layer", "绘制层级", "number", step=1, min=-100, max=100),
                             field("sway", "随风摇动", "boolean", optional=True), field("light", "附带灯光", "boolean", optional=True),
                             field("fade_near", "靠近时淡出", "boolean", optional=True),
                             field("depth", "视差比例", "number", min=0.1, max=2, step=0.05, optional=True),
                             field("receipt", "完成动作后出现", "select", options_source="receipts", optional=True)],
                            field="art_placements", kind="art", identity="indexed", point_key="point", anchor="foot", size=[48, 48],
                            translation_fields=translated(("point", "point"))))
    result.append(component("support", "结构支柱", "美术", "property_array", "point", {"point": [0, 0], "support_height": 192},
                            [point, field("support_height", "支柱高度", "number", min=1, step=8)],
                            field="art_placements", kind="art", identity="indexed", point_key="point", anchor="foot", size=[24, 64],
                            match={"key": "support_height", "exists": True}, translation_fields=translated(("point", "point"))))
    for name, label, prop, category in [("retry_anchor", "挑战恢复区", "retry_anchors", "流程")]:
        fields = [bounds, field("point", "恢复落点", "point")]
        default = {"bounds": [0, 0, 256, 128], "point": [128, 64]}
        if name == "retry_anchor":
            default["section"] = "main"
            fields.append(field("section", "所属分区", "select", options_source="sections"))
        result.append(component(name, label, category, "property_array", "bounds", default, fields,
                                field=prop, kind="zone", identity="indexed", rect_key="bounds", anchor="top_left",
                                translation_fields=translated(("bounds", "rect"), ("point", "point"))))
    result.append(component("section", "房内分区", "流程", "property_array", "bounds", {"id": "main", "bounds": [0, 0, 256, 128]},
                            [field("id", "正式分区", "select", options_source="sections"), bounds],
                            field="section_volumes", kind="zone", identity="id", rect_key="bounds", anchor="top_left",
                            translation_fields=translated(("bounds", "rect")), help="只使用该房间已登记的分区身份。"))
    for prop, label, category, addable in [("start_point", "房间默认起点", "流程", False),
                                         ("rest_point", "休息点", "流程", False), ("traveler_point", "旅人剧情落位", "叙事", False),
                                         ("reward_point", "Boss奖励落位", "流程", False), ("boss_position", "Boss落位", "流程", False),
                                         ("battle_entry_anchor", "战斗失败落点", "流程", False)]:
        result.append(component(prop, label, category, "property", "point", [0, 0], field=prop,
                                kind="anchor", identity="singleton", size=[24, 36], addable=addable, deletable=False,
                                help="微调现有落位；新增休息点、Boss或剧情职责在主游戏中完成。"))
    result.append(component("arena_bounds", "Boss战斗范围", "流程", "property", "rect", [0, 0, 512, 256],
                            field="arena_bounds", kind="zone", identity="singleton", anchor="top_left", addable=False, deletable=False,
                            allow_empty=True, help="没有Boss的房间使用空范围；只微调主游戏已有战斗场。"))

    position = field("position", "位置", "point")
    nodes = [
        ("moving_platform", "移动平台", "地形", "WorldMovingPlatform", "mechanism", [
            position, field("platform_size", "平台尺寸", "point", min=1), field("endpoint", "终点偏移", "point"),
            field("period", "往返周期（秒）", "number", min=0.1, step=0.1),
            field("phase_offset", "起始时间偏移", "number", step=0.1), field("one_way", "单向碰撞", "boolean"),
            field("route", "路线偏移点", "points"), field("endpoint_dwell", "端点停留（秒）", "number", min=0, step=0.1)]),
        ("npc", "已有NPC", "叙事", "WorldNpc", "mechanism", [position,
            field("npc_id", "正式人物", "select", options_source="npcs"), field("display_name", "展示名称", "text")]),
        ("interaction", "已有交互／收集物", "叙事", "WorldRoomInteraction", "mechanism", [position,
            field("action_id", "正式动作", "select", options_source="actions"), field("section_id", "所属分区", "select", options_source="sections"),
            field("label", "交互提示", "text"), field("visual", "表现素材", "select", options_source="interaction_visuals"),
            field("radius", "交互距离", "number", min=8, step=4)]),
        ("return_latch", "已有返程机关", "机关", "WorldReturnLatch", "mechanism", [position,
            field("action_id", "正式返程动作", "select", options_source="return_actions"), field("section_id", "所属分区", "select", options_source="sections"),
            field("label", "交互提示", "text"), field("visual", "表现素材", "select", options_source="interaction_visuals"),
            field("radius", "交互距离", "number", min=8, step=4), field("return_steps", "开启后的台阶", "rects"),
            field("closed_panels", "关闭时的挡板", "rects"), field("metal_hatch", "金属翻板表现", "boolean")]),
        ("flag_presentation", "钟状态表现", "叙事", "WorldFlagPresentation", "mechanism", [position,
            field("flag", "读取正式状态", "select", options_source="flags")]),
    ]
    for name, label, category, node_type, kind, fields in nodes:
        if node_type not in runtime["node_types"]:
            raise ValueError("Editor descriptor has no registered codec node: " + node_type)
        if any(f["key"] not in runtime["node_fields"][node_type] for f in fields):
            raise ValueError("Editor field is not admitted by codec: " + node_type)
        default = copy.deepcopy(runtime["node_defaults"][node_type])
        row = component(name, label, category, "node", "node", default, fields, node_type=node_type,
                        kind=kind, identity="node", point_key="position", size=[28, 40],
                        translation_fields=translated(("position", "point")))
        if node_type == "WorldMovingPlatform": row["size_key"] = "platform_size"
        if node_type in ["WorldNpc", "WorldRoomInteraction", "WorldReturnLatch"]:
            source = "npcs" if node_type == "WorldNpc" else "return_actions" if node_type == "WorldReturnLatch" else "actions"
            row["binding"] = {"field": "npc_id" if source == "npcs" else "action_id", "options_source": source,
                              "room_restricted": True, "unique": True}
        result.append(row)
    for row in result:
        if row.get("field") and row["field"] not in runtime["room_fields"]:
            raise ValueError("Editor descriptor has no runtime room field: " + row["field"])
    return result


def make_catalog(root: Path, scenes: dict, world: dict, rooms: dict, baseline: str) -> dict:
    from build import local_returns

    runtime = scenes.get("catalog_runtime")
    if not isinstance(runtime, dict) or not runtime.get("enemies"):
        raise ValueError("Scene export lacks live gameplay catalog; re-export with the current workbench_scene_io.gd")
    enemies = copy.deepcopy(runtime["enemies"])
    for row in enemies:
        row.update(label=ENEMY_LABELS.get(row["id"], row["id"]), value=row["id"])
    actions = [copy.deepcopy(a) for a in world["actions"] if a["room_id"] in rooms]
    returns = [copy.deepcopy(a) for a in actions if a.get("type") == "local_return"]
    returns += local_returns(root / "config/world", set(rooms))
    def authored_defaults(key, value):
        hosts = [node for room in rooms.values() for node in room.get("nodes", []) if node.get("properties", {}).get(key) == value]
        if len(hosts) != 1:
            return {}
        return {name: copy.deepcopy(item) for name, item in hosts[0]["properties"].items() if name != "position"}
    def action_option(a):
        defaults = authored_defaults("action_id", a["id"])
        return {"value": a["id"], "label": a.get("description", a["id"]), "room_id": a["room_id"],
                "section_id": a.get("section_id", "main"), "type": a["type"], "unique": True,
                "defaults": defaults, "addable": bool(defaults)}
    authored_interactions = {node["properties"]["action_id"] for room in rooms.values() for node in room.get("nodes", [])
                             if node["type"] == "WorldRoomInteraction" and node.get("properties", {}).get("action_id")}
    # Existing switch/station actions predate the optional interaction_required
    # field. Their actual authored host is authoritative evidence of support.
    action_options = [action_option(a) for a in actions if a.get("interaction_required") or a["id"] in authored_interactions]
    action_refs = [{"value": a["id"], "label": a.get("description", a["id"]), "room_id": a["room_id"],
                    "section_id": a.get("section_id", "main")} for a in actions]
    receipts = {a["id"]: a.get("description", a["id"]) for a in world["actions"] + returns}
    for chapter in world.get("traveler_story", {}).get("chapters", []):
        if chapter.get("receipt_id"):
            receipts[chapter["receipt_id"]] = "阿栖 · " + chapter.get("title", chapter["id"])
    npc_options = [{"value": n["id"], "label": n.get("display_name", n["id"]), "room_id": n["room_id"],
                    "section_id": n.get("section_id", "main"), "unique": True,
                    "addable": n.get("placement_policy") != "dynamic_single_instance",
                    "defaults": {"npc_id": n["id"], "display_name": n.get("display_name", n["id"]),
                                 **authored_defaults("npc_id", n["id"])}}
                   for n in world["npcs"] if n["room_id"] in rooms]
    props = json.loads((root / "assets/plains_v07/manifest.json").read_text())["props"]
    pixels = json.loads((root / "art/world-art-v2/assets/pixel/manifest.json").read_text())["sprites"]
    authored_assets = {row["asset"] for room in rooms.values() for row in room["properties"].get("art_placements", []) if "asset" in row}
    missing_assets = authored_assets - props.keys() - pixels.keys()
    if missing_assets:
        raise ValueError("Authored art has no game manifest entry: " + ", ".join(sorted(missing_assets)))
    art = [{"value": key, "label": row.get("label", key), "size": row["size"], "source": row["image"]}
           for key, row in props.items()]
    art += [{"value": key, "label": row.get("label", key), "size": [row["w"], row["h"]],
             "source": "art/world-art-v2/" + row["file"]} for key, row in pixels.items()
            if (key.startswith(("plains_", "windchime_plains_", "gear_city_")) or key in authored_assets) and key not in props]
    interactions = json.loads((root / "assets/plains_v07/manifest.json").read_text())
    # Animated interactions use the clip registry; the chest host uses UnderworldObjects.
    visual_rows = dict(interactions.get("assets", interactions.get("animations", {})))
    visual_rows["chest"] = {"renderer": "WorldRoomInteraction / UnderworldObjects"}
    if not visual_rows:
        raise ValueError("Unknown world interaction manifest shape")
    flags = sorted({str(flag) for a in actions + returns for flag in a.get("grants", [])})
    sections = [{"value": str(section["id"]), "label": str(section["id"]), "room_id": room_id}
                for room_id, room in rooms.items() for section in room.get("sections", [])]
    for room_id, room in rooms.items():
        ids = {"main", *(str(x.get("id", "main")) for x in room["properties"].get("section_volumes", []))}
        ids.update(a.get("section_id", "main") for a in actions + returns if a["room_id"] == room_id)
        for section_id in sorted(ids):
            if not any(x["room_id"] == room_id and x["value"] == section_id for x in sections):
                sections.append({"value": section_id, "label": section_id, "room_id": room_id})
    source_files = ["tools/world/workbench_catalog.py", "tools/world/workbench_scene_io.gd",
                    "game/world/levels/world_room_draft.gd", "game/world/levels/fixed_world_room.gd",
                    "game/enemies/enemy_behavior_registry.gd"]
    source_files += [row["definition"].removeprefix("res://") for row in enemies]
    source_files += [path.removeprefix("res://") for path in runtime["node_scripts"].values()]
    source_files += ["game/enemies/enemy_factory.gd", "assets/plains_v07/manifest.json",
                     "art/world-art-v2/assets/pixel/manifest.json"]
    sources = {path: hashlib.sha256((root / path).read_bytes()).hexdigest() for path in source_files}
    result = {"schema": 1, "source_revision": baseline, "source_files": sources,
              "node_types": runtime["node_types"], "node_fields": runtime["node_fields"],
              "room_fields": runtime["room_fields"], "indexed_fields": runtime["indexed_fields"],
              "components": descriptors(runtime), "enemies": enemies,
              "options": {"enemies": enemies, "npcs": npc_options, "actions": action_options,
                          "action_refs": action_refs, "receipts": [{"value": k, "label": v} for k, v in sorted(receipts.items())],
                          "return_actions": [action_option(a) for a in returns],
                          "flags": [{"value": value, "label": value} for value in flags], "sections": sections,
                          "art_assets": art, "interaction_visuals": [{"value": k, "label": k} for k in visual_rows]},
              "room_fields_editor": [field("arrival_text", "进房文字", "text", multiline=True),
                                     field("art_profile", "房间材质", "select", options=options(
                                         ("meadow", "草原"), ("mill", "磨坊"), ("barn", "谷仓"), ("cellar", "地窖"), ("well", "井道"), ("secret", "隐室")))],
              "policy": {"game_owns_behavior": True, "slopes": False, "unknown_component": "reject",
                         "new_behavior_workflow": "主游戏实现并登记 → 导出匹配目录和运行包 → 工作台更新"}}
    # Commit identity is separate from the component contract. A documentation
    # commit must not invalidate a still-compatible accepted gameplay package.
    contract = {key: value for key, value in result.items() if key != "source_revision"}
    result["source_hash"] = hashlib.sha256(json.dumps(contract, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    return result
