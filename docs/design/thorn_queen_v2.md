> 历史版本：本文保留旧 Queen／迁巢织场的原始设计与验证范围。
> 新 Canopy v3 设计及其未验边界见[棘冠女王 Canopy v3](thorn_queen_canopy_v3.md)，不以新黄金追签本文旧结论。
# 棘冠女王：迁巢织场

**当前整体设计未通过。** [最新独立整体验证](../evidence/forest_depth_v2/reviews/final-experience-v7/REVIEW.md)发现第三网覆盖不到中枝，允许长期安全输出；下文31／36的局部CONTINUE不关闭该缺陷。旧网调位和路线结43–46均未晋升最终Boss核心，当前另做实体遮挡、真实横扫和连续H／反冲换射击面的黄金。主运行Queen仍是此处旧版本，不能把实验方案写成已完成三阶段。

FOREST-DEPTH-02 的未发布候选 `ThornQueenV2`，当前 Definition 版本6、织网存档 schema13。女王沿可预告的世界路线迁巢，身体始终可伤。玩家选择普通走射、反冲换层、借活结或剪网改变射角与退路；不采用守卫的扑落、铃反击或计时开放弱点。

Queen31 已获不同作者[有限CONTINUE整战黄金](../evidence/forest_depth_v2/reviews/queen31/REVIEW.md)，**尚未完整Boss准入**。Queen36沿用同一Def6/schema13生产，补完两项局部69/0和同源正常完整H/普通影片；[不同作者整片独审](../evidence/forest_depth_v2/reviews/queen36/REVIEW.md)有限CONTINUE进入playtest与技术整合，不代签正式准入。原23/24整体REVISE、32局部失败与旧45秒影片失败全保留，不能用路径数量或技术通过替代玩法判断。23旧188/0不代签新源。

## 核心交互

同一个24×24、2HP活结既能借，也能被普通枪剪断。真实H接触伤结1HP并按原玩家规则恢复空中动作；其后的反向枪弹可再伤1HP剪网，同时产生反冲换位。保结留下借点与持续危险，剪结清场但失去该借点。全剪后普通jump/R和唯一固定环仍合法。H不是事件密码，也不规定每阶段次数。

静止靶、窄孔六H顺序、强制每次低位 excursion 借固定环均已淘汰。固定环保作应急恢复，不能为增加H次数强加进攻手续。合法普通快杀仍是必要对照。

## 几何与碰撞

坐标唯一来源是 `scripts/bosses/thorn_queen_weave_definition.gd` 和实际Resource；公共Factory只读取和平移。

| 元素 | 当前局部坐标与作用 |
| --- | --- |
| 场地 | 900×600，永久floor在y600 |
| 左/中/右枝 | `(80,400,140,20)`、`(300,360,300,20)`、`(680,400,164,20)`，one-way |
| 两内口 | x220..300、600..680，宽80；Queen48身体居中各有16净空，Player24各有28 |
| 厚根瘤 | `(420,500,60,40)`，真实solid，挡角色、钩索、弹丸 |
| 活结 | `(620,300)`、`(430,220)`、`(720,260)`，各2HP |
| 固定环 | `(450,450)`，切光活结后的应急路线；不强制借 |
| 身体 | Queen48×54，Player24×36；所有危险与支持判断使用完整身体 |

女王是飞行Boss，保留实际世界碰撞。只对当前绑定Player实例加入physics collision exception，避免单向推挤把Boss推出路线；重新绑定角色时更新该实例。真实全身体扫掠 ContactEmitter 仍经Policy/iFrame扣正常伤害，没有接触免伤。迁移每帧仍不得超过240/60=4px，存档路线约束不放宽。

成熟织带是可见非实体危险：不推人、不阻挡弹/H，避免身体内突然长solid造成夹身出场。实际绘制与伤害用同一相邻帧带凸包，按Player半尺寸12×18展开后交Policy；结仍是可钩可射实体。

## 三段空间与持续网络

网络阶段和物理路线分别保存，满足 `1≤route_phase≤stage_phase≤3`。网络可先预告，女王完成当前已承诺路线再转入新路线，不瞬移、不复活已剪结，移动中也可伤。

| 段落 | 真实变化 | 可选决策 |
| --- | --- | --- |
| P1高巢巡视 | 首次出巢预告读取Player岸域一次，锁定完整左右巡视路线；随后不追身 | 读完整路径普通走跳让岸，或借620300升到巡线之上继续输出 |
| P2同岸低巢 | 首次转换采岸一次；由最近80宽内口下降至右720450或左180450，枝体实际挡弹 | 留岸等移动射窗，普通换层/换侧开角，或借主结并R剪旋网主动清场 |
| P3高低连接 | 剩余网络加可预告升降网，实际路线连接高左与低右 | 普通升到宽中枝、保网抢射角、主动剪网或必要时借固定环恢复；不硬要求第三H |

P1右巡视经过874340→640340→630300→270300再往对侧高巢；左巡视对称选择合法世界通路，预告显示完整线路。不能把中枝当永久安全答案：后半段在y300横巡，中枝站立身体可能真实受击。

P2原30外缘路径总长1240.88px，加预告约349帧，最强普通法785杀时不可能已抵885低巢，原内容反例保留。31通过内口缩为约800.83px，加39帧预告约239帧，实际edge在536采岸、775抵720450且Boss仍4HP。没有加HP、速度或锁血救到达。

地网 `(200,570)→(12,570)`；主旋网以420300为中心、内180/外570、初角−90°、20°/s；第三网 `(200,570)→(888,585)`，45px/s上下180、完整周期8秒。都先1.2秒预告、.65秒生长。中枝主网完整身体安全中心约x312..577.7；若还保双向84.7地面R接收预算，约397..493。不能把整枝称免险区。

## 当前31实测与限制

同起态Player5HP/E100、Boss24HP，真实Motor/输入/Policy，三法共41项断言通过：

| 策略 | 击杀/结束tick | 玩家损血 | 末精力 | 实际选择 |
| --- | ---: | ---: | ---: | --- |
| 读预告借结后接完整目的法 | 1492 | 1 | 100 | P1借620300，P2借430220并反向剪网；第三H中断 |
| 原25目的函数 | 1385 | 2 | 100 | 原完整策略同字节；主借剪成立，第三H中断 |
| 原25最强edge函数 | 1115 | 1 | 80 | 无H、不剪网，普通瞄射、反冲与纠偏换位合法快胜 |

edge仍最快，H不宣全指标优势。新场地实际引出普通角度与高低变化：edge P2身体x662..832/y360..383；P3迁行期间x494..804/y147..384。P2抵巢后必须看实际射角和身体动作，不能仅因函数字节相同就沿用旧“始终站右岸”的判断。edge在P3迁行中击杀，尚未看完高左到达或完整第三巡回；不能宣三套路线都完整体验。

真实九身体表面样点/枪口radius3 ShapeCast记录在frame的 `actual_low_perch_visibility`：edge690/720可射、750全部有限样点不通；不是整个P2永远不可射，也不是穷尽所有合法瞄准。观察不会发弹、写Motor或改资源。

第三H失败已离线定位：目的861请求720260，862cast/866fly，869真实女王身体接触扣1，同帧应用伤害回调取消H→free；原目的752→760同因。起钩距离约136px，小于231，前两结已死，没有旧结截获证据；未记录目标接触或hook_miss。不能把这个可选硬借写成成功。36已仅从目的驾驶删去该冗余drop/H/反打，固定环仍可选、生产不改；不将第三H计为成功。

P1局部28/29提供独立取舍：普通0伤、输出6、591tick回中枝12帧/E76.5；借结0伤、输出8、569tick回岸/E69.5。H多2输出早22tick、成本7E。这是可选收益，不是强制谜题。

## 36完整片与局部因果

36从当前主工作区复制2019个运行文件，cold editor import实际完成；10个女王生产文件SHA逐项与31相同。两条影片使用同一冻结源、正常60fps、1280×720、未裁剪完整输入，逐项全源前后守卫通过：

| 完整影片 | 帧数/时长 | 击杀tick | 玩家损血/末精力 | 实际软件GL采集耗时 |
| --- | ---: | ---: | ---: | ---: |
| [读预告H目的完整片](../evidence/forest_depth_v2/queen36/movies/adaptive_H/gameplay.mp4) | 1493 / 24.883秒 | 1492 | 1 / 100 | 42.874秒 |
| [最强普通edge完整片](../evidence/forest_depth_v2/queen36/movies/edge/gameplay.mp4) | 1116 / 18.600秒 | 1115 | 1 / 80 | 32.813秒 |

普通法快377tick（6.283秒），同受1伤；H保20更多精力，借首/主结、主结反向剪网成立，不宣H全面更优或第三H成功。60秒是因旧23/24的软件GL吞吐不足而明确变更的单次采集预算，不改60fps、玩法速度、native120或旧失败判定。

局部修正保留最初HP5：实际P2低巢在940落位，普通跳974从完整中枝起跳，1007以204.924/381.960完整落左枝。通用walk的7px容差不能代替24px完整支撑，因此驾驶在90帧硬界内以实际支持收束。1180唯一伤害为第三网 `queen/weave/2/1/0`，与该实例field/epoch的accepted sweep和Policy逐事件配对；1343完成周期、保存负例、真实第三借剪及返岸，47/0。观察对照22/0，全程5HP，主借剪与输出成立。

32–35失败全部保留：旧230落点已在新80缺口；中枝观察误忽略P1身体巡线；34b残留移动轴导致跌地；35普通跳确实落枝但右脚超出1.26px且与P2下降路线相撞。36只修驾驶与因果读取，不放宽支持/伤害条件，不重取HP基线。Python reader独立拒绝把35身体754伤、33地网439伤算作第三网。32全套188/4fail没有追签；36只补两local，最终完整Harness仍需实际再跑。

## 入口、保存与证据

自然入口唯一参数gap48/overlap24/player_half18/观察点130582，prep脚底映原floor600，connector仅左floor沿重叠24，不加会截女王外绕的高桥。Factory map2 `ok` 仅技术几何合法，`admission=experimental_whole_boss_pending`；支持显式pin v2、production_pool=false；registry现默认v2试玩候选、v1保存消费者保留。自然App实战、奖励与fresh恢复必须独立验证。

schema13保存身体、阶段、真实路线、一次采岸、目标巢、活结HP/已剪状态、网age/growth/cadence；类型先守卫，畸形输入拒绝而不抛脚本错误。旧12 failclosed仅影响未发布v2候选，不改v1旧存档。schema13的正式App自然通关、fresh角色/女王恢复、真实pointer奖励与边界已有[独立App05证据](../evidence/forest_depth_v2/campaign_node_boundary01/README.md)；该消费者用当前v4整体场地原点，不能拿本局部固定场地或same-instance测试代签。整体验证与最终准入仍分开。

规范入口已收敛为 `tests/support/forest_queen_gameplay_fixture.gd`、`tests/thorn_queen_sweep_runner.gd`、`tools/run_thorn_queen_sweep.py`；wrapper自含90秒cold editor import与120秒native预算、源SHA守卫。历史8producer按exact SHA归档，不保并行生产体系。

- [Queen36当前durable完整片/源/关键帧与局部因果包](../evidence/forest_depth_v2/queen36/README.md)：两条正常完整MP4、原输入时间线、2019源守卫、旧失败引用。
- [Queen31源/raw/阶段输入/射线包](../evidence/forest_depth_v2/queen_design_history/whole31-package.json)：三策略同态实战，第三H失败因果和全部限制。
- [旧Queen23整体REVISE](../evidence/forest_depth_v2/queen23_independent/REVIEW.md)：保留旧缺陷，不提前签新31。
- [P1普通/H真实恢复对照](../evidence/forest_depth_v2/queen_design_history/response29-package.json)。
- [Queen18局部独审](../evidence/forest_depth_v2/queen_design_history/Queen18-REVIEW.md)：CONTINUE不代签whole。
- [旧设计exact归档](../evidence/forest_depth_v2/queen_design_history/design-through21.md.txt)与[至30归档](../evidence/forest_depth_v2/queen_design_history/design-through30.md.txt)：原失败、电影、收据不追签。

36不同作者整片独审已有限CONTINUE，下一门槛是结合正式App独立证据、最终Harness与真实playtest评完整Boss价值；不代签趣味、正式准入或设备。素材仍是可读白盒，没有宣称精美美术、音频、设备覆盖或玩家认可。


本轮补采：[Queen36 canonical all](../evidence/forest_depth_v2/queen36/canonical-all36/README.md)实际194／0严格退出干净，原import90／native120／outer240预算，outer19.564秒，全source及verifier前后guard真。此为冻结36源的新实际全项结果，不冲销canonical32及33–35旧失败，也不代签后续默认／整个区域／真人与设备。
