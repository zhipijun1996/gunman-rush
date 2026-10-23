# AI 关卡设计 v1 实验证据

工程报告（含真实 Godot 对照录像）：[打开报告](index.html)。[下载 27.6 秒录像](pilot-latest.mp4)。[下载原生证据和源覆盖](evidence.zip)，恢复规则及逐成员 SHA 见 [索引](evidence.index.json)。

托管目标：https://zhipijun1996.github.io/gunman-rush-previews/reports/AI-LEVEL-DESIGN-01/v1-f3a4de289eb1/

这是一份工程审查页，不是可操作游戏。四层 sidecar 不替换正式 Godot 消费者；Macro 可选。全部 177 份参考有可追溯初审，其中 9 份深入、168 份有限审查；169 份仍需进一步证据。

最终主线与最新开发规则各 27 个原生策略条件，每组 13 通过、14 保留失败；有界关系搜索 12 个条件通过。41 项合同/流水线反例测试及 22 项规划器测试通过。录像六段连续采集的 frames/events 与对应 headless 实验相同，不代表真人趣味认可。

新候选全部保持 review/rework：高路可被普通一跳替代；回家环缺少状态或收益价值；回望候选两轮修补后停止。零正式准入。奖励仅位置/返回标记，未覆盖正式领奖、动态机关、整图、真人或设备。

首次 ai-level-pilot 的内层九条件通过，但外层因同时写文档触发 source_changed 拒绝；原失败收据保留。最终冻结后的重跑另附，不能追认首次通过。完整历史 docs/quality 因 sparse checkout 缺少历史原件未通过，未放宽原守门。

恢复：按 evidence.index.json 中每个 runtime 的不可变 Git SHA 检出源码，再覆盖 ZIP 中对应 source/，逐项检查 runtime_source 的 SHA，安装 tools/setup_environment.py 指定 Godot 4.7.2，按原 request 和 catalog 重跑。二进制美术从固定 Git 基线取得。早期 v1/v2 没有完整 producer 源字节，只保留诊断原件，不称完全可复现。

最终独审：[限定技术 ACCEPT、内容设计 REVISE](../../ai_level_design_v1/independent_review.md)。完整源码设计与命令见 [体系说明](../../ai_level_design_v1/README.md)。

最终冻结后原 Harness `ai-level-pilot --release` 实际重跑 exit 0，原九条件通过；[重跑外层收据](harness-pilot-retry.json)与[首次拒绝](harness-pilot-first-failure.json)分开保留。质量记录一致性检查 exit 0，任务仍为 review。

恢复物化范围也属于证据：原实验使用 sparse 工作树，必须按各 `runtime_source` 清单物化运行文件，再应用文本覆盖。完整检出会多出未测文件，严格旧缓存会拒绝复用；可重新运行生成新的完整源收据，不能把旧收据重签。引擎二进制亦须与索引 identity 一致。

公开托管已完成并匿名逐成员 SHA/长度核对，Chromium 实测 54 案例、177 条参考、筛选/滑块和 27.6 秒视频解码正常，无页面异常；见 [发布收据](public-delivery.json)。源码草稿 [PR #107](https://github.com/zhipijun1996/gunman-rush/pull/107)。独立质量工作树补足原资产后，针对实际 PR base 的 [quality diff](quality-diff.log) 通过。本 PR 因共享 Harness 注册变更正确升级 full（[原影响计划](development-plan.json)），整套 PR CI 尚待完成，不由局部通过代签。
