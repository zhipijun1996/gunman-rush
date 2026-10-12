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
