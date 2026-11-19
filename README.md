# Gunman Rush

Godot 4.7.2 Standard 固定世界类银河恶魔城项目，以射击反冲、平台动作、永久成长与能力回访为核心。

当前默认入口运行冻结的风铃平原。重做版从新房间起步，新房间就绪后切换正式入口。平原仍可从固定版本单独恢复。

[平原归档与启动](docs/project/worklines/plains_bible_v2_01/scope.md) · [冻结源码 ZIP](https://github.com/zhipijun1996/gunman-rush/archive/4f2bb5e41573e930603789c64b52a0c15a6a3dc4.zip) · [此前发布的平原试玩](https://zhipijun1996.github.io/gunman-rush/) · [当前状态](docs/project/current_state.md)

新房间按[普通房间组装](docs/bible/room_authoring.md#普通房间组装)制作。[TileSet 恢复与使用](docs/project/worklines/plains_bible_v2_01/scope.md#独立-tileset-包)单独保留可复用地形资源。

横屏触控使用左杆移动、右杆瞄准／松手射击、JUMP 短按小跳／长按大跳；键鼠和手柄共用动作意图。手机性能、手感、听感与完整玩法品质仍需实际体验验证。

## 开发

Codex 从 [AGENTS.md](AGENTS.md) 开始；按 [任务索引](docs/project/tasks.md) 和模块导航加载所需上下文。

```sh
python3 tools/setup_environment.py --engine-only
bash tools/godot.sh --path .
python3 tools/ci.py
```

开发专项通过 `tools/harness.py --check <ID>` 显式选择，见 [Harness](docs/project/harness.md)。素材工具依赖按需安装：`python3 -m pip install -r tools/requirements_art.txt`。导出使用 `tools/build.py`，生成物进入 `build/`。

| 需要了解 | 入口 |
| --- | --- |
| 当前产品与缺口 | [当前状态](docs/project/current_state.md) |
| 修改落点、设计与验证 | [模块导航](docs/project/module_map.md) |
| 状态所有权与调用 | [运行架构](docs/project/architecture.md) |
| 目录职责 | [项目结构](docs/README.md) |
| 跨会话协作与交付 | [生产规则](docs/project/cloud_production.md) |
| 游戏与长期设计 | [游戏设计](docs/bible/game_design.md)、[世界与故事](docs/bible/story.md) |

文档分项目管理、设计圣经、具体数据和临时文件，入口见 [四类文档索引](docs/README.md)；对象规范样例见 [平原冲锋怪](docs/data/enemies/plains_charger.md)。
