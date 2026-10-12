# 项目整合与开发规范交接

2026-10-12：最新 fix/web-loading-resilience 的 924a8d1 已经 [PR54](https://github.com/zhipijun1996/gunman-rush/pull/54) 合入 main，提交 6568e9a。当前整理分支 chore/project-harness-skills，基于该 main；起始工作区干净。

## 本轮范围

归档旧 AGENTS/README，建立 [当前状态](current_state.md)、[结构](project_structure.md) 与 [harness](harness.md)。四个本地 skills 指导切片、生成、美术与整合。统一 runner 复用既有检查，保留正式两图玩法、旧开发消费者、源素材和失败证据。详细最新运行与发布证据见 [D083归档](archive/handoff_d083.md)。

## 验证与继续

验证结果见 [整合记录](project_integration.md)。每轮先 python3 tools/harness.py --plan，再按范围执行 profile；临时报告在 build/verification/harness/，精选报告随任务进入 docs/evidence/。

下一切片：依据用户实际试玩反馈，用 [模板](templates/iteration.md) 定义一个可观察改进，读相应 skill，保持技术/GUI/设备/趣味性分开。完整真人探索、手机/手柄、大陆真实连接仍待验，国内镜像未部署。不能因整理或 main 合并标成已通过。
