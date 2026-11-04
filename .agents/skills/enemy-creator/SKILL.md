---
name: enemy-creator
description: 新怪物、实质行为改造或补齐已有物种。
---

# enemy-creator

## 适用任务

新怪物、实质行为改造或补齐已有物种。

## 操作

1. 从 [对象索引](../../../docs/data/README.md) 读取相关地区圣经和物种规范，定位本次缺口；制作范围按 [开发手册](references/development_workflow.md) 与 [完成标准](../../../docs/project/enemy_completion.md) 选择。
2. 先整理物种规范：职责、接敌、预告、攻击、收势、受伤、死亡，以及玩家如何识别和应对；描述看得见、听得到的效果。数值引用配置，代码结构和检查放模块导航。
3. 沿 `game/enemies/` 的现有组件实现一组攻防，再补身体、动作、声音和正式遭遇。局部补齐沿用未变机制，表现消费实际接受的事件。
4. 在拟定地形检查距离、视线、落点、安全空间及击杀／绕行策略，按本次范围验证中断、返回场地与奖励。

## 验证与交付

选择 `enemy-structure-native`、`enemy-region-state` 和实际遭遇检查。验证活体／死亡／未激活、中断、回退、切图及奖励幂等；交付逐物种缺口、素材／代码、连续动作和正式遭遇证据。

模板：[现有设计卡](../../../docs/project/templates/enemy_design.md)。验收方法见 [开发质量](../../../docs/project/development.md)，实现与检查入口见 [模块导航](../../../docs/project/module_map.md)。
