# Codex 工作规则

## 权威来源

产品目标：docs/game_design.md。世界/地区/剧情/风格上位锚点：docs/world_and_story.md；区域候选白名单：docs/world_regions.json（design-only），来源docs/references/recoil_roguelike_handoff_v02.md。正式运行/路线：docs/run_and_routes.md；奖励/道具/构筑/商店：docs/rewards_and_builds.md；血量/两类伤害/段回退/真正死亡：docs/damage_and_respawn.md；家园/永久成长/存档：docs/home_and_save.md。物理规则：docs/player_mechanics.md。输入：docs/controls_contract.md。资源：docs/combat_and_recharge.md。当前原型移动/射击/慢时参数唯一来源：config/player_tuning.json；后续Character/Weapon/Health/Stamina Definition按stat保持唯一基础来源，旧配置只作兼容映射，禁止两份重复默认值；输入参数唯一来源：config/input_profile.json（InputProfile读取）。原 aim_deadzone 已迁移为设备各自死区，不在物理参数中维护副本；开发 Resource 时同步文档引用，不维护两套数值。
生成与空间权威：docs/procedural_generation.md；模块蓝图：docs/platforming_modules.md；难度/路线节奏候选：docs/difficulty_profiles.md；大场景挑战/学习曲线/地区模块与禁用组合：docs/biome_challenge_design.md。模块草图不等同可玩地图。
代码模块分类/当前框架：docs/module_map.md；仅导航与接入状态，不覆盖设计。任务状态：docs/tasks.md；验收证据：docs/acceptance_tests.md 与 docs/handoff.md。

## 执行流程

读取规则与当前 Git 状态 → 选择依赖满足任务 → 创建 feature/fix/docs 分支 → 小范围实现 → 验证 → 修复 → 更新状态和证据 → 提交并推送 → 创建 PR → 继续可独立任务。
用户已授权项目内文档、可逆实现、验证、分支、提交、推送和开发任务管理。日常工作不逐项请示。默认不自动合并 PR、发布商店、使用付费服务或更改核心玩法；这些需明确授权。禁止强推、覆盖用户改动、提交密钥。

## 实现约束

Godot 4.7.2 Standard + 类型化 GDScript；先验证安装版本再创建工程。文件 snake_case，类型 PascalCase。组合优先；不用没有实际消费者的框架。输入不得改人物位置。PlayerMotor 是唯一 move_and_slide 调用方，每物理帧最多一次。表现订阅事件，不能决定玩法结果。
参数可配置；新能力使用资源策略和能力配置，不能在关卡中硬编码玩家脚本。固定/生成关卡共用对象契约。正式每大关8小关/第8 Boss，3关仅development_only测试。按docs/roadmap.md的P0–P6推进，用户已确认初验并授权生成设计，GEN-DESIGN/固定模块样片可推进；2026-10-10用户明确要求先尝试随机拼接整关效果，GEN-PREVIEW-01可在详细设备验收前做独立开发试玩；本轮D054用户明确授权平原正式8关生成与最小永久币切片按任务分阶段实现，生成关真机独立验收且不假装通过；不把Health、商店、Boss、家园和存档一次全部实现。

## 验证与完成

每次运行 `python3 tools/check_docs.py`。创建工程后运行 `godot --headless --path . --editor --quit`。M1 必须新增有失败退出码的 tests/run_tests.gd，然后运行 `godot --headless --path . --script tests/run_tests.gd`。
针对改变运行必要测试。记录命令、版本、退出码、提交与输出；未执行写未验证。禁止降低标准、删除失败测试来伪造通过。输入和手感真机验收由用户实际试玩，不可用 headless 代替。
任务完成需实现、相应检查通过、文档同步、证据和提交齐全。需要真机的任务保持 awaiting-device，不能标 done。

## 会话恢复

结束前更新 docs/handoff.md：分支、提交、已完成、失败、阻塞、下一任务与命令。阻塞时推进独立工作，不声称后台无限运行。没有用户明确要求，不启用子代理。

## 新增权威契约

整体风格：docs/visual_and_gamefeel.md。可增减能力：docs/ability_components.md。地图对象：docs/world_components.md。敌人/Boss：docs/enemies_and_bosses.md。M1 起次数数据化，能力组件与 Motor 分离；不把第三跳拒绝写成普遍规则。世界组件可独立实例化；敌人 AI 不依赖玩家输入；Boss 不在玩家脚本硬编码。

## 正式肉鸽新增约束

新用户设计优先于冲突旧规格，已修正权威文档；历史报告/旧测试通过不代表新规则完成。D027–D031为暂定策略，Q001–Q016待决策，不擅自升级为用户确认。docs/design_contract.json用于文档结构检查，不是运行时配置。

Health/Stamina/ActionResources独立，正式精力用途未定，不给移动/跳跃/松手射击加精力消耗。既有AirFocus/遮罩保留原型实验；正式消费绑定另定。不同枪发射方式未定，不自动连射。

环境存活伤害段回退、零血RunEnd回家园；旧机关直接die与整场reset只允许显式Legacy测试。段回退不重置敌人/机关相位/补给/奖励/商店账本，不复用WorldContext.respawn全重置。Run/Stage/Actor epoch分层，死亡取消未结算奖励与延迟回调。胜负/伤害批次/二选一/交易确定性且去重，不能靠回调顺序。

RunState/BuildState与MetaProgression、RunCoin与MetaCurrency分离；未定兑换不自动转币。随机流分离并记录完整版本化RunManifest。局部服务与类型化事件，禁止万能全局事件总线/大量类型switch堆Loader。道具修改来源Modifier/组件，从基础重算、可撤销，不直接累加玩家字段。只在实际任务有消费者时实现最小接口，不创建全套空框架。


## 当前固定 demo 入口与迭代范围

用户已授权连续完成多个依赖满足任务至可玩demo框架；按P2/P3/P4分别实现、检查后集成，仍禁止未验证的一次性全系统改写。默认入口`scenes/demo/demo.tscn`为TITLE→可操控Home→正式平原8关独立随机；DEVELOPMENT DEMOS保留3关development_only快试与8关固定大关试炼。固定/生成模式共用六类房间与伤害/构筑/奖励契约；8关第7两个出口必进Boss8，金奖励后以biome_complete回家园，Meta.completed_biomes独立累计，禁止把一大关完成算成完整游戏成功。`scenes/test_levels/graybox.tscn`与WorldContext只保留明确LEGACY测试路径。新增任务不得把选择性SegmentRespawn改回全场reset，也不得用旧机关即死测试代替新流程。

开发fixture的价格、血量、掉落、交互式金领取、家园NO_TRANSFER只是演示配置，Q001–Q016继续待决策。正式8/Boss8不可改为3；用户已确认初验，生成设计/模块样片进入GEN-DESIGN/GEN-MODULES；详细分设备证据仍独立跟踪，不把初验当全部设备/性能通过。旧固定fixture的Meta只存进程内摘要；本轮音符永久钱包/一种demo升级/最小SaveService有实际消费者，剧情/Steam集成不实现；结束时逐项记录技术验证与真机待验。

DemoMenu只负责展示/请求，App拥有暂停、动作取消和输入配置应用。主页/暂停/设置/帮助/构筑/返回确认必须保留；返回Home明确确认，不提供旧整关reset快捷按钮。五项输入滑条需Apply、只在当前会话保留，默认值仍唯一来自config/input_profile.json；不声称已实现持久设置或SaveService。金币房10金币/回血房恢复当前2HP仅fixture，不锁定正式奖励规则。

生成设计：空间LayoutProfile与主题/类型解耦，支持横/纵/方形，禁止直接旋转横向地形改变重力。模块端口包含动作余量/速度/相位；逐步实装CameraRig与实际Motor验证。难度P/C/T/R候选，不偷偷改角色物理；主路不依赖慢时/未有能力/损血穿越。设计图/几何连通不能冒充物理通过；同类型能力兼容保底、有界失败、Manifest实际布局/预算/版本必须保留。

当前静态模块消费者：主菜单MODULE LAB，八个独立模块/端口Resource复用真实Motor/输入/段回退。练习不会结算Run/Meta奖励；RETRY或模块选择显式新尝试，环境存活回退保留HP/精力/冷却/补给/计时与实例。GEN-MODULES技术交付review，不把八个样片视为完整随机生成或三拓扑镜头验收。

动态样片：PlatformingModule局部游戏clock保留段回退相位；ModuleSawHazard提交FrameDamagePolicy环境伤害（不调用Legacy die），不同实例接触source隔离。ModuleMovingPlatform以AnimatableBody2D经Motor碰撞携带，不直接搬玩家；静态危险接触与动态全包络安全验证分开。新模块轨迹逐phase验证，不以Geometry/Definition筛选替代真实可达性。

Boss样片ModuleBossTrial局部BuildState/RewardService可授本次练习GOLD一次，离开丢弃，不更新Run/Meta。缓冲区拒绝双方战斗伤害、核心射出子弹按开火资格与epoch校验；允许练习撤退是候选消费者政策，不擅定正式封门。Boss同帧与玩家死亡优先Home且无金奖，切换/死亡/离开立即取消旧弹体。

随机整关试玩授权：主页RANDOM STAGE独立development_only消费者，可平移不等尺寸的微模块与精心编排大模块组成横向多段关卡，端口直接重合、不得额外生成绿色接桥或中间ENTRY/EXIT标记，保留世界镜头、Seed重试与关内锚点；不伪称正式六类型/十关随机集成完成。段回退保持同一Manifest和实例，不重新抽图/刷资源。本轮用户D054授权平原8关生成消费者先行实现；详细设备门槛继续单独保留为验收，不作为新授权实现范围的隐含禁止。


当前生成试玩追加D045/GEN-CHALLENGE-01：用户要求显著高落差、远平台、连续上升交错移动平台与机关。先保持已验证无缝拼接基础，再真实Motor/反冲弹体/平台携带轨迹验证后入池；不可改核心物理、凭空补资源或删除无损/扫掠断言以容纳挑战。新增真实物理覆盖可提高明确测试时间预算，仍必须有界且失败非零。


平原美术：用户授权接入feature/demo-plains-art风格作为首个大关候选。docs/demo_art_route.md及各art文档为素材锚点/来源/视觉语义权威，不覆盖物理/输入/Run规则。皮肤仅表现，不用图片尺寸替换碰撞或重抽关卡；任意模块尺寸端头不拉伸，前景不遮落点/危险。后续模块沿用此风格与连接契约。SVG简化demo表现与painted母版区别明确，真机最终验收保持待验。


新世界交接整合：反冲位移与平台操作是体验重心，敌人/Boss服务动作压力；平原为固定首区，六层/16地区是长期候选，正式总数/工作名/主角身份/结局不擅定。大关选地区与小关选类型独立，未实现内容不开放；发光花意象对应Home，不替代段内安全锚点。已有攻击弹体、跳跃配置、死亡/回退/Modifier与永久升级方向保留，正式精力用途继续未定。每次文档检查同时验证世界设计，独立命令python3 tools/check_world_design.py；不能把图可达当真实角色可通关。

## 2026-10-10 美术精修反馈

用户明确对当前运行美术不满意，认为不够精美。现有简化SVG作为技术可用占位，不能视为用户视觉确认或最终风格；已有接入/物理验证保留。世界观与各区场景介绍以docs/world_and_story.md和world_regions.json为锚点，正式品质与制作门槛见docs/art_quality_target.md。先制作平原合屏黄金样板，用户视觉认可后再批量精修；材质/云层/角色/机关统一，不能靠增加资产数量代替精美。精修只改表现，不变碰撞、端口、相位、资源和输入。场景扩写为候选，不擅定身份/结局或开放16地区。


平原生成必须按跳跃与位移实际性能筛选，解析包络不冒充真实Motor证据。用户后续金色道具解锁贴墙缓降见docs/wall_slide_design.md；不默认向上攀爬/墙跳/耗精力或贴墙补动作次数。后期必需路线需前置确定授予与门槛验证，当前平原无此要求。


D054/D055本轮范围：最新手绘平原资源只作表现，不覆盖Motor/碰撞；每关独立随机且类型影响布置。金币局内、音符永久分离，无默认兑换；音符保留/升级数值D056为demo暂定。最小永久存储需错误拒绝、版本/备份/幂等实际验证，Web刷新和原生平台各记证据。最新角色稿不具备独立枪瞄准时可保留现有正确独立枪表现并报告，不误导为角色候选已全套验收。

D058本轮迭代权威补充见docs/plains_polish.md及docs/title_home_ui.md：最新PR33只选择性导入资源与契约，运行家园复用真实Motor；正式平原左下出生/局部模块镜像/空间分散出口触发奖励、道具弹窗。慢时确定0.20、地面反冲降低且空中保留，候选镜头比例不改变世界碰撞。Web冷/热加载需实际传输证据，缓存更新不清永久存档。

## D060 当前反馈权威

用户最新十项要求优先于D054/D058冲突部分，见docs/plains_eight_revision.md：正式8关/Boss8；靠近出口显示奖励与进入/留下确认，确认前不得领取或切关；自然色多层平原远景；空间分岔/汇合/折返优先于继续加直线模块。历史十关任务ID和报告保留溯源，不作为当前规则。新原创素材仅改变表现，尖刺以荆棘表现但危险体积不扩大；受伤表现不增加击退。

## D062 当前分岔与移动端反馈

新增权威见docs/plains_branch_revision.md：非Boss不强制全清；中途分岔通向两条路线末端门，不在中途放出口。模块量、反冲/摆渡/机关组合是本轮重点；浮动摇杆、跳跃键右置、接触回血与独立击杀掉落流按A81–A86验证。视觉放大不改变碰撞；具体掉落概率与镜头为demo暂定。


D063：手机输入权威见controls_contract与唯一InputProfile/PlayerTuning；JUMP大命中区、稳定两档、基础速度现由D068降速校准，须保持真实Motor验收。变化度后续设计见docs/plains_variety_design.md；默认正式新局产生新种子，显式种子继续复现；多骨架/段落语法/去重未实现前不可标为完成，不以layout hash变化量冒充玩法多样性。

D064权威补充见docs/plains_encounter_revision.md。用户已确认：平原默认一段跳，后期每大关获得一个新能力；具体能力/发放时点/跨局保留待定。分岔告示牌显示实际出口下一房型，不结算奖励；早期奖励不随机恢复二跳。通用N跳能力保留，高级双跳模块按能力过滤，不通过删测试冒充一跳可达。

D065本轮趣味性迭代权威见docs/plains_playful_blueprints.md：实际横渡/攀升编排、稳妥/挑战收益、反冲救场及Seed槽位交替；仍是一次分岔，不虚称环路/多重分岔。技术门槛与用户趣味性认可分别记录。

D067最新平原美术与关卡接入见docs/plains_v3_integration.md：美术PR38按资源融合，不覆盖当前玩法；源图交付状态与runtime_integration消费者清单分开。保留门、荆棘、地面甲虫的明确语义，压缩只在Godot导入缓存，原始PNG不改。中期齿轮节奏需实际相位验证。

D068最新实体辨识/降速权威见docs/plains_readability_and_control.md：平原一跳不变、未来二跳低于首跳；降速必须同步实际可达性，不能降低验收。地形支撑新增真实碰撞需manifest版本/明确记录，表现不可误导可穿性。
