# DEATH-RUNTIME-01 当前交接

目标：保持死亡动画，优化死亡运行成本。

- 进度与直接依赖见 [任务表](../../tasks.md)，本文件不复制状态。
- 接续：从当前 main 建本议题分支并认领写集；本轮管理整理未执行本议题的内容修改。
- 实现／检查来源：`10dcd39abd8dd8be57cf838167989dd0ca93502b`；原结果只证明该来源，不能代签当前源码。
- 代码与写集入口：[实际消费者](../../../../game/presentation/actors/underworld_plains/underworld_enemy.gd)；相关规范和专项由 [模块导航](../../module_map.md) 定位，按本次目标限制修改范围。
- 下一动作：聚合首用／战斗／死亡性能链，在同版真实设备复验；技术合入不代签帧时间。
- 可运行的相关入口：`python3 tools/harness.py --check enemy-structure-native`。是否执行及是否需要设备，按上面的下一动作决定；本交接未把它记为新成绩。
- 本议题当前按普通交接继续，不要求质量卡。 原始记录按需见 [来源](../../../evidence/quality/records/DEATH-RUNTIME-01.json)。

## 当前缺口

同版真实设备的首次使用、战斗及死亡帧时间未验。
