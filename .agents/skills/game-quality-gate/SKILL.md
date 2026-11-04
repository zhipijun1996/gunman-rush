---
name: game-quality-gate
description: 重要游戏内容的质量阶段、专业路由、验证范围和完成声明。
---

# game-quality-gate

## 适用任务

统筹重要游戏内容；局部修复与流程整理按实际影响选用既有small_fix／process类型。

## 操作

1. 明确玩家体验、真实消费者、任务基线、允许写集与完成条件。选一个专业主导技能，其余专业只承担需要的输入或审查。
2. 路由：人物／武器／能力→对应creator；敌人／Boss→对应creator；模块／连续动作／遭遇／地区→level-module-creator、challenge-choreographer、encounter-director、region-generator；资产／画面／构图／动态／音频→art-director、visual-director、scene-composer、animation-vfx、audio-director；剧情→story-writer；独审→gameplay-reviewer。
3. 共用一份任务质量记录。G0写规格；G1验证真实操作；G2做视听样板；G3接正式消费者；G4自动检查及独审；G5记录用户与设备。适用门槛由 [policy](../../../docs/quality/policy.json) 定义。
4. 先一个黄金样板，再扩展内容。设计审查比较目的打法、退化打法和关键机制消融；地区创作按 [当前Bible入口](../../../docs/creative_direction/README.md) 选择版本。
5. 失败定位到责任专业，保存发现与实际证据，修复后复验受影响范围。独立无依赖工作可继续；达到任务预算时交可恢复状态。

## 验证与交付

使用 [Harness](../../../docs/harness.md) 的影响计划选择开发／集成检查。`quality.py init`建立记录，`quality.py check`校验；最终完成声明使用`--require-complete`。

交付范围、十一维、G0–G5及证据规范唯一见 [开发质量](../../../docs/development_quality.md)。技术、正式GUI、独审、用户体验与真机分别记录。任务恢复与媒体选择见 [协作交付](../../../docs/cloud_production.md)。
