# 四层设计契约 v1

最终独审补强：`technical.status=passed` 必须同时附匹配的原生raw与outer `receipt.json`（各自实际SHA），并复用原runner的完整实际source/input闭包、真实Godot二进制、日志绑定和终态验证。仅有producer/catalog/tuning一致但Controller或其他依赖漂移的旧raw，只能作为历史观察，不能签当前源通过。`near_reward` 是走近后直取奖励位置的独立策略，与 `direct` 一样不要求地图出口；它不代表完整奖励回程。

这是现有关卡对象的离线设计 sidecar。`schema_version: 1` / `artifact_kind: level_content_bundle` 的机器词汇见 [content.schema.json](content.schema.json)，语义校验与命令入口见 [level_content_contract.py](../../tools/level_content_contract.py)。不替换 `PlatformingModuleDefinition`、森林工厂、区域 Manifest、RunManifest、PlayerMotor 或原质量记录，不修改正式地图入口和存档格式。

| 层 | 负责的体验 | 对应现有运行对象 | 何时使用 |
| --- | --- | --- | --- |
| Cell | 一种空间、动作、机关或交互原语及其接触语义 | Definition 中平台/刺面/锯轮/摆渡，森林工厂中的宿主/果实/钩点等 | 有独立可复用的操作面或关系时；不是强制按每个矩形拆对象 |
| Module | 独立动作挑战：观察、选择、起手、承诺、接收与恢复 | 现有 `.tres` 模块或森林独立工厂结果 | 可独立验证一个玩家目标时 |
| Macro Module | 多个挑战共同负责的段落、状态、连续资源、分叉回环和节奏 | Foundry itinerary、区域 route/场所/段落的现有组装结果 | 跨模块责任无法由单个 Module 解释时；单纯再包一层不构成新内容 |
| Map | 地区探索拓扑、能力锁、授予、奖励与返回关系 | 平原/森林生成器输出、现有区域 Manifest | 解释完整地区目标及其真实消费者时 |

Macro Module 是可选的设计单位，不要求 `Cell → Module → Macro Module → Map` 逐层包装。Map 可直接引用 Module、Cell 和 Macro Module；Macro Module 可引用 Module/Cell；Module 可引用 Cell；Cell 不再嵌套内容。依赖严格向下，禁止自引用及组合环。不要为满足层数把普通两平台模块包装成四份内容。

`identity.composition_status=legacy_atomic` 允许现有复杂模块先以原始 Definition 为边界导入，保留 `identity.elements` 中实际观察的组成对象；这明确表示尚未完成 Cell 分解。`decomposed` 的非 Cell 对象必须有真实 `parts`。两者都不能把推测的几何抽象称为已运行的新 Cell。

## 数据与身份

Bundle 包含 `capability_catalog`、`contents`、`connections`。每个内容有稳定 `id`、正整数 `version`、四层之一的 `layer` 和 `region`。ID 在同一 bundle 内唯一；内容变化须增加版本并保留 `lineage.parents`、`variant_family`、`changes` 与原失败 artifact。删除或隔离旧候选用 `quality.admission=discard`，不覆盖原失败数据。

`identity` 记录名称、目标玩家体验、玩法基因、组成状态和实际元素。`parts` 绑定内容 ID、层、版本与实例平移；本地引用必须真实存在，外部引用必须附来源路径和 SHA-256。外部绑定校验原字节，不声称该文件已被正式消费者加载。`runtime` 只指向现有 `consumer/format/binding`，不产生第二套运行格式。`integration=formal_source` 仅表示源对象的正式使用声明，和当前候选的准入分开。

`provenance` 保存仓库、完整 40 位提交、来源 artifact 的完整 64 位 SHA-256 和许可说明。传 `--root` 时实际读取所有绑定字节，拒绝缺件、哈希漂移、绝对路径、目录逃逸及符号链接逃逸。省略 `--root` 仅验证设计声明，不得因此报告证据已核验。

## 玩家目标、玩法关系与难度

`design.goals` 描述可观察的玩家目标；`actions` 记录动作 verb、目标、前置动作、玩家判断、成功和失败条件，拒绝悬空或有环的动作依赖。`interactions` 的两端须属于真实元素、动作或组成实例，用关系表示“这一枪同时开门并反冲”“先观察摆渡相位再选择发射时机”等耦合。名称或基因标签只表示设计假设，不能证明创新。

`difficulty` 沿用 map-edit 的 `gunman-rush/module-difficulty/v1`，1–10 或 `null`，`basis` 记录判断依据。未评估保持 `null`；不能把动作数、机关数或工坊配置自动换成真人校准难度。`tolerance`、`rhythm`、`recovery` 和 `alternative_solutions` 解释容错、动作链中的停顿、失败回收与替代解。静态填写不证明这些意图在真实轨迹中发生。

## 多入口、多出口与状态连接

`ports` 是多端口集合，方向为 `entry/exit/both`。位置使用玩家完整身体中心，沿用 `PlatformingModulePort` 语义；每个端口还声明 `velocity_x/y` 闭区间、角色 `states`、资源闭区间、所需/保证能力、相位和坐标系。数值必须来自源 Definition 或具体运行采样，不在此复制 PlayerTuning 默认值。

`connections.from/to` 指定内容与端口以及各实例 `offset`。语义校验要求出口和入口在实例坐标系中相接，出口速度、角色状态和资源的**完整保证范围**都被入口接受，所需能力已在出口保证集合中。仅区间交叉不足以保证所有出站状态都可接续。非空动态相位必须一致；不同相位应保留拒绝，另跑真实连续输入再设计连接。

这些是连接声明约束。满足它们不代表碰撞净空、可站立支撑、危险扫掠、真实冷却或动态相位已经验证。原 `PlatformingModuleDefinition` 保留 canonical `entry_port/exit_port` 与 `entry_ports/exit_ports`；映射时由现有消费者选择真实端口，sidecar 不改写其数据。

## 能力、资源与拓扑

`requirements` 的 `all_of` 为 AND；`any_of_groups` 组内 OR、组间 AND，空 OR 组拒绝。`status=unspecified` 仅允许全空要求；`partial` 表示已知约束但不保证最低需求完整；`defined` 才可把空条件解释为无能力锁。资源区间引用真实资源名和观测范围，声明不是资源恢复证据。

`topology.nodes/edges/entry/goals` 表达主路、支路、奖励、回程和回环；每边有能力要求、通过后 `grants` 与风险收益说明。`available_capabilities` 是该拓扑入口的实际授予集合，必须独立于工坊最大能力配置。校验从入口探索能力状态，能力只在合法通过边以后授予，拒绝“用边后的奖励证明能通过该能力锁”和不可达目标，限制状态搜索预算。该图不证明真实空间可达，也不以资源声明推断无限补给。

## 三类证据与原准入流程

`evidence.technical`、`evidence.ai`、`evidence.human` 分栏：

- 技术轨：`unverified/passed/failed`，方法为 `unverified/structural/real_motor`，绑定具体 scope 与 artifact。`passed` 必须有实际读取的原生 Motor 观测收据；只写 `passed:true`、静态评分或几何可达均拒绝。
- AI 轨：`unreviewed/reviewed`，必须注明 reviewer 与具体 findings。AI 可以判断为何改、应保留何种决定、哪些疑点需反证；不代签真人趣味和设备手感。
- 真人轨：`unverified/accepted/rejected`，判定必须附真实来源 artifact；没有试玩保持 `unverified`。证据文件有 hash 只证明字节身份，不证明其作者、观点或效力。

技术收据目前只注册本轮 `level_pilot_validate.gd` 原生格式的窄适配，其他生产者先保留 `unverified`，不猜测旧日志含义。适配要求 `raw.id == raw.candidate == content.id`、实际 runtime consumer 和 scope 完全匹配；原 `exit_code:0`、`passed/ok/driver_reached/actual_goal/entry_contract/audio_released:true`、空失败/危险接触；逐帧位置/速度/资源有限、`motion_steps == frame`、真实 requested/accepted 动作数组以及最后 grounded。非 direct 路线还须真实出口合同与末帧位于原 main-route 最后 anchor 的接收范围，reward 路线须实际奖励位置与回程均成立。初始 fixture 放置明确允许；中途注入、资源覆盖和额外手动 Motor 步拒绝。

原生 producer SHA 必须对应当前 `tools/level_pilot_validate.gd` 并出现在 `content.provenance.artifacts` 中，catalog 和 PlayerTuning SHA 对应真实原字节。自定义搜索 catalog 使用 raw `catalog_path`，旧原生记录缺该字段时仅绑定默认 `config/level_pilot_candidates.json`。从实际 catalog item 与 raw candidate/strategy/variant/tuning 重建原 `input_identity`，按本轮 Godot 的排序紧凑 JSON 字节重算 `input_fingerprint`；换候选、换条件、换输入或源漂移均拒绝，不用 wrapper 的绿色标签替代原件。

`source_fingerprint` 保留原 FoundryCatalog.basis 身份，原 wrapper/Harness 仍负责完整运行源闭包、进程终态、动作因果和正负例检查；此读取器不重建第二份 Godot 模拟或通用源闭包实现。本工具不能给自行编造的 JSON 提供真实性背书。契约通过只能说明匹配格式和绑定的证据声明有效，不能提升为正式地图、真实奖励交易、设备或真人趣味认可。

`quality.admission` 只允许 `candidate/review/rework/discard`。**没有 `formal` 状态**，因此 sidecar 无法授予正式池准入；引用 `quality_record` 只是链接现有十一维记录与 G0–G5，不能绕过原流程。原型技术通过、AI 值得保留与真人认可都必须单独报告。正式准入仍由现有政策及真实消费者决定。

## 执行与迁移

```sh
python3 tools/level_content_contract.py path/to/content-bundle.json --root .
python3 -m unittest discover -s tests -p test_level_content_contract.py -v
```

Python 调用入口是 `validate_bundle(data, root=None) -> list[str]`；`make_content(id, layer, region, runtime_path, source_commit, source_hash)` 提供诚实的未评价模板。模板没有伪造动作、难度、测试和真人认可，调用者填入真实提取结果及评价。返回 `valid_design_declaration` 不能转述为已通过物理/趣味/正式准入。

旧内容渐进迁移：冻结源提交与原数据 → 按既有消费者建立 sidecar → 保留 partial/unspecified 和未评级 → 对有责任边界的片段补 Cell/Module/Macro 分解 → 把物理观测与 AI findings 分开写回 → 沿原质量记录审查。v1 不自动反写 map-edit 工程，不静默降级不支持的弧轨/机关，也不把 177 份参考都重造为新内容。
