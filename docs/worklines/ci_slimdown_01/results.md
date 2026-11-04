# CI-SLIMDOWN-01

范围：从 main `f11c750` 创建 `codex/ci-slimdown`，替换 CI/Harness 架构；游戏玩法、正式场景/资源、SDK、素材和导出预设不改。

- 日常：227 个原注册检查、179 项 full → 固定 4 项自动验证（1 个 Actions context `affected`）。项目检查、导入、正式入口冒烟和必要核心契约；main/PR 使用同一套，无自动发布。
- 手动：172 项可选专项；原游戏 GDScript 测试全部保留。退出注册的历史/实验/质量/录像检查不参与日常 CI；手动与废弃分类见 [测试取舍](../../ci-test-inventory.md)。
- 删除：影响规划、production_impact、输入工件恢复、双通道合流/缓存证明、旧 CI artifact 浏览器证明协调器及专用测试；两个自动工作流直接缩写，旧 docs 工作流删除。没有新增调度器、缓存或证据框架。
- 发布：environment.yml 仅手动，支持 Web/Windows/Android、Windows+Web，勾选才部署；已有包的 prepared playtest 部署保留。原 Web 工件名称、部署验证接口和公开 PCK 检查保留，publish_playtest 消费者继续有效。
- 开发：AGENTS、集成技能、当前创作入口已同步显式相关专项规则，不再要求 full/质量卡/历史证据。

实际本地验证：锁定 Godot `4.7.2.stable.custom_build.gunman_sd1.ed1daf0bf`，四项 CI 成功（exit 0），20.76 秒，已存在导入缓存。project 0.87 秒、import 10.52 秒、smoke 7.19 秒、contracts 2.18 秒。冒烟 9、核心契约 239、原存档 39 断言均零失败；复用现有音频 drain，退出无泄漏。首轮冷导入的自定义字体启动错误和早期测试清理失败已修正，不将旧失败计为通过。

真实故障注入后全部恢复原字节：

| 注入 | 实际结果 |
| --- | --- |
| project.godot 指向不存在主场景 | project exit 1，0.86 秒 |
| 冒烟脚本继承不存在类 | smoke exit 1，0.43 秒，实际解析错误立即中止 |
| RunWallet 重复 receipt 再发金币 | contracts exit 1，1.67 秒；原 239 断言检出 9 失败 |

Harness 8 项真实子进程测试通过，覆盖非零退出/缺 marker/超时/脚本与 Shader 错误/退出泄漏/子进程清理；发布辅助工具原 13 测试通过。actionlint 检查新 CI/发布/已有包部署工作流通过；Python 编译和 git diff --check 通过。正式游戏/资源 diff 为空。

2026-11-04 已通过 GitHub branch API 实读 main：`protected=false`，`required_status_checks.contexts=[]`，`checks=[]`，`enforcement_level=off`；rulesets API 返回 `[]`。Administration protection API 的直接读取被 App 权限拒绝，但 branch API 已提供上述明确状态。当前无旧 required context 待移除；以后只设 `affected`，不设置手动 job 为必需。

实际远端冷 CI：提交 `553b831` 的 [Actions #41749090783](https://github.com/zhipijun1996/gunman-rush/actions/runs/41749090783) 已 SUCCESS，00:44:36–00:46:13 UTC，总 97 秒（含排队/准备/收尾），唯一 `affected` job 94 秒。四项验证日志合计 59.06 秒：project 0.72、import 52.52、smoke 4.51、contracts 1.31；远端同样 9＋239＋39 断言零失败。检出约 20 秒、编辑器安装约 4 秒；没有模板、历史证据或 full。另经独立审查修复现行创作路由对已删除注册名的引用；路由校验隔离了历史媒体加载，不代表内容验收。

本分支已创建 [PR #133](https://github.com/zhipijun1996/gunman-rush/pull/133)。本报告及剩余技能旧命令清理的后继提交会自动触发同一四项 CI，最终 head 状态以该 PR/Actions 和交付回复为准。此任务不合并 main，不发布新游戏，不把 headless 测试当设备/视觉/完整游戏验收。手动正式多平台导出本轮未执行。
