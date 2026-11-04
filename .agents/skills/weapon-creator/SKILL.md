---
name: weapon-creator
description: 新增武器、升级分支或整套攻击行为。
---

# weapon-creator

## 适用任务

新增武器、升级分支或整套攻击行为。

## 操作

1. 按分支读取动作设计和当前武器规范，先写清射击方式、运动效果、命中反馈、技能及切换／取消时玩家能感知的结果。
2. 沿 `game/combat/weapons/`、WeaponCatalog 和 `resources/weapons/` 修改现有实现与参数，明确攻击包、弹体、反冲、伤害、共鸣与冷却的结算。
3. 先验证一段真实输入下的完整攻击，再扩分支；覆盖空发位移、碰撞、命中去重、升级／切换和旧弹体清理。

## 验证与交付

用相关 `all-weapons`、`weapon-feel`、`studio-input` 检查及真实消费者验证连续动作。交付分支设计、运行定义、资源／反冲轨迹和正常速度音画。

模板：[现有设计卡](../../../docs/project/templates/design.md)。验收方法见 [开发质量](../../../docs/project/development.md)，实现与检查入口见 [模块导航](../../../docs/project/module_map.md)。
