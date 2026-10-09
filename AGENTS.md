# Codex 工作规则

## 权威来源

产品目标：docs/game_design.md。正式运行/路线：docs/run_and_routes.md；奖励/道具/构筑/商店：docs/rewards_and_builds.md；血量/两类伤害/段回退/真正死亡：docs/damage_and_respawn.md；家园/永久成长/存档：docs/home_and_save.md。物理规则：docs/player_mechanics.md。输入：docs/controls_contract.md。资源：docs/combat_and_recharge.md。当前原型移动/射击/慢时参数唯一来源：config/player_tuning.json；后续Character/Weapon/Health/Stamina Definition按stat保持唯一基础来源，旧配置只作兼容映射，禁止两份重复默认值；输入参数唯一来源：config/input_profile.json（InputProfile读取）。原 aim_deadzone 已迁移为设备各自死区，不在物理参数中维护副本；开发 Resource 时同步文档引用，不维护两套数值。
代码模块分类/当前框架：docs/module_map.md；仅导航与接入状态，不覆盖设计。任务状态：docs/tasks.md；验收证据：docs/acceptance_tests.md 与 docs/handoff.md。

## 执行流程

读取规则与当前 Git 状态 → 选择依赖满足任务 → 创建 feature/fix/docs 分支 → 小范围实现 → 验证 → 修复 → 更新状态和证据 → 提交并推送 → 创建 PR → 继续可独立任务。
用户已授权项目内文档、可逆实现、验证、分支、提交、推送和开发任务管理。日常工作不逐项请示。默认不自动合并 PR、发布商店、使用付费服务或更改核心玩法；这些需明确授权。禁止强推、覆盖用户改动、提交密钥。

## 实现约束

Godot 4.7.2 Standard + 类型化 GDScript；先验证安装版本再创建工程。文件 snake_case，类型 PascalCase。组合优先；不用没有实际消费者的框架。输入不得改人物位置。PlayerMotor 是唯一 move_and_slide 调用方，每物理帧最多一次。表现订阅事件，不能决定玩法结果。
参数可配置；新能力使用资源策略和能力配置，不能在关卡中硬编码玩家脚本。固定/生成关卡共用对象契约。正式每大关10小关/第10 Boss，3关仅development_only测试。按docs/roadmap.md的P0–P6推进，生成晚于LEVEL-02新固定关卡真机验收；不把Health、商店、Boss、家园和存档一次全部实现。

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

用户已授权连续完成多个依赖满足任务至可玩demo框架；按P2/P3/P4分别实现、检查后集成，仍禁止未验证的一次性全系统改写。默认入口`scenes/demo/demo.tscn`为开发3关HOME/战斗/分支/Boss/金奖励/家园闭环。`scenes/test_levels/graybox.tscn`与WorldContext只保留明确LEGACY测试路径。新增任务不得把选择性SegmentRespawn改回全场reset，也不得用旧机关即死测试代替新流程。

开发fixture的价格、血量、掉落、交互式金领取、家园NO_TRANSFER只是演示配置，Q001–Q013继续待决策。正式10/Boss10不可改为3；GEN仍等待LEVEL-02真机固定挑战。当前Meta只存进程内摘要，没有SaveService/永久购买/剧情/Steam集成；结束时逐项记录技术验证与真机待验。
