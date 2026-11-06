# PLAYER-PRESENTATION-01 当前交接

目标：主角连续动作代表样板。

- 进度与直接依赖见 [任务表](../../tasks.md)，本文件不复制状态。
- 接续：从当前 main 建本议题分支并认领写集；本轮管理整理未执行本议题的内容修改。
- 代码与写集入口：[实际消费者](../../../../game/presentation/actors/underworld_plains/underworld_player.gd)；相关规范和专项由 [模块导航](../../module_map.md) 定位，按本次目标限制修改范围。
- 下一动作：在当前共享人物消费者检查连续动作和画面；旧快照不代表当前外观已认可。
- 可运行的相关入口：`python3 tools/harness.py --check underworld-player-animation`。是否执行及是否需要设备，按上面的下一动作决定；本交接未把它记为新成绩。
- 本次内容审查见 [质量卡](quality/record.json)。

## 当前缺口

连续动作、真实合屏与用户视觉认可未验。
