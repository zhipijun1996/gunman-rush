# 地图领取状态与宝箱候选的职责收口

基线为 `c59c24fb76762a0f66033e0f79d7b2cba7a84444`；两批依次实施。这里记录生产调用关系，不新增运行注册表。

## P10：领取事务成功后，由 Stage 更新自身状态

| 文件 | 职责变化 | 保留的行为 |
| --- | --- | --- |
| `game/application/demo_app.gd` | 完成原钱包／治疗／音符事务后调用 Stage；停止直接写拾取行、领取账本和调用森林 Assembler | 原拒绝条件、收据、声音、反馈、Manifest 输出及执行顺序 |
| `game/world/levels/providers/generated_demo_stage.gd` | 唯一拾取状态提交；金币计数；公开委托原运动持久化 hook | 传入同一 Dictionary，原 position／clock 读取时点，不复制或重新查找行 |
| `game/world/levels/providers/plains_region_stage.gd` | 原地图账本写入、唯一宝箱领取提交及后置 hook | 使用原共享 `region_state`，保留宝箱→账本→后置处理顺序 |
| `game/world/levels/providers/thorn_forest_region_stage.gd` | 只实现森林宝箱后置机关解锁 | 使用原 Assembler，不复制领取实现 |
| `tests/run_session_runner.gd` | 在原运行消费者补指针、行身份、时钟、计数和重复领取反例 | C59 原正文／断言／动作保留；森林无散币时使用明确的已存掉落测试夹具 |

实际调用：`App resource transaction → Stage commit → 原 feedback/audio → Stage persistence → 原 Manifest output`。Stage 不接收 Session、钱包或奖励服务。Forest、环境和 Golden 派生继续继承已有实现；显式 disconnected 政策由调用者原布尔值决定。

原 Harness 已执行：run-session 首次 60 条中 1 失败，原因是新增夹具误以为森林种子有散币；失败原件保留。只修新增测试准备后，61/0、7.594/180 秒；双区 world-objects、四项 audio-feedback、item-v5-formal 分别通过，30.208/240、27.050/240、19.605/240 秒。生产四文件与独审候选逐字一致。见[本批原件](../../evidence/game_architecture_02/p10-stage-claim-owner-01/current-evidence-index.json)。静态领取所有权守门已同步迁移，原164例及新增13组共177/0，134.879/180秒；借用行复制和 receiver 重绑定三个实际反例均拒绝。以上结果不代表全量 CI。

## P11：宝箱候选规则只保留一个实现

后继候选使用 `game/rewards/offers/cache_reward_policy.gd` 共享纯候选排列和 tier 音符数量。App 保留 offer 注册、复制、事务与 UI 所有权；原 Generator 只调用同一纯数量函数，不改变随机抽取。资源顺序、满血跳过治疗、第二道具优先、一次音符补位和原数量保持。

当前为已静审的外部候选，尚未应用／原生验收；不能据此签 P11 完成。原 resources-only 分支可能显示未注册的第二道具、重复 note ID 是独立既有缺陷线索，未混入本次保行为重构。

## 验证与回退

P10 先验证原 run-session、world-objects、audio-feedback、item-v5-formal，以及原 underworld-pipeline 所有权正反例。P11 后续验证真实 App 候选、正式道具、随机上下文和音效；按用户最新范围，不再要求旧地图布局／路线矩阵作为默认验收。

P10 回退基点为 C59；P11 必须以实际 P10 收口提交为基点。撤销须先撤后继依赖，再撤对应独立提交；不直接覆盖用户工作树。准确提交和最终验证在各批保存时补录。
