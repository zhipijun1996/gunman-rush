# Gunman Rush

Godot 4.7.2 Standard 动作肉鸽原型，以射击反冲、平台动作和随机探索为核心。

[公开试玩](https://zhipijun1996.github.io/gunman-rush/) · [当前状态](docs/current_state.md) · [模块导航](docs/module_map.md)

正式流程：标题 → 可操作家园 → 平原两图 → 领取 H／钩索 → 荆棘森林两图 → 开发边界。家园支持会话内选择三种 Lv.1 武器和外观，以及永久升级、道具图鉴与出发携带。开发菜单提供动作练习、关卡工坊和 mapgen 候选入口。

横屏触控使用左杆移动、右杆瞄准／松手射击、JUMP 短按小跳／长按大跳；键鼠和手柄共用动作意图。手机性能、手感、听感与完整玩法品质仍需实际体验验证。

## 开发

Codex 从 [AGENTS.md](AGENTS.md) 开始；按 [任务索引](docs/tasks.md) 和模块导航加载所需上下文。

```sh
python3 tools/setup_environment.py --engine-only
bash tools/godot.sh --path .
python3 tools/ci.py
```

开发专项通过 `tools/harness.py --check <ID>` 显式选择，见 [Harness](docs/harness.md)。素材工具依赖按需安装：`python3 -m pip install -r tools/requirements_art.txt`。导出使用 `tools/build.py`，生成物进入 `build/`。

| 需要了解 | 入口 |
| --- | --- |
| 当前产品与缺口 | [当前状态](docs/current_state.md) |
| 修改落点、设计与验证 | [模块导航](docs/module_map.md) |
| 状态所有权与调用 | [运行架构](docs/architecture.md) |
| 目录职责 | [项目结构](docs/project_structure.md) |
| 跨会话协作与交付 | [生产规则](docs/cloud_production.md) |
| 游戏与长期设计 | [游戏设计](docs/game_design.md)、[世界与故事](docs/world_and_story.md) |
