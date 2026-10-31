# R3 当前内容合同迁移：实施前设计

状态：仅设计。最新 all 诊断仍为 exit 1，不得把 4954 帧、Boss 0 / player 5、原 25 谓词无失败写成整个新候选通过。新增三个失败是实际发射组与延迟命中组的归属问题；其 observer 修复仍须独立审查和同源原生通过。本设计不改代码、旧失败或验收。

## 最小写集与双消费者

1. `tools/bellstrider_01/legal_input_pilot.gd`：采用最终实测且独审的同一 first/all 平台流程。当前 a77017e1 导航冻结，不为 R3 单测复制/再调策略。没有平台模式的旧行为保留；不改变射击、能力、物理或随机来源。
2. `tests/underworld_plains/bell_platform_fixture.gd` 及 UID：新增一个测试专用 RefCounted 薄装配/观察 helper。它不是新 App、地图提供器、物理或碰撞实现，也不拥有全局状态。只有下面真实两个消费者调用。函数名为拟议 API，尚未实现。
3. `tests/underworld_plains/capture_underworld_r3_boss_fight.gd`：真实 full consumer 迁移到 helper；**当前 Bell/map1 默认导航必须接同一 all 流程**，不能默认继续旧 cautious2死亡、只增加另一个绿色测试。原 wrapper无新参数也必须调用这个真实当前策略。map2 Pressure分支不改变；first只用于显式组件诊断。旧导航仅保为明确 opt-out历史诊断（拟复用同一参数 `--platform-counterplay=off`，参数解析结束后按实际 map选择默认，不能受参数先后影响），旧失败不覆盖。此处明确是测试输入策略合同迁移，并非逐字等价重构。保原 setup/signal/初始 placement 次序及所有原成功/失败条件。采用最后独审的实际 shot_id 发射归组 observer，不能在 helper 中另写一套匹配算法。
4. `tests/underworld_plains/test_underworld_r3_boss.gd`：原 flat-floor 两分支保完整动作，新增当前正式平台正向 consumer。其他 phase/armor/HP/restore/暂停/terminal/Windkeeper 历史分支不动。
5. `tools/harness/profiles.json`：只对 `underworld-continuous-bosses` 等实际引用该 helper 的现有检查尾追加新增真实输入及 UID；核既有 pilot/capture/module inputs 已覆盖。原检查集合、命令、预算、权重、cacheable 和 serial 都不变。独立质量迁移记录和原失败档案按既有机制提交，不另加 wrapper/framework。

## helper 的窄边界与顺序

- `create_formal_app(tree, seed) -> DemoApp`：仅抽原 `DemoApp.new`、关闭 meta persistence、加入 tree.root、原 `start_plains(seed)`、原等待 8 physics frames。返回真实 App；不复制任何配置、工厂或地图算法。capture 的 map2 fixture仍在原位置设置原 director map 索引并 `_load_stage` / 等8帧，不借此改成自然过图宣称。
- `place_initial_entry(tree, app, boss)`：仅原 `player.reset_at(boss.global_position + Vector2(-250,47))` 与5帧。必须在消费者已绑定真实健康、伤害、发射、死亡信号之后调用。它是明确的唯一初始摆位 fixture；两消费者不得中途再用。
- `platform_observation(stage, player, controller, encounter)`：移动已有 `_bell_platform_observation` 的唯一实现，读取真实 Module 的 one_way indices、已安装 StaticBody/CollisionShape、真实 slide contact 法线、有效 jump capability、当前 rig bounds。参数只给这几个直接读取者，不传万能 session、不创建碰撞形状/射线模型、不预测物理。
- 事件观察/最终诊断：把最终经过独审的 signal/shot_id 关联及判据转为测试 helper 的同一实现；每个消费者独立实例和 ledger。`shot_fired` 记录实际 ID→发射时组，actual `bell_hit` 按同一实际 projectile ID 关联；冲突、缺 ID、重复 ID 都 fail closed，命中时组另保作观察，不能重写生产 event。不得将跨组延迟命中算成多发或漏发。精确实现以正在修复的 observer 为准，不能按此文档伪称已验证。
- 原 capture 的 lifecycle 失败收据继续是它自己的职责；helper 只产出平台判据和只读证据，不能调用 quit、自动赢或吞失败。新 R3 consumer 也必须在真实 App 释放/terminal 失效时明确失败并保收据。
- 所有 World 清理由消费者使用现有 `audio_teardown.drain_world` 和原 App abandon/free；helper 不加持久 Node 引用、不会自动重复清场。

## 原覆盖逐项迁移

| 原覆盖 | 保留或迁移后的真实覆盖 |
|---|---|
| 原站立150帧、真实 flat floor/body 接触损血 | 原分支和动作逐字保留，仍断言真实 HP下降；保原 bounded travel/recovery 检查 |
| 原68帧后按住基础跳、向右78帧 | 原坐标、直接 warning fixture、等待、输入和循环逐字保留；明确标为当前 upper-bell 实际接触负例，要求真实 policy 玩家结算及 HP下降，不只改文字或 expectedfail；原旧‘无伤’断言版本/失败日志永久保留 |
| 原‘基础能力无伤跨真实 Boss 身体’正向义务 | 同一进程新增真实 App map1、实际 Module 低台、原 base caps/noH、同一 pilot first scope；从真实首 warning 到该组完成，要求实际支撑、普通起跳、空中换边、回落同一支撑、整个窗口 HP不降且零真实玩家结算、原两枪/两次真实 base-one 命中。不是单独反转旧断言 |
| 旧 roll 有界后恢复 | 两旧分支原 mode 检查保留；新增正例另由实际 groups_completed 和原 Definition/自然状态验证，不以固定78帧代表所有新组时长 |
| 当前全场两阶段/回冲/伤害/奖励 | 原 capture all 流程及25条件；全场每个自然选中 roll 由同一 helper核验，phase2 return 两腿必须在实际 ledger中出现才可称已验证，不强制改随机或循环重试 |

正向 case 的执行建议：`roll_trials()` 先完成原两 flat branches，结束 trace_roll 并 clear_fixture；随后建立真实 App，以同一个连续战斗 seed/入口 fixture 启动，运行同一 pilot first scope。每帧只刷新同一个 observer 并调用原 step；条件是实际 trial 完成或明确失败/对象释放/原上限耗尽。不存在读取以前成功 JSON 替代当次运行。正例完成后停止 Router 输入、保实际 receipt、正常 abandon/drain/free，再继续原后续 component cases。

为避免复制 full loop，新增正例仅驱动一个 group；其循环仍有显式至多7200 physics frame硬上限，并受原 component native 180s封顶。可在实现时从真实当前 Definition 推导更窄、解释得清的上限，但不得凭试出来的帧数提高原预算。全场完整行为继续只由原 capture负责，不把 capture SceneTree当库或启动嵌套引擎。原 `--roll-only` 应运行两个原 flat case与新增正例，保持名称覆盖含义明确。

原 wrapper完全保留：import90；component180；direction120；lifecycle180；两个 full各180。现 `underworld-continuous-bosses` Harness 外层360、serial=true、cacheable=false、原 success pattern均不动。是否新增正例还能在真实预算内完成，必须实跑证明，不以估算放宽。

## 实施前与提交门槛

1. 当前 all observer 修复先独审并运行成功，所有旧25及新判据都0fail；真实 phase2双腿、40发射/40唯一ID/40真实1伤、玩家HP、4物理币共12和 map2结算逐项绑定。此前 exit1 不覆盖。
2. 只在这之后实现上述 shared helper/两个真实消费者迁移；逐字逆变换核原 flat动作、全部无关断言、等待与 original capture预算。
3. 独立审查必须逐项批准：旧 late保证已经由真实当前正例承接、负例是原有动作而非换站位、旧 failed证据保留；不是单纯删‘无伤’检查或将伤害改成成功。
4. 验证矩阵包括：原 component及原 roll-only实际进入first正例；不加平台参数的原 full map1必须自然进入all并成功；原 map2 Pressure路由不变；显式off仅验证旧诊断可复现并保其失败、不纳成功基线；完整原 R3 wrapper --full-fights不加新CLI参数也必须全部成功（同源，仍原预算）。失败保持 failed，不能通过提高能力、传送、改碰撞/损伤/弹药或重选参数补绿。

以上为具体最小实施设计，不是成功保证或主树修改授权证明；执行时间和 source commit由 root最终真实结果绑定。
