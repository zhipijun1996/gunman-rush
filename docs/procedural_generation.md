# 模块化生成与内容复现

本文件为生成架构与约束权威。2026-10-10用户确认初步验收完成，并授权开始随机地图设计，明确小关允许横向、纵向、方形等空间组织。新增要求优先于旧“只有横向串接”的隐含假设。生成架构设计已交付；运行入口仍为固定3/10关，另有MODULE LAB提供四个静态与两个动态模块样片；实际Motor证据分别记录。未实现LevelGenerator，样片不能冒充完整随机生成。初验不冒称Android/iPhone分别三次通关或20分钟性能记录。

## 参考与原创转换

参考[社区Wiki白色宫殿／苦痛之路](https://hollowknight.wiki/w/White_Palace#Path_of_Pain)（2026-10-10实际读取正文）：锯轮、尖刺与狭窄墙段组织连续空中挑战，原作使用包括骨钉弹跳在内的移动能力。资料只用于理解挑战组织，不作为本项目尺寸或官方物理参数来源。

采用的设计语言：进入挑战前看见危险；先单一动作、后组合；连续空中段结束于可读安全落点；空间高低差形成路线记忆；危险周期可观察。原作壁跳/冲刺/骨钉弹跳替换为现有可配置跳跃、向下/斜向射击反冲及经验证补充对象。原创地形/符号/角色/美术，不复制地图、素材或音乐。既有段回退/扣血规则不变，不复制原作资源补给规则。

首批8种蓝图详见[模块目录](platforming_modules.md)，[原创模块示意](diagrams/platforming_modules.svg)与[整关形状示意](diagrams/stage_topologies.svg)。图中坐标是展示用布局，不是可执行碰撞尺寸或已验证关卡。

## 三个独立维度

`BiomeDefinition`选主题/机关/敌人内容池；`StageTypeDefinition`选完成/奖励/商店规则；`LayoutProfile`选空间形状和拓扑。`DifficultyProfile`给出平台/战斗/时间压力及容错预算。它们通过内容兼容标签组合，火山金币关可以纵向，机械城战斗关可以方形；不把“商店=横向”写进类型分支。

形状描述世界AABB和长宽比，不依赖手机屏幕像素。首版横向/纵向/方形为独立模板，未来可扩展L/U形、蛇形、分叉与环路。空间外形不等于路径：方形可有上下折返；横向也能有高低支路。Boss必须匹配已有战斗模板核心，不能为了形状随机旋转核心。

| LayoutProfile 候选 | 路径语法 | 必须验证 | 首版范围 |
| --- | --- | --- | --- |
| horizontal_chain | 安全入口→2–3挑战→安全奖励/出口区 | 接口速度、落地恢复、末端双出口均可达 | GEN-LAYOUT首个实现 |
| vertical_ascent | 下入口→交错落点→向上反冲段→上部出口区 | 高度/头顶、上升剩余动作、坠落安全段和镜头预告 | 第二个实现 |
| square_loop | 主环路+一条可选支路，出口在共同安全区 | 没有单向落坑困局，两出口可达，回环不刷奖励 | 第三个实现 |
| descending_switchback | 上入口→交替下降段→底部安全区 | 终端速度、停止距离、视野下方落点、不可逆落差 | 先模块样片，后拓扑 |
| branched_hub | 安全枢纽→主挑战与可选挑战→汇合 | 主路有最低能力解、支路收益一次结算、回枢纽安全 | 后续扩展 |

横向/纵向/方形都是支持目标，首个可玩切片只接横向，随后分别验证纵向与方形，不用第一种通过推断全部通过。不自动90度旋转模块（重力不旋转）；镜像也须重新验证反冲/碰撞/机关相位与敌人可读性。平移是首版默认组合操作。

## 生成流水线与职责

`RunDirector → RoutePlanner → GenerationRequest → LayoutPlanner → ModuleAssembler → LevelValidator → LevelDefinition → StageFactory`。

- RunDirector拥有索引、胜负、epoch，仍正式10关/Boss10；RoutePlanner拥有两出口与节奏，不负责摆平台。
- GenerationRequest固定当前主题/类型/能力快照/地图seed与版本，不能读取正在变化的全局玩家。
- LayoutPlanner从兼容LayoutProfile构建有向ModuleGraph：入口/挑战/安全区/交互区/出口节点，主路与可选支路显式标记。
- ModuleAssembler选择RoomDefinition、匹配端口和接缝、平移世界对象并分配stable_id；不得修改PlayerMotor。
- DifficultyProfile提供预算，内容选择器在预算内选经验证变体；类型完成条件仍来自StageCompletionRule。
- LevelValidator验证几何、动作/资源、动态时间窗、安全段与规则；返回类型化错误、已选择尝试号与验证版本。
- StageFactory实例化已经验证的LevelDefinition，接入现有DamagePolicy/SegmentRespawn/奖励/交易/Boss服务。现有DemoStage先保留固定模式作为回归与保底消费者，避免大改PlayerController。

这些是计划接口，不是本轮已创建空服务；仅在下面对应任务有实际消费者时实现。

## 数据契约

| 定义 | 必需信息 |
| --- | --- |
| LayoutProfile | id/version、形状/拓扑、world_bounds约束、节点数量预算、主路/支路/汇合规则、入口与双出口候选区、camera_profile_id |
| RoomDefinition | id/version/content_hash、场景与AABB、禁止重叠包络、入口/出口ports、平台/战斗/时间标签、最低能力、支持变体与类型/主题兼容标签 |
| ModulePort | stable_id、局部位置/朝向、净空、地面/空中到达、normal/recoil入口速度区间、跳跃/射击余量及冷却、下一安全落点、机关可进入相位窗口 |
| ModuleGraph | stable节点/边ID、模块变体与世界变换、主路/可选支路标识、reward-group ownership、出口可达证明索引 |
| DifficultyProfile | id/version、阶段预算、各类型修正、连续高压上限、恢复段预算、变体权重；具体平衡是候选 |
| GenerationRequest | run/stage token、biome/type/layout IDs、stage_index、capability_snapshot、difficulty_profile及实际预算、map seed、全部算法/内容/物理版本 |
| LevelDefinition | 版本、world_bounds、StageEntry、SegmentAnchor列表、模块/连接图、实例化对象/相位、奖励与商店绑定、两个出口、Boss模板与CameraProfile引用 |

能力要求按0/N和实际Modifier结果求解，不能硬编码必需二跳两枪。每模块必须交代进入状态和离开状态；“模块A单独可过、B单独可过”不保证A→B可过。安全落点能恢复现有动作次数，但不凭空恢复HP/精力或刷新世界账本；无地面连接需明确动作余量和冷却。正式精力用途未定，必经路线不得要求慢时开启或精力满。

## 按房间类型组装

| 类型 | 空间配方（候选） | 压力与结算约束 |
| --- | --- | --- |
| combat | 入口预告→平台/战斗模块→安全双出口 | 平台高压与同时活跃敌人错峰；当前完成规则仍defeat_targets |
| coin_reward | 一条基础可达主路→一次金币领取区；以后可选风险支路 | 首片仍现有单份金币fixture，不把支路多次取币功能冒称已完成 |
| health_reward | 短低压入口→安全领取区→出口 | HP恢复/最大HP效果独立；当前只HEAL_CURRENT fixture，Q004不变 |
| item_reward | 可配置短挑战→安全二选一→出口 | 不移动领取规则；组账本一次结算，未选项不能从另一支路再取 |
| shop | 短可达入口→安全交易区→两个出口 | 平台/战斗预算0或低；不在交易界面背后生成活动攻击 |
| boss | 验证入口→固定核心及必要躲避区 | 随机外围只匹配Boss攻击模板，双死优先规则/金奖励不变 |

类型名称不决定强制跳跃难度；第8关商店仍安全，不因索引高变成必经高压机关房。类型新完成条件/额外风险奖励必须单独确定Q013及账本契约后才实现。

## 难度曲线与路线节奏

详见[难度配置](difficulty_profiles.md)。平台P、战斗C、时机T和容错R分别配置，不用单一数字同时加窄平台/加敌人/缩短时间窗。形状不是难度倍率：纵向初级房可以比横向高压房容易。优先增加动作组合、可读时机与敌人组合，不偷偷更改人物速度/重力/反冲，首版不按玩家装备自动抬高敌人HP抵消成长。

RoutePlanner按阶段权重和最近房间历史生成可选类型；约束只能筛类型候选，不暗中更换用户选中的房间，不绕过Boss。追加奖励抽样不污染地图/路线。实际预算、路由约束、候选/选择、模块变体均写Manifest。

## 相机与手机读图

现有固定单屏不支持任意大世界，必须在GEN-LAYOUT实际加入CameraRig后再启用非单屏关卡。CameraRig只跟随/夹取LevelDefinition.world_bounds，不移动人物；横向前视、纵向上下预告、方形汇合处视野过渡分别配置。朝向切换有滞回，禁止以突然镜头移动提升难度。

看不到落点的盲跳不能成为必经解；允许在安全平台观察下一段或增加预告区域。首次纵向验证必须覆盖高速下落/向下开枪上升/顶部和底部夹取、触屏杆与HUD遮挡。鼠标瞄准使用世界坐标，触屏/手柄方向仍统一Router；镜头移动不能改变已缓存发射方向。不同屏幕只改变可视范围/UI布局，不改碰撞几何和资源。

## 有界验证、保底与复现

顺序：几何接口与重叠→在现有Motor上的动作轨迹/资源验证→机关相位/敌人攻击时间窗→完整主路及两个出口→安全出生→批量Seed回放→真实手机抽样。

首版先以预录合法动作意图验证每模块和接缝，再用有界状态搜索检查少量变体；不能用仅A*几何连通或单个理论跳高推算替代真实Motor。状态包括位置、normal/recoil速度、Health、动作余量/冷却、危险相位与能力快照。验证器的上限/超时是显式结果，不记为“可达”。支持能力削弱/0次数时筛可兼容主路，能力过强也检查顶撞和越界；不能依靠角色受伤穿危险保证可达。

重试次数/每次节点上限/验证tick与时间预算配置化。失败使用同主题、同类型、能力兼容的已验证保底图；没有保底显式报告错误，不换房间类型、不无限重试。具体上限在性能任务实测确定。

map/route/reward/shop/boss_pattern独立随机流。记录完整版本化RunManifest：形状/拓扑、图节点与边、模块ID/version/hash与变体/变换、world_bounds、实际难度预算/曲线版本、CameraProfile、初始对象相位、能力快照、验证版本/结果、attempt_index、fallback_id及原因，再保留已有配置/路线/奖励/交易/Boss结果。旧版本缺失明确不兼容，不能重新抽样冒充恢复旧地图。回退不重新生成当前小关。

## 实施顺序

GEN-DESIGN-01（本轮设计）→GEN-MODULES-01（8种蓝图分批做固定样片，先safe_hub/stepped_crossing/descending_switchback，后recoil_shaft）→GEN-LAYOUT-01（横向可玩切片，随后纵向/方形与CameraRig）→GEN-DIFFICULTY-01（类型预算/路线节奏）→GEN-01（完整集成与批量Manifest验证）→LEVEL-GEN-01（生成关真机）→LOOP-01。

初验记录与原固定挑战详细设备验收分别管理，不伪造全部设备已通过。本轮不改物理参数，不把所有模块、生成器、相机和难度系统一次性实现。
