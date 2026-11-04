---
name: level-module-creator
description: 平台挑战模块的新增、端口／几何／机制修改及模块准入。
---

# level-module-creator

## 适用任务

平台挑战模块的新增、端口／几何／机制修改及模块准入。

## 操作

1. 读取目标模块的动作、碰撞与端口约束，先整理入口／出口、合法能力、机关、落点、恢复和视觉意图。
2. 从 `game/world/components/` 和实际模块库修改定义、几何及配置，分别核对身体包络、机关相位与视觉锚点。
3. 用真实 Motor 完成单模块的镜像、最差相位和连接验证，核对平台、刺面、支撑与装饰的实际关系。

## 验证与交付

用模块对应Motor检查；runtime-map内容使用 `runtime-map-windchime` 或M35相关专项。交付模块卡、准入拒绝原因、真实输入轨迹、连接／恢复与合屏结果。

模板：[现有设计卡](../../../docs/project/templates/design.md)。验收方法见 [开发质量](../../../docs/project/development.md)，实现与检查入口见 [模块导航](../../../docs/project/module_map.md)。
