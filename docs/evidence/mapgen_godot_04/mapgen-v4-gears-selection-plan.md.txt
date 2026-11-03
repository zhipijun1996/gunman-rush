# 0.4 已交付地图中的 ferry-gears 候选（独立补充规划）

结论：已有限检查官方既有 **40** 个历史 seed 的0.4原始 replay，**10个seed、14个instance**含精确模板版本。推荐独立受控案例 **validation-930007**：该图只有一个 `game-plains-ferry-gears`，原向且无封口，可完整保留现有机制。它恰好也叫M35，但选择依据是模板/版本/角色与真实图，不是复用旧编号。

此报告只读检索已经交付的地图，没有运行solver/Godot、没有随机reroll、没有改仓库或默认930001选择规划。上游既有文件不是本宿主生成证据；0.3 gear回归继续属于0.3 baseline。

## 查阅范围和来源

固定来源为map-gen PR5 head `6bf07ab5a655ea056461b935ae4354e15ef83482`，只取现有 `upstream-evidence-inventory.json` 已列的40条 `replay/calibration-*` 与 `replay/validation-*` gzip。没有把success/batch重复文件计成额外seed，也没有查第41张新图。

每个下载的gzip均实际验证 Git blob SHA和长度，另记SHA256；40份原件在 `/tmp/mapgen-v4-gears-plan/raw/`，完整收据在 `scan.json`。均为原implementation=`mapgen/gdscript-candidate-0.4.0`、algorithm=`stable-v3-reward-space` 的PASS输出。

| seed | 匹配instance标签 |
|---|---|
| 271033 | M28 |
| 271036 | M32、M35、M37 |
| 271043 | M34 |
| **930007** | **M35（推荐，唯一、原向、无封口）** |
| 930010 | M19、M35 |
| 930013 | M18、M38 |
| 930014 | M30 |
| 930015 | M32 |
| 930017 | M36 |
| 930018 | M30 |

全部命中content_version均为 `sha256:18e0578b0631239884f0ff9bb598b04867396bcbe3988c036b512ebe32e092b3`。部分其他实例有镜像或封口，不能据命中模板就宣布原Resource/路线可用；本次不扩查它们的物理适配，不剥封口凑通过。

## 唯一推荐案例的原输入

原输出：`validation/runtime-reward-B/replay/validation-930007.json.gz`，其具体URL、Git blob SHA、SHA256见JSON。

实际下载并校验对应官方输入，与输出`map.inputs`逐字段相等：

- [request-930007.json](/tmp/mapgen-v4-gears-plan/request-930007.json)，SHA256 `1594181d4d48a419bb26e920a609a559e10e06dbe7bf6d485a1fc26aca745021`。
- [config-930007.json](/tmp/mapgen-v4-gears-plan/config-930007.json)，SHA256 `65998d9fede6df44f832cde7bb1e368f09eb092aa3f31c9a5fbb9f7c34ea8062`。

来源路径均是该固定head下 `validation/runtime-reward-B/replay/inputs/validation-930007/`。request仅seed与官方默认930001不同，其余字段一致；config与0.4默认config完全一致，原目标、评分、500000候选预算及90秒墙钟均未变。这些是原官方输入原件，不是宿主为了找到模板重新编写的请求。

## 实际实例、完整内容与邻接

- module_id=`game-plains-ferry-gears`，上述精确content_version，role=`traversal`；该图匹配数恰为1，标签M35。
- origin_blocks=`[3,3]`，world origin=`[384,384]`；size_blocks=`[8,6]`，local bounds=`[0,0,1024,768]`。
- mirror_x=false，content_is_materialized=true；source_affine=`[1,0,0,1,0,-342]`仅保留，不再次执行。
- 原seals=[]，三个原port均connected/INOUT：entry LEFT/ROCK[0,576]；exit RIGHT/ROCK[1024,64]；C TOP/ONE_WAY_PLATFORM[576,0]。
- 完整保留4原平台（index2 one-way）、危险带`[44,658,912,40]`、`relay_gear`全8字段及`ascent_0/ascent_1`全7字段。两线性渡台仍travel3/dwell1.5/phase0；锯轮仍period4.8/radius20/damage1/interval0.7。没有敌人/奖励/hooks/thorns/latches/wall。
- 原helper body entry[24,590]、exit[1000,78]，无封口遮挡；仍须真实4.7 `Resource.is_valid`及body/support验证，不借旧图证明。

| 实际edge | 本模块端点 ↔ 真实邻居 | world位置 | surface |
|---|---|---|---|
| C004 | C ↔ M02.B（idea-spec02-s12-001） | [960,384] | ONE_WAY_PLATFORM |
| C053 | entry ↔ M43.L（idea-spec02-s13-001，target_reward） | [384,960] | ROCK |
| C054 | exit ↔ M36.L（idea-interface-s12-001） | [1408,448] | ROCK |

完整peer版本/角色/来源行在JSON。建议先加载单模块完整机制，三名邻居均不假装已装。C004若变为内部连接仍触发现有ROCK-only拒绝，不能借此补充计划扩大连接协议；也不为切片边缘增加封墙/地板。

## 当前几何推导的出生候选

由本次实际原platform0 `[0,608,180,40]`：水平中心90，top608减body半高18，得到local `[90,590]`。再只加本次origin `[384,384]`，得 **world `[474,974]`**。

- world支撑平台`[384,992,180,40]`；local身体`[78,572,24,36]`，grow8=`[70,564,40,52]`。
- 原ferry全包络为`[190,438,420,164]`、`[440,136,450,164]`；锯轮全包络`[492,108,40,520]`。
- Python几何子集确认完整脚底支持、身体不穿任何原平台、grow8不交危险带或任一完整运动包络。这不是只挑当前相位，也不是Godot物理查询通过。

不能用0.3旧world spawn`[1626,1742]`或旧load hash。root后续必须以此**原request/config**实际在4.7宿主生成，再按模板/版本/角色/邻接重新消歧。重新得到唯一原向无封口实例后，仍从实际platform重新计算world点，通过原body shape+三脚底支撑登记才可激活；不同输出或安全检查失败就拒绝，不改模块凑通过。

推荐案例与默认930001玩法/样例选择并行注明来源；旧0.3 evidence不追签为0.4。当前未证明0.4本宿主生成、实际携带/伤害/回退/退出、Web、整图或设备。
