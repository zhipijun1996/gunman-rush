# Gunman Rush

原创 2D 精确平台跑酷：默认二段跳、360° 射击反冲与空中资源续航。当前优先 Android 横屏；Windows PC 是未来正式平台，Steam 第一版优先 Windows。继续使用 Godot + GDScript，共用玩法逻辑。

当前阶段：**M1 固定灰盒原型**。已有可运行 Godot 工程及移动、跳跃自动测试；Android debug APK 与 Windows 导出仅验证灰盒构建。触屏、射击与平台试玩仍未完成。

## 开发入口

先阅读 [AGENTS.md](AGENTS.md)，再从 [任务清单](docs/tasks.md) 选择第一个依赖满足的任务。

| 文档 | 用途 |
| --- | --- |
| [游戏设计](docs/game_design.md) | 已确定玩法与范围 |
| [MVP 规格](docs/mvp01_spec.md) | 第一阶段交付 |
| [架构](docs/architecture.md) | 职责与接口 |
| [输入契约](docs/controls_contract.md) | 触屏、键鼠与手柄的统一动作意图 |
| [人物物理](docs/player_mechanics.md) | 运动执行顺序 |
| [射击与续航](docs/combat_and_recharge.md) | 资源与命中规则 |
| [关卡设计](docs/level_design.md) | 固定关卡优先 |
| [随机生成](docs/procedural_generation.md) | 后期扩展 |
| [AI 内容流程](docs/content_pipeline.md) | 美术、音乐、音效 |
| [验收](docs/acceptance_tests.md) | 可验证完成条件 |
| [路线图](docs/roadmap.md) | 阶段依赖 |
| [决策](docs/decisions.md) | 变更原因 |
| [项目管理](docs/project_management.md) | Issue、PR 与发布 |
| [环境](docs/environment.md) | 工具链与阻塞 |
| [交接](docs/handoff.md) | 当前状态与继续指令 |

## 检查

`python3 tools/check_docs.py`：文档、相对链接、任务依赖及参数检查。

按 [环境文档](docs/environment.md) 安装固定工具链，再运行：

```sh
bash tools/cloud_start.sh
bash tools/godot.sh --headless --path . --editor --quit
bash tools/godot.sh --headless --path . --script tests/run_tests.gd
bash tools/godot.sh --path .
python3 tools/build.py android
python3 tools/build.py windows
```

灰盒：A/D 或方向键移动，Space 跳跃，R 重置。自动测试失败返回非零；构建产物保存在忽略的 `build/` 中。文档、解析、物理、构建与真机验收分别记录，不以 CI 通过代替试玩。

Android APK、Windows 导出、物理测试与真机试玩分别记录证据。Linux、macOS 和 Steam Deck 后续分别验证；桌面调试通过不等于 Windows 正式构建通过。开发不要求 Steam 账号或 Steam SDK，完整 Steamworks 接入与商店发布另立任务。

## 扩展契约

- [整体风格与操作](docs/visual_and_gamefeel.md)
- [人物能力组件](docs/ability_components.md)
- [地图组件与存储点](docs/world_components.md)
- [敌人和 Boss](docs/enemies_and_bosses.md)
