# 项目归整与 harness / skills v1

2026-10-12，基线 main 6568e9a，分支 chore/project-harness-skills。最新累积内容已经 PR54 合入 main，本轮不改玩法。

## 实际变化

旧 AGENTS/README 的历史叠加说明归档，当前入口收敛为通用实现底线、现行状态导航、四个本地 skills 和一个 harness。现行规则明确两图探索/命中回能，旧三关/八关继续作为开发回归。结构文档说明目录职责、删除条件、保留的源母版和真实消费者。

harness 配置化复用既有 docs、core、历史、region、art、Web 工具，范围选择包含提交/工作区/新文件，unknown 保守 full；每项有超时、退出码、成功标记和日志。CI 使用相同入口，不删除既有检查。故障测试覆盖非零退出带成功文本、零退出缺完成标记、超时（含独立引擎会话）、缺工具、脚本错误假成功与范围选择。

## 验证记录

首次 docs profile 因本记录文件尚未创建而失败；保留 build/verification/harness/20261012T161311.104859Z/docs.log，创建后重新验证。最终结果在完成验证后补充，未执行的项不记通过。

设备、手感、趣味性与大陆网络继承未验范围；不声称自动生成规范已能保证游戏获得用户认可。后续用真实可玩切片继续快速迭代。

额外实际清理：四个测试 runner 的输出从历史证据目录迁往 build/verification/generated/；docs/preview 加 .gdignore，并删除无运行消费者的 Godot 导入元数据。保留原图和所有断言。
