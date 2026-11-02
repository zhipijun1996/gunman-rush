> 后续实际范围已扩为八个测试与两份测试专用历史资源依赖，并完成 current15 有限验证；详见 [实际迁移、分类和验证](ci_boss_consumers_01.md)。下文是五测试阶段原计划，保留为来源，不能替代后续范围。正式 Boss 物理、伤害、奖励及资源版本没有随测试迁移改变。

# CI-BOSS-CONSUMERS-01：测试跟随当前 Boss 消费者

独立于 GAME-ARCH-OWNERSHIP-02。原始只读定位见 `/workspace/refactor-evidence/region-boss-fixture-migration-review.md/json`；迁移前原测试及失败日志必须逐字归档。目标是让现有 CI 验证已合入的 PR122/124 内容，不改生产 Boss、生命、死亡/掉落/钱包/随机政策，不通过弱化断言取得绿灯。

允许写集仅五个现有测试：`tests/plains_cohesion_lifecycle_runner.gd`、`plains_campaign_fixture.gd`、`plains_campaign_map_runner.gd`、`plains_exploration_expansion_runner.gd`、`plains_region_boss_runner.gd`。共享切图夹具有七个真实消费者，应复用原夹具或既有 Boss 测试 helper，禁止在七处复制死亡/捡币代码；若必须新增一个有限 helper，先明确真实消费者并交独审。

- 保留实际封墙、锚点、跳跃/射击准入、重复领取、能力选择、两图转场及死亡优先等断言意图；明确 pin 历史16HP/36HP的其他夹具保持原合同。
- 高跳测试关闭的 Boss physics 必须在实际死亡流程前恢复。等待条件读取当前 Definition/真实死亡进度并有界，不能改生产时长或加无限等待。
- 当前 Bell 的旧“单一 `_boss_loot`/通用 mini DefeatBurst”正断言与当前显式排除策略冲突：旧原文保留归档，迁移必须检查实际有限死亡表现、真实实体币和无重复通用层，逐项记录等强度覆盖，不声称原旧断言原样通过。
- 当前生命和伤害预期取已有 Definition；涉及射线/弱点应使用真实命中通路，不能直接改 HP 或切旧 Boss 以凑结果。
- 金币只经原拾取/钱包/账本结算，区分 Bell 和 Pressure 各自的就绪条件。不要凭空新增“未捡完时手动出口必拒绝”的规则；若发现原缺陷另列。
- 原预算、原15套地域调度、完整182检查数量保持。验证五文件直接检查、共享夹具七个实际消费者、相关原 region/core/Boss suites，最终全量与真实导出仍必需。

当前是规划与只读诊断；基线对照尚待 root 确认。实现作者仅改测试/夹具，root 协调唯一引擎租约；独立审查者不得修改被审代码。该迁移不替 GAME-ARCH-OWNERSHIP-02 的等价声明背书。
