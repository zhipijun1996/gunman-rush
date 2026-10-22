# ENEMY-FEEDBACK-01 v5 独立审查

## 167ff993 首候选：技术有限 ACCEPT，视觉 REJECT / REWORK

实现者 `/root`，独立审查者 `/root/feedback_review`。按 gameplay-reviewer、review_method 审源码、消费者、状态×时间×epoch、GPU及原影片。审查者只写本报告/自己的build输出，不写生产或测试。reviewed_commit 为 **`167ff993d446556936d503b76a271706830081ca`**；工作树 `/workspace/enemy-feedback-01-v4-after` 当时clean，848个生产脚本/任务测试/驱动SHA运行前后变化0。只是该范围的冻结，不称后续整个workspace不变。

用户原话见 user-feedback.json：“死亡只是反过来，没有重新绘制。或者增加爆炸效果消失吧。”本轮选择用户提供的爆散消失选项，两对象仍为plains_charger/plains_diver。旧持久尸体要求只在这两个样本上superseded；v3/v4正式moving-support精确恢复62/1失败保留，不改称保存已修复。音效继续deferred，新死亡画帧不作为这次替代方案的前置。

### 源码与测试合同

复用同名EnemyFeedback01Remains叶，改为.045秒致死闪、原皮肤纹理切片和短断弧/细屑、最迟.55秒spent隐藏。删除terrain/support/尸体旋转依赖，未另造并行死亡系统。旧EnemyPresentation与UnderworldEnemy继承链仍各自接入。Actor/父类clock/visible/modulate、AI、碰撞、伤害、奖励、正式场景与保存schema未改。

只由现有accepted lethal receipt开始：Damageable.damaged与sample event_id/epoch/serial匹配，terminal/death_active且_begun未消费；initialize dead直接spent，不再capture/burst/drop。pause/slowtime沿原delta，host退出dispose断连并清理Callable/碎片。共享非致死闪和v4亮材质未修改。新测试将尸体支撑合同换成消失合同是用户显式变更，不是删除严格保存断言以追认旧版本通过。

GPU隔离death leaf的visibility channel测取消/消失，捕获后恢复mask/layer；没有清生产globalFX。它只能证明本叶取消，不证明全场所有接触特效立即消失。作者首GPU162/2因暂停cyan混入判据而失败的旧原件保留gpu-first-rejected.tar.gz，不追签成生产修复。

### 独立引擎执行

原件位于该工作树 `build/enemy-feedback-01/v5-review/`，含四logs/exit、runtime、GPU PNG/report、source-before.json与source-and-log-audit.json。Godot4.7.2 Standard、Linux、Dummy audio、fixedfps60；GPU为Xvfb1280×720、gl_compatibility、Mesa llvmpipe，不是实体设备。

native/support/formal使用 `bash tools/godot.sh --headless --path . --audio-driver Dummy --fixed-fps 60 --script tests/enemy_feedback_01_{tests,support,formal}.gd` 分别实际执行；GPU去掉headless并用gl_compatibility及pixels.gd，命令在独立回执。

| 实际顺序 | checks / failures | 完整退出 |
|---|---|---|
| native | 370 / 0 | 0 |
| support边界 | 141 / 0 | 0 |
| GPU | 162 / 0 | 0 |
| 正式App | 62 / 0 | 0 |

native覆盖两对象×两继承链、实际Router弹体、拒绝/旧epoch/重复、暂停/慢时、初始化/安装器替换与释放；support六例为两链各void/aerial/moving-host，均真实弹体终态及旧快照静默spent，不认证旧支撑保存。默认App实际生成对象、正式掉落ledger和同图reload通过新合同：不重播死亡、不重复drop、saved-dead缺席。不是自然路线。

GPU实际致死后早期可见像素charger509/diver679，暂停前后相同；burst扩展仍有444/576像素；自然结束及暂停中epoch取消均spent、该叶可见像素0，旧impact样本无新事件。没有把visibility-only捕获叫完整场景美术通过。

额外独立执行原四项Harness：`python3 tools/harness.py --check actor-actions --check underworld-damage-feedback --check underworld-formal --check forest-bible-integration-tests --release --jobs 1`。四项fresh passed/exit0/reused=false，整进程exit0。报告 `build/verification/harness/20261022T190459.098408Z/report.json`。完整marker分别2872/0、317/0、96/0（2maps）、54/0。所有四专项/四Harness日志逐项审完，未见SCRIPT ERROR/ERROR/ObjectDB/RID/资源泄漏诊断；GPU仅一条不支持调整VSync的warning。全部完成后已归还engine租约。

这些是Development有限回归；不是146项完整Integration或Release完成，也不覆盖Action Studio实际可视、设备、全运动图集或用户认可。

### 实际影片与视觉失败 EF05-R1

实际原片 `build/enemy-feedback-01/death-burst-v5/after.mp4`，SHA256 **`1f2d766352f5e9e63c9ce7edcf30c385d5d2a36fb95a8b3209cca676719e839d`**，report记录clean167/source_stable=true。真实6次HP提交、2次death；trace每case最后210帧隐藏，accepted_death_visual_seen=true。

独立比较保留的v4 trace，1560帧frame/case/local_frame/paused/player_position/player_velocity/enemy_position/enemy_velocity/HP/state严格相同，inputs/shots相同；events去掉进程局部Actor前缀后相同，session/shot及其他字段保留。见media/comparison-v4-v5.json，不称raw event_id逐字一致。

实际观看MP4解码的**charger v179–224逐邻帧（2.983–3.733s）、diver v966–1011逐邻帧（16.100–16.850s）**，另打开原尺寸1280×720全图v188、972、990、1504。v编号0起始，不与trace frame混同。media/selection.json及charger-death.png/diver-death.png保留；未完整正常速度播放、未听音轨、未测设备，不假称完整HK手感。

**EF05-R1 / animation-vfx / 视觉REJECT，需REWORK。** 早期flash到爆散时，原图出现清楚的横竖网格缝，随后白金矩形块沿圆形包络散开。charger v185–190、diver v972–977连续可见，尤其原尺寸v188/v972呈拼片/切格感。它确实不是翻转尸体，也实现了消失，但未消除粗块感；技术162/0不能代签这段视觉。

后段碎片收束并确实无尸体，原尺寸v1504空场与trace一致；未见此范围第二次死亡。短断弧本身属于这次用户授权爆炸方向，不能因旧v3曾拒环就自动判越界；批评的是实际矩形拼片。建议在同一叶/片数预算内改善碎片轮廓与致死闪后原材质回归，再以冻结新片复审，不能以新色/速度数值代签消除方格。

首候选结论：**已运行工程合同有限ACCEPT；EF05-R1使视觉候选REJECT/REWORK。** 原持久尸体保存问题属于superseded旧方向而非本轮未修复阻断。后续修订须新源与实际影片，再追加本报告；167原件与结论保留。

## 3c533855 修订复审：有限技术 ACCEPT，候选可交用户

最新源 **`3c5338552b2f7ac275203c4bbf1003e29520a312`**。只有原死亡leaf变化：Atlas片段UV显式映射到原atlas.region；同80片上限内改为渐尖不规则五边片、初始尺寸.72；仅死亡leaf的flash在.08秒内退回原材质。普通受击shader/时长、事件与生命周期合同不变，没有编辑共享Actor/父类/正式场景。

首候选167的视觉REJECT与原片保留。本审查者先打开修订片v188/192/972/976/990原尺寸，确认有实质改善后才继续以下独立引擎检查，不因需要收尾而把原候选改签通过。

### 新源完整退出与旧Atlas分支

另存 `build/enemy-feedback-01/v5-refine-review/`，没有覆盖167轮。独立依次重跑native **370/0**、support **141/0**、GPU **162/0**、formal **62/0**，四进程exit0。

原主GPU只覆盖Underworld PNG，不能用headless370外推新Atlas手工UV正确。总控明确追加授权后，审查者在ignored build内编写独立只读观察driver **old-atlas-pixels.gd**，SHA256 **`532bc387e72075ead79646059265d05ad911ddf43223eb7716c5a1ea34618171`**。它extends既有native脚本，以`setup(path,false)`分别建立两种实际原链消费者，各用三发Router弹体造成真实HP终态；没有直接调用反馈，也没有修改tracked tests/生产。使用同GPU参数实际运行，**32 checks/0 failures，exit0**。

driver在实际leaf的独立render channel捕获early、自然过程到age=.116667的fragment、自然过程到spent=.55后的ended各一张原尺寸PNG。记录实际分支：charger为beetle.png atlas1536×1024，region(56,111,413,323)；diver为actors.png atlas1536×1024，region(935,570,580,445)，uv_origin与region一致。early有1429/1342像素；fragment确有原材质细片，ended均0。实际打开六阶段原像素裁片和两张1280×720 fragment全图，未见整atlas串图、错误图格或大白块。这里检验的是该两个真实Atlas样本，不外推任意margin/嵌套Atlas。driver/receipt/report/六PNG在old-atlas-pixels目录及其同级，可复现。

随后同一新源再次fresh运行原四Harness，四项passed/exit0/reused=false，整进程exit0、68.865秒。报告 `build/verification/harness/20261022T191336.037344Z/report.json`，完整marker仍为2872/0、317/0、96/0（2maps）、54/0。全部专项、补充GPU及Harness的完整退出日志均审计，无SCRIPT ERROR/ERROR/ObjectDB/RID/资源泄漏诊断；两次GPU仅VSyncwarning。前后848源路径hash变化0，审计为source-and-log-audit.json。临时driver在ignored build，不冒称tracked生产新提交。全部进程结束后已归还engine租约。

### 修订影片实际观看与EF05-R1的处理

新原片 `build/enemy-feedback-01/death-burst-v5-refined/after.mp4`，实际SHA256 **`18d14745a67582cfb58f6338b8c055286a7691a0bd4727f5b4b0a8eac7c1688a`**，采集报告归属clean3c/source_stable。独立重新比较167/3c两trace：1560玩法投影字段严格相同，inputs/shots相同，events去掉进程局部Actor前缀后相同；各case仍三个HP提交、一次death、最后210trace帧隐藏。见media/comparison.json，不把raw event_id当逐字相等。

实际查看新版**charger v179–224每一邻帧、diver v966–1011每一邻帧**，覆盖命中前、短闪、纹理碎片扩散与尾段消失；另打开v188/192/972/976/990和v1504原尺寸全图。media/charger-death.png、diver-death.png、ended-full.png为未缩放原像素查看材料，非静图动画。没有完整正常速度播放/听音，也没有把解码的其他帧写成已看。

**专业判断：有实质改善，可以继续交当前房间候选。** 原167的连续白色矩形拼板与横竖缝显著减轻，换成较小尖角碎片，铜/青原材质更早回来；未再转原图充当尸体，burst之后确实消失。早期仍短暂可见规则颗粒排列，短断弧和既有cyan接触效果仍明显；不能称完全没有分格/礼花感，更不能把此判断升级为用户认可或HK完整手感。

EF05-R1记录为**原候选保留REJECT，修订后大白矩形拼板问题在所看样本有实质缓解，允许继续用户评审**，没有追认167，也不以新五边形的数学定义签整段美术完成。新源的真实接受/epoch/暂停/初始化/唯一掉落/卸载/有界消失，以及两继承链PNG/Atlas分支的已运行技术范围有限ACCEPT；视觉最终认可、完整正常速度体验/正式美术合屏、Action Studio实际GUI、146项完整Integration、设备仍UNVERIFIED，不宣称全任务done或可合入。

本次到此停止写报告，供交付文档冻结；新旧原件/测试来源各自保留。
