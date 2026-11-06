# 《失序之钟》类银河恶魔城转型：工程管理与 Codex 交接方案

日期：2026-11-06。审计基线：`zhipijun1996/gunman-rush` 的 `main@48cddb6a70983b0a0206304d18c98d274a9a7549`，以及用户上传的 `world-graybox-kit-v04.zip`。

本文是转型实施方案与首个迁移任务的交接材料。已确认的游戏设计来自用户及附件；本文新增的目录、任务编号、代码边界和迁移顺序是工程建议。本文没有修改仓库、合并 PR、执行 Godot 测试或宣称新世界已实现。执行时先核对最新 main 与本基线的差异。

## 1. 总体决策

在原仓库内完成转型，沿用现有按功能组织的 Godot 工程，以及 `docs/project`、`docs/bible`、`docs/data` 三类文档。保留人物动作、武器实现、敌人和 Boss 组件、表现、输入、UI 基础、存档可靠性机制等成果。

这次工作的核心是替换：

- 随机生成世界及每局路线推进。
- Run 结束清空进度、按图刷新与随机奖励供给的产品规则。
- 仍把上述规则视为强制设计的文档、Skill 描述、自动路由、检查脚本及默认任务。

目标是固定世界、能力解锁后的回访、房间/分区级可达、永久世界状态和明确的休息周期。旧运行代码按消费者逐步替换；旧规则应先退出现行设计入口。

迁移目标不是长期维护两个正式游戏模式。旧原型只承担有明确退役条件的过渡与回归用途。

## 2. 已经存在、应继续使用的管理基础

当前 main 已有以下机制，无需再建一套：

| 职责 | 当前入口 | 维护方式 |
| --- | --- | --- |
| 会话入口与共同规则 | `AGENTS.md` | 简短，保留按任务读取与协作边界 |
| 当前实际实现 | `docs/project/current_state.md` | 只写运行事实、当前入口、已知差距 |
| 任务进度 | `docs/project/tasks.md` | 进度的唯一可编辑入口 |
| 当前任务交接 | `docs/project/worklines/<议题>/` | 沿用该议题已有的一份当前交接，不叠加多份 HANDOFF/NEXT |
| 功能导航 | `docs/project/module_map.md` | 主题 → 代码 → 设计 → 检查 |
| 设计规则 | `docs/bible/` | 整合正文，每条规则只定义一次 |
| 对象规范 | `docs/data/` | 玩家可感知行为、表现、参数来源 |
| 来源与复现证据 | `docs/evidence/` | 按需引用，不作为日常必读 |
| 临时输出 | `build/` | 当前工具输出、日志、录屏和中间报告 |
| 日常 CI | `python3 tools/ci.py` | 现有 project/import/smoke/contracts 四项 |
| 手动专项 | `tools/harness.py` | 按实际改动显式选择 |

当前任务表有 13 个当前议题，并指向 369 项历史任务归档；20 个仓库 Skill 的主体已经相当短。当前问题主要是规则适用范围和自动调用链，而不是缺少更多管理文件。

### 实际发现的冲突

1. `game_design.md`、`regions.md`、`design_contract.json` 仍定义动作肉鸽、六阶段、每地区两图及本局成长。
2. `AGENTS.md`、`development.md`、`content_pipeline.md`、`game-quality-gate/SKILL.md` 仍写着“不设灰盒阶段”。本轮用户决定已覆盖该旧约定。
3. `tools/check_docs.py` 强制两图、第二图 Boss、每局六区和八个初始模块。
4. `tools/check_world_design.py` 要求地区只向下一层连接、路径无环且示例路线长为六。这与新世界的回访和环路直接冲突。
5. `policy.json`、`tools/level_design.py`、`tools/production_loop.py` 仍主动选择并读取随机地区/模块制作 Skill。只改 AGENTS 不能完成迁移。

`check_docs.py` 是文档维护检查/手动专项，并不是当前四项日常 CI 之一。应准确区分每个检查在哪个入口运行。

## 3. 附件的真实范围和权威

附件已提供 16 区域、216 房间、288 连接、310 分区、188 条有向房内通路、22 场 Boss、40 休息点、16 裂缝交通点及唯一奖励/修钟/捷径/结局关系。

只读核验中，主世界 JSON 的房间、连接、区域、动作数量与摘要已核对；整包清单的 73 个被列文件大小和 SHA-256 匹配。主数据原始字节 SHA-256 为：

`c59bd40603624c57a7270e9b2f3233ae472a0a4895764f96fe94a0ea70d8e230`

附件现存检查报告属于数据/图状态验证。本次没有重新执行其完整构建和模拟，亦未在 Godot 中验证跳距、镜头、门台或战斗。

| 内容 | 附件权威 | 工程处理 |
| --- | --- | --- |
| 已确认规则、实施解释、候选参数 | `design/world-graybox-bible-v02.txt` | 按原有主题整合进设计圣经，保留确认程度 |
| 世界身份、连接、分区、能力条件、唯一事件 | `world-room-layout-v04.json` | 唯一人工维护的世界拓扑来源 |
| 收集/成长/装备/休息周期含义 | `design/COLLECTION_SYSTEMS-v04.txt` | 整合到成长、保存和对象规范 |
| 装备来源槽与系统参数分层 | `design/collection-catalog-v04.json` | 通过稳定 ID 引用世界位置，避免第二份空间数据 |
| 逐房场景接口与工作尺寸 | `design/room-graybox-contracts-v04.json` | 生成物；门台、镜头与尺寸须先有明确人工输入 |
| 地图、PDF、PNG、SVG | 图册与地图文件 | 人类阅读视图，不决定真实碰撞 |
| 静态模拟和 QA | `simulation/`、`qa/` | 检查输入/脚本与输出分别管理 |
| v03 来源 | `source_inputs/` | 当前仍有构建依赖，脱钩后才作为纯历史资料 |

### 必须解决的生成链问题

附件允许直接编辑 v04 主数据，但：

- `simulation/build_route_plans.py` 仍读取 `source_inputs/route-plans-v03.json`。
- `design/build_room_contracts_v04.py` 仍读取 v03 世界与合同，部分门方向、场景路径等来自旧数据。
- `build_handoff.py` 仍读取旧世界做一次迁移中的 ID 集合相等检查。
- `migrate_world_v04.py` 从 v03 重建 v04，会覆盖当前主世界；它只适用于迁移重现，不能成为日常重建默认步骤。

因此首次导入要保留内部相对路径和版本文件名。随后专门完成“人工维护输入/派生输出”分离：

1. 把房间工作尺寸、门台、相机意图、场景路径等人工可调整内容提取为现行施工输入。
2. 把当前路线计划保存为独立回归输入，不在每次构建时重新从 v03 推导。
3. 合同和运行包只由现行输入生成，手工修改回到所属输入。
4. 一次迁移的“ID 集合完全相等”检查与长期“已存在 ID 不静默变更”检查分开；允许有计划地新增房间/对象。
5. 确认重建等价后，v03 输入和迁移脚本才退出日常链。

50 个来源槽已经规划，其中灯与抗毒滤芯两个工具已明确；其余 48 件尚未从旧候选中选定并绑定最终效果。保持来源 reward_id 稳定，不代表保留全部旧装备，也不代表只差补装备 ID。价格、部分技能消耗、死亡金币规则等也仍有未决项。不得由代理补成“已确认”，也无需让这些事项阻止纯结构灰盒。

`collection-catalog-v04.json` 是人工维护的非空间规则/装备映射加世界引用，目前没有自动重建它的脚本。世界数据改变后，应先检查相关 action/stock 引用，再更新关联摘要；也可在整理时将输入摘要移入派生 manifest。`build_handoff.py` 只校验这些对应关系，不会自动修复它们；不能只改 hash 让检查变绿。

## 4. 复用与删除边界

### 4.1 可继续作为主体的成果

| 系统 | 实际代码/资源入口 | 复用范围及适配点 |
| --- | --- | --- |
| 玩家移动、反冲、H/W/D | `game/player/`、`config/player_tuning.json`、`resources/player/` | 保留共同手感与唯一 PlayerMotor；能力获得和持久化改为新进程 |
| 输入 | `game/platform/input/`、`config/input_profile.json` | 保留键鼠、触控、手柄意图；补跨房短暂接管与归还 |
| 武器 | `game/combat/weapons/`、`resources/weapons/` | 保留弹体、攻击事件、取消和反冲；成长来源、完整一枪伤害预算按新设计调整 |
| 普通敌人 | `game/enemies/`、`resources/enemies/` | 保留行为、动画、声音和反制；改固定实例身份及休息周期刷新 |
| Boss | `game/bosses/`、相关 `scenes/` | 保留招式、弱点、演出；适配永久胜利、场地重入、奖励与新 HP/节奏 |
| 世界零件 | `game/world/components/` | 平台、索点、锁、危险、补给等继续复用；修改保存与进入/离开语义 |
| 镜头与场景装配 | `game/world/generation/`、`game/world/levels/` 中的共享实现 | 按文件判定；generation 目录不全是随机算法 |
| 道具基础 | `game/loadout/`、`config/item_v5_*.json` | 效果执行、装备容量、UI 可复用；选定效果、重复升级、次数刷新逐件迁移 |
| 经济事务 | `game/economy/`、`game/rewards/` | 复用扣费/授予/唯一收据和幂等；改变本局清空与随机供给政策 |
| 保存可靠性 | `game/platform/persistence/meta_save_service.gd` | 复用校验、备份、版本检查、Web/本地持久化技术；重新定义新世界 payload |
| UI/美术/音频 | `game/presentation/`、`assets/`、`shaders/` | 基础控件、字体、素材族、表现事件可用；地图/成长/休息/交通页面需适配 |

武器/能力/怪物的“实现可以复用”，不意味着原解锁方式、数值、房间分布、存档字段和 UI 文案可以原封不动继承。附件的 Q 也有明确新规则，应作为单独功能迁移。

### 4.2 第一轮就应退出现行入口的内容

- 六阶段、每区两图、选择下一地区、每局结束清空、随机世界拓扑等旧产品约束。
- 旧地图生成路线的默认 Skill 触发和自动任务路由。
- 只为随机地图、模块扩池、旧 v18 布局采纳服务的当前任务。
- 把灰盒强行要求达到最终美术/完整内容质量的统一门槛。
- 旧方案在 README、AGENTS、模块导航和设计索引中的主入口身份。

这些内容的历史由 Git/tag/必要来源保留。当前正文直接重整；不要追加“银河城补丁”后让两套规则同时生效。

### 4.3 新链可运行后，再从活跃源码删除的候选

| 候选 | 删除前提 |
| --- | --- |
| `PlainsRegionGenerator`、`ThornForestRegionGenerator` 及旧布局版本 | 新世界不再调用；共享装配/镜头先保留或提取 |
| `experiments/generation/runtime_map_*` 与 `config/mapgen_candidate.json` 中仅服务 mapgen 的部分 | 所有开发入口、预加载、测试和导出引用已迁移/移除 |
| `RuntimeMapV2Provider` 及 SDK/模块包运行依赖 | 新世界完全不消费；通用机关绑定与地形处理已保留 |
| 旧 RunCampaignProgression、地区选路与结算流程 | 新世界推进/死亡/保存已替代，正式入口已切换 |
| 旧随机地图专项、旧流程 smoke 和无消费者脚本 | 新功能已有对应检查，历史用途已明确退出默认路由 |
| 老风格实验、重复导出和预览 | 没有正式/开发/回放/许可证/生成链消费者；保留可恢复来源 |

这是一份候选清单，不是可以直接整目录删除的命令。实际删除按每个消费者核验并在同一任务里更新引用、UID、动态路径、注册表、测试和导出清单。

### 4.4 不能凭名字删除

- `scripts/`、`scenes/`、`resources/`：当前仍有 Definition、Boss 场景和森林默认布局消费者。
- `game/world/generation/`：镜头和装配也可能在此。
- 带 `Run`、`Meta`、`v2/v3`、`Seed` 的所有文件：名字不是废弃证据；随机 Boss 招式、表现随机和测试复现仍可能需要 RNG。
- `assets/` 里的历史风格目录：先确认实际选中资源、manifest、动态加载和导出。
- 附件 `source_inputs/`：尚未解除构建依赖。
- 字体、音效、素材的许可证和原始授权证明。
- 用户旧存档：新世界使用明确版本/新存档槽或显式转换，不把旧存档误当新存档，也不默默覆盖。

可再生成、无必要追溯用途的临时缓存、旧导出、重复录屏与报告可清理；清除 Git 当前文件不会自动缩小全部 Git 历史。历史重写是另一项工作，不与转型混做。

`map-edit`、`map-gen` 两个仓库停止作为新世界运行时的必要依赖。保留已有成果及版本，今后有具体需求再作为离线零件创作/研究工具使用，不要求新主游戏继续集成随机生成算法。

### 4.5 未合入成果也要纳入基线盘点

核查时 PR136 `feat/mapgen-formal-plains` 仍为 open draft，尚未合入 main，head 为 `e3b726632f6dc9c576f30bb4ad79525dc58550e7`，共 261 个变化文件。不能把它的“正式平原已接入”说明当作 main 现状。

保留该分支的可恢复引用，按功能评估其中的可视机关绘制、地形/地图缓存、HUD 布局及卸载/取消安全改进。其随机求解、家园预生成和完整模块池接入不作为新固定世界的前置条件。择取改动要包括必要调用端和相应检查，不能孤立复制一个方法。其他未合入人物/怪物/美术成果也按同样方式核对是否已被后续主线吸收。

## 5. 目标目录与数据所有权

保留当前工程主体，新增内容按既有功能归属组织。以下是建议目标路径，并不表示这些文件已经存在。

| 路径 | 唯一职责 |
| --- | --- |
| `AGENTS.md` | 项目方向、读取路由、共同实现/协作约束 |
| `docs/project/` | 沿用状态、任务、工作线、架构和模块导航 |
| `docs/bible/game_design.md` | 固定世界产品设计 |
| `docs/bible/world_structure.md` | 房间、分区、物理门、能力阻隔、回访、捷径、世界变化规则 |
| `docs/bible/world_progression.md` | 新世界能力取得、推进、结局规则，替代旧 run_and_routes 的设计角色 |
| `docs/bible/home_and_save.md` | 家园/服务、永久状态、休息、死亡与保存边界 |
| `docs/bible/regions/` | 各区的体验、敌人生态、美术和时间主题；不复制逐房数据 |
| `docs/data/` | 具体玩家/武器/装备/敌人/Boss/机关规范 |
| `config/world/world.json` | 现行房间/分区/连接/永久事件的人工权威源 |
| `config/world/construction.json` | 人工调校的尺寸、门台、镜头与场景绑定；只覆盖其所属字段 |
| `config/world/collections.json` | 收集系统/来源引用/已选装备映射，不复制门/房间拓扑 |
| `game/world/rooms/<region>/<room_id>.tscn` | 真实 Godot 房间场景与该房内容 |
| `game/world/state/` | 沿用/扩展世界、休息周期和挑战状态实现 |
| `game/world/levels/` | 沿用 Request/Plan/Provider/Stage/Runtime 集成边界 |
| `game/platform/persistence/` | 保存介质、封装、备份、版本与转换 |
| `tools/world/` | 导入、合同编译、房间上下文抽取、验证、图册工具 |
| `tests/world/` | 房间/连接/保存/路线回归输入及专项 |
| `build/world/` | 编译合同、QA、地图和图册生成物；构建时明确将必要 runtime 数据打包 |
| `docs/evidence/` | 原包/来源索引、必要许可、关键验收证据 |

目录规则：场景按功能靠近脚本；新运行内容继续进入 `game/`；旧资源在被实际触及时迁移，避免一次全仓移动制造路径与 UID 风险。

### 导入的过渡安排

第一轮可以把完整附件放到 `docs/data/world/import-v04/`，保持内部结构，并明确它是当前导入输入。游戏不直接把该 docs 目录当运行包。

完成现行源/派生结果分离时，一次性切到上表的稳定路径，同步修改脚本、场景路径映射、导出与验证。切换后导入目录退出现行读取和构建入口，仅保留来源档案或由 tag 恢复。不要长期保留两份可编辑 world 主文件。

`build/world/` 下的生成结果若用于游戏，必须由构建工具显式纳入导出包，或同步到单一、明确只读的运行资源目录。不能认为 `.gdignore`、`.gitignore` 自动承担所有导出排除/包含规则；需核验现有 raw export 插件与 PCK 实际内容。

世界图布局坐标与房间内游戏世界单位属于不同坐标系，不能用统一倍率互换。`scene_ref` 是附件提出的计划路径，应由实际场景绑定生成规则一次性映射到项目路径。

编译器默认只重建合同和只读运行数据，不覆盖已人工制作的房间场景。房间外框/门台/相机等公共接口由施工输入拥有，场景中的对应实现通过同步或检查保持一致；房内地形、敌人和装饰由场景拥有。若需要生成场景骨架，采用独立生成层或显式一次性初始化，重建不得抹掉人工编辑。

## 6. 存档与运行架构的迁移

当前工程已经有 `LevelRequest → Provider → LevelPlan → Stage/LevelRuntime` 的内容装配边界。优先检查该接口是否能表达固定房间，再扩展缺少的房号、入口、分区和稳定身份。不要因为换游戏类型就重做玩家、战斗和全部工厂。

实际代码证明这仍只是复用起点：`LevelRuntime.assemble()` 接受 `PlainsRegionState`，选择平原/森林 Assembler；`RunSession.reset_maps()` 清空地图账本，`clear_run_services()` 调用 `build.clear()` 和 `wallet.discard_balance()`；`DemoApp._cleanup_run()` 调用这条清空链，`_select_next_region()` 又调用 `reset_maps(true)`。新世界必须切断这些旧重置时机，不能只改类名。

另有 `game/world/state/world_context.gd` 明确标记为历史“死亡全重置”夹具；不要因为它名叫 WorldContext 就把它直接作为新世界核心。

将新世界的固定内容提供器接入相同消费链；如果现有 Stage 明显承担整张随机大图的假设，再提取可复用的公共装配，建立薄的房间实现。避免把旧随机地图的整套 Manifest 强塞给新房间，也避免建立一个包办所有状态的超级管理器。

附件给出的四种状态寿命需要明确分开，可用数据结构和窄接口完成，不要求建立四套庞大的服务系统：

| 状态寿命 | 内容 | 不应触发的错误重置 |
| --- | --- | --- |
| 永久 | 能力、装备所有权/成长、唯一奖励收据、Boss 胜利、修钟、捷径、任务、售出库存 | 死亡、普通过房、休息不能清除 |
| 休息周期 | 周期 ID、普通敌人周期状态、限定次数、配装锁定等 | 普通过房、交通、对话、自动保存不刷新 |
| 挑战尝试 | 当前房/分区、真实进入侧、失败返回锚点、局部瞬态机关 | 失败不能返回出口侧或穿越能力阻隔 |
| 动作瞬态 | Q 资格/冷却、反冲、攻击包和有限射线预算 | 换房不能免费补资格/清冷却 |

继续复用伤害、奖励事务、幂等收据和存储校验机制，替换旧“终局清空并回家园”的策略。保存要有新世界格式与内容版本；只迁移有明确语义对应的旧字段。

### 最重要的规则验证样本

- 左右步行门；向上过房落到真实侧台再归还操作；向下过房下方有安全平台。
- 普通能力锁放在房内真实环境，入口可预览且可原路退回；到过房间不等于到过所有分区。
- 普通地形失败扣 1 HP、特殊危险扣 2 HP，归零死亡；存活返回实际挑战进入侧。
- Q 仅反冲位移期保护敌人与光幕，真实落地资格和 2 秒冷却同时满足；实体荆棘/齿轮/熔岩/毒水照常伤害。
- 能力、Boss、奖励、修钟、捷径、商店唯一库存跨死亡/读档保持，重复回调不得重复发奖或重复扣费。
- 普通切房、交通、对话、自动保存和读档不触发休息。显式休息按已确认规则恢复 HP、登记复活点并刷新周期。死亡后的 HP 恢复、周期推进和普通敌人刷新按附件试制默认实施并明确标记，不能冒充已确认设计；死亡金币政策仍保留待定。

## 7. 文档整合清单

| 当前文档 | 处理方式 |
| --- | --- |
| `README.md`、`AGENTS.md` | 改项目定位；入口保留；移除旧“不设灰盒”约束 |
| `current_state.md` | 分清新目标与旧运行实现，写明当前真正可运行到哪里 |
| `tasks.md`、迁移工作线 | 旧方向任务退出活跃表；建立一条迁移主任务及后续实际任务 |
| `module_map.md`、`architecture.md` | 更新新入口/状态边界，未实现类不得写成已接入 |
| `game_design.md` | 重整成固定世界核心体验与范围 |
| `run_and_routes.md` | 由固定世界推进规范替代；更新所有现行引用 |
| `procedural_generation.md`、`platforming_modules.md` | 退出正式世界权威入口；有价值的机关/动作制作经验迁入房间制作说明 |
| `regions.md`、`world_regions.json` | 保留地区身份与主题，迁移六层 DAG 和地区选择模型；建立原 region key 与新 code/ID 映射 |
| `damage_and_respawn.md`、`home_and_save.md` | 按失败/死亡/休息/永久状态重整 |
| `rewards_and_builds.md`、`data/items.md` | 改永久装备、NPC 升级与休息周期；逐件处理本局/每图效果 |
| `data/abilities.md`、`data/weapons.md` | 保留基础动作，增补 Q、新成长与完整攻击预算 |
| `regions/windchime_plains.md`、`regions/thorn_forest.md` | 保留区域风格/生态/动作主题，替换两图流程、旧 Boss 位置和能力取得关系 |
| `story.md` 和相关叙事规范 | 按固定世界任务/修钟/结局更新；时间循环叙事是否保留以新设定为准 |
| `visual_bible.md`、敌人/Boss 对象规范 | 主体保留；修改确实受新进程影响的部分 |
| `design_contract.json` | 迁移为新设计与当前实现边界，避免成为第二份参数或拓扑源 |
| `development.md`、`content_pipeline.md`、`policy.json` | 支持结构灰盒的适用验收，保留相关质量要求，明确旧自动地区生产 route 的范围 |

正文维护原则：修改所属正文，删除被替代段落。历史解释写 PR 或迁移交接，不在每篇圣经尾部追加补丁。

检查工具同步修改：`check_docs.py`、`check_world_design.py`、`level_region_context.py`、`region_creative_direction.py`、`check_quality.py`、相关测试和 Bible 注册表。地区文档若由注册表绑定路径/SHA，应同步绑定新正文及确认依据，不篡改历史验收。

旧“禁止回路”的检查应替换为连接与端点完整性、可预览后退出、能力取得无自锁、关键剧情可达、捷径单向状态和奖励幂等检查。不要用删除所有校验来解决设计变更。

## 8. Skill 和上下文管理

### 8.1 现有 20 个 Skill 的建议

| Skill | 建议 |
| --- | --- |
| `player-creator` | 保留，继续调用共同动作与表现消费者 |
| `weapon-creator` | 保留，更新永久武器成长语义 |
| `ability-creator` | 保留，更新永久解锁与 Q |
| `enemy-creator` | 保留，补固定实例/休息刷新 |
| `boss-creator` | 保留，补永久胜利和重入 |
| `animation-vfx` | 保留，核新切房生命周期 |
| `art-director` | 保留，独审是否需要按任务约定 |
| `audio-director` | 保留，修正已失效的 `docs/audio_director/` 引用 |
| `challenge-choreographer` | 保留，用于房内动作、恢复和回程 |
| `encounter-director` | 按 room_id/section/状态定位，替换默认 Seed 定位 |
| `scene-composer` | 保留构图、支撑和可读性方法 |
| `visual-director` | 按固定房间/镜头定位，审查要求按任务适用 |
| `region-creative-director` | 保留区域主题和表现统筹职责 |
| `story-writer` | 改固定世界剧情进程，不继承每 Run 多轮推进假设 |
| `gameplay-reviewer` | 保留，按本阶段范围作结论 |
| `game-quality-gate` | 必改：允许结构灰盒，分清结构可玩与完成内容 |
| `project-integration` | 保留，用于引用、导出、UID 和迁移检查 |
| `design-grill` | 保留，仅对真实未决设计使用；已确认的本次转型无需再访谈 |
| `region-generator` | 从正式随机世界流程退役，建议一对一改为固定世界装配职责 |
| `level-module-creator` | 改为房间/Section 内容制作职责，保留已有机制制作方法 |

可将最后两个分别更名为 `world-builder`、`room-builder`，但必须同任务修改 frontmatter、`policy.json`、路由、执行器及引用；也可先保留名字缩小适用范围，再在一次完整迁移中改名。选择一种过渡方式，不能同时维护两个同职责活跃技能。

停用的 Skill 移出活跃发现目录，不继续让其名称和描述参与自动匹配。仓库技能随游戏代码版本管理；这不需要修改全局个人技能或新增“总导演/超级管理”流程。

每个 Skill 只承担重复工作的方法：触发范围、需要的局部上下文、关键操作、相关验证与交付。HP、门连接、能力地点等事实放在所属规范/配置。新房间流程先做通代表样房，再把已证明的方法整理进 Skill。

OpenAI 的现行说明确认 Skill 先加载名称/描述，再按匹配加载正文。因此减少误触发和矛盾的描述，比简单追求 Skill 数量少更有价值。

### 8.2 新会话读取路径

1. 核对当前分支、最新 main、工作区用户改动与任务基线。
2. 读取 AGENTS 和当前实现短表。
3. 找任务表这一行，读取其唯一当前交接。
4. 在模块导航选择相关主题，读取适用圣经、对象规范和真实代码。
5. 房间任务只提取目标房、分区、相邻连接、相关永久事件和所用对象；不要全读世界 JSON/合同/回放。
6. 按任务触发相关 Skill；历史证据只在追溯具体问题时读。

附件世界主数据约 3.82 MB、逐房合同约 10.06 MB，完整回放约 3.18 MB。它们应由脚本筛选，不作为每个会话全文上下文。

建议用一个小型按房间提取工具输出目标房合同、相邻门、能力条件、对象 ID、状态影响和场景引用。具体 CLI 在实现后再写进导航，不在交接中把计划命令冒充现有命令。

不要要求修一个音效的会话读取 216 个房间，也不要要求调一间房尺寸的会话加载全部怪物、所有 Skill 和历史任务。

### 8.3 每次结束如何交接

继续更新当前工作线的一份交接，包含：

- 目标及本次范围。
- 分支/源码 SHA，以及可试玩构建对应的源码身份。
- 写集和直接依赖。
- 实际完成的结果、设计与实现差异。
- 实际运行的检查、试玩/短录屏、明确未验范围。
- 阻塞或未决选项。
- 下一条具体可执行动作。

进度只改任务表；方向变更才改圣经；实现行为变化时同步所属对象规范/配置。普通缺陷修复不必在所有文档制造改动。

## 9. 任务与并行协作

### 当前任务的处理

| 现有工作 | 建议 |
| --- | --- |
| 手机性能、死亡卡顿、音频、玩家动作、普通怪表现 | 继续保留，使用新房间夹具逐步复验 |
| 巡游机与牧风者优化 | 保留招式/演出成果；更新旧 40/60 HP 等目标与新攻击档位的关系 |
| ITEM-V5 | 改为永久装备筛选与效果迁移；不要机械迁移全部旧道具 |
| STORY-DESIGN | 转为固定世界故事、NPC、修钟和结局 |
| MAPGEN-HOST、FOREST-VARIETY、旧两图地图量产 | 停止旧目标，保留有价值资产，退出活跃视图 |
| PLAINS/FOREST 区域完善 | 重定为固定世界区域内容任务 |

仓库当前任务状态枚举没有 `cancelled`/`retired`。旧任务移入归档后保留真实最后状态，在迁移交接说明“因转型停止推进/被哪项替代”。不要把未完成工作标为 done；若要增加状态，必须同步文档和解析器。

### 建议的三个迁移任务

| 任务 | 产出 | 完成条件 |
| --- | --- | --- |
| `MV-MIGRATION-01` | 方向、规范、源数据、技能/检查/路由迁移 | 新会话能准确识别固定世界目标、真实实现状态和下一步；没有现行旧规则强制退回肉鸽 |
| `MV-RUNTIME-01` | 共同状态与代表样房闭环 | 真实过房、能力阻隔、失败/死亡、休息、唯一授予、保存与回访成立 |
| `MV-WORLD-GRAYBOX-01` | 216 房结构及运行路线 | 真实游戏连接、入口台、分区、交互和状态可走；按指定路线验证；占位未冒充正式战斗 |

之后按区域/具体系统开内容任务，不一次创建 216 个独立长文档任务。已有世界 JSON 保存房间设计；进度仍在对应父任务。可从世界 ID 和场景检查生成房间清单，避免手工维护第二份世界目录。

并行边界：一条集成工作线负责共享接口、主数据、保存和公共规则；房间/区域会话修改各自范围；人物、怪物、音频、美术继续独立迭代。共享接口变更集中处理，区域代理提出拓扑修改需求后由所属世界任务整合。

每条工作线用独立分支/工作树，基于最新稳定 main。没有合入的共享依赖写清具体分支/SHA；避免长链 draft PR 的默认隐性继承。

## 10. 三个阶段的交付边界

### PR1：迁移项目方向、资料与开发入口

- 记录 main、当前可试玩构建和有独立成果的分支/PR；建立可恢复的转型基线，不只保留一个无法定位源代码的网页。
- 原样导入附件，核验清单，建立权威映射及源/派生关系。
- 整合相关圣经与状态、任务、导航；移除“不设灰盒”和旧肉鸽设计的当前权威身份。
- 修改相关检查语义和 Skill/路由引用。旧自动地区量产 route 明确不用于本次固定世界灰盒；普通 Codex 任务可直接实施既定计划。
- 保留旧游戏运行入口作为迁移期间已实现事实，不把新文档标成运行完成。
- 做文档链接、路由、源数据/引用完整性及受影响项目检查；所需运行检查执行后如实记录。

PR1 完成在“迁移交接可以直接使用”。不在此 PR 一并批量实现 216 房、不全仓搬动素材和旧代码。

### PR2：共用运行时与代表样房

按附件既定样房：P-R03/P-R01/P-R06/P-R14，F-R04/F-R10，I-R05/I-R11，K-R16/K-R05，A-R04，S-R05。

先在平原形成可连续游玩的最小闭环，其余样房可通过明确的开发状态载入验证专用能力。完成真实门/入口台、相机、能力环境阻隔、失败/死亡、休息、永久事件、保存与重入。

完成源/派生结果的长期整理：人工门台/尺寸输入、按房提取、固定提供器与运行包。素材和控制器使用已有实现。

新世界正式接入时替换启动/烟雾检查覆盖。录屏应展示一次连续体验和关键状态恢复，不把纯日志或静态 JSON 检查当作可玩证明。

### PR3：全世界结构灰盒与旧链退役

扩展 216 房场景、288 连接、分区、入口台、相机区、真实能力环境占位、NPC/休息/交通/修钟/捷径/奖励与结局交互。

在真实运行时执行附件的 A 先 W、B 先 D、C 真结局路线，D 为材料/齿轮专项审计。路线证明所选路径可行，不代表唯一顺序或最短路径。

Boss 开发替身只证明胜利事务/奖励/进程，不证明 Boss 战斗完成。灰盒通过后逐区完善平台、敌人、Boss、美术和经济。

删除已无消费者的旧生成与 Run 推进代码，同步测试、导出、UID、导航；若某段新旧链尚有共享依赖，在迁移清单写明具体退役条件，避免永久双模式。

## 11. 最小而有意义的验证

保留现有四项 CI 框架，阶段性更新其覆盖内容；专项沿现有 Harness 挂接。

- 文档/技能迁移：导航、链接、Skill 注册和路由、现行设计验证。
- 数据迁移：ID 唯一与引用存在、房门端点/分区、来源摘要、人工输入重建稳定性。
- 状态系统：跨房不休息、唯一动作重复调用、死亡/休息/读档不丢永久状态、购买扣费和授予一致。
- 房间系统：真实控制器进出门、上下落脚、不可用能力的预览/退回、失败返回正确侧、相机不露房外。
- Q：真实落地与冷却两个条件、光幕与实体危险分类、切房不刷冷却。
- 导出：运行必需 JSON/场景/素材真实进入包，历史资料/工具不被误打包；能实际加载启动。
- 内容验收：结构灰盒只签结构与运行；新美术/敌人/完整遭遇按对应任务验收。

测试应随所保护的产品合同迁移。旧功能已经退役时，删除或替换其专属断言；共同运动/输入/伤害/保存可靠性回归继续保留。无需为了文件名或说明文字的小变化重跑全部历史专项。

## 12. 可直接给新 Codex 的首个任务

将本文件与原始 `world-graybox-kit-v04.zip` 一起提供，发送以下内容：

```text
项目 github.com/zhipijun1996/gunman-rush 已决定从横版肉鸽转为固定世界的类银河恶魔城。附件 world-graybox-kit-v04.zip 是已确认设计与施工输入；其中已确认规则、实施解释和候选参数要保持区分。

请先完成 MV-MIGRATION-01，只做转型所需的项目管理、文档、数据入口、skills 和相关检查/路由迁移，提交一个独立 PR；本轮完成到新会话能够直接开始代表样房开发。

先核对最新 main、实际运行入口和未合入成果。沿用现有 docs/project、docs/bible、docs/data、任务表和每工作线一份交接。按《metroidvania-migration-handoff.md》落实迁移：完整导入并核验附件，指定唯一权威和生成链；整合正文；同步处理六阶段/两图/禁止回路/不设灰盒等旧约束及其检查、policy、Skill 和自动路由引用。

保留现有人物、武器、能力、怪物、Boss、UI、美术和共同基础设施。旧代码按消费者列出保留、适配、退役清单；当前仍被调用的代码与 source_inputs 不直接删除。新世界文档与当前旧运行实现如实分开记录。普通世界手感沿用当前实际参数。

完成受影响验证，更新任务表和唯一当前交接，列出改动、实际检查、仍待迁移的依赖以及 MV-RUNTIME-01 的下一步。不要把本轮扩成全仓重构或 216 房实现。
```

PR1 合入后的日常任务可以简化为：

```text
继续 MV-RUNTIME-01。按 AGENTS、任务表及该工作线当前交接，完成本批代表样房与其中列出的验证。使用现有角色和表现，给可试玩构建及关键行为短录屏；同步当前交接中的结果和下一动作。
```

用户负责确认产品方向、审美和体验取舍；Codex 负责查明真实实现、按既定范围完成实现和验证、保持当前资料准确。已确认的设计不在每个新会话重新讨论。

## 来源索引

以下仓库链接固定到本次审计提交，避免未来 main 改变后无法复核：

- [AGENTS](https://github.com/zhipijun1996/gunman-rush/blob/48cddb6a70983b0a0206304d18c98d274a9a7549/AGENTS.md)
- [文档入口](https://github.com/zhipijun1996/gunman-rush/blob/48cddb6a70983b0a0206304d18c98d274a9a7549/docs/README.md)
- [当前实现](https://github.com/zhipijun1996/gunman-rush/blob/48cddb6a70983b0a0206304d18c98d274a9a7549/docs/project/current_state.md)
- [任务表](https://github.com/zhipijun1996/gunman-rush/blob/48cddb6a70983b0a0206304d18c98d274a9a7549/docs/project/tasks.md)
- [模块导航](https://github.com/zhipijun1996/gunman-rush/blob/48cddb6a70983b0a0206304d18c98d274a9a7549/docs/project/module_map.md)
- [运行架构](https://github.com/zhipijun1996/gunman-rush/blob/48cddb6a70983b0a0206304d18c98d274a9a7549/docs/project/architecture.md)
- [设计合同](https://github.com/zhipijun1996/gunman-rush/blob/48cddb6a70983b0a0206304d18c98d274a9a7549/docs/bible/design_contract.json)
- [文档检查](https://github.com/zhipijun1996/gunman-rush/blob/48cddb6a70983b0a0206304d18c98d274a9a7549/tools/check_docs.py)
- [旧世界检查](https://github.com/zhipijun1996/gunman-rush/blob/48cddb6a70983b0a0206304d18c98d274a9a7549/tools/check_world_design.py)
- [Skill policy](https://github.com/zhipijun1996/gunman-rush/blob/48cddb6a70983b0a0206304d18c98d274a9a7549/docs/project/policy.json)
- [地区任务路由](https://github.com/zhipijun1996/gunman-rush/blob/48cddb6a70983b0a0206304d18c98d274a9a7549/tools/level_design.py)
- [生产执行器](https://github.com/zhipijun1996/gunman-rush/blob/48cddb6a70983b0a0206304d18c98d274a9a7549/tools/production_loop.py)
- [保存实现](https://github.com/zhipijun1996/gunman-rush/blob/48cddb6a70983b0a0206304d18c98d274a9a7549/game/platform/persistence/meta_save_service.gd)
- [当前 Run 生命周期](https://github.com/zhipijun1996/gunman-rush/blob/48cddb6a70983b0a0206304d18c98d274a9a7549/game/application/run_session.gd)
- [当前应用接线](https://github.com/zhipijun1996/gunman-rush/blob/48cddb6a70983b0a0206304d18c98d274a9a7549/game/application/demo_app.gd)
- [公共地图装配](https://github.com/zhipijun1996/gunman-rush/blob/48cddb6a70983b0a0206304d18c98d274a9a7549/game/world/levels/level_runtime.gd)
- [未合入 PR136](https://github.com/zhipijun1996/gunman-rush/pull/136)
- [日常 CI](https://github.com/zhipijun1996/gunman-rush/blob/48cddb6a70983b0a0206304d18c98d274a9a7549/tools/ci.py)
- 用户附件：`START_HERE.txt`、`BUILD_AND_VERIFY.txt`、`handoff-status.json`、`design/world-graybox-bible-v02.txt`、`design/COLLECTION_SYSTEMS-v04.txt`、`world-room-layout-v04.json`、`design/collection-catalog-v04.json`、`design/build_room_contracts_v04.py`、`simulation/build_route_plans.py`、`build_handoff.py`、`migrate_world_v04.py`、`MANIFEST.json`。
- [OpenAI：AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md)
- [OpenAI：Build skills](https://learn.chatgpt.com/docs/build-skills)
- [OpenAI：精简技能和项目指令](https://developers.openai.com/blog/rethinking-skills-and-prompts-for-gpt-6-astra)
