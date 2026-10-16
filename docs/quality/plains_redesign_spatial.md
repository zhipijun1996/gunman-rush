# PLAINS-REDESIGN-SPATIAL-01：整区生成候选 v10

本页说明本开发分支的正式消费者候选，不是 G5 完成或玩家趣味认可。基线为 `30f6a825712fbb30e607791c996de142c6757a79`；授权与目标见 [整区设计](plains_redesign_design.md)，原问题见 [空间审计](../evidence/plains_redesign/audit/spatial.md)。采用 region-generator、challenge-choreographer、encounter-director、level-module-creator。没有修改 PlayerMotor、武器、资源、能力成长、随机流服务或 MetaSave。

## 实际设计与消费者

`PlainsExplorationTopology.make → PlainsRegionGenerator._candidate/_fill_edge/_deep_loop → RunManifest → PlainsRegionAssembler → PlainsRegionStage` 继续是原正式链路。旧 RoomGrammar、LEVEL FOUNDRY 和八关历史不替代正式两图。本分支默认内容版本为 `plains-region-v10`，named RNG derivation 保持 `plains-region-v4`。

三种手工宏观轮廓分别安排上方钟庭与下方溪岸交织、下降井环与独立攀回、中央维修汇合与外围回环。先选这三种完整足迹及外臂扩展，先在剪边/锁门/单向转换前写入三条完整初访分流合流合同并保住其每一步，再有界选择营地后保持连通、环路、双 Boss 接近的 gallery/回程锁变体；没有先创建完整矩形再随机删格。仍使用少量正交对齐的地形轴，`area_X_Y` 保留为地址。它不是任意连续空间嵌入引擎，不能称已经解决所有规则构图问题。

正式坐标不再按统一 `DX1400/DY700` 计算。先按路线身份选择实际动作短语，再用真实模块宽度分配各段净空；不同 terrace 采用经现有运动关系验证的 510/700 高差，梯步上限保持原 100/190。旧固定小 sample 单独保留其历史尺寸与选择流，保护已有回归；它不代表默认图的生成方式。

四个空间身份进入实际 recipe 池和 geometry 分配：风车草岸采用反冲跨越与头顶空间变化，断钟庭院采用新的射角/开路顺序，溪岸采用渡台、落点与独立回程，维修汇合保护商人与恢复站位。对应身份字段也是下一阶段正式构图消费者的输入，当前并不据字段宣称美术已完成。

第一短链是已验证的“观察井铃 → 跳起 → 同次射击开门并反冲升高 → 修正落点 → 真落地 → 读低顶 → 短跳释放 → 落地”。全图不再通过 hazard 覆盖配额强塞机关；其余路径在身份合法池中维持动作反重复，保留原全部 16 配方，再加这一条已验组合。上侧发现、溪岸回环与短技巧路径通向已知的 `area_2_1` 维修营地。中箱一个靠第一恢复岸，另一个在邻近钟庭或溪岸发现点；总奖励、道具与经济预算不变。

两个高级奖励各有三种真正不同的组合，`variant` 实际改变模块：high 包括新的登阶→远钟、移动渡台→登阶、限时铃→连续反冲；top 保留齿轮渡台/顺序铃与连续反冲的不同顺序。仍只有正式基础一跳和当前单武器，H/W/D 与随机道具都不是主路前置。复杂度不能仅由动作数、配方数或 Hash 推断。

高级回程使用拓扑明确的入口/回归合同，不再从 `col+1` 与 DX 推出。奖励后下降至已知上岸，必要时实际交互打开已有的上侧捷径，再下降到恢复岸或更前方的主脊。较长 top ferry 链选择其实际出口附近的已存在回归点。Manifest 记录实际 `return_intent/return_polyline`；没有新增传送、无敌、补能或更长的掉落测试预算。

敌人继续消费正式行为/预算，钟后俯冲与渡台远程压力仍是真机关/敌人组合；商人/入口/整备保持不放普通 guards。旧真实 fan/diver 无伤渡船测试继续运行。新默认全部敌态、击杀/引诱解、低资源与相机中的公平性仍必须由正式 live cohort 检验，不能从无敌人的 assembler 轨迹外推。

## 真实返工与边界

保留了最初返回点不存在、升降台目标停在上岸左端、可变高差末梯过短导致提前落在上层、奖励直落被实体锁门挡住、侧落被水平实体地面挡住等真实失败。修复依次使用已存在的明确回归点、实际入出口中点、保留最大步高的可验证高差、真实上侧交互回程。未删除断言或改角色手感。

`tests/plains_region_trace.gd` 只为可变几何读取实际目标、为新远钟调用已有真实 latch driver，并允许奖励回程请求 `interact`。普通 fixture 的交互信号接同样的距离/上侧开关消费者；正式 `level_formal_trace` 使用 DemoApp 自己的输入、交易和 modal 优先级，fixture 不证明正式 modal 一定不吞输入。

旧 v9 的 5380 接缝和固定两地标是历史布局合同。两个原 runner 的全部断言字节不变，工具从 [精确冻结源清单](../evidence/plains_redesign/frozen_v9/manifest.json) 重建 30f 的源码并验证全部资产原 git blob，再实际运行正反例。隔离工程父目录使用 `.gdignore`。这不是把原 15 地区套件挪到旧版本；15 套仍对默认 v10 运行。v10 原生 JSON/正式 RunManifest 回放另验；旧版本 Manifest 在新消费者明确拒绝。

## 可调用验收

```sh
python3 tools/run_plains_redesign_spatial_tests.py
python3 tools/run_plains_region_tests.py
python3 tools/run_plains_action_golden_tests.py
python3 tools/run_plains_autonomy_tests.py
python3 -m unittest discover -s tests -p test_level_design_analysis.py
```

新专项由原 Harness 的 `plains-redesign-spatial` 调用：20 个 canonical Seed/map 生成、真实教程后完整短路到营地并同 body 返回、两个最差 Seed 的上方/溪岸替代路合流和高级奖励回程、合法消耗至零精力、350 个原 corpus 的实际方向/初访门态/能力合同、当前版本/JSON 身份/重哈希坏几何拒绝；另实际删除正式生成 well 的接收岸，必须物理跌落且 exit1。完整逐帧位置、正常/反冲速度、精力/容量、同一 Motor/session、输入产生的 shot 数与原严格全身危险扫掠保留。生产语义校验直接拒删除必需步、倒置单向、未开启锁门、未授能力四个重哈希反例；wrapper 另拒空轨迹、重复地图、瞬移、缺精力、未知版本、第二步/方向/门态/能力伪造、营地假位置和缺少替代路线等十一类伪证据，所有 Godot script/parse/shader 错误均拒绝，即使 exit0。

完整 15 套包含原 150-seed family corpus、100 图动作/压力/预算、两图 campaign、所有开放边正反向连续巡游、高奖与异路回程、真实 fan/diver 遭遇、Boss/奖励/保存生命周期。具体最终计数和源指纹以 [本切片证据索引](../evidence/plains_redesign/spatial/index.json) 为准；保留失败原件，不将早期运行改标为最终新源。

`level_design_analysis` 增加显式 v10 支持，原 v8 的历史 scenery projection 只对 v8 生效；未知未来版本继续拒绝。该诊断是体验代理，图连通、动作签名和自动输入成功均不证明真实玩家学得会或喜欢。

G0/G1 仅技术候选：需要后续独立只读审查、正式敌人/镜头/正常音画、完整同条件前后比较、美术与实体设备/玩家体验验收。当前没有把这些项目签成 passed，也不把默认开发分支接入等同于正式发布或主观完成。

## 第二轮元数据修正

原 production loop 第一轮的全部物理/生成/分析检查通过，`tools/check_quality.py` 因任务表仍为 `in_progress`、质量记录写成 `review` 而实际拒绝。原失败保留在证据索引的 `round2_metadata/original_quality_failure.log`。本租约未授权写任务表，因此只把记录工作流恢复为真实的 `in_progress`；G0/G1 技术证据与其余未验门槛均保留。完整内容确实仍制作中，尚无独立审查。旧 current 原生轨迹、日志、receipt 与运行/测试/专项工具文件逐项 SHA 完全未变，可精确复用；本次 worker 没有声称重跑原生矩阵或原 15 套，原 controller 会自行 fresh 检验。


## SPATIAL-R1：真实独审拒绝与内容返工

前一次独立审查为 **REJECT**：19/20 张 canonical 图至少一条声明路线缺步，7/20 缺真正的第二步到营地。`/03` map1、`/04` map2 从入口至营地实际初访图路线各须绕 8 边，`/01` map2 须 6 边。原 760 项第一短链断言没有覆盖营地/合流，不足以签 G0；其原件和旧通过测试仍保留，绝不改成“旧整区设计通过”。原独立报告、反例、完整旧源 620 个文件与哈希在证据索引的 `round3_repair/` 中。

本次是内容返工：`PlainsExplorationTopology.route_specs` 在任何裁边之前定义完整的短技巧两步、上方钟庭探索和溪岸相位支路；`_semantic_edge` 保护其相邻步不被删、锁或反向转换。生成器最终 `semantic_route_errors` 独立校验节点、实际连边、方向、初访门态与真实基础能力白名单，完整 fallback 同样遵守。不是把意图事后改名为长绕行。营地后仍变化真实图连边、Boss 接近与奖励回程，原多样性门槛不降低。

新当前技术证据为 **1029/0**、20 张图、54,555 个完整物理帧、10 个真实零精力入口；20 张图都实际走完第二步抵达营地并同 body 返回。最差 `/03` map1 与 `/04` map2 继续在同一 body/session 中走上方与溪岸替代路、合流营地、领取位置的高级挑战和异路回程。它们不含正式敌人，仍只是地形/资源/机关路线证明。350 个原 corpus 的合同样本 **712/0**；四个生产级语义负例与十一项伪证据拒绝均有真实结果。

原独立失败脚本仅改变输出文件路径后再运行，原三张最差图均无缺步、实际初访图路线均为 **2 边**；脚本归一化回原输出路径后字节完全一致。前后对照是图结构与门态，不伪称玩家时长或趣味分数。生成器没有改变 Motor、资源、机关或掉落预算。

保护语义路线后曾导致少数 linked_rings 没有真实单向下降，原 expansion 四个断言实际失败并保留。修复保留上方发现岸 `area_1_0 → area_1_1` 的单向返回，另有 0/2 列攀回选择；这处在营地前，不称为营地后新路线。原 15 套当前源码 fresh 完整复验实际退出 0，231.250 秒、源前后逐 SHA 相等；原阈值、断言和 body/resource/动态机关守门均未下降。阶段 1/2 的地图图签名与早 Boss 行程仍分别为 33/13、46/24，原复合排除/数量要求保持。

证据当前入口已改为 `round3_repair/current/`。旧根目录 `current/` 明确是被拒候选的历史原件，未覆盖。新版原生矩阵来自实际 `run_725x2we5`，在续行 worker 中先逐项验证源码与该次 source_before/source_after 完全一致后精确复用，未假称重复执行；原 15 套在续行中确实 fresh 重跑。旧目录 4 次调用、3 轮及误读旧截止时间造成的真实 blocked 均保留；续行仅用原预算剩余 2 次调用，原计数/终态不改。

尚待不同代理对返工后的 G0/G1 复审；整区视觉、正常音画、正式敌人策略、实体设备与真人趣味验收仍未完成。原中间 fast/growth 死亡与 1100 帧镜头遮挡录像只作为前一候选的真实失败留证，不能当本次最终源的正式通过证据。
