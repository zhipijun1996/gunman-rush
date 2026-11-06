# 固定世界迁移当前交接

目标：将《失序之钟》迁为固定世界类银河恶魔城。本轮仅MV-MIGRATION-01；后续运行时/216房施工和原包CODEX_START_PROMPT不在本轮范围。进度唯一见 [任务表](../../tasks.md)。

## 可恢复基线

核实于2026-11-06，main为 `48cddb6a70983b0a0206304d18c98d274a9a7549`，与用户审计基线一致。初始工作区干净；工作分支 `feat/mv-migration-01`，迁移实现提交 `6a6053c`，本次收尾从 `1284c01` 接续；同一 [PR137](https://github.com/zhipijun1996/gunman-rush/pull/137) 的后续提交记录收尾写集。原型启动 project.godot → game/application/demo.tscn → DemoApp，普通出发仍是Plains/Forest Provider。

公开构建 `9c5a54c99d13` 对应源码 `7a49abda9092a2f63e63f32db7c8126e6ad5cfe6`，属于PR136工作线，不是main。实时读取的 [build-info快照](../../../data/world/live-build.json) 保留引擎、包与源码身份；可按SHA恢复分支源码，不只保存网页。本轮未部署或替换试玩。

[未合入PR快照](../../../data/world/open-prs.json)记录全部开放PR的分支与head；下列引用未合并，不自动cherry-pick，也不作为本轮隐性前置。PR标题/旧报告不代表成果仍未被后续main吸收；取用前逐文件比对消费者与测试。

| PR | 分支 | head SHA | 取用策略 |
| --- | --- | --- | --- |
| [#136](https://github.com/zhipijun1996/gunman-rush/pull/136) | `feat/mapgen-formal-plains` | `e3b726632f6dc9c576f30bb4ad79525dc58550e7` | 机关可见性、缓存、HUD和取消安全可评估；随机求解/家园预生成不作为前置 |
| [#118](https://github.com/zhipijun1996/gunman-rush/pull/118) | `feature/plains-monster-revision-01` | `81ccd085b5dd6bcb81f8d3fdb58e8e0876e0f091` | 按功能核与main重叠，保留来源；不自动采用 |
| [#116](https://github.com/zhipijun1996/gunman-rush/pull/116) | `feature/enemy-workshop-01` | `0d33ab56cb06d5bb37b30bd82387415ae5c7725e` | 按功能核与main重叠，保留来源；不自动采用 |
| [#94](https://github.com/zhipijun1996/gunman-rush/pull/94) | `feature/underworld-plains-production` | `0fab13fcc446bf9abd3c6beaf21e0fc5b76bd9ad` | 按功能核与main重叠，保留来源；不自动采用 |
| [#93](https://github.com/zhipijun1996/gunman-rush/pull/93) | `feature/windchime-five-style-lab` | `8382a41cb0ccf9a8e2e56075ade9edaceb4ff67a` | 按功能核与main重叠，保留来源；不自动采用 |
| [#90](https://github.com/zhipijun1996/gunman-rush/pull/90) | `feature/plains-world-rebuild` | `913d77afa4019a0a2e6c84f270f3fe30ac2f00ba` | 按功能核与main重叠，保留来源；不自动采用 |
| [#89](https://github.com/zhipijun1996/gunman-rush/pull/89) | `feature/plains-art-language` | `28236ef9e5546c7c3d588f67e8e99813b5ac6e9f` | 按功能核与main重叠，保留来源；不自动采用 |
| [#88](https://github.com/zhipijun1996/gunman-rush/pull/88) | `feature/plains-landform-first` | `07ffe3f3cf6972910e0d4eedd12addf1b00cd9ae` | 按功能核与main重叠，保留来源；不自动采用 |
| [#87](https://github.com/zhipijun1996/gunman-rush/pull/87) | `feature/plains-joint-challenge` | `16e98690ea207bfda4424a1dd7d0b90c70d55658` | 按功能核与main重叠，保留来源；不自动采用 |
| [#86](https://github.com/zhipijun1996/gunman-rush/pull/86) | `feature/plains-regional-synthesis` | `b5fc02706348d93da3cbd2df91eb0db6871e246e` | 按功能核与main重叠，保留来源；不自动采用 |
| [#85](https://github.com/zhipijun1996/gunman-rush/pull/85) | `feature/plains-joint-place-synthesis` | `148d9251da2a457944213ba73b082525edf5e729` | 按功能核与main重叠，保留来源；不自动采用 |
| [#84](https://github.com/zhipijun1996/gunman-rush/pull/84) | `feature/plains-place-grammar` | `f8dead080f2195c5c3b332966ec76fe4ba2181e3` | 按功能核与main重叠，保留来源；不自动采用 |
| [#83](https://github.com/zhipijun1996/gunman-rush/pull/83) | `feature/thorn-forest-depth` | `ac002e7641fd282c291cdd7c25c9cf5d2450ce0a` | 按功能核与main重叠，保留来源；不自动采用 |
| [#82](https://github.com/zhipijun1996/gunman-rush/pull/82) | `feature/plains-environment-grammar` | `4a4b3fd7d3ce8ae1ca0808ecb725935d0dd50e45` | 按功能核与main重叠，保留来源；不自动采用 |
| [#81](https://github.com/zhipijun1996/gunman-rush/pull/81) | `feature/p1-random-plains-avatars` | `e545b05e5de5c33656cc489cc5f3d3ebaf69432d` | 按功能核与main重叠，保留来源；不自动采用 |
| [#79](https://github.com/zhipijun1996/gunman-rush/pull/79) | `feature/p1-native-pilot` | `ed647d5dee2a72d5c7ef95f43fa5fdffe6d88ac1` | 按功能核与main重叠，保留来源；不自动采用 |
| [#78](https://github.com/zhipijun1996/gunman-rush/pull/78) | `feature/art-direction-reexploration` | `d549ad9daa17b0397b893f923760d379b75167de` | 按功能核与main重叠，保留来源；不自动采用 |
| [#77](https://github.com/zhipijun1996/gunman-rush/pull/77) | `feature/painted-terrain-grammar` | `da05c27a3a5b5d06ea14f24b299b598713c8ab1d` | 按功能核与main重叠，保留来源；不自动采用 |
| [#75](https://github.com/zhipijun1996/gunman-rush/pull/75) | `feature/visual-language-production` | `0905516bb8c996a5f79ee4ac242ea0a0ab2205de` | 按功能核与main重叠，保留来源；不自动采用 |
| [#73](https://github.com/zhipijun1996/gunman-rush/pull/73) | `feature/spatial-golden-production` | `5c1e6549987e1e68c846302e9595a106ca1d79e7` | 按功能核与main重叠，保留来源；不自动采用 |
| [#70](https://github.com/zhipijun1996/gunman-rush/pull/70) | `feature/production-capability-repair` | `92f9336620df052913f23e4c41cc205c6686a9dd` | 按功能核与main重叠，保留来源；不自动采用 |
| [#69](https://github.com/zhipijun1996/gunman-rush/pull/69) | `feature/plains-production-v3` | `4f2066fd610faa1b86de5a942fa7c1c0bdacda26` | 按功能核与main重叠，保留来源；不自动采用 |
| [#68](https://github.com/zhipijun1996/gunman-rush/pull/68) | `feature/visual-director-golden` | `ed0623000c61287282f89e6b0463937b0afe0aca` | 按功能核与main重叠，保留来源；不自动采用 |
| [#67](https://github.com/zhipijun1996/gunman-rush/pull/67) | `feature/plains-designed-exploration` | `2c2904172045017037e4110323c1097f9d24c5ad` | 按功能核与main重叠，保留来源；不自动采用 |
| [#58](https://github.com/zhipijun1996/gunman-rush/pull/58) | `fix/foundry-mobile-menu` | `7ad11ea38d0ed7eee81cca48f4af46a8ed9d30b9` | 按功能核与main重叠，保留来源；不自动采用 |
| [#57](https://github.com/zhipijun1996/gunman-rush/pull/57) | `chore/game-quality-system` | `5fd9c272d74616ae477809fa4285f609e6b697c6` | 按功能核与main重叠，保留来源；不自动采用 |
| [#53](https://github.com/zhipijun1996/gunman-rush/pull/53) | `fix/web-loading-resilience` | `924a8d18c3ff6b7e8b9cf6dda01aff7dc5d47e6b` | 按功能核与main重叠，保留来源；不自动采用 |
| [#51](https://github.com/zhipijun1996/gunman-rush/pull/51) | `feature/plains-cohesion-and-pressure` | `53f88e58b89048034c7a53065e04066aee625fae` | 按功能核与main重叠，保留来源；不自动采用 |
| [#50](https://github.com/zhipijun1996/gunman-rush/pull/50) | `feature/plains-interactive-platforms` | `d7cd4c3a99e57d1e4ce7e95e4ab0b8c8424fca26` | 按功能核与main重叠，保留来源；不自动采用 |
| [#49](https://github.com/zhipijun1996/gunman-rush/pull/49) | `feature/plains-exploration-expansion` | `872aa221db5245b11f6355faf5a429b7ca574949` | 按功能核与main重叠，保留来源；不自动采用 |
| [#48](https://github.com/zhipijun1996/gunman-rush/pull/48) | `feature/plains-experience-energy` | `91d3ef45e267944a22fb3bc09b1c93ca16ebb9f6` | 按功能核与main重叠，保留来源；不自动采用 |
| [#47](https://github.com/zhipijun1996/gunman-rush/pull/47) | `feature/plains-spatial-combat-art` | `906c3805dc8d06808941dce76ebeacedfb390e74` | 按功能核与main重叠，保留来源；不自动采用 |
| [#38](https://github.com/zhipijun1996/gunman-rush/pull/38) | `feature/plains-art-v3` | `17edc86dc9e0ad1d8ca61230452c840ae9b9d3ff` | 按功能核与main重叠，保留来源；不自动采用 |
| [#37](https://github.com/zhipijun1996/gunman-rush/pull/37) | `feature/biome-style-review` | `89dbadb16760cdad9bb8a6bb2b8cdeec336092db` | 按功能核与main重叠，保留来源；不自动采用 |
| [#36](https://github.com/zhipijun1996/gunman-rush/pull/36) | `feature/plains-branch-challenges` | `f749db9dabd9cd08077a017ce8d27b8a4cde7479` | 按功能核与main重叠，保留来源；不自动采用 |
| [#35](https://github.com/zhipijun1996/gunman-rush/pull/35) | `feature/plains-eight-room-graph` | `5da8aba9d9a508cdeaa8501bb1f5af8c8c58a861` | 按功能核与main重叠，保留来源；不自动采用 |
| [#34](https://github.com/zhipijun1996/gunman-rush/pull/34) | `feature/plains-polish-home` | `faecae2e838a262542f6b125418677ff49b90d5e` | 按功能核与main重叠，保留来源；不自动采用 |
| [#33](https://github.com/zhipijun1996/gunman-rush/pull/33) | `feature/title-home-ui` | `aa7efffbce76eb4ba67d1d2094edd6f7e9654a7f` | 按功能核与main重叠，保留来源；不自动采用 |
| [#32](https://github.com/zhipijun1996/gunman-rush/pull/32) | `feature/plains-ten-generated` | `680cf798ae7915c349f0b7117a446a31920b0fa4` | 按功能核与main重叠，保留来源；不自动采用 |
| [#31](https://github.com/zhipijun1996/gunman-rush/pull/31) | `feature/plains-capability-generation` | `cc2b9335a12be2c6b6bec8b8370b9f1c419d5796` | 按功能核与main重叠，保留来源；不自动采用 |
| [#30](https://github.com/zhipijun1996/gunman-rush/pull/30) | `feature/painterly-plains-v2` | `3bacc326c419741f1ded43fd32e8877cf706dbc5` | 按功能核与main重叠，保留来源；不自动采用 |
| [#29](https://github.com/zhipijun1996/gunman-rush/pull/29) | `docs/biome-challenge-design` | `86e7fe9074fb4f0e8d313494f74514407f27e888` | 按功能核与main重叠，保留来源；不自动采用 |
| [#28](https://github.com/zhipijun1996/gunman-rush/pull/28) | `docs/world-story-anchor` | `4ad6d505f201edd73eb962687e8754ed641f1271` | 按功能核与main重叠，保留来源；不自动采用 |
| [#27](https://github.com/zhipijun1996/gunman-rush/pull/27) | `feature/plains-art-integration` | `d1a63cc4de8fd6b11e4a2cb70fe1cb5db412f85c` | 按功能核与main重叠，保留来源；不自动采用 |
| [#26](https://github.com/zhipijun1996/gunman-rush/pull/26) | `feature/seamless-mixed-modules` | `317619c1055ad142acc2681f096c5f0851b05af8` | 按功能核与main重叠，保留来源；不自动采用 |
| [#25](https://github.com/zhipijun1996/gunman-rush/pull/25) | `feature/random-stage-preview` | `5c5cba11033b4eb7bdc78f1d0795ef5bd1022118` | 按功能核与main重叠，保留来源；不自动采用 |
| [#23](https://github.com/zhipijun1996/gunman-rush/pull/23) | `feature/loop-boss-modules` | `d718779612c91da9595d6ba152462fc103776dc3` | 按功能核与main重叠，保留来源；不自动采用 |
| [#22](https://github.com/zhipijun1996/gunman-rush/pull/22) | `feature/dynamic-platforming-modules` | `cb79b05f536c4cab56b8aac2d7702262e7209781` | 按功能核与main重叠，保留来源；不自动采用 |
| [#21](https://github.com/zhipijun1996/gunman-rush/pull/21) | `feature/platforming-module-lab` | `3c0ca91b013a5de07be3cb43511d8c00f349d2e0` | 按功能核与main重叠，保留来源；不自动采用 |
| [#20](https://github.com/zhipijun1996/gunman-rush/pull/20) | `docs/procedural-layout-design` | `56b70d9547ac32e386a4454831def0bafc969b95` | 按功能核与main重叠，保留来源；不自动采用 |
| [#19](https://github.com/zhipijun1996/gunman-rush/pull/19) | `feature/ten-stage-menus` | `b3d13f5597c327830fc5e5afe8b7642fdc5ae860` | 按功能核与main重叠，保留来源；不自动采用 |
| [#18](https://github.com/zhipijun1996/gunman-rush/pull/18) | `feature/playable-demo-loop` | `060d88185b5e7b1e82c503668d646eaaa2c7b107` | 按功能核与main重叠，保留来源；不自动采用 |
| [#17](https://github.com/zhipijun1996/gunman-rush/pull/17) | `feature/enemy01-patrol` | `b2eb137e47862f5d9e6197942081577e81006a5b` | 按功能核与main重叠，保留来源；不自动采用 |
| [#16](https://github.com/zhipijun1996/gunman-rush/pull/16) | `feature/actor-resources-framework` | `524c97433573402bfc2a3f34b03b9d6238efc23b` | 按功能核与main重叠，保留来源；不自动采用 |
| [#15](https://github.com/zhipijun1996/gunman-rush/pull/15) | `docs/roguelike-run-contracts` | `c104d247214d98413cf7d2e3c69869c117d74dbe` | 按功能核与main重叠，保留来源；不自动采用 |
| [#14](https://github.com/zhipijun1996/gunman-rush/pull/14) | `feature/snappy-shot-burst` | `77b10ec92e97aa89eddd92d83c409154f5d732b5` | 按功能核与main重叠，保留来源；不自动采用 |
| [#13](https://github.com/zhipijun1996/gunman-rush/pull/13) | `feature/core02-combat-controls` | `2baff9745ba39fbb63ddbf77dd9f70e5b418546e` | 按功能核与main重叠，保留来源；不自动采用 |

## 写集与直接依赖

README/AGENTS、现行project/bible/data正文、20个仓库skills、policy、文档/世界/地区上下文/路由/执行器与相关测试；完整轻量附件及其来源清单。未改游戏代码、现有运行配置、素材、UID或旧存档。唯一拓扑与生成链见 [世界输入](../../../data/world/README.md)。导入目录内52文件原样保留，24个省略预览不当缺失；v03依赖未删。

## 实际结果与设计差距

固定世界权威已替代旧六阶段/两图/禁止回路/禁灰盒约束。对象索引、玩家物理及两份creative_direction已统一永久H/W/D/Q、真实进入侧回退/最后休息点死亡恢复、固定房间扩展和按任务约定的审查；不再要求U1/U2、两图Boss或强制G2/多Seed。保留技能名称但一对一迁移职责，不增加同职责技能。随机地区route和直接content_plan停止，旧自动mission在执行器拒绝；普通Codex按当前交接实施。visual_director.route同步拒绝并清除不可达的旧计划组装；直接调用方只测试退役拒绝，通用执行器通过手写固定世界mission夹具验证。旧lessons仅为仍实际读取的历史visual recipe作前置，冻结配方仍不可执行。质量策略增加world_graybox适用项。地区正文SHA绑定新正文，原选型证据不改，新增本次转型确认依据。

原型仍能调用旧生成与Run清空策略；新固定Provider、房间场景、Q、新存档和周期运行均未实现。导入合同的scene_ref是计划路径。48件装备效果、价格、部分技能消耗、金币死亡政策仍未定；死亡回血/新周期/刷新普通敌人为试制默认。

新会话沿AGENTS → current_state → tasks → 本交接 → module_map/目标规范接续。PR137合入前必须基于`feat/mv-migration-01`，main仍没有本轮迁移；合入后从最新main开始MV-RUNTIME-01。关卡离线工具文档已移除退役route的成功示例，资源正文明确四种状态寿命，避免正文与入口声明矛盾。当前可开始代表样房运行时迁移，尚不能把旧Provider/RunSession直接用于216房量产。

## 消费者保留、适配与退役

| 代码/数据 | 当前消费者与处理 | 退役/适配条件 |
| --- | --- | --- |
| game/player、combat、input、presentation、assets、resources | DemoApp/RunComposition、Factory、实际场景使用，保留动作/素材/许可证 | 新房间复验，不能为跳距改共同参数 |
| LevelRequest/Plan/Provider/Stage/LevelRuntime | DemoApp经Plains/Forest Provider、Stage装配；LevelRuntime接受PlainsRegionState且选旧Assembler | 扩展房号、入口、分区/稳定实例；必要时提取薄房间装配，不新建超级管理器 |
| RunSession、RunCampaignProgression、DemoApp | reset_maps清地图账本；clear_run_services调用build.clear/wallet.discard_balance；_cleanup_run和_select_next_region实际调用 | 新永久/周期/挑战/动作状态与死亡/休息/保存接通、入口替换后移除旧流程 |
| game/world/generation、scripts/generation、scenes/bosses | Plains/Forest Provider、默认森林v15、BossFactory仍加载；generation还含共享镜头/装配 | 逐文件无调用/预加载/动态引用后退役；先保留公共组件 |
| RuntimeMapV2Provider、experiments/generation/runtime_map_*、mapgen_candidate | 开发菜单及专项/导出仍消费 | 新入口及对应检查替换、无消费者后删除；map-gen/map-edit不作为新世界依赖 |
| game/loadout、item_v5_* | 原型装备/effect/UI继续消费 | 逐件选型、NPC升级与周期语义接入，保留事务/容量/效果执行器 |
| economy/rewards、MetaSaveService | 原型扣费/收据/备份校验仍使用 | 复用原子提交与存储可靠性，换新payload/schema/content版本，旧档隔离 |
| world_context.gd | 历史死亡全重置夹具 | 不作为新世界状态核心；夹具消费者消失后再退役 |
| 两份forest slice wrapper/runner | 独立H-only夹具绑定真实runner/traversal及SHA，不再读取已删除design.stage/gate；默认短钩和历史长钩分别回归 | 手动`forest-current-slice`/`forest-historical-slice`，夹具反例`forest-slice-fixture-tests`；旧`forest-h-slice`仅留冻结注册原件，均不签新世界房间 |
| 附件source_inputs、migrate_world_v04.py | 合同/路线生成与一次ID相等审计仍读取v03 | 提取现行人工输入、回归路线并证明重建等价后退出日常链 |

FOREST-VARIETY-04（blocked）与MAPGEN-HOST-WINDCHIME-041（review）保留原状态归档，因转型停止旧目标，分别由固定区域内容及MV-RUNTIME/WORLD承接；未标done。手机性能、死亡卡顿、音频、玩家、普通怪、Boss成果继续保留，新房夹具逐步复验。ITEM/STORY/PLAINS/FOREST原工作线重定向，历史卡不改签。

## 验证

迁移初验与本次PR137收尾的最终通过结果如下（保留初次阻塞及修正原因，不以历史结果签收新运行时）：

- `python3 tools/world/verify_import.py`：52个实际文件（manifest列51项加自身）、大小/SHA256和文件集通过；24省略视图按轻量清单处理。
- `python3 tools/world/validate_routes.py`：新跑A/B/C/D成功，55路线/状态反例、17合同、13跨文件检查通过；216房、288连接、576门/入口、310分区、188内部路线；重建合同及回放与导入语义等价。输出build/world/validation，不改源。
- `python3 tools/check_docs.py`、`python3 tools/check_world_design.py`、`python3 tools/check_quality.py`：导航/任务依赖、世界引用/摘要、20技能发现（14 core）及policy/模板通过。
- `python3 tests/test_world_design.py`：9项通过，含坏门/分区/来源、局部提取、旧route拒绝、Bible迁移依据篡改反例、导出配置隔离。
- `python3 tests/test_level_region_context.py`（8）、`python3 tests/test_level_design_routing.py`（11）、`python3 tests/test_context_navigation.py`（5）、`python3 tests/test_quality.py`（61）：通过。被替代的六层/两图/旧route正向断言迁为固定世界检查，快照/损坏/来源/权限等通用回归保留。
- `python3 tools/ci.py`：project/import/smoke/contracts四项通过；CI SMOKE 9、CI CONTRACTS 239、META NOTES SAVE 39断言无失败。初次因缺锁定Godot拒绝，随后运行`tools/setup_environment.py --engine-only`安装并校验4.7.2 gunman-sd1后重跑成功，没有换用环境内4.6.3冒签。
- 地区F及P-R03局部提取实际运行成功；自编改动的`git diff --check`通过；完整差异报告原包font-LICENSE.txt与atlas_utils.py末尾空行，按原字节导入要求保留，不清理来源。确认export_presets排除docs/*，raw exporter不额外加入世界导入包；未导出新PCK。

本次PR137收尾重新验证：

- `tests/test_production_loop.py` 113项、`test_region_bible.py` 41项、`test_region_creative_direction.py` 12项、`test_visual_director.py` 25项、`test_lightweight_workflow.py` 6项通过。保留预算、检查顺序、恢复、权限、证据篡改和stage/content区分等通用回归；新手写mission仅用于测试，不恢复自动量产接口。
- `tests/test_forest_slice_fixture.py` 5项（能力泄漏、资源缺失、消费者错配及摘要变更）、`test_harness.py` 13项、`test_level_design_contracts.py` 31项通过。历史合同测试只在内存重定位已移动文档路径并适配质量快照排除规则；历史JSON、日志、SHA和REJECT原件未改。
- 手动Harness运行`forest-current-slice`、`forest-historical-slice`、`forest-slice-fixture-tests`均通过，日志在`build/verification/harness/20261106T053038.843356Z/`。两个真实控制器正例分别132/168物理tick；各自删除索点及禁H反例均480tick、原生退出1，wrapper确认预期失败，不把失败捕获当成功路线。摘要分别在`build/forest_current_slice/20261106T053038_444c42dc/summary.json`及`build/forest_h_slice/20261106T053051_6fb8d5f3/summary.json`。
- 当前短钩首次实跑揭示旧时间能量消耗断言；现行射击消耗空中弹药，测试已按真实air_shots验证耗弹/落地补弹，并验证无瞄准射击不耗时间能量，未改游戏逻辑或资源参数。稀疏工作区缺的历史回归输入从同一HEAD精确恢复后重跑，没有伪造证据。
- `test_world_design.py` 9项、`test_level_region_context.py` 8项、`test_level_design_routing.py` 11项、`test_context_navigation.py` 5项、`test_quality.py` 61项通过；上述Python套件共340项。文档、世界、质量/skills、导入完整性检查及新增改动`git diff --check`通过。日常`python3 tools/ci.py`四项重跑通过（9/239/39断言）。

数据图检查不等于Godot跳跃、战斗或镜头验收；CI仅保护当前旧原型。未验：新世界实机、手机、全世界运行路线、完整经济/装备、内容美术与战斗。本轮没有需要录屏的新游戏行为，也未发布构建。

## 下一动作：MV-RUNTIME-01

基于合入后的main开独立分支，先按房提取P-R03/P-R01/P-R06/P-R14形成连续闭环，再做F-R04/F-R10、I-R05/I-R11、K-R16/K-R05、A-R04、S-R05。先整理人工尺寸/门台/镜头/场景绑定输入和独立路线回归输入，证明生成等价后一次切换config/world权威与运行资源导出。

接入真实左右/上跳/下落门、入口侧落脚和相机，分清永久/周期/挑战/动作状态。验证普通跨房不休息、1/2HP失败回真实进入侧、死亡不丢永久、Q真实落地加2秒及危险过滤、唯一奖励/购买重复调用、版本化保存与读档。使用已有角色与表现，给同源可试玩构建及关键行为短录屏；Boss替身只证明胜利事务。216房扩展与旧链最终退役属于MV-WORLD-GRAYBOX-01。
