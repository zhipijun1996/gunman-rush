# Codex 工作规则

## 权威来源

产品目标：docs/game_design.md。正式运行/路线：docs/run_and_routes.md；奖励/道具/构筑/商店：docs/rewards_and_builds.md；血量/两类伤害/段回退/真正死亡：docs/damage_and_respawn.md；家园/永久成长/存档：docs/home_and_save.md。物理规则：docs/player_mechanics.md。输入：docs/controls_contract.md。资源：docs/combat_and_recharge.md。当前原型移动/射击/慢时参数唯一来源：config/player_tuning.json；后续Character/Weapon/Health/Stamina Definition按stat保持唯一基础来源，旧配置只作兼容映射，禁止两份重复默认值；输入参数唯一来源：config/input_profile.json（InputProfile读取）。原 aim_deadzone 已迁移为设备各自死区，不在物理参数中维护副本；开发 Resource 时同步文档引用，不维护两套数值。
生成与空间权威：docs/procedural_generation.md；模块蓝图：docs/platforming_modules.md；难度/路线节奏候选：docs/difficulty_profiles.md。模块草图不等同可玩地图。
代码模块分类/当前框架：docs/module_map.md；仅导航与接入状态，不覆盖设计。任务状态：docs/tasks.md；验收证据：docs/acceptance_tests.md 与 docs/handoff.md。

## 执行流程

读取规则与当前 Git 状态 → 选择依赖满足任务 → 创建 feature/fix/docs 分支 → 小范围实现 → 验证 → 修复 → 更新状态和证据 → 提交并推送 → 创建 PR → 继续可独立任务。
用户已授权项目内文档、可逆实现、验证、分支、提交、推送和开发任务管理。日常工作不逐项请示。默认不自动合并 PR、发布商店、使用付费服务或更改核心玩法；这些需明确授权。禁止强推、覆盖用户改动、提交密钥。

## 实现约束

Godot 4.7.2 Standard + 类型化 GDScript；先验证安装版本再创建工程。文件 snake_case，类型 PascalCase。组合优先；不用没有实际消费者的框架。输入不得改人物位置。PlayerMotor 是唯一 move_and_slide 调用方，每物理帧最多一次。表现订阅事件，不能决定玩法结果。
参数可配置；新能力使用资源策略和能力配置，不能在关卡中硬编码玩家脚本。固定/生成关卡共用对象契约。正式每大关10小关/第10 Boss，3关仅development_only测试。按docs/roadmap.md的P0–P6推进，用户已确认初验并授权生成设计，GEN-DESIGN/固定模块样片可推进；生成运行集成依任务细分及详细设备门槛，生成关真机独立验收；不把Health、商店、Boss、家园和存档一次全部实现。

## 验证与完成

每次运行 `python3 tools/check_docs.py`。创建工程后运行 `godot --headless --path . --editor --quit`。M1 必须新增有失败退出码的 tests/run_tests.gd，然后运行 `godot --headless --path . --script tests/run_tests.gd`。
针对改变运行必要测试。记录命令、版本、退出码、提交与输出；未执行写未验证。禁止降低标准、删除失败测试来伪造通过。输入和手感真机验收由用户实际试玩，不可用 headless 代替。
任务完成需实现、相应检查通过、文档同步、证据和提交齐全。需要真机的任务保持 awaiting-device，不能标 done。

## 会话恢复

结束前更新 docs/handoff.md：分支、提交、已完成、失败、阻塞、下一任务与命令。阻塞时推进独立工作，不声称后台无限运行。没有用户明确要求，不启用子代理。

## 新增权威契约

整体风格：docs/visual_and_gamefeel.md。可增减能力：docs/ability_components.md。地图对象：docs/world_components.md。敌人/Boss：docs/enemies_and_bosses.md。M1 起次数数据化，能力组件与 Motor 分离；不把第三跳拒绝写成普遍规则。世界组件可独立实例化；敌人 AI 不依赖玩家输入；Boss 不在玩家脚本硬编码。

## 正式肉鸽新增约束

新用户设计优先于冲突旧规格，已修正权威文档；历史报告/旧测试通过不代表新规则完成。D027–D031为暂定策略，Q001–Q013待决策，不擅自升级为用户确认。docs/design_contract.json用于文档结构检查，不是运行时配置。

Health/Stamina/ActionResources独立，正式精力用途未定，不给移动/跳跃/松手射击加精力消耗。既有AirFocus/遮罩保留原型实验；正式消费绑定另定。不同枪发射方式未定，不自动连射。

环境存活伤害段回退、零血RunEnd回家园；旧机关直接die与整场reset只允许显式Legacy测试。段回退不重置敌人/机关相位/补给/奖励/商店账本，不复用WorldContext.respawn全重置。Run/Stage/Actor epoch分层，死亡取消未结算奖励与延迟回调。胜负/伤害批次/二选一/交易确定性且去重，不能靠回调顺序。

RunState/BuildState与MetaProgression、RunCoin与MetaCurrency分离；未定兑换不自动转币。随机流分离并记录完整版本化RunManifest。局部服务与类型化事件，禁止万能全局事件总线/大量类型switch堆Loader。道具修改来源Modifier/组件，从基础重算、可撤销，不直接累加玩家字段。只在实际任务有消费者时实现最小接口，不创建全套空框架。


## 当前固定 demo 入口与迭代范围

用户已授权连续完成多个依赖满足任务至可玩demo框架；按P2/P3/P4分别实现、检查后集成，仍禁止未验证的一次性全系统改写。默认入口`scenes/demo/demo.tscn`提供3关development_only快试与正式10关固定大关试炼。两模式共用六类房间消费者与伤害/构筑/奖励契约；10关第9两个出口必进Boss10，金奖励后以biome_complete回家园，Meta.completed_biomes独立累计，禁止把一大关完成算成完整游戏成功。`scenes/test_levels/graybox.tscn`与WorldContext只保留明确LEGACY测试路径。新增任务不得把选择性SegmentRespawn改回全场reset，也不得用旧机关即死测试代替新流程。

开发fixture的价格、血量、掉落、交互式金领取、家园NO_TRANSFER只是演示配置，Q001–Q013继续待决策。正式10/Boss10不可改为3；用户已确认初验，生成设计/模块样片进入GEN-DESIGN/GEN-MODULES；详细分设备证据仍独立跟踪，不把初验当全部设备/性能通过。当前Meta只存进程内摘要，没有SaveService/永久购买/剧情/Steam集成；结束时逐项记录技术验证与真机待验。

DemoMenu只负责展示/请求，App拥有暂停、动作取消和输入配置应用。主页/暂停/设置/帮助/构筑/返回确认必须保留；返回Home明确确认，不提供旧整关reset快捷按钮。五项输入滑条需Apply、只在当前会话保留，默认值仍唯一来自config/input_profile.json；不声称已实现持久设置或SaveService。金币房10金币/回血房恢复当前2HP仅fixture，不锁定正式奖励规则。

生成设计：空间LayoutProfile与主题/类型解耦，支持横/纵/方形，禁止直接旋转横向地形改变重力。模块端口包含动作余量/速度/相位；逐步实装CameraRig与实际Motor验证。难度P/C/T/R候选，不偷偷改角色物理；主路不依赖慢时/未有能力/损血穿越。设计图/几何连通不能冒充物理通过；同类型能力兼容保底、有界失败、Manifest实际布局/预算/版本必须保留。

当前静态模块消费者：主菜单MODULE LAB，四个独立模块/端口Resource复用真实Motor/输入/段回退。练习不会结算Run/Meta奖励；RETRY或模块选择显式新尝试，环境存活回退保留HP/精力/冷却/补给/计时与实例。完整GEN-MODULES仍in_progress，不把四个样片视为完整随机生成或三拓扑镜头验收。
