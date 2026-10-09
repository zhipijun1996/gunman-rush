# Gunman Rush

原创 2D 精确平台跑酷：默认二段跳、360° 射击反冲与空中资源续航。当前优先 Android 横屏；Windows PC 是未来正式平台，Steam 第一版优先 Windows。继续使用 Godot + GDScript，共用玩法逻辑。

当前阶段：**M1 固定灰盒原型**。已有移动、N 跳、360° 射击反冲与攻击弹体，支持触屏、键鼠、手柄输入；练习区及固定挑战候选含补充点、机关、单向平台和检查点。Android debug APK 与 Windows 导出已构建，真机手感及挑战验收待完成。见 [本轮验证报告](docs/core02_report.md)。

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
python3 tools/run_tests.py
bash tools/godot.sh --path .
python3 tools/build.py android
python3 tools/build.py windows
python3 tools/build.py web
```

灰盒默认进入 Practice 练习区，可点击 Challenge 切换固定挑战候选；死亡快速回到已选检查点。

- Android：左摇杆移动，独立 JUMP 跳跃；右摇杆拖动瞄准、松手同时发射子弹并产生反向反冲；回中心松手取消。左杆向下触发单向平台下穿。
- 键鼠：A/D 或方向键移动，Space 跳跃，鼠标瞄准、释放左键射击；S/下方向键下穿，W/上方向键交互，R 重试，Esc 暂停。
- 手柄：左杆移动，南侧面键跳跃，右杆有效瞄准后回中射击；断连/失焦/暂停取消。首次连接需先回中。

次数/物理与弹体参数在 `config/player_tuning.json`，死区/灵敏度/映射在 `config/input_profile.json`；设置 UI 尚未制作。当前试调默认每枪反向短爆发（1100×0.14秒，打断下落）；`recoil_mode=legacy_impulse`可切指数模式。完整 [试调依据与报告](docs/gamefeel_tuning.md)。默认空中两次射击耗尽后不能开火，补充点可补一次，落地恢复；次数可配置，不限制扩展。子弹可击破灰盒靶并被地形挡住。

自动测试失败返回非零，脚本错误或提前结束也判失败；构建产物保存在忽略的 `build/` 中。文档、解析、物理、构建与真机验收分别记录，不以 CI 通过代替试玩。

Android APK、Windows 导出、物理测试与真机试玩分别记录证据。Linux、macOS 和 Steam Deck 后续分别验证；桌面调试通过不等于 Windows 正式构建通过。开发不要求 Steam 账号或 Steam SDK，完整 Steamworks 接入与商店发布另立任务。

## 扩展契约

- [整体风格与操作](docs/visual_and_gamefeel.md)
- [人物能力组件](docs/ability_components.md)
- [地图组件与存储点](docs/world_components.md)
- [敌人和 Boss](docs/enemies_and_bosses.md)
