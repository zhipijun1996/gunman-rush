# PR124 到来后的架构实施顺序

> 后续执行更新：用户明确“先把 PR124 合入，然后重构修复”，覆盖此前本次合入前要求全量绿色的顺序。PR124 已于 2026-10-31 01:57:14 UTC 普通合并，main 新提交为 `bd86237456c7ce12a352b040857b208bdede7f66`；远端已核 merged=true。本轮未绕过分支保护、未改 CI 状态，原失败保留。新 main 修复工作区 `/workspace/gunman-rush-ci`、分支 `fix/current-ci-01` 已建立；首个修复只补齐 VisualFixture 的 nullable boss 字段，生产代码不改。以下是合并前核验记录，PR124 的 open/draft 状态已由本条更新。

2026-10-31 用户确认 PR123 已关闭，新增 PR124 Boss 内容需要合入，并询问后续架构优化。保留既定目标架构；先形成包含两条 Boss 工作线的可信底座，再迁移职责和目录。当前没有执行远端合并，也没有把下述目标组合写成已存在的提交。

## 实际核验

| 对象 | 精确来源与状态 |
| --- | --- |
| main | `840108da9ae91e412dc9f1d8a38ccdad0229bb11` |
| PR122 鸣铃巡游机 | `66c6c41d1a77e6b2f034999b6111c272a11f2d76`，open/draft，尚未合入 main |
| PR124 牧风者 | `1fe4889d02359517252644c3aaf0450ddec8f853`，open/draft，尚未合入 main；不包含 PR122 |
| PR123 固定地图接法 | closed/unmerged，继续排除 |

目标底座为 main＋PR122＋PR124，但其精确组合 SHA 尚不存在。PR124 的合入授权不等于 PR122 已经合并；本工作线继续保留用户先前指定的 PR122 内容。两条内容线与架构候选分开验收，不把未验收重构一起带入内容合并。

PR124 [当前 CI](https://github.com/zhipijun1996/gunman-rush/actions/runs/41118658287)失败：

- 并行通道的 `generated-consumers` 失败：`PlainsStageVisual._pressure_rewards_visible()` 在 `scripts/art/plains_stage_visual.gd:184` 访问 `VisualFixture` 不存在的 `boss` 属性，继而失败于出口表现断言。必须核实运行对象契约和实际消费者，不能删测试或仅伪造通过。
- 串行通道的 `forest-depth-region` 超时。保留原覆盖、预算与失败，先诊断运行热点/调度，不直接延长预算掩盖问题。
- `affected` 汇总失败，尚不具备合入所需的完整验证。

只读 `git merge-tree` 试合 PR122/PR124 返回 10 个冲突文件：

```text
docs/creative_direction/bibles/registry.json
docs/creative_direction/thorn_forest.json
docs/creative_direction/windchime_plains.json
scripts/demo/demo_app.gd
scripts/ui/windkeeper_hud.gd
tests/test_production_plan.py
tests/test_region_bible.py
tests/test_region_creative_direction.py
tests/underworld_plains/capture_underworld_r3_boss_fight.gd
tools/harness/profiles.json
```

两条分支各有 169 项 full 检查，分别在 main 原 168 项上增加 `bellstrider-rework-01` 和 `windkeeper-pressure-01`。组合必须保留两项，集合为 170 项，不能任选一侧 profiles 文件而漏测另一位 Boss。自动合并成功的共享代码也要检查语义，例如接触伤害、地图表现和既有回归消费者。

## 当前未提交改动的处置

已在 `/workspace/refactor-evidence/20261031-baseline-refresh/` 保存原 `previous-candidates.patch` 和 `previous-untracked.zip`，没有覆盖或清空工作区。patch SHA256 为 `34703b858629b1b3fe58e411bdebb74fa3fae576908c0bd11e19a69b4d2583f4`，归档 17 个未跟踪文件。试合并输出同目录 `pr122-pr124-merge-tree.txt`；其 tree 对象不是已验收提交。

PR124 与现有未提交修改重叠于 `demo_app.gd`、`demo_contact_emitter.gd`、`module_lab.gd`、任务和交接文档。旧候选不整包应用到新底座：按功能重新迁移，避免覆盖新 Boss 支撑绑定、死亡掉落、Manifest 和表现接线。

PR124 增加 `WindkeeperPressureEncounter` 及专属动作/音频/奖励实现。既有实体快照候选必须覆盖真实新消费者及其额外状态，不以旧 Windkeeper 的恢复测试替代。PR124 也已增加三处历史链接目标文件；原链接检查器候选需要重新评估是否仍必要，不能叠加两种解决方案。

## 后续实施批次

| 顺序 | 交付内容 | 完成标准 |
| --- | --- | --- |
| B0 内容底座 | 修复 PR124 原 CI；整合 PR122/124 的共享入口、HUD、内容绑定、检查清单；记录实际组合 SHA | 两位新 Boss 同时存在；无 PR123；完整原检查及两项 Boss 专项保留并通过；内容合并与重构分别可回退 |
| B1 本局和关卡 | 落地 `game/application/` 与 `game/world/levels/` 的真实职责；玩家/钱包/配装归本局，伤害队列/地图实体归当前图 | 正式 Home→平原第一图→第二图及森林都使用同一关卡接入边界；换图无服务重复创建、旧回调失效 |
| B2 Boss 接入边界 | 使用现有 Boss 基类/工厂收敛激活、场地绑定、终态、状态恢复和奖励结果；保留两位 Boss 独有行为 | App/地图/UI 不窥探具体 Boss 私有字段；巡游机与牧风者死亡→各自掉落→领取→出口按原顺序运行，数值/碰撞/招式不变 |
| B3 配装和交易 | `game/loadout/`、economy/rewards 的完整业务操作；库存事务不向外暴露任意写入回调 | 获得→装备→升级→卸装、破损→修复失败/成功、奖励重放全链真实验证；只有原权威账本 |
| B4 全入口、表现与资源 | 共享装配接入实验/预览；修复并单列音频宿主缺陷；明确正式/历史资源选择 | 每个入口可启动及退出；采用当前选定图声；没有遗漏装配引起的旧版回退；运行代码不依赖 tests |
| B5 目录与清理收口 | 按已形成的功能边界分批搬迁脚本/场景/定义，更新 UID、动态路径、CI 和导出闭包 | 每批旧→新路径表、真实消费者和回退 SHA；只删除证明无消费者的资源；冷导入及实际 PCK 验证 |

B1 起每批迁移真实消费者，并将已独立的模块放入目标目录；B5 收口剩余路径和资源，不能一直只加 helper 而没有功能模块落地。新增 map-edit 地图仍在统一接口验证后接入，不提前引入新地图内容。

PR124 暴露的表现层直接查 Boss 状态问题正是 B2 应解决的耦合：关卡/遭遇提供明确的可领奖/出口状态，表现只读取结果。先用保持现有行为的最小修复恢复内容基线，再迁移这个职责；不借架构重构重调 60HP、三阶段、六招或 20 金币。

本阶段只完成核验、备份和顺序更新，未宣称 PR124 已合并或新组合通过。公开网页也不能因关闭 PR123 而视为自动回滚；最终试玩必须另核来源提交和实际导出包。
