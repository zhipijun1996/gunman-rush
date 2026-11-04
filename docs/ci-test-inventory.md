# CI 测试取舍（CI-SLIMDOWN-01）

日常自动检查入口由 `.github/workflows/production.yml` 与 `tools/ci.py` 定义；具体命令和计时见 [Harness](harness.md)。自动 CI 不读取手动 Harness 注册表，不下载历史证据，也不隐式扩张到 full。开发只选择与修改有关的专项。

## 仍在使用的测试

所有游戏 GDScript 测试源码、运行资源和正式素材保留，包括核心物理/输入/资源、伤害与死亡、存档/交易幂等、背包/道具、家园、敌人/Boss、平原/森林及 mapgen 宿主测试。

`tools/harness/profiles.json` 保存 173 个显式 `manual` 命令，包括当前文档检查 `docs`。每项仅记录执行命令、超时和成功标记；取消 full/gameplay/art/web 自动分组。示例：

```sh
python3 tools/harness.py --list
python3 tools/harness.py --check core --plan
python3 tools/harness.py --check item-v5-inventory --check item-v5-economy
```

不带参数只列出命令。手动执行顺序运行所选项，首个失败即返回非零；保留实际日志和简短结果。`--profile`、`--reuse`、`--jobs`、`--lane`、`--verify-lanes` 和 `--mission` 不再是 Harness 接口。独立创作工具如 `production_loop.py` 本身仍可显式执行，不属于日常 CI。

## 仅手动保留的测试与工具

- 当前游戏的较大专项和长路线、真实渲染/音频、录像、Web 浏览器/缓存/导出包检查按需执行，不作为每次 PR 的门禁。
- 原 history/legacy-compat 组的 38 个历史或兼容注册项退出注册表；原测试脚本/fixture/历史证据保留，可直接运行原脚本。原因是它们有历史重放、正式消费者对照或创作工具引用，不能仅因退出 CI 删除游戏测试源码。
- 世界设计、Bible/风格、质量卡和创作流程的 Python 测试退出默认注册。它们仍在源码中供相应工具维护时手动运行；当前来源、路由、执行和恢复保护继续验证，撤销架构专用断言按下表退休。
- `harness.run_check` 仍供森林/平原专项 wrapper、原生录像、人工发布工具调用；源码清单/摘要辅助函数仍供这些人工捕获工具使用。日常 CI 和新的手动命令执行器均不调用全仓库哈希/归档。

## 已废弃并删除的实现

| 删除实现 | 删除专用测试 | 消费者核查 |
| --- | --- | --- |
| `tools/production_plan.py`、`config/production_impact.json` | `tests/test_production_plan.py` | 旧 `production.yml` 的影响升级/双通道准备及自身测试；该工作流已被固定小检查替代 |
| `tools/cloud_inputs.py` | `tests/test_cloud_inputs.py` | 旧 `production.yml` 的多 GB 输入物化/工件导出/恢复及自身测试；新 CI 无此依赖 |
| Harness 的缓存、隔离工作区、lane 证明、证据 ZIP 归档/恢复 | `tests/test_harness_artifact_archive.py`；重写 `tests/test_harness.py` | 旧 Actions/影响计划、自身测试；当前手动游戏 wrapper 只需有界运行 API |
| `tools/verify_ci_artifact_browser.py` | `tools/test_verify_ci_artifact_browser.py` | 旧完整 lane 工件证明已无生产者；直接浏览器游戏测试继续手动保留，现行发布工具不引用此协调器 |
| `tools/production_timing.py` | 原 `test_harness.py` 内专用计时器测试 | 无游戏运行/发布代码导入；旧手动生产计时说明不再要求额外账本 |

自动组与旧协调器的 55 个注册项退出当前表；当前文档检查以一个独立手动项提供。移除注册不等于删除对应游戏测试实现。正式发布/试玩部署由独立的手动工作流和现有导出/部署工具承担。

## 关键故障验证

`python3 tests/test_harness.py` 使用真实 Python 子进程验证：非零退出、成功标记缺失、脚本/Shader 错误、原生资源退出泄漏、打印成功后卡住超时、超时后子进程清理都会失败；默认 list/plan 不执行测试，失败后不继续后续项。实际执行 8 项测试通过。游戏本身的自动故障注入与远端计时由本次 CI 验收报告记录。

## 创作工具兼容与退休边界

| 范围 | 当前处理 | 原因／保护 |
| --- | --- | --- |
| 当前地区／视觉路由 | 使用当前手动检查和 Bible 绑定，路由可由 production_loop 校验 | 不恢复旧 full/profile/lane；Skill 使用三段当前合同，森林样板选 current-slice |
| 历史视觉配方 | 保留参考生成器，标记 historical_metadata_only；执行器明确拒绝 | 旧素材配方不是当前生产授权，不为它恢复 visual-director-tests 等旧注册项 |
| 手动创作控制器 | 保留并修复 113 项协议测试的当前注册／mode／日志夹具 | 独立身份、来源漂移、越界、预算、超时、取消、nonce、检查点和恢复仍须通过 |
| Bible 当前校验 | 保留 41 项当前来源／媒体／区域隔离／恢复测试 | 这些方法正文与整理前完全相同；原 SHA、坏源拒绝和当前 style-v34 实体绑定保留 |
| Bible 旧迁移测试 | 退休 52 项逐版本历史迁移、方法 AST 保全与对应旧输入向量测试 | 它们维护旧测试结构及 style 递增步骤，已无当前自动 CI 消费者；当前原件回放器与损坏／缺失拒绝仍有保留测试 |
| Bible 旧自动缓存断言 | 退休当前分区中的 4 项 inputs／digest 向量测试，删除 1 项分区保全测试 | 手动表不再声明自动缓存 inputs，历史／当前分区随旧迁移组退出；input_digest 辅助函数本身仍供人工捕获工具使用 |
| 森林冻结前缀 | 退休 production_loop 中 2 项依赖注册表旧 inputs／cacheable 的专用测试 | 通用显式目录输入、真实稀疏缺件、来源字节和零调用拒绝仍验证，不把不存在的注册元数据当运行合同 |
| 文档导航预检 | 对齐当前导航检查范围；稀疏索引链接只验证存在性 | 不读取证据／archive 正文，不物化只为链接存在检查的媒体；真实删除、明确字节依赖与坏来源仍失败 |

精确退休方法、保留方法正文比较和实际命令／日志见 [本次验证](evidence/codex_context_01/verification.json)。这些测试是工具协议与来源校验，不是实际 AI 创作质量、真机性能或用户审美验收。测试退休仍需要 PR 语义审阅，静态差异检查不能代签。
