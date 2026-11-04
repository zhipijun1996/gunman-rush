---
name: game-quality-gate
description: 重要游戏内容的质量阶段、专业路由、验证范围和完成声明。
---

# game-quality-gate

## 适用任务

统筹重要游戏内容；局部修复与流程整理按实际影响选用既有small_fix／process类型。

## 操作

1. 明确玩家体验、实际场景、基线、写集和完成条件，按任务读取相关圣经与对象规范，核设计、参数和实现是否一致。
2. 选择一个主导专业，其他专业只承担需要的输入或审查；对象开发找对应 creator，关卡找模块／挑战／遭遇／地区，表现找美术／构图／动态／音频，剧情和独审分别找对应 Skill。
3. 按 [policy](../../../docs/quality/policy.json) 选择适用范围：G0 规格、G1 操作、G2 视听、G3 集成、G4 检查与独审、G5 用户与设备，共用任务记录。
4. 先验证一个黄金样板，再扩展；失败交责任专业修复并复验，发现、证据、预算与恢复信息留在工作线。

## 验证与交付

使用 [Harness](../../../docs/harness.md) 显式选择相关专项，日常CI运行`tools/ci.py`四项检查。`quality.py init`建立记录，`quality.py check`校验；最终完成声明使用`--require-complete`。

交付范围、十一维、G0–G5及证据规范唯一见 [开发质量](../../../docs/development_quality.md)。技术、正式GUI、独审、用户体验与真机分别记录。任务恢复与媒体选择见 [协作交付](../../../docs/cloud_production.md)。
