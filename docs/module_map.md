# 功能模块与修改入口

这是当前代码的功能导航；实际调用与状态所有权见[运行架构](architecture.md)，迁移和验证状态见[执行记录](worklines/game_architecture_01/execution.md)。文件类型不决定模块归属：专属脚本、场景和可迁移局部资源靠近所属功能；原图、声音与许可仍留在 `assets/`。

| 目录 | 负责什么 | 修改时应使用的现有入口 |
| --- | --- | --- |
| `game/application/` | 正式用户流程、局服务所有权和装配 | DemoApp、RunSession、RunComposition；不新增平行流程或全局服务容器 |
| `game/player/` | 玩家控制、动作能力及专属表现 | PlayerController、PlayerMotor、现有能力；输入仍只提交意图 |
| `game/combat/` | 共用资源状态、伤害、弹体、武器、段回退 | 现有资源与伤害请求/结果契约；不另写扣血算法 |
| `game/loadout/` | 目录、库存、装备、属性与效果族 | 原 ItemCatalogV5/authoring、RunInventory、EquipmentService、BuildState、ItemRuntime |
| `game/enemies/` | 普通怪工厂、行为、物种、状态与表现 | 原 EnemyBehaviorRegistry/EnemyFactory/Definition；地图只调用实体快照/恢复接口 |
| `game/bosses/` | 共用遭遇基础与各 Boss 的专属机制 | 原 BossFactory/Definition 与 encounter；保各自阶段、弱点和时序 |
| `game/economy/` | 本局钱包、报价、购买、修理、扩容与刷新 | RunWallet、ShopService；已有 receipt replay 和库存受限事务 |
| `game/rewards/` | 奖励候选、来源账本、掉落、提交适配 | RewardService、现有池和掉落规则、SupplyHealEffect；不复制余额或另造奖励账本 |
| `game/progression/` | 永久成长、家园、出发携带与发现 | MetaProgression 和原保存事务；局内金币与永久音符分开 |
| `game/world/` | 地图内容协议、原生成器、世界组件和地图状态 | LevelRequest/Plan/Runtime、实际 Provider、原模块目录与版本校验 |
| `game/presentation/` | 跨实体的世界画面、UI、音频、效果 | 既有表现组件、局部音频宿主及 WorldAudioLifecycle；表现不裁决玩法结果 |
| `game/platform/` | 输入适配与存储适配 | 原输入协议和保存格式；不混入玩法或购买政策 |
| `experiments/` | 动作、音频、地形、生成及平台实验 | 各自明确的入口/历史版本/练习政策，复用正式能力；正式核心不反向依赖实验 |
| `config/` | 当前调参、authoring、选择与目录配置 | 更新真实权威字段，不再复制默认值到新表 |
| `assets/` | 原图、音频、字体、来源与许可 | 保持已采用版本；按真实消费者及导出合同审核变动 |
| `tests/` / `tools/` | 原行为回归、内容检查、构建和交付 | 现有 Harness、影响分析、真实 PCK 校验；不平行建第二套运行体系 |

## 常见修改如何落点

- 新道具：先判断是否可由现有 authoring/参数和效果族表达；可表达就不改装备核心。新机制放对应效果族，持久进度仍由库存实例保存，收益仍交钱包/成长权威。
- 新怪物：沿现有 Definition、行为注册和 Factory 创建；专属 AI 与外观归物种，复用已有伤害、生命、碰撞和恢复协议。
- 修改 Boss：改其专属 encounter/Definition，通用弹体或终态政策只有存在同语义消费者才共用；不把不同阶段规则塞入统一大状态机。
- 接新地图：Provider 产出同一 LevelPlan，实例仍由现有实体工厂创建。旧 Manifest/表现/保存适配保持在旧来源边界；新来源的表示和记录适配需在接入时明确，不假设旧 Stage 的私有 Manifest 字段自动适用。
- 新预览：先选择正式组件和明确练习政策。复用 InputSetup 的输入/菜单接线、既有玩家场景、音频宿主及释放实现；仅为独立实验需要保留差异。

## 保留旧路径的例外

部分 `scripts/`、`scenes/`、`resources/` 文件是历史 Manifest 的逻辑身份或原始 SHA 依赖。它们在完成消费者和版本协议迁移前保留原路径/必要字节，不能用同名包装文件复制另一套实现。判断身份看实际注册表、回放和导出消费者，不能只凭目录名或最后修改时间。

实验不是废弃代码，当前正式代码也不应从实验取业务规则。历史证据不作为新代码的第二份参数来源。具体保留/迁移理由和逐文件用途由本次审计索引记录；没有动态加载、导出、实验和回放的完整无消费者证明，不删除资源。
