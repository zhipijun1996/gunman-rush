# ENEMY-FEEDBACK-01 · v6 更强受击与爆裂

用户继续要求“爆炸和受击的特效可以再夸张一点。增加玩家打击反馈感”。本轮沿animation-vfx / game-quality-gate，只增强两个现有任务leaf；当前运行源73556539d4337065eb73537ce2fc2c03d7729c18，前版真实运行源3c5338552b2f7ac275203c4bbf1003e29520a312。仍仅plains_charger/plains_diver，EnemyPresentation与UnderworldEnemy两链分别复用。

## 视觉节拍与所有权

普通已接受命中：保留批准的0.12秒body flash和原hurt动作时钟；3短芒改5个方向尖芒，主芒15→31wu，并增加16wu穿出短芒；细尾屑8→12，速度92–162→145–235wu/s，先亮后散。致死接触相应更强，主芒20→42wu、细屑12→18。两者持续时间仍0.26/0.42秒，最多3并发burst；不堆厚方块或持续辉光。

死亡叶：保留0.045秒当前体型交接、原材质渐尖纹理片及正确Atlas UV。短8尖压力轮廓在0.085秒内收束，三段断弧22/25→38/43wu，纹理片速度62–110→98–168wu/s，细尾16→24；最后仍在0.55模拟秒前spent/hidden。地面/空中保留原材质、身体轮廓及空中略快差异。

这里只通过敌方正式接受事件增强玩家看见的命中回馈。没有新增玩家动画、镜头抖动、hitstop或音效接口；没有修改Actor/Definition/父类死亡计时与可见性、AI、碰撞、HP/击退、资源、奖励、Boss或共享材质。死亡/掉落/epoch/恢复/卸载沿原收据门，不另建系统。音效继续按用户之前指示暂缓；完整运动帧、正式整体美术/手感仍欠缺。

## 采证与范围

新真实MovieMaker原片约26秒、1280×720/60fps/原立体声音轨，6次正式Router弹体HP提交、2次死亡；每物种最后210帧死亡叶不可见，开始后确有接受演出。冻结源source_stable=true；与v5相同1560玩法投影及实际输入/shot/HP事件投影完全相等。只新视觉变化，原事件ID可能因进程不同而变，不声称JSON逐字节相等。显式Courier/简单地面fixture，不是正式关卡美术黄金、自然路线或设备性能。

[14秒新版](movies/after.mp4) · [20秒v5/v6对照](movies/comparison.mp4)，各物种连续片段、原速/音轨；完整新片、gzip事件、实际ffmpeg/probe/SHA在movies。没有插帧/慢放或静图冒充连续游戏。

实际三次剪辑包装失败均保留：concat时间基使avg_frame_rate不为严格60；-r与passthrough参数矛盾；仅修时间基仍留下末包0时长。最终在既有精确1/60帧格上采用CFR赋正常末包时长，严格60/1、840/1200原始帧数均通过，区间/原速/音轨保持。失败原件留build/.../package-{first,second,third}-rejected，完整失败回执和实际修订命令见movies。

独立技术/像素/视觉判定与未验范围见[review](review.md)。完整受影响Integration、正式视觉消费者、完整运动帧、整体美术与用户/设备仍未签，保持草稿不合main；原v4存档失败是因v5新消失合同被替代，没有被修复。中央任务文件仍由总控持有。

## 当前同条件像素事实

原字节相同的新观察器在3c基线与735新版各442/0，共20对两物种×两链×受击2/6帧、死亡3/6/12帧；actual age/origin/canvas/ROI严格相等，双方均未裁切。实际受击可见半径比的中位数约1.76；死亡差分像素量比中位数约1.69。初始身体交接的部分Atlas样本半径仍由原身体轮廓主导，不声称每个时刻/每条链统一放大倍数；这是空间/像素事实，不代表“好玩”分数。

[精确运行源包](runtime-source.bundle)依赖公开v5提交0eef179073c239592a310dd68d02e03e52d08743，保实际735运行源；manifest记录完整SHA/树/大小。Git只读fetch后核对同tree软对齐published parent，已保留本地v5archive分支，没有覆盖工作源码或强推。恢复：已有0eef179的克隆运行`git fetch <bundle路径> HEAD`后`git checkout --detach 73556539d4337065eb73537ce2fc2c03d7729c18`。发布提交元数据可能不同，最终tree与本地交付逐项核对。

最终短片实际探测：after.mp4为14.000000秒/840帧/60/1；comparison.mp4为20.000000秒/1200帧/60/1，均带48kHz双声道原音轨（编码保留），输入全字节前后不变。声音未重制、未由本线签听感。

## 当前独立回归与归档

在干净735工作树新跑native370/0、support141/0、GPU162/0、正式默认App62/0；同观察器v5/v6各442/0，另反向/斜向真弹样本185/0。原四Harness fresh：actor-actions2872/0、underworld-damage-feedback317/0、underworld-formal96/0、forest-bible-integration54/0，全部exit0。source-and-log-audit记录850份当前代码/测试/配置/资产源前后未变（基线848份）；全部日志读取，无ERROR/退出泄漏，GPU仅VSync提示。它不是全仓库文档/媒体snapshot或实体设备性能。

independent保留原日志/退出码/源清单/观察器/报告，extent-comparison为独立派生比较；gpu-observations.tar.gz保留完整已完成的两版extent、reverse-diagonal与当前GPU collector输出及其Godot import侧文件，逐成员大小/SHA在MANIFEST，已全成员读回验证。解包路径v6-review对应原build/enemy-feedback-01/v6-review；v5-pixels是未改动的既有GPU采集器目录/schema名，本次真实运行源735，不能因其名字误称旧像素。四Harness归档为选定报告/日志，不声称包含所有辅助历史。

media四张全尺寸帧直接取新原片：hit-ground=video62、kill-ground=186、kill-ground-tail=190、kill-diver=974。静图只定位细节，连续正常速度短片见movies。完整旧失败继续留v4/v5；本轮没有覆盖它们或把旧结果升签成当前全量通过。

原wrapper日志末尾空行真实触发diff空白检查；4份完整wrapper日志以wrapper-logs.tar.gz保留原字节并逐份读回验证，避免清洗原生日志。各正式native/GPU日志及退出码仍直接归档。

独审有限技术ACCEPT，确认所采命中更清楚、死亡层次更爆裂，当前候选可交用户；仍指出短星形与既有cyan接触有图形化倾向、早期碎片排列可短暂可见，不签最终艺术/手感。完整原尺寸邻帧、反向诊断可由原片/逐项PNG重建；审查者未完整常速播放或听音轨。

最终只选定原Harness docs检查fresh passed（exit0），不声称docs全profile；check_quality.py仍exit1，原因为中央ENEMY-FEEDBACK-01索引planned与本线review不一致，归总控同步，本线不改中央文件。单卡一致性errors=[]，整体仍REJECT，保留完整Integration与艺术/用户/设备阻断。development-plan保留未知依赖保守升级的原计划；本轮已执行反馈专项与四原消费者，计划不冒称完整执行。
