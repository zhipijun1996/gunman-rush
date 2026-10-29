# 怪物开发skills补齐

任务ENEMY-WORKFLOW-01，process；基线`75f23dfd`，沿草稿PR112继续。用户已要求统一完成标准，现追问怎样用开发skills达到标准。本轮将实际制作方法纳入现有技能，不新增另一个完成标准或运行框架。

## 实际变更

- [开发手册](../../../.agents/skills/enemy-creator/references/development_workflow.md)：按目标选起点，逐工序给出操作、实物交接、工具入口及失败返工层；由技能从源码补卡，用户不需手动填表或串联。
- enemy-creator统筹完整制作；art-director做同身体母版／同族素材与原图／裁区／锚；animation-vfx做实际步态／攻击／受伤退出及接受事件／死亡／声音接入；game-quality-gate路由同一任务。声音与遭遇沿原专业。
- 原Enemy／Art／Animation模板追加制作计划／专业交接，保G0–G5／十一维／原质量policy；三处旧BGM说明及两处旧排期改为引用当前授权／选择，不弱化Bible和漂移规则。
- 使用[冲锋怪卡](../../design/enemies/plains_charger.md)的CHR-VIS-01作为方法走查输入，下一操作记在本目录；原卡及其已绑定的规格／失败／影片保持原字节和来源。[旧复盘](../../enemy_feedback_01_production_lessons.md)增加方法回流索引，旧原文仍保留。

## 案例走查与能力边界

1. 当前冲锋怪两次H退出结构突变：先路由到身体母版，再做动画退出；不会因native绿灯继续调粒子。输入为原报告和当前live／H／D资源，后续母版／姿态／运行片为预期产物，**本轮未生成**。
2. 原fixture没有charger attack：先查真实激活／视线／安全／相位及接近路线，补真实attack覆盖；不把改射程／关保护或「已发射」作为证明。
3. 新怪物目标：从玩家决策和灰盒开始；旧怪纯表现补齐则引用原机制。两者不会统一强制重造AI或预先批量生成固定张数。

以上为同作者的方法走查，不是图像生成、运行实现、独立内容审查或自动生产能力实证。CLI帮助／计划验证只证明现有工具参数可调用；只有后续实际出图、接Godot、正式遭遇和G4／G5证据才可签相应内容。此轮不复用上轮876项技术结果签新生产，不改PNG／运行脚本／配置／工具／测试。

## 验证

按原docs profile与quality diff执行，收据在本目录追加；当前源流程检查和内容未验分开。原始工具入口与范围来自实际文件及CLI帮助，计划不当执行，说明书不当无人值守生成服务。流程完成只签本process，现有怪物不继承PASS。

精确实现源`99e5afa8`已完成原33项docs fresh验证，33／33 passed、0复用；[原报告](docs-profile/report.json)与逐项日志同目录，[汇总](validation.json)分列本轮范围。原quality diff通过；CLI帮助和development计划保存在[cli目录](cli/)，计划明确33项选择、0升级，只规划未执行生产。最终记录／任务收口另做原quality、docs与diff检查，不称新的整套或内容验收。
