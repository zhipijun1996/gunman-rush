# GAME-ARCH-OWNERSHIP-02：剩余状态恢复调用收口

基线与整体回退提交：`ed95d67d8c19988ab6af3b720aa07a17fd1f59cf`。这是已授权架构重构的有限补充，不增加地图算法、图声内容或新业务规则。开始前的独立只读复核发现三处既存跨所有者写入；原始报告在 `/workspace/refactor-evidence/app-stage-ownership-closeout-review.md/json`，后续归档其原字节。

| 子批 | 具体写集与消费者 | 消除的问题 | 保留行为与验证 |
| --- | --- | --- | --- |
| Latch | `game/world/components/shot_latch.gd`、`game/world/levels/providers/plains_region_stage.gd`；原 Stage capture/setup 两消费者 | Stage 直接读写机关私有时钟、开关序列和平台运动字段 | 原字典键/类型/插入顺序、缺省值、恢复时点/重绘/运动位置不变；沿已有平台 `restore_motion`；原 plains-region/机关及 core 回归 |
| Flow | `game/application/demo_run_director.gd`、`demo_app.gd` 的 terminal reentry | App 直接写 `director.stage_complete=false` | 仍在同一加载时点重算已终态 Boss 的完成/奖励；不增加准入条件、不重置其他运行状态；原 Session/core/正式回归 |
| Boss arena | Windkeeper/Pressure Encounter、必要的 Arena 与 `demo_app.gd` 两个真实恢复位置 | App 调 Arena 私有 phase callback、遍历 Encounter 子节点修桥 | 普通 Boss 的 phase3 政策与 Pressure 实际 `bridge_break_ready` 保持分离；激活后恢复消费者也必须迁移；原 Pressure/Bell/森林恢复/core 回归 |

各状态只增加所属对象的窄操作，不引入新 Manager/Context/注册表。新增函数必须接真实消费者；不能仅搬字段或把不同恢复策略并为一个 phase3 判定。测试保全部原断言/命令/预算，按需要追加实际恢复/生命周期边界，不改假设来掩盖失败。

代理写集隔离：Latch 与对应既有测试由 items 负责；App/Director/Encounter/Arena 与对应既有测试由 preview 负责；root 负责文档、质量记录、整合及唯一 Godot 租约。独立审查者不改被审代码。候选冻结后核精确 SHA，原生定向回归通过再提交；最终仍须完整182及实际导出/GUI。当前仅批准范围，尚未实现/验收。
