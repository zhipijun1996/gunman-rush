# COMBAT-PERF-DEPLOY-01 · 战斗性能优化后同源交付

用户已明确授权“优化后部署”。任务处于实施阶段，基点为 `e42b277f37425458a2920815258d1cfc817acfc3`，分支 `refactor/game-architecture-02`；当前候选未部署，不默认合 main。此前公开包仍为 ab263ea6／build `2e1274f62210`，不能用它证明本轮改善。用户手机FPS、帧时间分位数和游玩认可均未验证。

本轮收敛已有战斗热点：反馈／残骸与足部表现、现Pose／Skin／Flora／Root计算、ItemArt读取以及实际同伴目标查询／排序。以真实调用链和原预算测量筛选候选；不是重写战斗或新增平行缓存／注册表。最终允许写集以各冻结补丁和实际Git差异为准，记录每个候选原件、独审、正反例、有限性能收益及代价。移动或减少调用必须保持原结果、生命周期与真实消费者。

约束：不改物理、碰撞、伤害、资源消耗、奖励、随机、保存格式或武器／能力规则；不重新生成或替换图声；不删除入口／历史测试、不放宽预算。若生产GD来源变化影响现行技术绑定，沿既有版本机制保留旧原件并做一次准确后继，不刷新旧接受SHA。PR123仍排除，旧full171或局部32项结果不追签本轮。

采用 [game-quality-gate](../../../.agents/skills/game-quality-gate/SKILL.md) 建立同一质量记录、证据和完成边界；[project-integration](../../../.agents/skills/project-integration/SKILL.md) 负责来源、正式CI和原包发布。生产实现与非作者独审分离，root统一引擎租约和最终冻结；本卡不替各具体候选自签。

完成顺序：

1. 限定候选及原消费者通过，保所有原失败；性能对照分别标明editor／release、原生／浏览器、核计算／整帧，不能把editor --main-pack当release缓存分支。
2. 最终生产／测试／绑定／文档合并为干净源F，核现行质量记录、实际base差异和提交内release证据。之后停止并行源写入。
3. 原 environment.yml 的完整171（parallel92＋serial79）及Windows／Web同源执行；不把局部或不同源码结果拼为fresh全量。预算、唯一注册及两个lane输出保管链保留。Android按原显式需求选项，不据本轮未执行冒称通过。
4. 取同run唯一API摘要绑定的Web ZIP，以原coordinator执行三个实际浏览器消费者、实际PCK空目录探针；同包prepared发布，再核公开源、完整64位PCK SHA／长度和基本入口。具体命令见[交付步骤](delivery.md)。
5. 技术交付通过与设备／玩家认可分开。没有本轮手机测量就保持未验证；部署成功也不签手机FPS达标。

空间操作仅限root已明确授权的四个旧诊断展开binary和一个可由413chunks精确重建的旧PCK。三个独特ZIP保留完整SHA、模式、双路径恢复映射；源码、原tar、原ZIP、当前锁定工具链及旧失败保留。外部完整收据位于 `/workspace/refactor-evidence/combat-perf-deploy-01/reversible-reclamation-01/receipt.json`，SHA `e4c05ee60ba5d0fd1c815fad41a3e495137fd93fb895751f0a92c751ea86ee57`。实际净回收846944035字节，完成时可用1036886016字节；这不是性能或游戏验证。

当前验收：G0范围已记录；G4最终同源回归／独审／交付待绑定。正式集成、正常速度画面／动作／声音、玩法、整体性能、手机与玩家均不宣称完成。撤回候选必须按其原件恢复生产、测试及对应技术绑定，保留失败与部署来源；不得单独回滚生产却保留新绑定或旧通过标签。
