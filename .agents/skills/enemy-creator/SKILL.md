---
name: enemy-creator
description: 新怪物、实质行为改造或补齐已有物种。
---

# enemy-creator

## 适用任务

新怪物、实质行为改造或补齐已有物种。

## 操作

1. 按 [开发手册](references/development_workflow.md) 定位最早缺失工序；用 [完成标准](../../../docs/quality/enemy_completion_standard.md) 逐项核对E01–E12。
2. 沿 `game/enemies/` 的Registry／Factory／Definition建立战斗职责、AI状态、移动、预警、命中与恢复。新物种明确玩家需要新增的判断。
3. 依次完成机制灰盒、统一身体母版、动作过渡、命中／死亡／声音和正式遭遇；局部补齐复用未变的既有机制。
4. 在拟定地形核对攻击距离、视线、落点与安全区，观察普通输入如何绕过、等待、引诱或击杀；奖励和状态恢复接现有服务。

## 验证与交付

选择 `enemy-structure-native`、`enemy-region-state` 和实际遭遇检查。验证活体／死亡／未激活、中断、回退、切图及奖励幂等；交付逐物种缺口、素材／代码、连续动作和正式遭遇证据。

任务使用 [现有设计卡](../../../docs/templates/enemy_design.md)。质量阶段、独立审查、证据与未验声明共用 [开发质量](../../../docs/development_quality.md)；验证选择见 [Harness](../../../docs/harness.md)，代码落点见 [模块导航](../../../docs/module_map.md)。
