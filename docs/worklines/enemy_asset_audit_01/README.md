# 怪物资料与素材现状盘点

**上一轮成品已被用户拒绝，本页不沿用“候选ACCEPT”作为制作质量结论。** 先查现在有什么、实际用了什么，再共同决定怎么验收和生产。源快照为`310c0421e18829088a4d2208c5f1b6cba3db35dc`；本轮未改生产代码、未生成／编辑图片、未启动Godot。

用户新增要求：**“最接近目标是平原的第5个。先不要批量做，先发现问题。”** 当前以问题诊断为主，参考编号待核对，不擅自当作黄金怪物采用。见[首批问题与待观察项](first-findings.md)。

用户再补充：**“所有的怪物需要整理并统一程序结构。”** 已扩展到[全怪程序结构盘点与统一边界](program-structure.md)：现在共用什么、实际分叉、明确问题与最小迁移次序。当前只交事实与方案，未实施重构；“先发现问题，不批量做”继续有效。

## 先看哪里

- [原素材浏览册](materials.html)：25个条目，覆盖14普通物种、2开发候选、8 Boss场景／9个Definition组合。可看当前代码所选裁区和完整原PNG；需要联网加载冻结提交的图片。**素材预览不是实机，缩略框也不是游戏实际尺寸。**
- [平原逐怪目录](plains-details.md)、[森林／候选逐怪目录](forest-details.md)、[Boss逐组合目录](boss-details.md)：设计文档、原图、母版、历史图、动作消费、受伤／死亡及缺失。
- [共享特效与声音](shared-feedback-audio.md)：哪些是共用程序表现、哪些有实际文件、选择配置与播放调用是否接上。
- [验收与生产流程讨论稿](discussion.md)、[原独审者补充复盘](review-postmortem.md)：区分本来已有但没执行的要求，与需要一起新定的规则；**尚未修改skills或让新规生效。**

检索用了Git完整树、Definition、安装／替换分支、实际绘制函数和manifest，补查sparse未检出文件；不以文件名或旧制作卡代替实际消费。这里的“未找到”只针对已检查的跟踪源和相关文档，不代表从未制作或外部没有原稿。“当前在用”是静态代码选择，非本轮重新运行的证明。精确路径、行号、尺寸、来源和共享关系在三份原始JSON中；[总索引](inventory-index.json)仅便于查询，不是新的资产登记系统。

## 平原：7种，原scene与Underworld不能混为一套

| 怪物 | 现有设计资料形态 | 当前身体／动作材料 | 库里另有什么、主要断层 |
| --- | --- | --- | --- |
| 巡逻怪 `patrol_drone` | 初代Actor／巡逻契约、旧SVG说明、地区和共用卡；未定位现源独立专卡 | Underworld为`patrol.png`单体；原scene用`meadow_actions/beetle.png`的idle_a／death | 旧SVG分层与状态图仍在；不能当当前7怪正在使用的素材 |
| 冲锋怪 `plains_charger` | 有[历史专卡](../../design/enemies/plains_charger.md)，另有反馈专题；历史专卡不是现源规格 | 两skin各一张v8 sheet；当前live取H3，受伤H0–3，死亡D4–7，live再程序变形 | 有独立受伤／死亡姿态，未找到当前完整独立行走／攻击／转向绘制序列；旧小身体图不再是live像素 |
| 俯冲怪 `plains_diver` | 行为、反馈专题、地区与集合卡；未定位独立Enemy Sheet | 两skin各一张v8 sheet；同样H3 live、4H／4D | 旧飞行母版仍在；与冲锋一样不能把H/D齐全当完整动作包 |
| 跃击怪 `plains_hopper` | 跃扑／D081和共用卡；未定位独立Enemy Sheet | Underworld为`hopper.png`；原scene与巡逻怪共用beetle的idle_a／death | 原beetle的idle_b、telegraph、attack、recovery格存在，当前不播放 |
| 炮哨 `plains_sentry` | D070行为与共用卡；未定位独立Enemy Sheet | Underworld为`sentry.png`；原scene用meadow sentry的idle_a／death | meadow sentry同样有4个未用动作格；当前动作主要是同图程序变化 |
| 扇形炮哨 `plains_fan_sentry` | D081扇射与共用卡；未定位独立Enemy Sheet | Definition实际`aerial=true`：Underworld用`aerial.png`；原scene用spatial actors的飞行裁区 | **旧卡“与sentry同炮哨母版”不实。** 原scene也不走本轮新mesh绘制，仅整体浮动／倾斜／缩放 |
| 根铃怪 `plains_root_bell` | 有[root设计](../../quality/region_production_v3/root_bell_design.md)和遭遇合同 | Underworld为`root_bell.png`；独立RootBell用专属六格页的idle／death；rawscene落通用旧enemy图 | 三链身体不同。专页telegraph／attack／recovery／hurt格存在却未选；爆发六格中的rise也未用 |

详见[平原目录](plains-details.md)和[78个相关HEAD文件的原始审计](plains-inventory.json)。这里“有图格”只证明有对应姿态意图，不证明已通过质量审查或能无缝播放；本次没有决定直接把旧格重新接回。

## 森林：7种，身体图与动作包要分开看

| 怪物 | 现有设计资料 | 当前身体源 | 动作／受伤／死亡素材现状 |
| --- | --- | --- | --- |
| 铃囊萤 `forest_lantern` | [生态v2](../../design/forest_enemy_ecology_v2.md)、森林Bible和集合卡 | `fine_32/lantern.png` | 单张身体＋程序关节；未检索到物种专用逐状态动作序列 |
| 棘籽哨 `forest_seed_sentry` | 同上 | `fine_32/seed_sentry.png` | 同上；弹体和预警另为程序表现 |
| 盾甲虫 `forest_bark_beetle` | [反馈生态](../../design/forest_feedback_ecology.md)、森林Bible和集合卡 | `fine_32/beetle.png` | 同图动作／受伤／终态；盾面闪线是程序特效 |
| 摆荡荚 `forest_swing_pod` | 反馈生态、森林Bible和集合卡 | `fine_32/swing_pod.png` | 同图动作／受伤／终态；绳和挂点另由代码画 |
| 跃枝怪 `forest_crossbranch` | 生态v2、Forest Depth、森林Bible和集合卡 | `fine_32/crossbranch.png` | 单张身体；位移路径、落点和起落动作不是独立图序列 |
| 织线蛛 `forest_thread_spider` | 生态v2、区域资料和行为实现 | `native/weaver_silk_bell_v5.png` | 与双入口织网怪共用身体；蛛线／预警是专有行为的程序表现 |
| 双入口织网怪 `forest_bible_weaver` | 区域／双入口设计、行为实现、集合卡 | **同一张**`weaver_silk_bell_v5.png` | 同图程序动作，未使用独立H/D图序列；双线逻辑不等于第二套身体素材 |

本次未定位这7种各自独立完整的Enemy Design Sheet，设计主要在生态／地区章节中。5张fine32身体来自相应母版裁切构建，两个蛛共用v5原图；旧native、weaver v4与“8实体概念atlas”均有留存，**8种实体图不是8帧动作**。族manifest中的旧native／direct_sampling字段也不能覆盖现源helper已选fine32的事实。详见[森林目录](forest-details.md)和[原始审计](forest-inventory.json)。

## Boss：8场景／9组合，当前主身体只有5个PNG载体

| Boss／组合 | 资料情况 | 当前身体与已有动作材料 | 准入／共享边界 |
| --- | --- | --- | --- |
| 旧发条守卫 `clockwork_guardian` | 通用Boss契约、atlas说明，未定位专Sheet | `clockwork_atlas.png`中phase1／phase2／dead三个静态键＋程序动作 | 旧demo／Lab；三个状态键不是完整连续动画 |
| 鸣铃巡游机 `bellstrider` | 平原Bible§6.1、[压力Boss设计](../../plains_pressure_boss.md)、运行文档 | 独立`bellstrider.png`静图；旧SVG／空间机身另存 | 当前平原图1；轮、悬挂、警告等代码实现，不是独立动作图包 |
| 牧风者默认 `windkeeper` | 迭代／运行文档、Bible§6.2 | `windkeeper.png`静图；另有旧v4六关键姿态和parts | 旧scene窗口配置；六姿态在另一分支，非当前Underworld主身体动画 |
| 牧风者Storm `windkeeper_storm` | 压力Boss强化、运行文档和Bible | **与默认完全同一张**`windkeeper.png` | 当前平原图2资源覆写，不是新增Boss物种或独立新美术包 |
| 旧森林守卫 `thorn_guardian` | 区域／通用资料散落，未定位旧场景专Sheet | `fine_32/guardian.png`，1×，同图程序动作 | 旧v1显式回放；与V2共用图 |
| 旧森林女王 `thorn_queen` | 区域／通用资料散落，未定位旧场景专Sheet | `fine_32/queen.png`，2×，同图程序动作 | 旧v1显式回放；放大不增加新姿态或新细节 |
| 根铃守卫V2 `rootbell_guardian_v2` | [专卡](../../design/rootbell_guardian_v2.md)、历史设计记录 | 与旧守卫同`guardian.png`，1×；铃／扑落／返击以代码与共用机关实现 | 当前森林候选入口图1，准入仍有范围限制 |
| 织网女王V2 `thorn_queen_v2` | [专卡](../../design/thorn_queen_v2.md)，原整体未通过记录仍在 | 与Canopy同`queen.png`，1×悬浮；网带／结点代码实现 | 旧layout pin／历史迁巢版本，不当当前新物种 |
| 棘冠女王 `thorn_queen_canopy` | [Canopy v3专卡](../../design/thorn_queen_canopy_v3.md)，有限整合与REVISE仍在 | 同`queen.png`，1×；单体程序动作与两网机制 | 当前森林候选入口图2，不能由资料／测试数量追认整体通过 |

五个主PNG载体是clockwork atlas、bellstrider、windkeeper、guardian、queen。后两张来自包含甲虫的fine32重绘母版；**共用母版不自动判差，也不能自动说明不同Boss身份和质量同档。** 查到原图、构建和来源，不等于有完整转面设定／动作分镜／逐帧包。`plains_bell_warden.tres`等无当前场景消费者资源另列，不多算Boss。详见[Boss目录](boss-details.md)和[原始审计](boss-inventory.json)。

## 两个开发候选

| 候选 | 资料 | 当前使用 | 已有但未按动作消费 |
| --- | --- | --- | --- |
| 诱导盾卫 `candidate_lure_guard` | 参数／玩法在ModuleEnemyPrototypes和ActionStudio；资产生成说明；未定位完整独立单卡 | 新`prototype_sheet.png`的guard neutral裁区＋程序动作 | 旧`plains_v7/enemies/guard_moth.png`六列两行，以及新页其它姿态意图图格 |
| 侧风蛾 `candidate_crosswind_moth` | 同上 | 同页moth neutral裁区＋程序动作 | 同上；第二轮被拒源页也留存 |

两个候选未进入正式池；“旧／新页有多姿态”与“当前只用两个neutral裁区”同时成立，不能写成没有任何素材，也不能称完整12帧动画已制作。详见[森林／候选目录](forest-details.md)。

## 对修改流程最有用的事实

1. **资料完备度不齐**：少量有历史专卡，多数是散落的行为／地区章节加后补实现表。历史冻结卡、现源实现和用户已采用方向需要分开；不能因“有一张卡”就算输入齐备。
2. **素材完备度不齐**：专门H/D姿态、单张身体、未消费动作格、共用母版、旧版和备用几何并存。先决定每只怪的目标与适合的制作方式，不能一律套单图UV法，也不反向规定全体必须逐帧。
3. **消费核对漏过了实际分支**：fan与root是已证反例。对象创建、advance和HP事件出现，都不能证明最终屏幕用到所描述的素材／动作。
4. **上一轮审查重心不够**：抽帧、无裂缝、源SHA和生命周期有用，但不等于完整正常速度下的造型、承重、发力、节奏、反馈和全体质量下限。用户不应成为这些常规缺陷的首个发现者。

下一步不是立刻再做全套，而是一起从原素材、现有实机与资料中选正／反例，确定应保留或重做的身体、动作方法及扩产条件。[讨论稿](discussion.md)只列待决定项，不是新验收规章。
