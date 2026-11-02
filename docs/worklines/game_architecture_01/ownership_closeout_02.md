# GAME-ARCH-OWNERSHIP-02：剩余状态恢复调用收口

基线与整体回退提交：`ed95d67d8c19988ab6af3b720aa07a17fd1f59cf`。这是已授权架构重构的有限补充，不增加地图算法、图声内容或新业务规则。开始前的独立只读复核发现三处既存跨所有者写入；原始只读报告已[逐字归档](../../evidence/game_architecture_02/ownership-closeout-02/baseline/app-stage-ownership-closeout-review.json)，原计划亦保留原字节。候选三项已实现，当前为2e1c基点加精确7生产/4测试WIP；该基点提交本身不包含候选实现。

| 子批 | 具体写集与消费者 | 消除的问题 | 保留行为与验证 |
| --- | --- | --- | --- |
| Latch | `game/world/components/shot_latch.gd`、`game/world/levels/providers/plains_region_stage.gd`；原 Stage capture/setup 两消费者 | Stage 直接读写机关私有时钟、开关序列和平台运动字段 | 原字典键/类型/插入顺序、缺省值、恢复时点/重绘/运动位置不变；沿已有平台 `restore_motion`；原 plains-region/机关及 core 回归 |
| Flow | `game/application/demo_run_director.gd`、`demo_app.gd` 的 terminal reentry | App 直接写 `director.stage_complete=false` | 仍在同一加载时点重算已终态 Boss 的完成/奖励；不增加准入条件、不重置其他运行状态；原 Session/core/正式回归 |
| Boss arena | Windkeeper/Pressure Encounter、必要的 Arena 与 `demo_app.gd` 两个真实恢复位置 | App 调 Arena 私有 phase callback、遍历 Encounter 子节点修桥 | 普通 Boss 的 phase3 政策与 Pressure 实际 `bridge_break_ready` 保持分离；激活后恢复消费者也必须迁移；原 Pressure/Bell/森林恢复/core 回归 |

各状态只增加所属对象的窄操作，不引入新 Manager/Context/注册表。新增函数必须接真实消费者；不能仅搬字段或把不同恢复策略并为一个 phase3 判定。测试保全部原断言/命令/预算，按需要追加实际恢复/生命周期边界，不改假设来掩盖失败。

代理写集隔离：Latch 与对应既有测试由 items 负责；App/Director/Encounter/Arena 与对应既有测试由 preview 负责；root 负责文档、质量记录、整合及唯一 Godot 租约。独立审查者不改被审代码。候选冻结后核精确 SHA，原生定向回归通过再提交；最终仍须完整182及实际导出/GUI。当前已实现并完成下列有限预检；未完成全任务验收。


实际候选与结果见[质量卡](../../quality/records/GAME-ARCH-OWNERSHIP-02.json)，精确文件/SHA见[原生冻结计划](../../evidence/game_architecture_02/ownership-closeout-02/native-preflight/plan.json)。Latch保存结构是原七字段；早先只读报告称八字段是文档计数错误，原报告不回写。

- [11项原生预检](../../evidence/game_architecture_02/ownership-closeout-02/native-preflight/report.json)：import、Session54、Latch生命周期26、Windkeeper175、Pressure六项（97/1198/63/72/139/130）及core5686均通过，source11前后一致。
- [Bell原8项](../../evidence/game_architecture_02/ownership-closeout-02/bell-preflight/report.json)全部通过；保无fixed-fps、每项原90秒及整体300秒约束。这些是直接原命令预检，不是整个Harness/full182。
- [扩大region预检](../../evidence/game_architecture_02/ownership-closeout-02/consumers-preflight/report.json)在第三项停止：baseline1274/0、drops30/0后，cohesion lifecycle19/5、exit1。原region15未完成，不能把未运行项签通过。原report scope提及计划23项，是region15加Bell8的计划范围，不是23项全运行结果。
- [精确pre-P9 ed95同引擎对照](../../evidence/game_architecture_02/ownership-closeout-02/cohesion-baseline-02/report.json)也真实19/5，五条失败逐项相同；原脚本SHA不变、运行后源干净。第一次对照[baseline01](../../evidence/game_architecture_02/ownership-closeout-02/cohesion-baseline-01/report.json)因旧UID缓存/autoload路径错误只完成import，未跑测试，原件仍保留，不能当缺陷复现结果。

旧fixture失败单独交由CI-BOSS-CONSUMERS-01处理，不混入所有权等价迁移，也不豁免本次失败。静态独审原件和测试变更理由仍保审查当时native pending文字；后来root运行证据另列，不追改旧接受。新增Latch断言覆盖实际ferry，Pressure重载使用settled/collected奖励fixture，均不能冒称所有timed/permanent/空中奖励时钟或自然全战斗已验。formal全消费者、完整region15/full182、导出/GUI/设备仍未验，工作流保持in_progress。
