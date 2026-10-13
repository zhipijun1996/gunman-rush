# Quality Gate Acceptance Report

## 任务合同

- task_id / task_type / workflow / owner / schema_version：
- baseline_commit / reviewed_commit / content_version / branch：
- 目的、玩家体验及与既有内容的实质区别：
- 设计限制、用户授权范围、重大创意 proposed/user_confirmed/not_required 及原始依据：
- 前置依赖、实际能力/武器/资源/配置版本、受影响路径与正式消费者：
- 交付物、相关 G0–G5、十一维状态记录路径：
- 未验事项、失败记录和返工门槛：

以下每条都要写具体入口、操作、可观察结果与失败条件；删除不适用项时给理由，不能保留空格后声称通过。

## 门槛和维度

G0/G1/G2/G3/G4/G5 每项写状态、理由、对应交付物和证据；与 quality/policy.json 的任务适用范围一致。十一维逐项填写 design、technical、formal_integration、visual、animation、audio_vfx、gameplay、performance、independent_review、device、player_acceptance，禁止只给 done。

## 逐场景验收

| criterion_id | 场景/前置 | 验证方法 | 期望观察 | 失败判据 | 实际结果/状态 | 证据 ID/版本 |
| --- | --- | --- | --- | --- | --- | --- |
| 待填写 | 入口/Seed/配置/能力/设备 | 自动命令/真实输入/连续录像/独立审查/用户反馈 | 可观察行为 | 明确什么情况退回 | 不以未验当通过 | 原始记录/时间段/hash |

## 完成计算

运行 python3 tools/quality.py check RECORD；提交 done 前再 --require-complete。CLI 有效只证明结构/声明一致；证据真实性和体验需要审查。列技术已完成、内容尚缺、用户未确认及设备未验。process 只需适用流程门槛，不等待未来游戏真人验收。
## 证据与返工

逐条记录 status（passed/failed/unverified/not_applicable）、证据 ID/路径/SHA256、source_commit/content_version、命令/退出码、操作者/设备、Seed/Manifest、录像时间段、实际观察。失败保留原始输出、复现步骤、发现 ID、修复提交、重跑和复审关系。若写 not_applicable，解释本任务为什么不涉及该项；用户认可需原话和来源。

## 完成判断

使用 [质量报告](quality_gate_acceptance.md) 汇总十一维；阶段原型完成不能作为完整内容 done。记录剩余项/阻塞/下一步，不将空白或 AI 自评当最终认可。

## 正式消费者覆盖

新正式任务填写 consumer_coverage（纯文档保留 null）。依 [覆盖闭环](../quality/review_method.md) 先运行 inventory，再逐消费者填观察与证据，区分运行实例覆盖、画面样本覆盖、排除范围。每个 observed ID 必须来自实际 inventory；只测辅助函数或别的消费者不算通过。
