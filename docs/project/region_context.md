# 地区与房间上下文

`tools/level_region_context.py`按现行身份映射提取固定世界地区主题和房号；不授予能力，不推断运行可达或内容完成。世界空间源唯一见 [世界输入](../data/world/README.md)。

```sh
python3 tools/level_region_context.py --region thorn_forest --output build/forest-context.json
python3 tools/world/room_context.py F-R04
python3 tools/world/room_context.py F-R04 --contract
python3 tests/test_level_region_context.py
python3 tests/test_world_design.py
```

地区上下文含ID/code、主题、时间状态、修钟意图、房号以及来源身份。按房输出目标分区、内部能力路线、相邻门、永久动作与计划场景引用；只有施工需要时加--contract。未知ID拒绝，不默认落到平原。大JSON由脚本查询，不全文作为会话上下文。

运行时尚未实现新房间；scene_ref是计划路径。当前原型入口与代码见 [当前状态](current_state.md) 和 [模块导航](module_map.md)。取得来源不等于取得能力，静态图检查不证明真实身体能通过。
