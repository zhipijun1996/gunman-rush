# ENEMY-FEEDBACK-01 v6 独立审查

**有限技术 ACCEPT；当前命中/爆散视觉候选可交用户评审。整体艺术、玩家最终手感、设备与完整 Integration 仍 UNVERIFIED。** 本轮没有新增玩家命中停顿、镜头、声音、击退或伤害机制，不能把敌方视觉增强写成玩家操作系统改造。

## 身份、合同与冻结源

实现者 `/root`；独立审查者 `/root/feedback_review`。沿用 gameplay-reviewer、animation-vfx、game-quality-gate、animation_vfx_standards 与正式伤害epoch合同；只写本报告和ignored build观察材料，未修改生产或tracked tests。

用户本轮要求：“爆炸和受击的特效可以再夸张一点。增加玩家打击反馈感”。死亡仍沿v5已授权的爆散消失，不回到翻转尸体。v5首候选167的白矩形REJECT及3c的有限改善保留；旧持久尸体保存62/1是已撤销方向，不称已修好保存。音效仍deferred。

候选生产源 **`73556539d4337065eb73537ce2fc2c03d7729c18`**；对照生产源 **`3c5338552b2f7ac275203c4bbf1003e29520a312`**。独立先在clean3c工作树运行ignored同字节observer，记录848源路径无变化，然后切到clean735运行候选与回归，850源路径前后无变化。根仅继续文档工作；不宣称整个workspace始终冻结。source-before/after及source-and-log-audit.json保留。

源码只改两task leaf和新增采证driver/UID。扩大接触扇面、通过方向的短反向笔划和细屑；死亡增加短8向pressure形状、较大断弧及传播。既有接受event/epoch/serial门、MAX_BURSTS=3、.045初始死亡闪/.55 spent、80片上限保留。普通body闪色、shader/素材、Actor/父类死亡计时和可见性、AI、碰撞、伤害、奖励、保存、Camera/Player/audio/time_scale未改。没有用VFX回调反向结算玩法；没有新增每片Node。最大并发上限是代码约束，不能据此签密集战斗或设备帧时预算。

## 独立执行及完整退出

统一输出根：`/workspace/enemy-feedback-01-v4-after/build/enemy-feedback-01/v6-review/`。Godot4.7.2 Standard，Linux，Dummy audio，fixedfps60；GPU为Xvfb1280×720、gl_compatibility、Mesa llvmpipe软件渲染。实际串行执行并读取完整退出及日志marker，结束后已归还engine/CPU/render租约。

| 实际检查 | checks / failures | exit / 证据 |
|---|---|---|
| v5同字节GPU extent | 442 / 0 | 0；baseline-extent.log、baseline-extent/report.json |
| v6同字节GPU extent | 442 / 0 | 0；extent-v6.log、extent-v6/report.json |
| native | 370 / 0 | 0；native.log、native-runtime.json |
| support边界 | 141 / 0 | 0；support.log、support-runtime.json |
| 主GPU | 162 / 0 | 0；pixels.log、pixels/report.json |
| 默认正式App | 62 / 0 | 0；formal.log、formal-runtime.json |
| 反向/斜向真实GPU观察 | 185 / 0 | 0；reverse.log、reverse-diagonal/report.json |

native/support/formal分别实际使用 `bash tools/godot.sh --headless --path . --audio-driver Dummy --fixed-fps 60 --script tests/enemy_feedback_01_{tests,support,formal}.gd`。GPU去掉headless、加gl_compatibility，经 `/workspace/scratch/run_enemy_v6_gpu.py` 管理display。extent精确命令/observer路径与输出见日志和observer-source.json；没有以计划命令充当执行。

随后同候选执行原Harness：`python3 tools/harness.py --check actor-actions --check underworld-damage-feedback --check underworld-formal --check forest-bible-integration-tests --release --jobs 1`。四项fresh passed/exit0/reused=false，整进程exit0，67.099秒。报告 `build/verification/harness/20261022T235600.317029Z/report.json`，marker为2872/0、317/0、96/0（2maps）、54/0。不是146项完整Integration或完整Release。

全部七专项/观察与四Harness日志无SCRIPT ERROR/ERROR/ObjectDB/RID/资源泄漏诊断；四次GPU仅不支持调整VSync的warning，原样保留。原生拒绝/旧epoch/重复、hurt/death暂停/慢时、paused initialize、安装器/卸载、void/aerial/moving-host边界及正式唯一drop/reload均沿原测试运行；没有通过放宽断言或预算取得结果。本轮没有新的运行失败；前轮真实失败保留各自归属。

## 同龄GPU对照：扩大事实与结论边界

同字节observer SHA256 **`72f962b92a0cbcc3e93a14e81d2543af4b149e7197da9e7f4c9954270a478655`**，复制到基线ignored `extent.gd`，没有修改基线生产。两链×两物种×hurt2/6帧、death3/6/12帧，共20对。独立核对全部key、actual age、origin、Canvas、ROI相等；receipt去掉进程局部Actor事件前缀后全部状态相等；每次off/on本身也全状态冻结。两侧均clipped_to_viewport=false、touches_roi_border=false。ROI为128wu，不以裁切画面假造上限。

| Underworld样本 | 实际年龄 | v5→v6半径wu | changed pixels v5→v6 |
|---|---|---|---|
| charger普通命中 | .033333 | 9.518→19.518 | 22→79 |
| diver普通命中 | .033333 | 8.153→18.153 | 29→87 |
| charger普通命中 | .1 | 13.673→20.136 | 8→22 |
| diver普通命中 | .1 | 14.283→20.783 | 12→29 |
| charger死亡 | .05 | 21.401→31.575 | 195→580 |
| diver死亡 | .05 | 23.006→32.478 | 264→645 |
| charger死亡 | .2 | 32.016→35.609 | 116→166 |
| diver死亡 | .2 | 32.572→39.376 | 139→208 |

完整20对见extent-comparison.json。原Atlas链同样实际绘制，不由headless外推；例如原diver死亡.05秒半径35.371→35.371，但像素482→865。原body轮廓可主导早期最远点，因此不能把增幅概括成所有阶段/所有链统一倍数，更不能把changed pixels解释成玩家感受强度。已实际打开六组v5/v6原像素裁片（Underworld hurt/death及两种原Atlas death），见extent-actual-review.png；旧链纹理和UV未见串图或整片白块。

反向观察driver仅在ignored build：reverse-extent.gd，SHA256 **`b7b3e43a51172fce19a1c7399c0e9cba00b5e4df0d7d49adea5b3f0cdb2e30f7`**。两链×两物种各右侧和抬高右侧fixture；只有射击前一次玩家Motor支撑位置设置，斜向使用显式平台，没有修改敌AI/HP或补偿反冲。真实接受方向x约-.9999或-.89..-.90，斜向y约.428..451；同龄visible切换不生成新事件。实际打开八张原像素裁片汇合reverse-actual-review.png，接触位于实际受击侧，扇面/短通过笔划随真实来弹方向变化。此为显式fixture，不称自然路线或全方向穷举。

## 实际影片观看与候选判断

原片 `/workspace/gunman-rush-work/build/enemy-feedback-01/v6/movie/after.mp4`，实际SHA256 **`d32ecd6c97682acc82ba03c8bcdee87ce603211487c8169b9c4c57c0d8096ae5`** 与采集report相等；report记录clean735/source_stable=true。独立比较v5保留trace，1560帧frame/case/local_frame/paused/player_position/player_velocity/enemy_position/enemy_velocity/HP/state严格相等；inputs/shots相等，events仅去掉进程局部Actor前缀后相等。各case仍三个HP提交、一次death、最终210trace帧隐藏。见media/comparison.json，不称raw event_id逐字一致。

审查者实际看了**charger非致死v55–76每一邻帧（.917–1.267s）**、**diver致死v966–1011每一邻帧（16.100–16.850s）**及**v62、186、974、1504原尺寸1280×720整图**。v编号0起始MP4解码帧，不等同physics tick。只生成两段原像素邻帧汇合和四原图，原MP4可重建；没有把汇合图当动画。**未完整正常速度播放、未听音轨、未测实体设备。**

有限专业判断：普通命中具有更长、更清楚的有向接触芒，仍快速回到原身体；致死的短星形峰值、断弧和纹理碎片明显比v5更爆裂，普通hurt与kill的等级差可辨。所看窗口里玩家、HP标记和原场景仍可读，后段正常消失，未见再次爆炸或长时全屏盖光。这是当前孤立消费者样本的候选判断，不外推同时多敌/密集预告遮挡。

新8向pressure本来就是本轮授权的夸张爆炸形状，不能把“星形”本身当技术失败；但它与cyan接触特效仍有较强烟花化/图形化倾向，原早期纹理颗粒排列也仍短暂可见。是否达到用户期待的打击感与画风精细度应由这版实际片确认，不以442项或半径增幅代签。v5白矩形拒绝不追认为通过，亦不声称完整HK手感、重画运动/死亡图集或新增玩家音画控制。

## 最终声明

**已运行的真实接受/epoch/暂停/恢复/唯一掉落/卸载/有界消失，以及两表现链的实际PNG/Atlas绘制范围有限ACCEPT；本版夸张反馈候选可继续交用户。** 完整正常速度操控体验、整体艺术、用户最终手感、Action Studio GUI/自然路线、146项完整Integration和设备性能仍UNVERIFIED，不签任务整体done或可合入。原持久尸体保存失败维持superseded旧方向，不冒称修复。

本报告完成后停止写入；engine/CPU/render租约已归还，原始日志、observer、PNG和失败历史分别保留。
