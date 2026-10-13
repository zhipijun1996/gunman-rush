# 项目归整与 harness / skills v1

2026-10-12，基线 main 6568e9a，分支 chore/project-harness-skills。最新累积内容已经 PR54 合入 main，本轮不改玩法。

## 实际变化

旧 AGENTS/README 的历史叠加说明归档，当前入口收敛为通用实现底线、现行状态导航、四个本地 skills 和一个 harness。现行规则明确两图探索/命中回能，旧三关/八关继续作为开发回归。结构文档说明目录职责、删除条件、保留的源母版和真实消费者。

harness 配置化复用既有 docs、core、历史、region、art、Web 工具，范围选择包含提交/工作区/新文件，unknown 保守 full；每项有超时、退出码、成功标记和日志。CI 使用相同入口，不删除既有检查。故障测试覆盖非零退出带成功文本、零退出缺完成标记、超时（含独立引擎会话）、缺工具、脚本错误假成功与范围选择。

## 验证记录

首次 docs profile 因本记录文件尚未创建而失败；保留 build/verification/harness/20261012T161311.104859Z/docs.log，创建后重新验证。修复后完整本地执行的 19 项检查全部通过。最终 runner 在干净实现提交 759e56e 单独通过 docs profile 与 11 项故障回归。

设备、手感、趣味性与大陆网络继承未验范围；不声称自动生成规范已能保证游戏获得用户认可。后续用真实可玩切片继续快速迭代。

额外实际清理：四个测试 runner 的输出从历史证据目录迁往 build/verification/generated/；docs/preview 加 .gdignore，并删除无运行消费者的 Godot 导入元数据。保留原图和所有断言。

## 最终证据与限制

- [机器摘要](evidence/project_harness/verification.json)：Core 5942/0、43 套历史、15 套地区、8 项素材检查、缓存预算、Web 实际导出与分块/许可完整性全部通过。
- [输出摘要](evidence/project_harness/check_summaries.txt)、[保留诊断](evidence/project_harness/diagnostics.txt)：既有退出资源诊断与导出 Busy 保留，不声称零诊断。
- [最终 runner 11 项故障回归](evidence/project_harness/runner_tests.log)、[干净源码 docs 报告](evidence/project_harness/docs_verification.json)、[首次失败](evidence/project_harness/initial_docs_failure.log)。
- [main 线上核对](evidence/project_harness/main_public_build.json)：合并后的完整 CI 成功，公开版本 eb5d12953417 来自 6568e9a。

完整本地执行起于有未提交变更的整合工作区，期间补完 runner 的超时/错误防护和文档；地区测试加载前已改写输出路径。生产玩法/场景/资源/参数未变。最终 runner 单独故障回归通过；实现提交的完整 CI 仍在运行，不把本地混合工作区报告说成最终提交的完整 CI 已通过。

本轮实际清理了历史入口说明、9 个非运行导入元数据和测试对历史证据的覆盖路径；未删除仍有消费者的开发回归、素材母版和失败证据。PR55 交付可审阅规范 v1，不改生产玩法。下一轮优先从正式入口完整体验定义可玩的改进切片，再用 skills/harness 验证，不直接扩展未实现地区。
