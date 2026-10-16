# PLAINS-REDESIGN-01：空间、探索路线与迁移只读审计

基线 `30f6a825712fbb30e607791c996de142c6757a79`；分支 `feature/plains-designed-exploration`。采用 region-generator。只写本目录 `spatial.*`，未改生产、测试、文档。最新用户整体重设计授权优先于 skill 中历史“最小问题/切片”生产策略；Motor、武器、资源、成长、RNG算法和保存保持边界。

已读：AGENTS、region-generator、current_state/handoff最新段、generation_current、procedural_generation、architecture、acceptance_tests、动作README、regions_v0.3、实际四个生成类、RouteRecipes、RegionStage/Scenery、地图绘制/雾图、RunManifest、region trace/live trace、两图测试和浏览器检查。generation_current写v8是旧快照，当前代码/最新状态实际v9；RoomGrammar属于保留的共享生成消费者，不属于正式两图主链。

## 实际采集与观察边界

Godot 4.7.2 Standard 实际执行：

```
bash tools/godot.sh --headless --path . --script build/plains_redesign/audit/spatial.gd
python3 build/plains_redesign/audit/spatial.analyze.py
```

前者正常退出0，capture.log保留完成标记。采集10个root：`level-design-v2-baseline`、`level-design-v2-baseline/01`至`/09`；每root按正式 `PlainsRegionCampaign.seed_for` 派生两图，map1 intro/map2 advanced；20个完整真实生成Manifest，不引用旧80组结果作新实测。JSON保存Manifest/hash/seed、脚本、日志及80项四策略图诊断。

这是生成器+图几何采集；没有跑80条真实Motor+敌人路径，没有体验评分，不证明主路无损、实际快速、完整Boss或趣味。本图诊断用开放有向边，不使用未开启捷径；水平/竖井用Manifest polyline，挑战用端点，因此只能诊断路径长度/重复，不是玩家运动时间。四策略目标与正式live policy一致：fast prep；growth首medium→merchant→prep；deep两个深层奖励→prep；return高奖励→入口。

| 实测项 | 结果 | 含义 |
| --- | --- | --- |
| 核心节点位于旧1400×700 lattice | 20/20图，100%核心节点 | 凹空删格仍是规则布置 |
| 水平端点距离 | 所有1400 | 不是随机地图尺寸表现 |
| 普通竖井端点距离 | 所有700 | 高差变化限于层数 |
| 连接补地宽度 | 40..520；178处 | 空间由选模块宽度填满固定lane决定 |
| fast图路线长度（入口核心→prep） | 4900..9291.8 | 不包括tutorial/Boss，不是时长 |
| growth图路线长度 | 6898.6..22467.2 | 同tier奖励/商人可能造成大折返 |
| deep图路线长度 | 6748.5..25818.4 | 挑战实路径须Motor重新测 |
| return图路线长度 | 8189.7..22920.8 | 有环路不等于回程成本低 |
| 40中箱额外路线长度 | 约0..11380.9；18/40约零绕路 | 固定同risk/收益未绑定真实位置成本 |
| 现有BFS fast相对图距离最短更长 | 9/20图 | 测试“fast”不能当最快玩家路线 |

最差中箱反例：root `/05` map2，medium_1在 `area_1_0`，入口→箱→prep比最短入口→prep多11380.875图距离；与零绕路medium使用相同固定reward.risk。另 `/02` map1，旧BFS路径9089.07，对照图距离最短7891.80。数据见spatial.metrics.json。浮点近零按1e-8归零。

## 问题、证据、严重度与复现

### S1 高：空间身份来自坐标与随机标签，不能约束地形/路线

`plains_exploration_topology.gd:5-34` 先创建完整矩形、删格保环，family只改宽高/recipe名称；`plains_region_generator.gd:7-9,44-55` 固定DX/DY/HALF，只连右/上邻居；`119-123` 在几何生成后抽5种landmark并改label，recipe不读空间身份。全核心节点相同400宽junction（114-117），自然轮廓未驱动布局。

复现：本20Manifest显示每横边1400、每竖井700。读取同label区域的connection recipe可见任意混搭。玩家会看到串联石台/井，未证明风铃平原与其它地区的行动/轮廓身份。S1是设计问题；“不喜欢”仍需正常速度/玩家证据。

### S2 高：尺寸固定先于内容，产生填地与长竖井重复

`_fill_edge:335-365` 所有楼梯固定-750 bounds，switchback六层100间隔、recoil三层190、lift固定500跨度；`367-400` 任意水平recipe放入1000净lane，按world_bounds宽度推进，再填余量，不基于入口/出口动作与地形设计分配空间。40宽接缝是v9针对历史thorn_gap的有效修补，但无法成为整区设计方法。

复现：spatial.metrics中的178补地，宽度8类，最大520；全20图的主竖井重复相同高度和三配方。不能把补地距离直接断言为无互动：其真实敌人/拾取/走位必须查看帧证据。

### S3 高：环路数量与分岔数量不证明有意义选择/回程

`_candidate:63-106` 删除部分边维持cycles，随后把冗余stairs改成backside；`validate:516-519` 仅底线cycles≥3、fork≥3、prep入度≥2。没有“绕路为谁服务/捷径实际省时/安全和风险差异”约束。`_deep_loop:280-317` 两入口永远col0/2、奖励永远上方、落下到邻列；没有整体reward→camp/entry返回策略。

复现：return在本20图达到22920.8，最大重复边长度9291.8；它仍满足三个环路。不能据此宣布游戏无用绕行，需要真实return trajectory和已领取内容重复时间。设计必须拒绝没有用途的环路：每环有安全替代/省时风险/资源探索/返回功能至少一种且可观察。

### S4 高：相同medium风险/收益和实际成本脱钩

`_candidate:160-165` 两medium从任意未占junction随机抽，risk固定depth2/platforming1/timing1/pressure1/return1；没有离主路成本或return预算。`merchant:107-112` 任意抽，`growth`顺序首箱→camp→prep，不考虑共线/顺路。保持经济预算不等于保持奖励布局。

复现：`/05/map2 medium_1`额外11380.875与18个近零绕路同风险字段。不能靠增加金币解决，因为经济已冻结；应将同预算reward放在等价成本区间，较难分支兑现已有更高tier。

### S5 中：正式“快速”策略是最少边BFS，且网格ID泄漏到路线测试

`tests/plains_region_trace.gd:207-230` BFS不加权，仅依连接数组顺序；`tests/level_formal_trace.gd:24,198-215` 硬编码area_0_1/deep_high/deep_region_top。现阶段所有核心边只有两尺寸，使此问题被掩盖；新非规则短/长边会放大。要保留旧BFS轨迹作测试policy，另给设计分析记录按actual时间估算的策略，不将最少边当最快。

复现：本20图中9图BFS长于图距离最短；`/02`map1约15%额外图距离。但加权几何也不等于Motor最快，需要phase/敌人/风险分别建证据。

### S6 中：地图几何输出未反映真实关卡轮廓，world_bounds非几何导出

`_candidate:267` world_bounds固定高6000、宽cols*DX+3350；`plains_region_map.gd:22-29` 用整bounds fit，`105-115`多为端点直线/简化polyline。新不规则空间若仅换坐标，会出现空白占画幅、拐弯与实际平台不一致、回程落点不可读。雾图CELL280是探索采样，不应误判为关卡网格或擅改。

浏览器`verify_plains_region_browser.py:13-68`真实点图、fog/zoom/drag/close和tutorial输入；不检查完整路线可读性或全景构图，文件顶部明确声明限制。应新增三处关键分岔/回程口真实GUI合屏，而非增加OCR标签作为漂亮证明。

### S7 中：二维“地标”修补没有整区身份消费

`plains_region_scenery.gd:5-6,98-151` 最多2个、只接收ruin_arch/stones，风车/风铃/ivy标签主动省略，是前轮安全导航切片。该切片正确保护碰撞落脚/危险，但无法代表整体视觉重设计。保留不挡路/真实静态支撑的准入，允许整体新的场景构图合同替换MAX2和候选限制。

## 两种整区方案比较

| 方案 | 内容与空间 | 优点 | 代价与主要反例 |
| --- | --- | --- | --- |
| A 推荐：多套语义骨架+经Motor验证的空间变体 | 先分配主脊、河岸、修复庭院、上方钟塔、回程口；选已验非规则宏观骨架，再按实际port分配不同长度模块和地形 | 可用现有Generator/Recipes/Assembler；每条路有用途，容易验证和艺术构图，失败保底是完整设计骨架 | 若只换骨架名称/平移仍是假多样；必须至少3个真正不同分岔/回归关系，模块/遭遇随语义改变 |
| B：语义约束图+连续空间嵌入 | 先生成主支环图，节点赋角色/风险/学习，再解不规则空间与模块路径；用面积/交叉/视线约束优化 | 长期最多样、轮廓可独立生长、合适未来地区 | 地形碰撞、桥穿井、单向落下绕过奖励/锁最难；有界重试及Motor成本高，当前全改可能变成空框架 |

A不是另造框架，也不是几行切片：同一四类主体改成语义编排，现有Resource/Manifest/RNG/Assembler仍消费具体模块。先做两个完整地图黄金骨架，再生成多套拓扑变体/模块替代/遭遇变体。B的语义校验可作为A离线检查，不在本轮增加无消费者嵌入引擎。

## 推荐整区蓝图（设计候选，非用户最终审美认可）

S1共同身份：低缓草岸/横向开阔+少量垂直旧铃构筑；用反冲方向、落点、制动逐步教学；自然地形承担通行与恢复，黄铜机关集中在遗址。禁止将每个空地都塞危险。基础一跳+现有R均可；不引入H/W/D/U1、额外资源/无敌/强制损血。

map1“溪岸与钟庭”：入口安全缓坡→能看到主钟楼的草岸分岔→溪岸与钟庭两个可见汇合→营地→双入口Boss整备。主脊用短动作链和宽稳定落脚，分岔一条较慢安全岸线，另一条较短已有ferry/铃机关路线；商人在汇合安全区。两个medium分配一个正常成长顺路小探索、一个靠近可观察的溪岸支线；high/region_top是上方钟塔/崖岸长链，终点各通过不重复原挑战的下降出口汇到已知区。奖励回程不能逆向从简单落下口直接领取。

map2“断钟峡与回风脊”：入口从低盆地见两条坡和高遗址→中央修复庭院提供恢复与已知回程地标→外围较慢山脊/内侧较短精确机关两路→跨溪废钟院→两个Boss approach。纵向只在盆地/钟塔/峡壁产生，避免全图三平行横线与每列一井。高难奖励是“登高→连续两种已学动作→上方奖励→单向回到庭院或前进主脊”，保证返回目标与快找Boss目标都合理。map2复合机关放在风险路和高级奖励，至少一条基础可恢复主路不需要复合硬门。

每图需要：≥3独立环路与≥3明确岔口，prep双入口，至少2有用途的backside shortcut；这些旧底线可以继续保留，不把它们当趣味结论。15/18普通节点规模可暂保留以减迁移，但节点分配到不规则地形片段，不为凑数添空回廊。模块尺度从微平台到整挑战不同；边有authored polyline/support端口，主路单段1–2个学习/执行意图为候选，奖励支线3–5个意图分安全恢复；具体深度不是动作计数难度评分，需资源/时序/战斗耦合一起验。

每个骨架变化至少改变一项可观察决策：安全岸线在哪分离/汇合；高奖励回到营地还是前进主脊；Boss双入口上下关系；河谷穿越方向；上方遗址入口/视线。仅坐标、模块ID、贴图/Hash差异不算结构/玩法差异。

## 具体函数修改包与顺序

1. `PlainsExplorationTopology.make`：返回具体语义areas/edges/outline/骨架版本（保留现有API消费者适配，不新增通用服务）；抛弃完整矩形删格，骨架承诺entry/prep/merchant/reward/return关系。`connected/cycles/boss_cell`转为实际边检查，不用四邻关系推图。至少3骨架+intro/advanced空间variant；输入均来自现有RunRandomStream。
2. `PlainsRegionGenerator._candidate`：读取实际节点position/semantic_role/landmark，拓扑决定学习和路的用途，再分配recipe/遭遇/奖励。现有DX/DY/HALF只保留历史fixture，不成为新布局合同；prep不再“最右且degree≥2”抽选，merchant不从全图随机散投；普通reward从成本/风险合适的语义候选中用reward stream选。
3. `_fill_edge`：改按端口对接的显式edge path/allocated geometry，分地面、坡级、渡溪、竖向、下降类型；真实module出口位置决定下一入口，支撑/观察/恢复片段是语义内容。保留补缝机制但拒绝为了固定1000净lane填大片无目标平地；接缝重叠仅已验solid，one-way不被混成solid；bounds/危险包络跨边要判重叠。
4. `_deep_loop`：接收具体入口、奖励、回归节点与挑战package；不能从col0/2和DX推出。记录exit/return路线和锁前预览。保持两高级权益/奖励ID稳定语义与反向入场否定测试，graph不宣称Motor可过。
5. `PlainsRouteRecipes.choose`：加读取edge用途/已教mechanism/空间identity的参数或本地过滤，least-used仍可在合法池中；不使用全图历史hazard最低覆盖强迫主路后半反复危险。intro与advanced规则照旧来源；每条main至少有必要的观察→执行→安全恢复，长链集中optional。
6. `_candidate`敌人/拾取块：按真实route角色保护恢复与岔口视线，再用原content/enemy布局写Manifest；保留26/36上限、simultaneous、Drop预算、Reward预算，不用多刷怪证明多样。普通coin仍24等预算；位置调整不改变成长/经济逻辑。
7. ground_supports/world_bounds：从具体solid terrain+宏观最低surface导出，不能只看row==grid_height-1。每块foundation保护下层通道/危险/落下回程、平台/地面合并接缝同原原则。world_bounds由union实际模块/arena/return+相机余量导出，检查boss与最高奖励不裁切。
8. `PlainsRegionAssembler.build`：继续逐recorded nodes构建，不重抽图；记录中的gate/control可不在固定700井内。保持clock/mechanism/open状态恢复；必要变更仅支持新连接geometry，不反向从art推碰撞。
9. `PlainsRegionScenery.plan`、RegionStage绘制/Map绘制：消费semantics/outline/明确route polyline；支持轮廓/地标与功能方向一致；真实静态支撑/落脚/危险遮挡规则继续。雾图CELL280独立于地形尺寸保持；新landmark不能泄漏未知目的地。
10. 版本和消费者：v9→v10只递增内容/布局版本；保留RNG derivation v4及各named stream算法，不改root→map2规则/MetaSave。RunManifest读当前版本，旧Manifest明确拒绝且旧源码可重演；`tools/level_design_analysis.py:165`白名单、golden runner版本、live/region trace网格ID需显式迁移。增加entry_id而非到处硬编码；deep目标以reward tier/semantic lookup取得。旧policy BFS仍记录名字，新分析另外输出time/risk/return。

## 不变量与历史冻结的区分

| 现有约束 | 分类 | 本轮处理 |
| --- | --- | --- |
| 正式两图，mini/region Boss角色，两图资源继承和实例前缀 | 基础规则 | 保留；不能退回八房流程 |
| S1基础一跳/现有R、单武器、无未授H/W/D/U1/补资源作弊 | 基础规则 | 原值/实现不改，真实Motor正/反测 |
| RNG算法/流域、可复现/有限候选/完整验证fallback | 基础规则 | 保留，版本变化诚实记录 |
| Manifest篡改、伪连接/伪奖励/删真实碰撞拒绝 | 基础规则 | 保留原负例并增加新布局负例 |
| 状态保持/伤害epoch/一次奖励/save/段回退/死亡优先 | 基础规则 | 无实现修改，受影响集成回归 |
| 有环有岔有prep双入口及backside返回捷径 | 原可继续保持的体验底线 | 保留≥3/≥3/2/2，附路线用途与成本证据 |
| 当前固定预算/敌人上限/初图复合排除 | 本轮系统边界/已验公平 | 保留，位置编排允许改变 |
| DX1400/DY700/HALF200、15/18 cells、20/23总area、row/col/area_X_Y | 历史内容冻结 | 用户整区授权合法覆盖；不应以维持旧坐标否决设计 |
| 三family名称与最右Boss、深层入口col0/2 | 历史实现/具体内容 | 可换语义骨架，必须补同级结构/路线差异测试 |
| MAX2/只ruin_arch+stones | 前轮小切片内容冻结 | 可整体重设；保留不遮挡/真实支撑准入 |
| v9特定thorn_gap/40px collar exact坐标 | 历史黄金内容+基础接缝缺陷回归 | 原件/断言不删；保留isolated原geometry测试并新增v10接缝及负例；不能用旧测试要求整张新图仍同坐标 |
| RoomGrammar/Branch/Blueprint开发消费者原接口/结构 | 共享消费者兼容 | 不因正式平原重设而删；保留全部31套入口与适用断言 |
| 地图初始未知目的地不泄漏/真实点击缩放拖拽/模态暂停输入 | 基础UI行为 | 原浏览器8类检查保留；新增分岔/回程实景 |

测试迁移不能简单把expect改为当前输出，也不能直接删除失败断言。每条layout专属assert给出旧目的、保留fixture/断言、新内容对应准入和独立diff审查；v9冻结证据继续留原目录。可把旧exact黄金放入测试专用固定geometry执行，当前正式测试从entry/semantic role寻目标。若这些保留无法实现，明确阻塞而非暗中降标。

## 15地区与31共享消费者逐套迁移/风险矩阵

所有套件入口、成功摘要和失败guard保留；以下是改动检查重点，不代表本轮已执行这些测试。

| 地区套件 | 保留保障 | 新布局迁移重点 |
| --- | --- | --- |
| cohesion_drops | 固定总预算、幂等drop/claim | 新enemy/reward IDs与真实分布 |
| cohesion_lifecycle | 回退/卸载/旧实例 | 新gate/node clocks恢复 |
| cohesion | module机制与危险一致 | 新macro中的支持/危险接缝 |
| interactive_platforms | 表面危险/远程机关真实物理 | 新主支路空间中phase/朝向 |
| interactive_lifecycle | 机关状态及幂等 | 新shortcut再载/回退 |
| platform_boss | Boss与真实平台行为 | 新arena offset/接近视野 |
| exploration_pressure | 真实敌人+路线压力 | 新全部路线/恢复不被占 |
| exploration_module | 已验模块动作 | 新port对接/长链衔接 |
| exploration_expansion | 深层回程/机关/5行为 | 固定col/deep脚本改语义goal，保留反向绕过负例 |
| experience_energy | 原精力与奖励能力行为 | 低资源新主路合法，不修改资源 |
| pressure_boss | Boss压力/无钥匙硬门 | 新Boss approach/Boss边界 |
| campaign_map | 两图/迷雾/资源/实例继承 | 新world_bounds/图线/ID/多样观测 |
| region | 有界生成+重放+真实itinerary | 固定20/23/area_ID改版本化scope；原forged负例保留 |
| region_lifecycle | 保存/再载/孤儿实例 | 新模块/捷径/return锚点 |
| region_boss | Boss起始存在/结算 | 新prep/arena和map transition |

| 共享套件 | 保留保障与迁移关注 |
| --- | --- |
| room_grammar | 旧共享Template/Branch/Encounter真实consumer保持，不能假称其为新正式主链 |
| feedback | 正式反馈版本/来源/导出按当前Manifest |
| core_access | Boss弱点/18px真实core，系统不改 |
| final_pier_repro | 旧具体平台反例留fixture，回程不传送/不rewind |
| polish_boss | 旧Boss技术fixture保留，新arena单独验证 |
| camera_trace | 相机舒适/玩家与Boss合屏，补新宏观高低变化 |
| polish_routes | 原操作轨迹保留共享consumer；新正式四策略另增 |
| windkeeper | Boss核心/阶段/伤害不改，新arena集成另外 |
| terrain_cohesion | 真实接缝/ground vs one-way不混淆 |
| generated_latch_trajectory | 远程机关/释放轨迹/时序保留，新增新方向/遮挡负例 |
| ground_support | 地面支撑不封下层空间，macro support改后重点 |
| recoil_margin | 弱资源实际无损余量保留，不改Motor凑数 |
| camera_comfort | 舒适/跟随/预告，非规则高度重点 |
| blueprint | 历史共享布局重放/防伪仍保留 |
| recoil_recovery | 单武器真实回能与epoch不变 |
| blueprint_schedule | 历史共享schedule/独立流仍保留 |
| jump_chain_measurement | 唯一基础物理参数不变 |
| floating_touch | 三端触屏/模态/输入取消不变 |
| weak_capabilities | 不从练习能力外推正式授予，新主路实际正向 |
| branch | 共享分岔布局/唯一节点归属保留 |
| branch_library | 已验library/真实动作保留，复用须新组合再验 |
| refresh_art | 对象视觉/收集反馈保留，合屏新轮廓另验 |
| spatial | 共享空间/非等尺寸/镜像/port真实支持规则保留 |
| jump_height_measurement | 不改变本轮基础重力/动作 |
| exit_routes | 历史终端出口consumer保留，新两图仍无八房exit |
| home_app | 正式Home/购买/出发/save，系统边界不改 |
| home_ui | UI输入/模态不变 |
| player_feedback | 真实接受反馈/事件不变 |
| painterly_skin | 旧皮肤/材质consumer保留，新构图不等于风格通过 |
| meta_notes_save | Meta与run独立、幂等存储不变 |
| ten_generation | 历史共享10阶段生成consumer保留，不作为新平原开放范围 |

另原v9黄金/action autonomy、V2 analyze/compare、Foundry basis校验与harness docs/gameplay/art/web仍适用。新的技术矩阵：10 roots×2 maps×fast/growth/deep/return×真实默认合法基础武器（目前正式仅实际授予的一种；未来其它开局候选不能冒称已开放）；无敌人terrain和有正式敌人全app分开。少量最差seed加0/25/50/75%phase、低精力/冷却、正反方向，保留无损/危险sweep标准和negative删平台/改gate/伪reward。

## G0审查退出与危险

推荐先冻结完整两图设计和三骨架关系，再写v10实现；不能拿本审计通过当设计用户确认。必须验证：主路真基础可达、最差seed+有敌人连续四策略、高级奖励后归路不重复挑战/不反向轻取、两图/回退/保存/流分离不变、真实地图及关键分岔合屏、Q7五签名分别成立。

最高实现危险：任意改坐标但继续固定700竖井；用world_bounds宽度代替实际出口port；基础地面support封掉低层；one-way下降旁路到高级奖励；全图最少用recipe破坏教学恢复；新短边却沿用BFS最快声明；新landmark前景遮住落脚/危险；v10Manifest白名单没迁移导致capture拒绝；为46旧套件改坐标断言时误删基础行为保障。每项应有故意失败负例。

独立设计结论：旧网格/随机标签/配方填道没有达到整区身份与路线价值合同。方案A可沿现有四类主体完整重设；必须同时改macro、edge realization、reward/return、scenery/map、当前版本消费者。仅改标签/局部危险/常数间距应REJECT整区完成声明。真实路线、美术、用户体验和设备结果仍unverified。

### 更新：减迁移与V9/V10并行证据的具体决定

推荐保留20/23总面积、3旧family、area_X_Y地址、area_0_1入口和两个deep名称；它们不是导致坏体验的因素，保留可让原15地区绝大多数断言完全不改。真正替换的是坐标公式、固定lane/竖井、空白填地与随机身份。ID/row/col可仅作稳定兼容地址，不能再从它们推position和bottom foundation。

旧V9 hard golden必须在 `/workspace/plains-redesign-baseline` 原30f项目中原断言真实实跑，不只保留JSON；旧15+31全部suite也继续在该冻结project执行。当前V10同15+31入口继续实跑，不能跳过；新V10黄金从当前真实默认流找目标并加删真实bank负例。精确旧布局断言（action golden5380/40宽、autonomy support[200,18,280,40]）归V9冻结轨；其基础保障（真实支撑、不挡路、无损往返、原Resource/epoch、否定反例）新增V10当前consumer，且旧断言保留。这是合法内容更新的版本双轨，不是减少回归。

非均匀竖井的真实driver陷阱是 `tests/plains_exploration_motion.gd:32`：shaft target写死module.position+(0,-700)；应读取end_module.world_entry/目标area，不写玩家位置。stairs walk_edge已读edge.path，可接受不同层数，但每step保持已验100/190左右能力包络，最终不足step落到真实上层坐标。lift定义finish据actual rise和已验上岸距离导出；三种drop固定180/210/280tick预算先不改，空间高度选有界黄金，失败明确记录。horizontal旧driver要求同y且e.a在左，可设计受约束macro/分段转向；不要仅把端点变斜而留move_to。
