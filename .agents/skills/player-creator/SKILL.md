---
name: player-creator
description: 主角整体设计、成套动作或操作表现改造。
---

# player-creator

## 适用任务

主角整体设计、成套动作或操作表现改造。

## 操作

1. 定位 `game/player/`、实际人物场景与 `game/player/presentation/`；读取输入、人物物理及当前Visual Bible。
2. 用一套身体母版定义脚底、枪口、附件与各状态姿态，列动作进入／退出、转向、受伤、死亡和落地衔接。
3. 先在正式控制器与真实镜头完成一个连续动作样板，再扩展其余状态。动作规则归能力与Motor，表现订阅已接受事件。

## 验证与交付

覆盖左右朝向、瞄准角、跳跃／反冲衔接、暂停／死亡及真实UI。相关 `core`、`weapon-feel` 和人物表现专项按实际修改选择；交付状态表、合屏和正常速度录像。

任务使用 [现有设计卡](../../../docs/templates/player_design.md)。质量阶段、独立审查、证据与未验声明共用 [开发质量](../../../docs/development_quality.md)；验证选择见 [Harness](../../../docs/harness.md)，代码落点见 [模块导航](../../../docs/module_map.md)。
