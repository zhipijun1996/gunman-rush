# Skills、生产循环与平原质量返工

状态：review / 部分 blocked。此报告不能作为整套游戏内容的完成声明。最新地形画面被用户拒绝后，已退回 G2 并撤下错误实现。

## 基线与正式范围

本分支 `feature/quality-review-and-production-loop` 基于 PR57 `5fd9c272d74616ae477809fa4285f609e6b697c6`，其上游为 PR55；main `6568e9a` 已包含 PR54 最新正式玩法。再次 fetch 发现并行 PR56 `f721795` 和其 PR58 `7ad11ea`，均未混入本分支。原正式入口依旧 Title → 可操控 Home → Departure → 连续随机平原；Module Lab、Foundry、旧固定关是开发/回归消费者。

没有修改 PlayerMotor 基础参数、能力授予、正式随机流/拓扑、奖励经济或正式入口。不发布新游戏版本，不自动合并 PR。

## Skills 如何工作

用户无需每次指定。Codex 根据 AGENTS 的路由和 Skill description 选择读取；重要任务由 game-quality-gate 组织专业 Skill，共用一份 G0–G5 和十一维验收记录。显式 `$skill-name` 用于固定主导职责。自动发现不等于自动通过，更不等于 Codex 未登录也能执行。

| 本轮新增 Skill | 触发/职责 | 协作及产物 | 验收重点 |
| --- | --- | --- | --- |
| player-creator | 主角整体操作和表现设计 | weapon/ability/art/animation；Player Design Sheet | 真实输入、身体/锚点、完整动作链、正式控制及状态恢复 |
| weapon-creator | 换武器、整套攻击、升级分支 | player/animation/reviewer；Weapon Design Sheet | 射击反冲差异、升级可撤销、武器切换/存档/奖励消费者、动作音画同步 |
| ability-creator | 二跳、墙跳、移动战斗能力及能力锁 | player/level/region；Ability Design Sheet | 获得/撤销/保存、真实Motor、已授予能力与路线合法性、边界失败 |

原八个制作/审查 Skills、project-integration、G0–G5 和十二类模板继续复用；完整原始体系与调用示例见 [实施报告](implementation_report.md)。新增武器/能力只是制作规范，不表示这些未来内容已经实装。

## 大任务循环

见 [production_loop](production_loop.md)。任务DAG → 专业实现 → harness → 新只读审查会话 → 携失败证据返工；限制轮次、调用数、单次超时，保存 prompt/JSONL/返回码/状态。依赖、源码变化、无进展、越界修改、缺玩家认可都会形成明确停止点；不自动push/merge/publish。

10项fake-worker测试通过仅证明执行器编排。实际 `skill-routing-smoke --execute` 第一轮已调用Codex，但因登录token失效退出1，calls=1、blocked。真实连续多Skill执行仍 unverified。不是“计划执行”冒充已执行，也不是把模型登录异常藏在模拟成功后面。

## 泛化审查与实际结果

审查方法是空间、状态、时间、消费者的不变量和变形对照，不是把用户现象逐条抄成永久规则。最初盲审独立发现暂停清弹重置攻击、可见敌人身体超出hurtbox、正式画面接缝，结论 REJECT。用户反馈作为回归样本加入后续复验。

| 项目 | 当前结论 |
| --- | --- |
| 乘平台镜头 | 实际碰撞携带下同步共同位移，跳离恢复原相对缓冲；专项技术通过，主观待验 |
| 暂停/菜单攻击 | 冻结相位及既有弹体，恢复继续；死亡/离开仍取消。旧测试期待暂停清弹被修正，独立限定 ACCEPT |
| Boss接触 | 正式与Lab共享活跃身体接触规则，intro/转换/死亡保护保留；体验待验 |
| Boss登场 | 开始/结束位置连续，保存总时长，重建不重播冲击；独立限定 ACCEPT，音画品质未通过 |
| 普通敌人视觉/受击框 | 两次缩放方案被审查 REJECT，已恢复基线；原问题未解决，不用逐帧非等比拉伸掩盖 |
| 新敌人 | 苔盾甲虫/柳籽蛾两个真实Actor候选，仅开发Lab，不计入正式丰富度完成 |
| 装饰 | 按实际支承与区域角色聚集，移除伪可交互铃，同层色调一致；整体美术待看正式合屏 |
| 地形 | 第一轮边框拼贴用户REJECT并撤回。新47邻接/多格组合与共享材质gallery在审；正式端头缺陷不能标已解决 |

独立报告保留失败和局部通过范围：[89ca510返工要求](../evidence/quality_review/rework/rejected_89ca510.md)、[局部复审](../evidence/quality_review/rework/independent_rework.md)。自动检查不能覆盖主观拒绝。

## 可变地形的制作方法

依据 Godot Terrain Set、Tiled、RuleTile 与 blob/sub-blob 文档建立 [拼接契约](terrain_tile_contract.md)。八邻接256输入归约到单材质47合法形态，四边、凸角、凹角、薄行/列、孔洞同时覆盖；多格素材遵守同一接口。该数字不包含所有多材质/坡面/单向平台语义。

AI生成共享材质母版，运行时从相同坐标组合合法tile；不是47张互不相干的整平台图。catalog由真实Godot消费者读取，宏块保存逐格mask。307种小形状和洞口验证无漏格/重叠/填洞；GUI从普通菜单进入，切换单格/宏块对比实际GPU像素。第一次切换暴露“信号中释放按钮”错误，保留失败并改为延后刷新，补实际按钮回归。

材质样板的拼接通过不等于风格认可。正式随机地图的非整格/极薄体、真实角色/机关/背景黄金合屏、设备性能和用户审美仍待验；当前仅开发入口，未把土墙覆盖到单向平台。

## 质量状态

保留 planned/ready/in_progress/review/done/blocked/awaiting-device。QUALITY-LOOP-01因真实模型认证blocked；PLAINS-QUALITY-01保持review，visual和整体independent_review为failed。局部通过单独说明，未验字段不填passed。用户未认可的画面、手感和趣味不计最终通过。

## 使用示例

```text
用 weapon-creator 为现有主角设计一种新武器及两条升级路线，覆盖整套瞄准、开火、反冲、空中和落地动作；先读正式武器与资源契约，交付G0规格，不擅自改PlayerMotor基础物理。

用 ability-creator 设计二段跳的获得、撤销与能力锁，先确认当前正式发放系统，复用真实Motor和region-generator能力验证；用反例证明未获得能力时不能进入对应必经路。

用 game-quality-gate 拆解一个森林区域任务，列出关卡、敌人、Boss依赖；先完成一个完整黄金样板，再生成有预算的production-loop mission。未经确认的地区风格与重要玩法标proposed，缺G5时停在待验，不伪造done。

用 art-director 检查一个新地形材质集，按terrain_tile_contract枚举邻接、孔洞和不同长度/厚度；验证1×1与宏块的真实GPU分块不变性，再看正式合屏，不用覆盖率证明漂亮。

用 gameplay-reviewer 独立审查本PR，按空间/状态/时间/消费者的不变量主动找反例，保留REJECT和复验记录，不修改被审正式代码。
```

## 实际验证与证据

完整命令/退出码/源版本/证据SHA见 [commands.json](../evidence/quality_review/final/commands.json)。

| 命令 | 真实结果 | 退出码 |
| --- | --- | --- |
| `python3 tools/harness.py --profile full` | 25项通过：Core5942断言、43历史套件、15区域套件及美术/Web检查 | 0 |
| `python3 tools/harness.py --profile docs` | 冻结9faa1a4上9项检查通过 | 0 |
| `python3 tools/harness.py --profile web` | 冻结0a4f92a上12项检查通过；最终shader、构建与元数据 | 0 |
| `python3 tools/run_quality_review_tests.py` | 最终952断言、0失败；含真实Motor平台参考系、暂停、候选弹体及tile预算/覆盖 | 0 |
| `python3 tools/verify_terrain_tiles_browser.py http://127.0.0.1:8765` | 实际菜单进入，47形态页正常，单格/宏块地形GPU像素差为空 | 0 |
| `python3 build/verification/capture_final_formal.py` | 正常Title→Home行走→Departure→正式地图，6段操作与暂停截图；不代表完整探索通关 | 0 |
| `python3 tools/harness.py --mission docs/quality/missions/skill-routing-smoke.json --execute --evidence-dir build/verification/skill-routing-smoke` | 真实Codex首次调用认证失败，calls=1、blocked | 1 |

全量run开始于89ca510的dirty工作区，期间冻结为9faa1a4；原报告的diff和文件hash完整保留，**不把它伪称单一冻结提交的全量重跑**。后续修改只有tile周期采样与build导入隔离，已补冻结Web、专项与GUI复验。初次全量因旧暂停断言失败、gallery按钮刷新失败、预算/shader/超时留证反例均保留，见rework目录；没有降低错误签名。

最终材质包 `7d364818e57f`，源提交 `0a4f92a3d36f3f5df85c9d3060e1625998678348`。证据：[组合样板](../evidence/quality_review/final/gallery/shapes-macro.png)、[47形态](../evidence/quality_review/final/gallery/all-47.png)、[正常速度GUI录像](../evidence/quality_review/final/gallery/normal_speed.webm)、[周期算式独立审查](../evidence/quality_review/final/independent/material_seam.md)。GUI无脚本/shader错误；favicon 404不当游戏失败，退出资源诊断仍按日志保留。

审查新增通用问题已返工：复杂孔洞邻域宏块超64边界时实际拆成1×1；GLSL smoothstep改正序；Codex超时/启动失败也写调用记录；材质周期边缘从均值常量改成双相细节过渡，避免竖条。`build/.gdignore`停止导入测试截图与临时夹具；失败素材从运行资源删除，Git保留历史来源。

## Git交付与未完成项

分支 `feature/quality-review-and-production-loop`；实现89ca510、拒绝返工9faa1a4、材质周期修正1f7a382、导入隔离0a4f92a。证据文档随后提交，运行代码以0a4f92a为准。

[PR59](https://github.com/zhipijun1996/gunman-rush/pull/59)，base=chore/game-quality-system，draft。已推送，不合并、不发布。远端CI与本地结果分开；最新远端状态以PR checks为准。

仍需：新材质方向反馈、真实角色/背景黄金合屏、正式非整格与极薄体适配、原敌人身体/hurtbox一致性、正式新敌人遭遇及玩家体验、Boss音画主观验收、真实设备性能。实际Codex生产循环需恢复本机登录后新建证据目录重试。上述工作不能靠这次技术通过或用户未回复自动关闭。


完整新增/修改路径与职责：[文件清单](iteration_files.md)。
