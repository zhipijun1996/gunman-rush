# AI-LEVEL-DESIGN-01 独立审查

审查者 `/root/independent_review` 是本轮新建的独立审查代理，没有实现被审代码；只读代码和真实原件，未启动 Godot。最终结论为 **限定技术方法 ACCEPT；内容设计 REVISE；真人、设备、美术与正式准入未验**。下列原拒绝及修复历史保留。此接受只覆盖离线有限生成、证据读取和反证工作流，不代表已有优秀新模块或一般运行时算法。

## 初审发现与返工记录

| ID | 事实与反例 | 初审结论 | 复审状态 |
| --- | --- | --- | --- |
| IR-01 | `archive` 原先接受手写的非空 `frames` 加 `ok:true`，进入 `cells` 并赋 `technical_ok=true`，不核原生进程证据 | REJECT 工具证据边界 | 已补 bound receipt / native / log / source / contract 读取；main/latest实际正控通过，删Controller依赖并重绑wrapper指纹的反例拒绝 |
| IR-02 | 独立CLI的缓存 identity 未绑定 `run_tests.py`、`godot.sh` 和实际引擎二进制；外层Harness虽更严格，不能替代CLI本身 | REJECT 缓存有效性范围 | 已补真实 4.7.2版本/二进制SHA、两份严格运行源和自定义catalog完整输入闭包；新源实际正控与pure反例通过 |
| IR-04 | 独立sidecar只带真raw而不带完整outer ledger时，复制producer/catalog/tuning到临时root并替换PlayerController，`validate_bundle`仍返回空errors | REJECT 当前源物理声明 | 已复用outer ledger核完整闭包；真raw+receipt正控通过，只留raw的反例拒绝，原生格式reader保持窄职责 |
| IR-03 | 用真实 `plains_bell_ferry_control`，只一致重命名 object ID/trackId/targetId，或把编辑平移与轨道点同步 +100，原 geometry_signature 都改变 | REJECT 相似性正确性 | 实际重命名与平移已保持 geometry/intent；改铃目标后 geometry 相同、intent不同，修复方向成立 |

IR-01 第二个反例使用实际 `pilot-main-r5` 成功原件：保留原 native/log，仅把 `runtime_source` 从1800项删到五条 required 项并刷新 wrapper identity/source_fingerprint，`verified_result` 仍返回 true。证据闭包必须完整，不能由输入自报一个任意子集。此复审发现已由作者修复，当前必须与完整snapshot精确相等；新main/latest正控和删闭包反例均已独立核对。我没有修改被审代码。

早轮 v1/v2 的 raw、hash 与说明仍有诊断价值，但没有保存完整 producer 源字节。它们不能称完全可复现，也不能借当前 v3 源解释旧通过。最终应保存准确基线 Git SHA、完整 overlay 源字节、输入、原生输出、日志及恢复索引。作者已确认披露此缺口。

## 实际读到的物理证据

初始主线基线为 `e9ab0e0743466b8983e34cc7de17bab1abf9d53a`，开发基线为 `a074a709ffa64c1382d73d2dab6dcff673222728`；两套最终实验分别有27个条件，未混签。每套13个策略物理通过、14个失败保留，7个粗行为描述符家族不等于7种新玩法。实验的 `source_commit` 是基线 HEAD，实际新增/未提交 overlay 另由完整运行源 SHA 绑定，不能把它冒称仅该 Git 提交的游戏。

初读旧 `pilot-main-final` 九条件通过，之后源漂移时守门真实拒绝，旧结果没有重签。最终已独立读取 `pilot-main-final7` 与 `pilot-latest-final7` 的source/raw/log/ledger，分别严格验证选定九条件，均返回9。pure原CLI最终41项、规划器22项独立exit0。201条四层sidecar用当前root校验无错误。最终export已逐个核成功样本的verified_result，只有main和reward都在已验证集合才导出complete；新增一真一伪或缺自己proof的反例在41项pure测试内。此处没有重新启动物理引擎。

`plains_overlook_choice / direct` 的真实第25帧有 `shot_fired`：main 的 shots 2→1、stamina 100→80；latest 的 shots 1→0、stamina 保持100。这说明两套规则确有运行差异，不能只改标签后共用证明。一次 direct 策略失败只否定这次策略，不证明所有正常跳跃/反冲都不能到达奖励。

新候选没有动态危险或H机制、正式领奖交易或敌人上下文；危险集合为空时不能签动态相位或伤害公平性。Router请求与真实 jump/shot 事件有分栏，逐帧唯一 Motor 步数与无中途注入声明和实际计数相符；初始 fixture 出生位置是明确允许的实验条件。隔离 Module 通过不外推正式 App 或整张 Map。

## 独立设计判断

| 内容 | AI判断 | 依据与仍需反证 |
| --- | --- | --- |
| 平原高台选择 | 重想高路编舞，保留普通分叉原型 | 低路175帧无动作，高路270帧三跳；按独审提出的强替代实测，先走到奖台下再满跳167帧、一跳到奖。阶段爬高并非必需；没有封路来强迫多跳 |
| 森林上下冠根选择 | 同族探索原型，继续返工 | 高路257帧三跳，近奖从下根一跳170帧到同奖；上下轨迹不同，仍与已有mushroom_fork相近，没有证明新决定或新机制 |
| 根盆回家环 | 优先删冗余回程或返工 | 默认领奖路线455帧六跳；同几何删回家环且仍访问奖励位置的当前搜索版本319帧三跳。没有新增机关、资源状态、信息或收益后果时，回家再进同盆可能只是重复劳动；不是“有环就有探索价值” |
| 回望宝藏 | 保留失败，停止本轮内容修补 | 有界修复后主路和奖励在实际首段落到错误支持，不能继续扩产；这只是当前驾驶/设计失败，不能断言几何物理无解 |
| 低拱旧模块 | 不得再声明跳跃是孤立通行的最低需求 | no_jump真实154帧成功，无jump_executed；推荐短跳是策略而非必需动作。正式敌人或其他上下文可能改变意义，需另验 |
| 长草甸 | 休整角色可保留 | no-action走廊可以承担恢复与阅读；脱离整图节奏，低密度既不能证明优秀也不能证明劣质 |

这些是 AI 专业判断，不是用户反馈或人类趣味预测的实证。最终短片容器已独立核对为27.6秒、1280×720、1656视频帧，带AAC音轨；六段capture的原生SHA及frames/events均与latest-final7/search-final7对应原件相等。这只证明实际采集与实验一致。本审查者未全片观看或听音轨，没有实体设备操作，视觉、手感、公平学习和重试意愿全部未验。ZIP与托管交付应由root另行核对，不包含在本次技术接受中。

## 架构、批量评价与CI

Macro Module 作为可选的跨模块责任层成立。Foundry itinerary的连续资源、接缝和节奏需要联合证明；单个大场所已有主支/回程时，不因面积而再包一层。现合同允许 Map 直接 Module/Cell，保留既有运行消费者，没有另建正式执行系统。

177份参考的评价明确是9份深入、168份有限源码初审；169条仍需证据。`retain` 不能转述为“优秀已验”；没有因低交互自动淘汰休整，或因长链自动评分高。这种分轨符合本轮目标，但尚未证明 AI 判断能预测真人喜欢与否。

搜索只消费有限工厂、route_order和8wu几何对照。没有证明任意新组合、完整参数域或runtime持续新鲜感。相同轨迹描述符只是粗筛，不能证明玩法等价；8wu变化也不能凭几何hash称创新。初审发现backlook原本就不在eligible集合，不能称反馈导致剔除；作者修复后，独立核对同seed同eligible：无反馈4父项，有真实失败反馈3父项，差集恰backlook。预期no_jump负例不淘汰正常候选。搜索最终12/12实际原生正控与自定义catalog闭包通过；8wu几何对照按策略落入相同描述符家族，basin的route_order确实改变回程运动。

独立对比原 Harness JSON：原163检查全部保留，新添2项成为165；所有旧检查定义字节语义未改，旧profile成员无删除。规划器仅对一个精确、孤立候选配置路径开放窄scope，共享配置和未知路径仍full。最后的生产计划仍须按真实PR base报告；修改Harness注册本身是共享边界，不能把这次完整PR验证称成只跑九条件。Release完整门槛保留，未运行的整套CI不在本次接受中。

审查冻结时作者另报：原Harness的ai-level-content fresh通过；ai-level-pilot内层九条件通过，但外层因同时修改质量/证据文档触发source_changed严格拒绝。该失败必须保留，不得追认通过；本审查未独立重读这次outer原件。最终文档冻结后的外层重跑和receipt由root另附，本报告不预签。本次技术结论只建立在已独立核实的native/direct CLI、当前源守门与pure证据上。

## 范围结论

四项工具守门发现均已修复并独立验证，取得本报告限定技术接受；内容仍应保持review/rework。正式入口、既有资源、Motor、能力、能量、RNG和保存合同没有因本轮被修改。真人趣味、真机、最终美术、正式奖励、跨模块相邻组合、多Seed整图、动态相位均不能由这些小样签收。

最终本地证据路径：`build/ai_level_design_v1/pilot-main-final7/experiment.json`、最新开发worktree的`pilot-latest-final7/experiment.json`及`search-final7/physics/experiment.json`。主线r6和final7的27组实际frames/events逐项相同，支持同物理源的重复策略执行可复现；它不是新的recorded-input replay消费者，也不证明一般随机地图。最终受审文件SHA、初次REJECT和各项复审结论见同目录JSON。
