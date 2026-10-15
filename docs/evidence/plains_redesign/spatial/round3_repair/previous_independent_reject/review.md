# PLAINS-REDESIGN-SPATIAL-01 / attempt 2 独立审查

Reviewer：`/root/plains_spatial_audit`。我只写过前期 ignored 空间审计，本次未实施被审生产、测试、文档或卡。审查租约 `13440e4c05564475b432f5f33a360b60`，request hash `e6e5c6540b5f157e7008ade6769dedcbbe0e8aea4edc72e9a329ef3eebfa9df5`，source digest `216bc630f9938e9b6767e986cb1726bee9422d24024c4e4752eb5f09c70b5ca2`。实际快照逐项核验一致。

**REJECT G0/G1阶段候选的总准入：SPATIAL-R1，G0高严重度。** 新默认的空间身份确实影响recipe池/模块组合/间距，真实动作、资源、旧断言双轨的多数保障成立；但生成器随机删掉自己承诺的语义路线，使“短技巧到营地/上方发现/溪岸回程”的字段与实际生成图不符。本结论不以未到阶段的美术/敌人/设备证据为拒绝理由。

## SPATIAL-R1：随机剪边未保住主短路和语义合流

位置：`scripts/generation/plains_region_generator.gd:65-78` 剪边仅保护 `area_0_1→area_1_1`，`140` 随后无条件写固定 `short_technique/upper_discovery/creek_return`。没有验证第二步到camp、上方/下方支线的实际相邻连边、方向和进入时门状态。`tests/plains_redesign_spatial_runner.gd:39` 只比merchant_id和main_recovery字符串，`48-72` 实际只走第一条well→arch边再原路返回。

实查当前native20个canonical实际Manifest，并用当前新专项再次生成，20个hash与portable完全一致：

- short_technique 7/20 缺 `area_1_1→area_2_1`。
- upper_discovery 15/20至少缺一个声明相邻边。
- creek_return 3/20缺声明相邻边。
- 19/20至少有一条声明路线断步。不是因玩家没开门而误报：这些声明水平step在connections中根本不存在；另外实际进入状态的backside井进一步阻止短上绕。

具体失败：`level-design-v2-baseline/03` map1，family linked_rings，hash `f810ae783cea6c5d461bce929cec3513f90493574a31f7c97d77b03ff592f082`。声明 `0_1→1_1→2_1(camp)`，第二边不存在；`1_1→1_0`和`2_1→2_0`都是尚未开启的backside。当前原真实trace `path_to` 初始状态必须选：

```
0_1 → 1_1 → 1_2 → 2_2 → 3_2 → 4_2 → 4_1 → 3_1 → 2_1
```

也就是8边下行到溪岸再绕col4爬回，替代承诺的2边营地短线。`level-design-v2-baseline/04/plains/map_2`也8边；`/01/plains/map_2`6边。这里的“8边”来自真实生产Manifest/原trace BFS初始门状态，是结构证据，不冒称实际玩家时间或Motor路线通关。

独立实际Godot反例（不修改生产源）执行：

```
bash tools/godot.sh --headless --path . --script build/plains_redesign/review_spatial_round2/semantic_probe.gd
```

实际exit1，三张实际默认图三条短路合同失败。脚本、完整trace选边、生成hash、日志和显式process退出码留同目录。`structure.json`保存20图完整声明/缺边/实际camp policy路线。不是篡改fixture后假装生产失败。

最小修复包：

1. 在剪边、backside改锁、单向转换之前，由三macro骨架定义有意义的必需step/分岔/合流合同；保护短技巧通camp，同时明确upper与creek如何分离和重返已知恢复/前方主脊。所有最终step存在、方向合法，并以该路线真实进入门状态可用；不能把字段事后改成8边绕行来消问题。
2. 生成后校验这些语义合同，而非仅连通/cycles/degree；有界候选/完整fallback也必须满足。样本中短技巧路线是first well→arch之后确实能到camp，较安全/较高风险替代有实际不同条件与汇合点。
3. 新专项覆盖20 canonical和原corpus的实际语义step；增加故意删必需边、倒置单向、加入未可开启门的必拒负例。新增断言不能仅靠再生成hash比较，应直接约束合同，并正反验证检测器。
4. 最差 `/03`map1、`/04`map2至少真实同body教程→短链→camp，以及替代路→同一合流/奖励回程，保留当前全身sweep/资源/相位门槛。仍区分无敌人terrain与正式有敌人App。不为新路线修改Motor、资源或延长预算。
5. 保留原20/23、≥3cycles/forks、prep双入口、两shortcut、≥10 early-Boss行程差异/六action-pressure/≤35%重复和全部适用断言。不要简单保护全部旧边导致多样性测试降标。旧失败与本REJECT证据保留。

## 已独立确认的保障与执行

- **fresh reviewer新专项**：`python3 tools/run_plains_redesign_spatial_tests.py`，实际exit0。目录 `build/plains_redesign/spatial/run_k0mkb_7c/`；positive 760/0、20图/20连续同body往返、27180帧，十个合法消费至零精力边界；17.776秒。删真实well接收岸实际29断言/1失败、exit1，落到Y1099.031，2.084秒；wrapper正确要求负例退出1。它证明当前第一短链的限定G1，不证明camp/全区语义路线。
- 原低资源、shot数、真实落地、严格body hazard扫掠、连续性检查保留。carrier唯一目标读取改为实际目标端口中心；未改Motor/武器/能力/RNG服务/保存与player tuning。fixture开门使用Router interact后实际距离上侧消费者；正式App依旧自有handler。该fixture不证明正式reward modal一定不吞interact。
- `provenance.json`：lease source digest匹配；reviewer fresh source_before==source_after==当前620 runtime/check文件；旧portable receipt源也与当前完全一致；旧/new20 Manifest hash全相等。77 portable成员压缩SHA、解压SHA、长度全部逐项核对无误。
- Frozen V9源964成员SHA全匹配；关键生成/旧golden两runner与git30f原字节匹配；484 assets原git blob验证无差异。两个旧golden runner当前字节也未改。旧action187/0、nav32/0和实际负例由当前controller fresh执行/portable保留；我核原日志与provenance后明确复用，没有假称reviewer重跑旧物理。
- 当前原15套controller fresh结果复用，其新默认生成、完整tour/deep/生命周期原断言未搬到legacy。原16recipe保留+新well_arch；六action/pressure、重复上限、初图复合排除等原断言未删降。共享31入口保留，当前lease没有额外独立重跑31全套，不能将保留入口当新全量PASS。
- 初始不存在返回点、carrier错误目标、premature上层落点、实体hatch与side floor挡路等失败/四轮return日志仍原样portable。metadata-only第二轮原quality失败原件保留；没有exit0或完整摘要赦免失败。

## 范围与后续

G1第一短链限定技术证据成立，不能抵消G0路线合同的客观错误。当前仍是少量正交轴及共享列宽的terraced embedding；不同family/recipe真实变化成立，不夸成任意连续嵌入或整区好玩完成。最长plain join仍可到560，是否属于有效观察/恢复须后续scene/encounter实际轨迹评审，未以静态长度单独判无聊。

正式旧策略中间fast/growth在第一链后被敌接触杀死、电影HUD遮动作，是保留的失败/后续包输入；本次既不签其通过，也不因此否定已实测第一链。正式全路线四态敌人/击杀与非击杀、镜头/正常音画、最终风格、设备和玩家公平/学习/趣味全未验。只在SPATIAL-R1修复并复审后可接受本G0/G1候选，仍不等于G2–G5或发布授权。
