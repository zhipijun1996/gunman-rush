# Gunman Rush

原创2D横版动作肉鸽：精确平台跳跃、释放射击与反冲移动、战斗/Boss、分支路线、局内构筑与家园永久成长。默认二段跳/两次射击只是可配置原型。当前优先 Android 横屏；Windows PC 是未来正式平台，Steam 第一版优先 Windows。继续使用 Godot + GDScript，共用玩法逻辑。

当前代码已接入**固定三关可玩demo框架**：家园开局→战斗→选择商店或道具房→Boss→领取金道具→家园。保留移动、可配置N跳、短/长跳、松手射击反冲与攻击弹体、触屏/键鼠/手柄和空中慢时原型；新增统一伤害批次、段回退、真正死亡、一次补给、可撤销构筑、二选一与最简交易。正式每大关10关，第10 Boss；3关只作development_only测试。默认入口为`scenes/demo/demo.tscn`，操作与完整路线见[demo试玩](docs/demo_playtest.md)。

代码接入、测试、Web/Android/Windows构建和真机验收分别记录于[任务](docs/tasks.md)、[验收](docs/acceptance_tests.md)与[交接](docs/handoff.md)。当前公开网页是否包含本轮demo以实际部署版本为准，不沿用旧网页作为新功能证据。随机地图、真实永久经济/存档、剧情和完整Steam集成尚未实现；家园仅进程内摘要。
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

默认从HOME开始固定demo。历史`scenes/test_levels/graybox.tscn`保留Practice/Challenge与旧即死整关重置，明确仅LEGACY回归测试；新demo环境存活回挑战段，零血结束run回家园。

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

## 手机网页快速试玩

[Android / iPhone 网页入口](https://zhipijun1996.github.io/gunman-rush/)：横屏打开；左杆移动，JUMP短按小跳、长按大跳，右杆拖动瞄准、松手射击并反向快速位移。键盘Space同样支持按住/释放。页面左下角显示试玩版本，更新后重新打开入口；导出包按内容指纹区分，避免沿用旧玩法缓存。iPhone Safari真机兼容、触控、安全区域及性能待用户验收。

后续以共享Web链接快速迭代，正常CI不再重复安装Android SDK或构建APK；保留`python3 tools/build.py android`。工作流加入可选手动build_android，工作流进入main后可从Actions界面触发。Windows导出仍独立验证。当前分支/PR与合并状态见[交接](docs/handoff.md)。详见[可变跳高报告](docs/variable_jump_report.md)。

## 空中瞄准慢时原型试玩

正式精力用途按新设计待决策；以下是此前已实现的实验，不将精力绑到移动/跳跃/射击。

空中拖动右摇杆有效瞄准时，全场以25%速度运行，方便选方向；松手射击恢复正常速度。精力条消耗，只有站在地面时渐渐恢复；每次腾空最多累计2秒慢时。键鼠需按住射击键瞄准，手柄右杆有效武装偏移同样生效。耗尽后仍可普通射击。容量、消耗/恢复、倍率与上限均可配置，供后续道具提升。网页入口不变，最新版本与证据见docs/handoff.md。

## 新动作肉鸽设计入口

- [运行、路线与Manifest](docs/run_and_routes.md)：正式每大关10关，第10 Boss；3关仅开发测试。
- [奖励、道具、流派与商店](docs/rewards_and_builds.md)：道具二选一、Boss金奖、分离回血/最大HP与原子幂等交易。
- [伤害、段内回退与真正死亡](docs/damage_and_respawn.md)：替代正式即死检查点，不用回退刷新奖励。
- [家园、永久成长与存档](docs/home_and_save.md)：Run/Meta与两币种分离，经济待定。

P0/P1基线保留；P2固定伤害、P3奖励商店与P4开发3关/Boss/Home已按模块接入。后续固定demo真机验收后，按P5正式10关随机→P6永久进度与内容实现。完整确认/暂定/待定表在[决策记录](docs/decisions.md)。

模块导航与接口见[模块分类](docs/module_map.md)，本轮证据见[交接](docs/handoff.md)，资源基线见[HEALTH-01报告](docs/health01_report.md)。

首个巡逻敌人见[敌人契约](docs/enemies_and_bosses.md)：AI/Motor/Health独立，可由玩家弹体击败；新demo接触伤害通过统一帧批次扣玩家HP。
