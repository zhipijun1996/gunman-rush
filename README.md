# Gunman Rush

Godot 4.7.2 类银河恶魔城。重做开发从 `production/project.godot` 开始。这里有可实例化的普通房、地形、机关、怪物与视听反馈。首个正式房间待制作；仓库默认试玩继续打开冻结平原。

| 目的 | 从哪里开始 |
| --- | --- |
| 制作新房 | [普通房间规范](docs/bible/room_authoring.md) · [机关目录](docs/data/world_objects.md) · [代码与素材](docs/project/module_map.md) |
| 接续项目 | [开发入口](AGENTS.md) · [当前状态](docs/project/current_state.md) · [任务表](docs/project/tasks.md) |
| 复玩平原 | [启动、归档与独立恢复](docs/project/worklines/plains_bible_v2_01/scope.md) · [原有线上试玩](https://zhipijun1996.github.io/gunman-rush/) |

在仓库根目录运行：

```sh
python3 tools/setup_environment.py --engine-only
python3 tools/check_ordinary_rooms.py
bash tools/godot.sh --path production res://tests/assembly_room.tscn
```

最后一条打开可操作的组装夹具。要试玩冻结平原，使用 `bash tools/godot.sh --path .`。首个正式房间就绪后再切换发布及启动入口。
