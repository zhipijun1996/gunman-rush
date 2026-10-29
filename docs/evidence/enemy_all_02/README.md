# ENEMY-ALL-02：逐怪实机审核索引

本轮已制作供审核的同体动作候选，并录下14种普通怪、22条宿主渲染链、2个开发候选及8个Boss场景／9个实际Definition组合。请先看[正式实机总览](candidate_v5/in-game-overview/review.mp4) **56.68秒**，再按下面时间表检查具体怪物；[Boss总览](candidate_v5/boss-all/review.mp4) **257.97秒**覆盖8个实验台组合及正式App的storm组合。

当前状态为 **review候选**。用户审美／趣味、实体设备性能和原音轨听审仍待审核；最新d91源的森林80图矩阵已80／80通过（原600秒预算，实际540.378秒）；森林7种已按d91干净源补录，83.85秒、零技术覆盖缺口。它是一个专项Harness检查，不代表完整CI或G5通过。

## 先看正式场景

交付媒体和完整元数据集中在[candidate_v5/manifest.json](candidate_v5/manifest.json)。总览按完整章节拼接，原视频包直接复制、原引擎PCM按样本拼接后一次AAC编码；没有补音乐、补静音、插帧或在章节内部剪掉失败。不同章节不是一条连续自然campaign。准确帧数／音频样本／SHA与生成命令见实际交付manifest。

| 对象／实际链 | 影片时间 |
| --- | --- |
| 正式平原冲锋怪：一次初始审核站位 · 真实生成stage | 00:00.00–00:09.43 |
| 正式森林map1：原出生点连续输入 · 真实生成stage | 00:09.55–00:39.55 |
| 牧风者正式storm36HP组合 · 真实正式App | 00:39.77–00:56.60 |

- **平原**：真正DemoApp、原生成地形／原有冲锋怪／双方伤害／HUD／StageCameraRig。仅开局一次把玩家置于已验证安全的真实支撑上，画面标有INITIAL REVIEW STAND／NOT NATURAL ROUTE；目标3→2→1→0，3次真实HP提交及210帧终态。它证明该正式消费者的战斗合屏，不证明从自然出生点走到此处。
- **森林**：debug直入正式生成map1后，从原出生点持续Router输入；原敌人与地形不改，片内棘籽哨3次真实HP提交、1次死亡，没有观察到悬荚。它不证明自然跨区解锁、全地图或全物种完成。当前总览的这段保留b71实际采证来源；新森林逐怪片另以d91补录。
- **正式牧风者**：真实App的map2 storm36HP组合，开战前一次明示玩家入场站位；战中沿原AI／阶段／弱点／资源／双方伤害。36次真实HP提交，死亡后210帧，保原镜头／HUD。它与scene默认12HP版本分列。

## 全部影片

| 影片 | 时长 | 实际范围 |
| --- | ---: | --- |
| [正式实机总览](candidate_v5/in-game-overview/review.mp4) | 56.68秒 | 3个真实App章节，边界见上表 |
| [平原逐链](candidate_v5/plains/review.mp4) | 159.55秒 | 7物种×2链＋独立RootBell，共15例实验台 |
| [森林逐怪](candidate_v5/forest/review.mp4) | 83.85秒 | 7物种，原正式艺术metadata；d91新实录 |
| [开发候选](candidate_v5/prototypes/review.mp4) | 24.42秒 | 盾卫／侧风蛾两例，未进入正式池或保存契约 |
| [Boss总览](candidate_v5/boss-all/review.mp4) | 257.97秒 | 8原场景实验台＋1正式App storm组合 |
| [8场景Boss实验台](candidate_v5/boss-lab-eight/review.mp4) | 240.95秒 | 各自原scene／Definition／AI及真实双方战斗 |
| [正式App牧风者storm](candidate_v5/boss-formal-storm/review.mp4) | 17.02秒 | 正式36HP组合，非scene默认12HP |
| [冲锋严格留尸](candidate_v5/corpse-charger/review.mp4) | 22.27秒 | Underworld＋scene两链；各settled之后210帧 |
| [俯冲严格留尸](candidate_v5/corpse-diver/review.mp4) | 22.30秒 | Underworld＋scene两链；各settled之后210帧 |
| [正式平原独立片](candidate_v5/formal-plains/review.mp4) | 9.55秒 | 一次初始玩家审核站位，原冲锋怪实战 |
| [正式森林独立片](candidate_v5/formal-forest/review.mp4) | 30.12秒 | debug map1／原出生点／自然连续输入；旧源范围 |

每组保留report、chapters、完整trace与原引擎PCM归档；source_stable及零coverage gap只签该驱动要求的事件覆盖。它们不替代身体连续性、正常全速观看、听感、自由游玩或设备验收。平原主片的“死亡后210帧”也不能代替下方补录的“settled后210帧”。

## 平原：7物种／15条实际宿主链

| 对象／实际链 | 影片时间 |
| --- | --- |
| 巡逻怪 `patrol_drone` · Underworld | 00:00.02–00:10.57 |
| 巡逻怪 `patrol_drone` · 原scene | 00:10.62–00:21.18 |
| 冲锋怪 `plains_charger` · Underworld | 00:21.23–00:31.80 |
| 冲锋怪 `plains_charger` · 原scene | 00:31.85–00:42.42 |
| 俯冲怪 `plains_diver` · Underworld | 00:42.47–00:53.02 |
| 俯冲怪 `plains_diver` · 原scene | 00:53.07–01:03.62 |
| 跃击怪 `plains_hopper` · Underworld | 01:03.67–01:14.18 |
| 跃击怪 `plains_hopper` · 原scene | 01:14.23–01:24.75 |
| 炮哨 `plains_sentry` · Underworld | 01:24.80–01:35.43 |
| 炮哨 `plains_sentry` · 原scene | 01:35.48–01:46.12 |
| 扇形炮哨 `plains_fan_sentry` · Underworld | 01:46.17–01:56.82 |
| 扇形炮哨 `plains_fan_sentry` · 原scene | 01:56.87–02:07.52 |
| 根铃怪 `plains_root_bell` · Underworld | 02:07.57–02:18.17 |
| 根铃怪 `plains_root_bell` · 原scene | 02:18.22–02:28.82 |
| 根铃怪 `plains_root_bell` · 独立RootBell | 02:28.87–02:39.47 |

看片重点：冲锋／俯冲的移动或attack→受伤→当前动作出口，角、背部齿轮、翅根和肢体身份是否连贯；跃击的承重与落点；两种炮哨的身体反冲是否和原预警／真实弹体相符；根铃三链的枝根锚和pulse边界。接触巡逻没有虚构远程招式。

## 森林：7物种

以下为d91干净源新录制的83.85秒时间表；逐帧记录与实际源SHA随影片保留。

| 对象／实际链 | 影片时间 |
| --- | --- |
| 盾甲虫 `forest_bark_beetle` · 原scene | 00:00.02–00:19.52 |
| 摆荡荚 `forest_swing_pod` · 原scene | 00:19.57–00:28.57 |
| 铃囊萤 `forest_lantern` · 原scene | 00:28.62–00:37.62 |
| 棘籽哨 `forest_seed_sentry` · 原scene | 00:37.67–00:48.30 |
| 织线蛛 `forest_thread_spider` · 原scene | 00:48.35–00:57.35 |
| 跃枝怪 `forest_crossbranch` · 原scene | 00:57.40–01:11.33 |
| 双入口织网怪 `forest_bible_weaver` · 原scene | 01:11.38–01:23.77 |

看片重点：盾甲虫腿／盾体与真实受击窗口；悬荚柄与真实绳端是否相连；灯翼／灯腹是否有独立运动；棘籽哨冠与根座发力；跃枝起落和恢复；两种织网身体与原有限线／双入口相位。固定生根者不伪造位移需求。

## 两个开发候选

| 对象／实际链 | 影片时间 |
| --- | --- |
| 盾卫候选 `candidate_lure_guard` · 原scene | 00:00.02–00:13.67 |
| 侧风蛾候选 `candidate_crosswind_moth` · 原scene | 00:13.72–00:24.33 |

两个新透明中性母版各自关节驱动，未采用漂移的整套12姿态，不宣称生成12帧动画或正式准入。检查盾卫盾肢与蛾翼根有没有拉伸／折叠／身体重影，hurt退出和死亡是否保持身份。

## Boss：8场景／9组合

下面时间使用257.97秒Boss总览。最后一章追加真实App storm组合，前八章是原场景实验台，不称自然路线。

| 对象／实际链 | 影片时间 |
| --- | --- |
| `clockwork_guardian` · 原Boss场景实验台 | 00:00.02–00:12.30 |
| 鸣铃巡游机 `bellstrider` · 原Boss场景实验台 | 00:12.35–00:29.05 |
| 牧风者scene默认12HP `windkeeper` · 原Boss场景实验台 | 00:29.10–01:02.77 |
| 旧守卫 `thorn_guardian` · 原Boss场景实验台 | 01:02.82–01:21.32 |
| 旧女王 `thorn_queen` · 原Boss场景实验台 | 01:21.37–02:21.37 |
| 根铃守卫v2 `rootbell_guardian_v2` · 原Boss场景实验台 | 02:21.42–02:56.62 |
| 织网女王v2 `thorn_queen_v2` · 原Boss场景实验台 | 02:56.67–03:25.25 |
| 棘冠女王 `thorn_queen_canopy` · 原Boss场景实验台 | 03:25.30–04:00.87 |
| 牧风者正式storm36HP组合 · 真实正式App | 04:01.05–04:17.88 |

R3已在当时源与选定媒体内看过新守卫／女王同族身体、功能胸心可读性及HUD／脚端安全带。根铃守卫该片`bell_counter_committed=0`，因此“返铃反击动作已看到”仍未成立；织网女王结点保留／剪断、所有失败落地及全部阶段打断组合也未穷尽。源事件齐全不能替玩家判断战斗是否好读或好玩。

## 冲锋／俯冲严格留尸补录

| 对象／实际链 | 影片时间 |
| --- | --- |
| 冲锋怪 `plains_charger` · Underworld | 00:00.02–00:11.07 |
| 冲锋怪 `plains_charger` · 原scene | 00:11.12–00:22.18 |

| 对象／实际链 | 影片时间 |
| --- | --- |
| 俯冲怪 `plains_diver` · Underworld | 00:00.02–00:11.10 |
| 俯冲怪 `plains_diver` · 原scene | 00:11.15–00:22.22 |

四链各自末210条post_draw记录的visible、settled、alpha、位置、旋转、缩放和D7均恒定；R3另外实看尾段起／中／末共12张原视频crop。只有这四条按原政策持久留尸；其他物种保留原隐藏、暗色或Boss终态，不能统一要求新增尸体。

## 版本、审查及剩余范围

- 当前生产身体源为`d91b27377c88e039560140deb87e0a67052a716b`；主要Boss与正式片生产身体原源为`67d28da6cbc082bb57ba3477aa2d950760975040`，采证工具源为`b71a87864d3843f8d4e898046224778890349dac`；普通逐怪主片保留其实际`94c95a80d4af831012fe7c1fc55e01abb95a30c1`来源。manifest内原源差异证明和各影片SHA完整保留，不重标旧影片来源。
- 独立审查R3为“ACCEPT：可供用户逐怪审核的候选范围”，没有运行Godot、没有全速看完全部影片或试听原声，没有签用户／真机。R1／R2失败与返工原件保留。
- 当前最新源`d91b27377c88e039560140deb87e0a67052a716b`仅增加保守屏外绘制裁剪，并修正悬荚绳端与不透明荚帽的接合。旧R3结论只属于其绑定源；d91的`forest-depth-region --corpus`专项已实际80图／80图通过，原600秒预算内540.378秒，exit0、0复用，精确干净d91源，报告为`build/verification/harness/20261029T051735.820131Z/report.json`（Harness总墙钟553.226秒）。森林7种已按d91重录，屏外裁剪对可见旧片复用已获R4独审限定ACCEPT；不能借旧source_stable追签新源或声称全CI绿。
- 用户仍需审核同体风格、动作连续性、反馈可读性和战斗趣味；原音轨听审、实体安卓／手柄／低端帧时和全部边角打断策略均单列未验。正式App片、实验台片、物种库存、工程回归和玩家认可分别记账。

制作与状态入口：[规格](../../worklines/enemy_all_02/spec.md)、[库存](roster.json)、[平原卡](../../worklines/enemy_all_02/plains-production-cards.md)、[森林卡](../../worklines/enemy_all_02/forest-production-cards.md)、[Boss卡](../../worklines/enemy_all_02/boss-production-cards.md)。各片完整SHA见manifest；11段MP4已实际HTTP200完整下载、178,500,792字节全部SHA匹配，见[公开下载收据](public-download.json)。

技术实跑与旧CI超时见[验证摘要](validation/summary.json)、[完整原日志／80条轨迹归档](validation/original-validation-artifacts.zip)；独审[R1](review/r1.md)、[R2](review/r2.md)、[R3](review/r3.md)、[R4](review/r4.md)按各自精确源和范围有效。当前PR为[114](https://github.com/zhipijun1996/gunman-rush/pull/114)，保持草稿，不自动合main。

冻结审核包的原docs profile已33／33 fresh通过，0复用／0失败；见[实际报告](validation/docs-profile-report.json)与[33项原日志](validation/docs-profile-logs.zip)。后续公开下载收据／交接账本只补相关静态守门，不冒称再次完整33或full165。
