---
name: weapon-creator
description: 新增武器、升级分支或整套攻击行为。
---

# weapon-creator

## 适用任务

新增武器、升级分支或整套攻击行为。

## 操作

1. 从 `game/combat/weapons/`、`resources/weapons/`、WeaponCatalog定位Definition、Runtime及当前装备消费者；按分支读取动作设计。
2. 确定攻击包、弹体上限、反冲、伤害时点、共鸣成本、瞄准、冷却与中断；同一时刻保持一个武器家族。
3. 先做一个真实输入攻击样板，验证无敌人时的位移、真实碰撞、命中去重和升级／切换后旧弹体取消，再推广各分支。

## 验证与交付

用相关 `all-weapons`、`weapon-feel`、`studio-input` 检查及真实消费者验证连续动作。交付分支设计、运行定义、资源／反冲轨迹和正常速度音画。

任务使用 [现有设计卡](../../../docs/templates/weapon_design.md)。质量阶段、独立审查、证据与未验声明共用 [开发质量](../../../docs/development_quality.md)；验证选择见 [Harness](../../../docs/harness.md)，代码落点见 [模块导航](../../../docs/module_map.md)。
