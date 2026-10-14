

最新[人物动作试玩9e1522fab3fc](https://zhipijun1996.github.io/gunman-rush/?v=9e1522fab3fc)：主菜单进入“动作练习/ACTIONS”，普通枪/三连、羽翼二跳、墙跳和钩索；三类成功动作恢复D/H，正式平原默认授予不变。规则/验证见 [AIR-REFILL-01](docs/quality/air_action_refill.md)。
新增[AI关卡工坊](docs/platforming_foundry.md)：[公开试玩1ca9017cc17e](https://zhipijun1996.github.io/gunman-rush/?v=1ca9017cc17e)已更新并实际核验；开发菜单 LEVEL FOUNDRY，36组合片段、18整段验证路线、能力配置与输入回放。视频为有限采样分析，趣味性待试玩。

最新加载优化：[D083 分块恢复与弱网加载](docs/web_loading_resilience.md)。[公开试玩 74867f67fb81](https://zhipijun1996.github.io/gunman-rush/?v=74867f67fb81)已更新并实际核验；首次响应体约少19%，人工限速启动46.6→39.1秒，国内镜像部署包已准备。大陆真实网络尚未测，国内地址尚未接入。

玩法基线：[D082 统一操作、Boss封场与连贯地形](docs/plains_cohesion.md)，本轮保留其有效修复。完整交付与边界见[交接](docs/handoff.md)。

# Gunman Rush

Godot 4.7.2 Standard 动作肉鸽原型，以反冲位移、平台操作和探索为核心。当前正式入口为标题 → 可操控家园 → 两张随机连通平原地图：第一图小 Boss，第二图三阶段牧风者；后续地区和大能力未开放。旧三关/八关模式保留为开发回归。

[公开试玩](https://zhipijun1996.github.io/gunman-rush/) · [当前状态](docs/current_state.md) · [交接与验证](docs/handoff.md)

横屏触控：左杆移动，右杆瞄准/松手射击，JUMP 短按小跳、长按大跳；键鼠/手柄共用动作意图。真实手机、手柄、完整探索趣味性与大陆网络仍需实际验收。

## 开发

先读 [AGENTS.md](AGENTS.md)，按 [任务](docs/tasks.md) 选择依赖满足的切片；本地 [.agents/skills](.agents/skills) 提供迭代、关卡生成、美术和整合工作流。

```sh
bash tools/cloud_setup.sh --godot-only
python3 -m pip install -r tools/requirements_art.txt
python3 tools/harness.py --plan
python3 tools/harness.py --profile docs
python3 tools/harness.py --profile gameplay
bash tools/godot.sh --path .
```

默认 harness 根据相对 origin/main 的改动选择检查，包含未提交和新文件；只打印计划不会验证。完整检查与证据说明见 [harness](docs/harness.md)。Windows/Web/Android 导出使用 tools/build.py，产物进入忽略的 build/。

## 项目导航

| 入口 | 用途 |
| --- | --- |
| [当前状态](docs/current_state.md) | 现行规则和最新修订 |
| [项目结构](docs/project_structure.md) | 目录职责、保留范围和清理规则 |
| [游戏设计](docs/game_design.md)、[世界](docs/world_and_story.md) | 产品与长期候选 |
| [模块导航](docs/module_map.md)、[架构](docs/architecture.md) | 运行消费者与接口 |
| [输入](docs/controls_contract.md)、[物理](docs/player_mechanics.md) | 角色实现边界 |
| [生成](docs/procedural_generation.md)、[路线](docs/run_and_routes.md) | 可复现布局与正式流程 |
| [奖励](docs/rewards_and_builds.md)、[伤害](docs/damage_and_respawn.md)、[保存](docs/home_and_save.md) | 状态与账本 |
| [内容流程](docs/content_pipeline.md)、[美术门槛](docs/art_quality_target.md) | 素材来源和视觉验收 |
| [验收](docs/acceptance_tests.md)、[决策](docs/decisions.md)、[环境](docs/environment.md) | 证据、待定项与工具链 |

技术、GUI、真机与主观验收分别记录；不以测试数量代替游戏品质。历史 README 已移入 [归档](docs/archive/readme_before_harness.md)。

项目级生产流程：读 [质量体系与 Skills](docs/quality/README.md)，重要内容使用 `$game-quality-gate` 路由八个专业流程。G0–G5、独立审查与玩家认可分开记录；技术测试通过不能代替游戏品质完成。
