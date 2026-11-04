---
name: ability-creator
description: 新增或实质修改H/W/D等移动／战斗能力、授予与能力锁。
---

# ability-creator

## 适用任务

新增或实质修改H/W/D等移动／战斗能力、授予与能力锁。

## 操作

1. 读取相关动作和地区能力门槛，先更新能力规范：如何操作、何时可用、产生什么运动、怎样恢复，以及失败／取消时的表现。
2. 从 `game/player/actions/` 与真实授予入口修改组件和配置。能力向唯一 PlayerMotor 提交运动，次数、冷却与恢复按实际来源结算。
3. 用真实输入验证地面、空中、墙面、移动参照、授予／移除和回程；影响地图准入时同步实际能力快照。

## 验证与交付

用 `all-weapons`、`weapon-feel` 或目标地区Motor专项中的相关检查，覆盖成功、失败和中断。交付能力状态表、授予代码、真实轨迹及教学／能力锁验证。

模板：[现有设计卡](../../../docs/templates/ability_design.md)。验收方法见 [开发质量](../../../docs/development_quality.md)，实现与检查入口见 [模块导航](../../../docs/module_map.md)。
