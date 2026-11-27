# Gunman Rush

Godot 4.7.2 类银河恶魔城。重做开发从 `production/project.godot` 开始。玩家从风铃平原 P01 起身、拾枪，沿 P02 田埂进入 P03 沟谷。当前世界设计涵盖 16 区、310 房和 392 条连接。已施工范围按[运行绑定](production/config/imported_world/bindings.json)和[制作交接](docs/project/worklines/room_rebuild/scope.md)查询。

| 目的 | 从哪里开始 |
| --- | --- |
| 接续世界 | [地图输入及版本](docs/data/world/README.md) · [实际房间](production/rooms/world) |
| 制作新房 | [普通房间规范](docs/bible/room_authoring.md) · [机关目录](docs/data/world_objects.md) · [代码与素材](docs/project/module_map.md) |
| 接续项目 | [开发入口](AGENTS.md) · [当前状态](docs/project/current_state.md) · [旧 demo 迁移核对](docs/project/worklines/room_rebuild/runtime-inheritance.md) · [任务表](docs/project/tasks.md) |
| 复玩平原 | [启动、归档与独立恢复](docs/project/worklines/plains_bible_v2_01/scope.md) · [原有线上试玩](https://zhipijun1996.github.io/gunman-rush/) |

在仓库根目录运行：

```sh
python3 tools/setup_environment.py --engine-only
python3 tools/check_ordinary_rooms.py
bash tools/godot.sh --path production
```

最后一条运行重做版的[标题场景](production/game/application/world_shell.tscn)。选择「新游戏」从 P01 开始，「继续游戏」读取专用存档。组件组装夹具单独使用 `res://tests/assembly_room.tscn`。复玩冻结平原使用 `bash tools/godot.sh --path .`。
