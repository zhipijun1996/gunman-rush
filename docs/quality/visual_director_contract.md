# Visual Director：真实画面证据适配器

`tools/visual_director.py` 复用原 `level_formal_capture.gd → DemoApp → PlainsRegionStage`、输入策略、PlayerMotor、真实敌人/资源/相机，以及 `harness.py → production_loop.py`。它不是另一套质量门槛，不把可计算候选、AI审美与玩家认可混为一谈。

## 实际入口

```sh
python3 tools/visual_director.py capture --seed level-design-v2-baseline --map-index 2 --strategy growth --encounter-policy kill_from_bank_v1 --max-ticks 6000 --output build/visual_director/before
python3 tools/visual_director.py inspect --capture build/visual_director/before/visual_capture.json --output build/visual_director/before_diagnostic.json
python3 tools/visual_director.py compare --before build/visual_director/before/visual_capture.json --after build/visual_director/after/visual_capture.json --output build/visual_director/comparison.json
python3 tools/visual_director.py route --request '优化风铃平原溪井黄金场景美术' --task-id visual-creek --quality-record docs/quality/records/visual-creek-golden.json --allowed-path assets/ --allowed-path scripts/art/ --allowed-path resources/art/ --allowed-path docs/ --allowed-path tools/ --allowed-path tests/ --output build/visual_director/mission.json
python3 tools/visual_director.py run --mission build/visual_director/mission.json --evidence-dir build/visual_director/host --execute --worker-mode host
```

`run` 只转交现有 Harness；`route` 只是任务合同，不是模型执行。host 模式必须有真实活跃 Codex 宿主接租约、交给实际不同的实施/只读审查代理；裸 shell 无宿主会按原预算阻塞。任务 ID、质量记录及 allowed_paths 必须在实施前登记；黄金记录 task_id 对应生成的 `<task-id>-golden`。原 G0–G5、十一维、独立审查和完整内容准入继续适用。新专项单测不是美术/实机通过；黄金技术阶段仅 G0/G1，另运行原 art-art 与 capture-tests，并必须提供真实同条件画面。G2实际合屏/独立像素审查及完整G5不能由本技术stage代签。`route --phase audit|golden|review` 可仅生成一个实际专业任务，单phase时 task_id 保持原值，适合复用已登记记录及精确allowed_paths。

## 捕获合同 v1

新输出只能写新的 `build/` 路径，失败不会覆盖。`visual_capture.json` 记录实际 request、完整原生 command、源前后 SHA（包含位图）、原生进程结果、日志、原生完整轨迹、实际 MP4、帧及媒体参数。`capture_process=passed` 只说明采集完整；`route_policy_failed` 仍是路线失败，不改成通关。

不在运行中调用 `get_image/save_png`；原真实驱动不传 frame-dir，Godot 完整 `--write-movie` 后才由 ffmpeg 抽取 PNG。`video_frame_index_zero_based` 与 `video_time_seconds` 是电影帧索引/时间，**不是**物理 tick。1280×720、60FPS、48k立体声、软件 GPU/单线程录制不是实体手机性能测试。禁止同时运行重型原生回归或另一部录像；录制期间冻结真实运行源和实际 producer。

`load_capture` 重新核验当前留存字节、原生完成标记、engine banner、完整policy/core/runtime inventory、无传送/注资源/禁敌、真实能力/Manifest、source前后、原生命令、媒体/抽帧元数据。Hash 是本地来源一致性，不是外部身份认证或画面优秀证明。生成后签名者伪造整套记录不是本工具能够密码学排除的威胁。

## 仅后处理失败的恢复

当原生 Godot 确实 passed、原生完整轨迹/原命令/原engine及 source-before/after 一致，而 adapter 或媒体后处理失败时，可以运行：

```sh
python3 tools/visual_director.py finalize-existing --original-receipt build/visual_director/before/visual_capture.json --output build/visual_director/before_finalized
```

仅在**新目录**重验原始完整原生合同、从保留原AVI编码/抽帧，绝不重跑引擎、不改变动作或源、不覆盖旧failed receipt/AVI。新receipt明确绑定旧failed receipt SHA、原错误、原状态、实际adapter及耗时。失败/超时的原生过程、源漂移、缺文件或被改写证据都不能获救。原GDScript只hash代码/资源JSON，不hash PNG；本工具向原policy validator传严格原source合同投影，全部位图仍独立保留并冻结在前后源快照，不用19driver/133core小投影冒充完整runtime来源。

## 诊断和审查

`inspect`/`analyze` 输出原生实际 scenery Node/纹理/AtlasRegion/缩放/landmark、逐tick相机和角色轨迹、实际电影和帧引用。旧原生观察器未采集 z_index、透明度、精确世界bounds、锚点连接或视差，工具明确保留 observation_gaps，**不根据文件名或图片尺寸猜出遮挡/悬空**。

新场景实际只读观察器 `scripts/art/plains_visual_space.gd` 仅在显式命令参数存在时写文件。`capture --composition` 添加唯一的 `--visual-composition-output=res://build/.../composition_raw.json`，原生完成后消费 `artifact_kind=actual_scene_composition_measurements` 原件，验证observer SHA在冻结源中，并生成绑定原raw SHA及对应native capture SHA的 `composition_observation.json`。`inspect` 自动消费此记录；缺raw明确未验，旧baseline无此参数继续有效。节点为最后一次真实测量，samples保留初始/约120物理帧/退出的实际相机及变换，不能冒称每tick全覆盖。初轮只有一个环境layer时，景深未观测诊断必须保留。

也可用 `--composition-observation FILE` 接收上述已绑定原件的记录，手填design JSON、错raw SHA、改动测量值、未冻结observer均拒绝：

- `artifact_kind=actual_scene_composition_observation`；`capture_sha256` 必须等于对应原生轨迹。
- `observer={path,sha256}` 必须在该次真实源快照中。
- `raw_measurements={path,sha256}` 指向实际引擎原件，`samples[]` 非空并原样保留，适配器不能修改实测nodes/保护区。
- `nodes[]`：唯一 `node_path`、`world_bounds=[x,y,w,h]`、`layer`（extreme_far/far/middle/gameplay/near/atmosphere）、`semantic`、`attachment_node_path`，可选 `spatial_use` 与 `asset_family.intended_use`。
- `protected_world_bounds[]`：`id` 与实际测得 `bounds`，不得把设计意图冒充运行观测。

检查输出可证伪候选：缺连接记录、连接不存在、资产空间用途与家族合同不符、前景AABB与保护区相交、景深职责未观测。AABB相交不是像素实际遮挡；缺锚点记录不是物件一定悬空。候选必须由实际帧确认，并交给责任 Skill 修复。本轮实际消费者为只读场景观察器→capture绑定→inspect通用候选；生产日志/真实capture必须另证它实际执行，单测与手填设计JSON不等于实机测量。

`--review FILE` 接收独立审查原件：`reviewer`、`scope=observed_actual_game_pixels`、非空 `observed_frames[]`（与该捕获实际帧 path/SHA/frame-index 完全匹配）、`verdict=ACCEPT|REJECT|UNVERIFIED`、`findings[]`。空审查、其他概念图和错Hash拒绝。工具不能判断审查者是否真的注意看过画面；完成声明还须关联真实多模态查看/连续录像审查记录，不能仅填写此JSON。

## 对照边界

`compare` 要求两侧各自源冻结/原生证据有效，且seed/map/strategy/phase/max_ticks/encounter、engine、软件渲染参数、真实初始能力、driver/core和完整生成Manifest/初始RunManifest一致；保留两侧实际源差异供人工审计。新源的装饰/表现代码可以不同，不能用源码不同否定必要美术升级，也不能用两个Hash不同证明画面提升。轨迹可能分歧；不宣称逐像素配准、整条路线通关、真人操作或美术优越。

## 失败、返工和验证

每次保留失败进程/命令/源/日志/电影；读取失败receipt不能转换为成功。视觉缺陷返工包定位 seed/map、观察帧时间、实际Node/资产、责任Skill、候选/客观事实/审美判断、修复假设和对照条件。模型/资产调用次数、耗时、退回轮次由原 production_loop/任务账本记录，工具不伪造 worker 或新建无限循环。连续两轮无实质画面进展停止，保留独立 REJECT 与未验用户/设备项。

`python3 tests/test_visual_director.py` 为明确标识的合成反例，检查源漂移、失败进程、空轨迹、错Hash、概念图误当实机、错frame/time、语义/根/前景候选及对照条件。**这些不是 Godot、PlayerMotor、真实电影或审美证据。**旧透明边缘问题继续遵守资产家族冻结合同：alpha>0 与可见alpha阈值是不同测量，不把极低alpha噪点当已证实GPU光晕，不降低旧合同以追认失败。
