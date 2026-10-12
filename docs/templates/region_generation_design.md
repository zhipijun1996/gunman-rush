# Region Generation Design Sheet

## 任务合同

- task_id / task_type / workflow / owner / schema_version：
- baseline_commit / reviewed_commit / content_version / branch：
- 目的、玩家体验及与既有内容的实质区别：
- 设计限制、用户授权范围、重大创意 proposed/user_confirmed/not_required 及原始依据：
- 前置依赖、实际能力/武器/资源/配置版本、受影响路径与正式消费者：
- 交付物、相关 G0–G5、十一维状态记录路径：
- 未验事项、失败记录和返工门槛：

以下每条都要写具体入口、操作、可观察结果与失败条件；删除不适用项时给理由，不能保留空格后声称通过。

## 五层设计

逐层填宏观拓扑、中观玩法段落、微观动作模块、内容奖励、体验导演；每层列复用类/输入/输出/约束/可观察体验/已实现与候选边界。使用当前 Generator/Topology/Recipes/Assembler/RunRandomStream 和 Manifest。

记录能力快照、武器反冲/资源差异、确定授予能力的前置路径、版本/保底、Seed 集合及选择理由。定义拓扑/动作/机制/风险收益签名、连续压力恢复、重复遭遇和回程统计的方法；阈值是设计提案还是已确认必须注明。

## 场景化验收

| ID | 场景/前置 | 方法 | 应观察结果 | 失败条件 |
| --- | --- | --- | --- | --- |
| R01 | 代表 Seed/极端/保底 | 分别检查图结构与真实 Motor 轨迹 | A拓扑、B物理、C能力资源、D复现分别成立 | 图连通掩盖碰撞不可达、错能力、重抽图 |
| R02 | 快找Boss/正常成长/绕高级奖励后返回 | 同 Seed 用真实输入完成三种路线 | 不同成本/收益/决策，回程可完成 | 只有一条固定操作链、奖励无风险关系 |
| R03 | 多 Seed 对照 | 拓扑和动作/机制组合/压力统计+录像 | E结构、F操作有实质差异 | hash/坐标/模块顺序不同但玩家动作相同 |
| R04 | 玩家完整探索 | 原始体验反馈和目标设备记录 | G趣味/惊喜/节奏按玩家实际评价 | 用统计或 AI 自评分冒充认可 |

## 证据与返工

逐条记录 status（passed/failed/unverified/not_applicable）、证据 ID/路径/SHA256、source_commit/content_version、命令/退出码、操作者/设备、Seed/Manifest、录像时间段、实际观察。失败保留原始输出、复现步骤、发现 ID、修复提交、重跑和复审关系。若写 not_applicable，解释本任务为什么不涉及该项；用户认可需原话和来源。

## 完成判断

使用 [质量报告](quality_gate_acceptance.md) 汇总十一维；阶段原型完成不能作为完整内容 done。记录剩余项/阻塞/下一步，不将空白或 AI 自评当最终认可。
