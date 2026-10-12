# Gameplay Review Report

## 任务合同

- task_id / task_type / workflow / owner / schema_version：
- baseline_commit / reviewed_commit / content_version / branch：
- 目的、玩家体验及与既有内容的实质区别：
- 设计限制、用户授权范围、重大创意 proposed/user_confirmed/not_required 及原始依据：
- 前置依赖、实际能力/武器/资源/配置版本、受影响路径与正式消费者：
- 交付物、相关 G0–G5、十一维状态记录路径：
- 未验事项、失败记录和返工门槛：

以下每条都要写具体入口、操作、可观察结果与失败条件；删除不适用项时给理由，不能保留空格后声称通过。

## 审查身份与范围

reviewer / implementers / independent（true/false）/独立依据；审查 commit/content_version；基线和 diff；使用的实际规格/代码/运行场景/工具；未读取或未运行的范围。审查者只写发现/隔离反例，不修改被审生产代码。独立性无法成立就 UNVERIFIED，作者自检明确 self_review。

## 十维审查矩阵

设计落实、玩法价值、操作流畅、动画自然、美术协调、特效音频、关卡公平、随机实质变化、正式消费者、性能/状态/保存回退。每一项记录“场景→实际方法→观察→失败判据→证据”，不要复述作者总结。

## 发现与反例

| ID/严重性 | 场景和复现输入 | 实际结果/违反的规格 | 证据时间段 | 所属门槛/修复建议 | 复审版本/结果 |
| --- | --- | --- | --- | --- | --- |
| 待填写 | 目标设备、Seed、能力、入口 | 客观失败与主观待审分开 | 文件、hash、命令或录像 | 先修根因再重跑 | 保留前次 REJECT |

## 结论

ACCEPT / REJECT / UNVERIFIED，列必修项、主观待审和残余风险。存在阻断缺陷或没有真正审查时不得 ACCEPT；主观价值没有证据写未验。通过仅覆盖实际审查内容版本，不自动认可未试玩设备或后续素材。
## 证据与返工

逐条记录 status（passed/failed/unverified/not_applicable）、证据 ID/路径/SHA256、source_commit/content_version、命令/退出码、操作者/设备、Seed/Manifest、录像时间段、实际观察。失败保留原始输出、复现步骤、发现 ID、修复提交、重跑和复审关系。若写 not_applicable，解释本任务为什么不涉及该项；用户认可需原话和来源。

## 完成判断

使用 [质量报告](quality_gate_acceptance.md) 汇总十一维；阶段原型完成不能作为完整内容 done。记录剩余项/阻塞/下一步，不将空白或 AI 自评当最终认可。
