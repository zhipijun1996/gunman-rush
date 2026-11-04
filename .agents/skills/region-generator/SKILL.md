---
name: region-generator
description: 随机地区拓扑、模块池、内容分布及探索节奏的新增或修改。
---

# region-generator

## 适用任务

随机地区拓扑、模块池、内容分布及探索节奏的新增或修改。

## 操作

1. 按目标地区读取选定 Bible、当前生成版本与相关能力约束，定位实际 Provider、代表／最差 Seed 及需保留的体验。
2. 先更新主路、可选发现、捷径、营地、Boss 接近和返回的生成规则，再修改模块池、能力锁与空间配置；候选版本保持显式选择。
3. 用一个黄金场所验证动作、敌人关系、空间和画面，再扩模块与种子。地图和奖励沿现有独立随机流，Manifest 记录实际选择与稳定实例。

## 验证与交付

使用 `level_design.py` 的validate／analyze／compare与相关 `region`／森林Motor／mapgen专项。交付版本、Seed矩阵、Manifest、真实出返程和空间差异；结构诊断与实际可达分别记录。

模板：[现有设计卡](../../../docs/project/templates/design.md)。新内容的审查方法见 [开发与审查](../../../docs/project/development.md)，实现与检查入口见 [模块导航](../../../docs/project/module_map.md)。
