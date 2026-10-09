# Gunman Rush

原创 Android 横屏 2D 精确平台跑酷：二段跳、360° 射击反冲与空中资源续航。

当前阶段：**M0 文档与项目管理**。尚无可运行游戏或 APK。

## 开发入口

先阅读 [AGENTS.md](AGENTS.md)，再从 [任务清单](docs/tasks.md) 选择第一个依赖满足的任务。

| 文档 | 用途 |
| --- | --- |
| [游戏设计](docs/game_design.md) | 已确定玩法与范围 |
| [MVP 规格](docs/mvp01_spec.md) | 第一阶段交付 |
| [架构](docs/architecture.md) | 职责与接口 |
| [输入契约](docs/controls_contract.md) | 触屏与键鼠 |
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

引擎准备后按环境文档运行 Godot 加载检查；当前没有 project.godot，不能运行游戏测试。文档 CI 通过不代表游戏验收通过。
