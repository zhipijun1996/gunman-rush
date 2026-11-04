# CI 测试取舍（CI-SLIMDOWN-01）

日常自动检查入口由 `.github/workflows/production.yml` 与 `tools/ci.py` 定义；具体命令和计时见 [Harness](harness.md)。自动 CI 不读取手动 Harness 注册表，不下载历史证据，也不隐式扩张到 full。开发只选择与修改有关的专项。

## 仍在使用的测试

所有游戏 GDScript 测试源码、运行资源和正式素材保留，包括核心物理/输入/资源、伤害与死亡、存档/交易幂等、背包/道具、家园、敌人/Boss、平原/森林及 mapgen 宿主测试。

`tools/harness/profiles.json` 从 227 个注册项缩为 172 个显式 `manual` 命令。每项仅记录执行命令、超时和成功标记；取消 full/gameplay/art/web 自动分组。示例：

```sh
python3 tools/harness.py --list
python3 tools/harness.py --check core --plan
python3 tools/harness.py --check item-v5-inventory --check item-v5-economy
```

不带参数只列出命令。手动执行顺序运行所选项，首个失败即返回非零；保留实际日志和简短结果。`--profile`、`--reuse`、`--jobs`、`--lane`、`--verify-lanes` 和 `--mission` 不再是 Harness 接口。独立创作工具如 `production_loop.py` 本身仍可显式执行，不属于日常 CI。

## 仅手动保留的测试与工具

- 当前游戏的较大专项和长路线、真实渲染/音频、录像、Web 浏览器/缓存/导出包检查按需执行，不作为每次 PR 的门禁。
- 原 history/legacy-compat 组的 38 个历史或兼容注册项退出注册表；原测试脚本/fixture/历史证据保留，可直接运行原脚本。原因是它们有历史重放、正式消费者对照或创作工具引用，不能仅因退出 CI 删除游戏测试源码。
- 世界设计、Bible/风格、质量卡和创作流程的 Python 测试退出默认注册。它们仍在源码中供相应工具维护时手动运行；其中断言旧 Harness inputs/profile/lane 架构的测试属于历史架构约束，不能用于判断当前 CI。
- `harness.run_check` 仍供森林/平原专项 wrapper、原生录像、人工发布工具调用；源码清单/摘要辅助函数仍供这些人工捕获工具使用。日常 CI 和新的手动命令执行器均不调用全仓库哈希/归档。

## 已废弃并删除的实现

| 删除实现 | 删除专用测试 | 消费者核查 |
| --- | --- | --- |
| `tools/production_plan.py`、`config/production_impact.json` | `tests/test_production_plan.py` | 旧 `production.yml` 的影响升级/双通道准备及自身测试；该工作流已被固定小检查替代 |
| `tools/cloud_inputs.py` | `tests/test_cloud_inputs.py` | 旧 `production.yml` 的多 GB 输入物化/工件导出/恢复及自身测试；新 CI 无此依赖 |
| Harness 的缓存、隔离工作区、lane 证明、证据 ZIP 归档/恢复 | `tests/test_harness_artifact_archive.py`；重写 `tests/test_harness.py` | 旧 Actions/影响计划、自身测试；当前手动游戏 wrapper 只需有界运行 API |
| `tools/verify_ci_artifact_browser.py` | `tools/test_verify_ci_artifact_browser.py` | 旧完整 lane 工件证明已无生产者；直接浏览器游戏测试继续手动保留，现行发布工具不引用此协调器 |
| `tools/production_timing.py` | 原 `test_harness.py` 内专用计时器测试 | 无游戏运行/发布代码导入；旧手动生产计时说明不再要求额外账本 |

共移除 55 个旧注册项。移除注册不等于删除对应游戏测试实现；只删除上述已撤销架构的实现及其专用测试。正式发布/试玩部署由独立的手动工作流和现有导出/部署工具承担。

## 关键故障验证

`python3 tests/test_harness.py` 使用真实 Python 子进程验证：非零退出、成功标记缺失、脚本/Shader 错误、原生资源退出泄漏、打印成功后卡住超时、超时后子进程清理都会失败；默认 list/plan 不执行测试，失败后不继续后续项。实际执行 8 项测试通过。游戏本身的自动故障注入与远端计时由本次 CI 验收报告记录。
