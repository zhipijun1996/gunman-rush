# 随机场所候选：尚未艺术准入

任务 `PLAINS-PLACES-01`，PR82 为基线。先看[当前检查点](checkpoint.md)与[独立源画审查](independent-01.md)。这是一项真实制作实验，不是已经验证的精美随机地区配方。P1仍只是用户偏好方向。

实际入口：`tools/plains_places_preview.gd`；原 `DemoApp`、控制器、Motor、资源、敌人与HUD继续消费候选。`tools/plains_places_capture.gd` 沿原严格捕获生命周期记录正常速度电影；`tests/plains_places_trace.gd` 沿原输入驱动逐点落稳，不赋角色位置。

制作链：完整共同绘制的顶—肩—侧—底原图 → 实测站面及侧缘、限定等比尺度 → 局部场所配方 → 合法端口重选 → 世界坐标编译 → 整体景层与真实相机 → 实机审查。不是先任意生成矩形，再把素材拉到几何上。旧PR82薄肩带/独立侧带/透明端退出已停止，不作为此方法的步骤。

实际合同与消费者：

| 层级 | 数据与执行责任 |
| --- | --- |
| 艺术语言 | P1候选母版、原PNG、prompt和reference SHA；未代签用户认可 |
| 宏观编排 | `PlainsPlacePlan` 使用独立随机流排列三场所，记录采样/拒绝及连接；Seed必须实际改变排列或连接 |
| 场所 | `places_v1.json` 局部几何、目的、端口、站位、路线、围合及层锚；不是矩形ID |
| 玩法几何 | 同一编译结果的solid/surface/真实桥踏面；原assembler实例化，renderer不写碰撞 |
| 美术实例 | `PlainsPlaceComposer` 原图完整等比变换、来源SHA和锚点；不把整屏图烘焙成背景 |
| 全图协调 | 一个世界远景/地标、共同视差参考、场所中景锚反补偿；连续相机无逐场所重置 |

硬约束来自实际源尺寸/SHA、限定scale、端口间隙/落点与真实支撑；不能表达的候选拒绝，有限重试失败返回错误。围合、焦点与密疏是构图意图，仍需实机看图；局部中景与对象位置可在合同允许范围创作，不能据元数据签美感。

快速工程入口：`python3 tools/run_plains_places_tests.py`（真实原生编译/复现/拒绝反例）；`python3 -m unittest discover -s tests -p test_plains_places_capture.py`（证据准入反例，非玩法/艺术）。捕获沿 `python3 tools/visual_director.py capture --help`，选新capture脚本。正常完整路线通过后交不同作者看原尺寸实机与运动抽帧；三个原型艺术未成立不扩随机电影或正式池。原PR82失败与原回归不覆盖、不删。

恢复：同branch当前HEAD、PNG/record/profile、Seed与Manifest、实际capture回执齐备后继续。实际进度与缺陷以质量卡和后续原生独审为准，route只生成现有Harness计划。
