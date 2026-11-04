---
name: boss-creator
description: 新Boss，或Boss机制、阶段与核心招式重构。
---

# boss-creator

## 适用任务

新Boss，或Boss机制、阶段与核心招式重构。

## 操作

1. 定位 `game/bosses/`、BossFactory与实际Definition／场景；读取目标区域Bible和当前Boss设计。
2. 设计招式组、预警／攻击／恢复窗口、阶段转换、弱点、反制和真实平台支撑。比较目的打法、最便宜退化打法及关键机制消融。
3. 先完成真实输入下的一组招式与反制，再扩阶段；接入封场、段回退、失效、死亡动画与保证奖励。每个实例拥有独立状态。

## 验证与交付

覆盖连续两次恢复、阶段边界、玩家与Boss同帧死亡、取消和奖励重复领取。相关Boss专项由Harness计划选择；交付招式时序、完整遭遇录像、状态与奖励收据。

任务使用 [现有设计卡](../../../docs/templates/boss_design.md)。质量阶段、独立审查、证据与未验声明共用 [开发质量](../../../docs/development_quality.md)；验证选择见 [Harness](../../../docs/harness.md)，代码落点见 [模块导航](../../../docs/module_map.md)。
