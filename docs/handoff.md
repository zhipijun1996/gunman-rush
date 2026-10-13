# 当前质量迭代交接（2026-10-13）

分支 `feature/quality-review-and-production-loop`，基线 PR57 `5fd9c272d74616ae477809fa4285f609e6b697c6`；并行 PR56 `f721795` 未合入。此次用户授权当前游戏审查与修复，覆盖上一轮“纯流程不改运行代码”的范围限制；不改 PlayerMotor 基础参数、正式生成/收益算法，不发布、不自动合并。

三个新核心 Skills（player/weapon/ability）和十二类模板；harness 增加有界、留证、可续做的真实 Codex 调用模式。用法见 [生产循环](quality/production_loop.md)。当前内容采用 [通用审查](quality/review_method.md)，初审独立 REJECT 及修复范围见 [本轮规格](quality/current_review_spec.md)。

已实现候选：平台参考系镜头、暂停保留攻击相位、Boss共用接触规则、可见敌人受击范围、地形并集四边/四凸角/四凹角绘制、统一地面装饰、只读登场演出，以及两个开发敌人候选。两敌人入口为 Module Lab → More Trials → ENEMY CANDIDATES，不算正式池扩容完成。新素材/演出/趣味及真机没有用户认可，PLAINS-QUALITY-01保持review。最新运行证据、独立复审和PR随后追加本页。

八方向边界是用户本轮明确提出的制作约束：素材边界连接必须一致，随机长短不能靠拉伸整图适配。生成工具不会自动产出合格素材；每稿需检查实际分区/alpha/接缝，并在正式画面验收。

复验：`python3 tools/harness.py --profile full`；`python3 tools/run_quality_review_tests.py`；`python3 tools/harness.py --mission docs/quality/missions/skill-routing-smoke.json --execute --evidence-dir build/verification/skill-routing-smoke`。

---

以下为上一轮交接，保留历史，不覆盖上述最新修订。

# 项目质量体系交接

2026-10-12，QUALITY-SYSTEM-01，chore/game-quality-system，基于最新未合并 PR55 的 da76b0aa65f257f5208cde23e98aa8d9b3098ad1；main 为 6568e9a，已包含 PR54 最新玩法。本轮不改正式入口、物理、敌人强度、经济或随机算法，不发布游戏，不合并 PR。

## 当前成果

八个核心 Skills、G0–G5、十一维状态、九类模板、Visual Bible、动画/生成规范、AGENTS 路由、任务/PR 集成和自动差异守卫已落地。旧三个宽泛 Skill 已迁移，project-integration 保留。使用入口 [quality/README](quality/README.md)，完整审计/用例/文件清单见 [实施报告](quality/implementation_report.md)。

## 验证与限制

最终命令/提交/证据记录见实施报告和 docs/quality/records/QUALITY-SYSTEM-01.json。静态检查、模板演练与实际宿主调用分别记录；不伪造独立审查、真人/设备或美术认可。

基线 PR55 的 Web CI 失败，干净 da76b0a 复现 windkeeper.tscn:13 Parse Error Busy，harness 退出 1（导出子进程却为 0）。[原始失败](evidence/quality_system/baseline_web/report.json) 保留，HARNESS-WEB-01 单独跟踪。不能以此前宽松导出通过覆盖当前严格失败；本轮不降低错误检查。

## 下一步

先读质量使用入口，选一个实际小切片显式调用新 Skill，按真实证据完善任务记录；用户确认新敌人/Boss/地区画风等重大创意。未来武器树/区域能力仍需正式设计实现。独立审查及用户/设备验收未完成的内容保持 review/awaiting-device。

常用：`python3 tools/harness.py --profile docs`；`python3 tools/check_quality_diff.py --base origin/chore/project-harness-skills`；`python3 tools/quality.py check`。纯流程可交付，不等待未来游戏完成。前轮 [v1 handoff](archive/handoff_harness_v1.md) 保留历史，当前结果以本页和新证据为准。

流程实现提交 8bac191769c4d0e94ef4ae0fa5c07919048b1dd4 已在固定版本复验：core profile 9 检查全部通过（25 质量单测、11 runner 单测、3 拒绝演练、Core5942/0）。QUALITY-SYSTEM-01 按 process 范围 done，independent_review 未验。命令和退出码见 [commands](evidence/quality_system/implementation/commands.json)。

并行分支：执行期间新增 PR56@4ed7ba6（关卡工坊），与 PR55 同源 main、互不包含。已读其流程/契约；本次不合并它。后续整合保留真实 Motor/回放/源码指纹/工坊 CI，将开发 promote 与正式 G3/G5 区分，同时合并 README/tasks/handoff，不覆盖任一方。

Git 交付：[PR57](https://github.com/zhipijun1996/gunman-rush/pull/57)，base=chore/project-harness-skills（PR55），head=chore/game-quality-system；实现 8bac191，证据 5ff6873。未合并、未发布。PR 的远端 CI 状态以 GitHub 实际检查为准，本地退出码已归档。
