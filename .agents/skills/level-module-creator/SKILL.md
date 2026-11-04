---
name: level-module-creator
description: 平台挑战模块的新增、端口／几何／机制修改及模块准入。
---

# level-module-creator

## 适用任务

平台挑战模块的新增、端口／几何／机制修改及模块准入。

## 操作

1. 定位 `game/world/components/`、模块Definition和目标模块库；读取任务涉及的动作、碰撞及端口合同。
2. 固定入口／出口、身体包络、合法能力、机关相位、资源余量和失败恢复。几何、素材尺寸与视觉锚点分别定义。
3. 先用真实Motor完成一个模块的正反镜像与最差相位，再验模块连接。平台、刺面、支撑和装饰由实际宿主关系决定。

## 验证与交付

用模块对应Motor检查；runtime-map内容使用 `runtime-map-windchime` 或M35相关专项。交付模块卡、准入拒绝原因、真实输入轨迹、连接／恢复与合屏结果。

任务使用 [现有设计卡](../../../docs/templates/level_module_design.md)。质量阶段、独立审查、证据与未验声明共用 [开发质量](../../../docs/development_quality.md)；验证选择见 [Harness](../../../docs/harness.md)，代码落点见 [模块导航](../../../docs/module_map.md)。
