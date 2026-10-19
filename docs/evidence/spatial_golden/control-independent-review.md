# 空间黄金生产控制独立审查

结论：REJECT（限定新control delta的三项源码缺口），不评价艺术，不签G1/G2实机、完整CI或发布。基线PR72 commit `1597db583a6ade25a469cb9ecb99b5762d6f76db`；本次审查的完整工作树SHA见`control-review-source-sha256.json`。只读生产代码/测试/Skills，未启代理，未跑Godot/全量/录像；按主任务要求暂未执行Python测试，以下明确是源码证据与可复现构造，不冒称实际已运行反例。

## P1 SPATIAL-WRITE-01：quality_record可额外授权core

`production_loop.spatial_experiment_input`构造`permitted = set(ref.allowed_paths) | {task.quality_record, 'docs/tasks.md'}`，只比较task.allowed_paths与此集合。`validate`对quality_record只检查相对路径/无`..`，不限制质量目录或JSON后缀。

因此手工mission可用真实合法experiment绑定，把quality_record设为`scripts/player/player_motor.gd`并把此路径加入allowed_paths；空间lease校验接受，worker随后可先改core。之后quality读取失败不会恢复已改core，也不能把越权写入事后变成未发生。应限制spatial任务quality_record到明确`docs/quality/records/<id>.json`，并确保它不形成核心文件别名；加入预检calls0负例。它不是对trusted worker恶意的猜测，而是“精确写集拒绝core”目前存在直接的结构旁路。

## P1 SPATIAL-DIRECTION-01：设计内总谱来源未绑定

真实against_wind_v1.json的design有direction_path/direction_sha256，然而`load_spatial_experiment`只要求design是非空dict，`spatial_experiment_input`只比region和experiment文件自身SHA，没有比对这两个内部字段与task.creative_direction。改总谱而保留同region旧布局设计仍能生成新mission，不会要求对旧设计RETHINK。

应要求真实设计的direction_path/SHA等于选定总谱绑定（并拒缺字段）；旧总谱/另一路径/错SHA需calls0，合法同源通过。当前测试fixture使用`design={'one_space': True}`，未测试这一来源边界。

## P1 GOLDEN-MEDIA-01：新媒体“硬门槛”只检查自报类型和ID

`check_task_quality`新增visual_admitted要求G2 screenshot/video两kind和独审reviewed_evidence覆盖ID，但不消费任何真实实机capture/录像来源回执、fps/速度或独审实际观看的租约绑定。原`quality.validate_record:123-130`只查文件存在/非空/hash/文件后缀，不解析媒体、也不将其绑定真实Godot producer；reviewer/independent/basis都是质量卡字段，未绑定对应实际review worker。

具体反例构造：任意非空文本分别命名.png/.mp4，写真实hash和完整旧质量字段，再给review填与owner不同的字符串、independent=true、ACCEPT及两个ID，便满足当前新增媒体条件；与真实游戏帧无关。即使有独立loop reviewer，这个附加“视觉独审”条目仍没有与它的身份/媒体观看证据关联。

应复用已有visual_director的真实capture/source/media指纹/原native终态回执，并将独审视看范围与实际不同代理回执及这些媒体字节绑定；不可仅新增另一个自报布尔。现VisualGoldenAdmissionTests完全patch validate_record且媒体没有文件，能证明分支路由但不能证明拒伪媒体。需真实fixture正例与假后缀/概念图代实机/错source/错独审来源等负例。

## 已有效的控制

public route绑定选定direction时，黄金任务现在联合level/challenge/art/visual/scene/encounter/animation，required_gates为G0/G1/G2并设requires_visual_admission；旧content_plan保留原明确G0/G1行为。正常public plan的integration直接依赖golden且启动前重跑其质量与visual admission，卡撤销后会阻断；G1-only标准卡不能直接释放此public integration。恢复也额外核验visual_admission_passed。实验源与direction都进入原host source_inputs，并在worker前后/collector/恢复中复核，实验JSON字节漂移拒绝这一点是有效的。

load_spatial_experiment拒目录/通配符/出界路径/直接symlink及明确core命名；仅为design/golden替换宽泛写集，保留真实spatial JSON。这些保护值得继承，但不能补偿quality_record旁路与设计内direction来源缺口。

## Skills delta与范围

本轮visual/art/scene/game-quality-gate将常规覆材的碰撞冻结与用户明确授权的空间实验区分，允许限定地形/平台/镜头重设并重验，仍冻结Motor/武器能力/资源/RNG/save。共同README要求首黄金G2实机与独审先于第二结构/多Seed；两轮无画面改善与失败母版限制保持。该措辞调整符合最新用户授权，不应退回“任何几何/镜头都不能动”的旧合同。此结论不签任何候选画面准入。

## 修复后第一次复审（保留原REJECT）

复审完整SHA见`control-rereview-source-sha256.json`。SPATIAL-WRITE-01已修：质量卡只能exact docs/quality/records/<task id或合法quality_task_id>.json，并拒绝质量卡与父路径symlink；核心quality_record不能额外授予。SPATIAL-DIRECTION-01已修：route及原lease都核design.direction_path/SHA与选定总谱一致，错源/缺字段calls0。

GOLDEN-MEDIA-01主要缺口已修：复用visual_director.load_capture/validate_review，真实native终态、当前capture sources、route_complete、G2帧/视频同receipt的path/hash、PIL真实PNG校验、ffprobe实际电影streams，以及attestation/card/实际host agent或CLI thread身份与恢复绑定。任意文本改后缀与错source/错review identity现已有真实媒体边界负例。

实际轻量验证（无Godot/全量/GPU）：SpatialLeaseBoundaryTests、NativeVisualMediaAdmissionTests、VisualGoldenAdmissionTests共4 tests / 1.725s / OK（故意坏mp4产生moov atom not found后正确拒绝），3项RoutingTests专项 / 0.188s / OK，均退出0。媒体fixture明确是synthetic native receipt、真实PIL/ffmpeg容器，不是实际Godot画面品质证明。

仍需补齐限定marker的观察覆盖：旧validate_review只要求至少一个known observed_frame，当前golden媒体函数未要求G2选中的screenshots在attestation.observed_frames中，也未要求该实际reviewer明确看过当前电影的正常速度路线。当前正例fixture只有静帧observed_frames，仍让video媒体通过，所以“独审实际正常速度路线后再扩产”的记录边界仍缺。这是观察声明覆盖问题，不要求机器证明人眼观看，也不建议造新框架；补marker限定observed_movie path/hash/normal_speed/route_complete与G2 frame子集后即可复审收口。已告实现者与主任务。

## 最终修复复审：ACCEPT（仅本轮生产control delta）

保留上文原REJECT、原源码SHA及第一次修复结果；最终源码SHA见`control-final-source-sha256.json`，关键文件：

- tools/production_loop.py `8d8fbf4daf84a787a205587b116684d48ce4595ce6c0e04e08aa5af0803ec6a0`
- tools/level_design.py `c357c9bbbe68991661d0b114b18114cf7b095e686688849f29460ff3993c07e6`
- tools/visual_director.py `5c0a29c0b2702f43711b70eff02395122629aa28bd6e24c54aedbc2390a69ed4`
- tests/test_production_loop.py `a046828f076a8c42fab4786e1ed79cd6894d46728862f4734c9cbe1f5e9708ed`
- tests/test_level_design_routing.py `f38c9d07aa74374b4cde6713ae52ebbf63affc7d2301472fae8e2b1693e196a6`

限定golden marker现在还要求：当前G2所用所有截图都在实际attestation.observed_frames，至少两个不同视频index并覆盖该capture采样首尾；observed_movie精确指向同native电影path/hash，normal_speed=true、route_complete=true；review_method与limits必须明确。保留原validate_review的已知真实帧来源与实际host/CLI review identity绑定。抽帧、未完整播放或未听音可诚实写明，门槛不要求伪造全片聆听或声称机器能认证人眼观看。

最终独立运行`python3 tests/test_production_loop.py NativeVisualMediaAdmissionTests`：3 tests / 2.948s / OK，退出0。含真实PNG与ffprobe容器/错源/错review identity、六类attestation负例（缺电影/错电影/非正常速度/不完整路线/单静帧/缺限制）和伪PNG/伪MP4解码拒绝。故意坏MP4输出moov atom not found，按预期被拒，不能忽略为成功媒体。前述空间写集与路由7项轻量验证仍适用于未再变动的对应实现；最后helper只重跑相关3项，未无意义扩大到全量。

三项原P1的修复已满足本轮control验收：不能以quality_record额外授权core，旧方向设计不能绑新总谱，无真实native媒体/观察覆盖/actual独审身份不能释放黄金扩产；正常public pipeline技术G1不能替代G2且integration前重核。该ACCEPT不授予任何样板的实际艺术准入，不签G1/G2真实玩法结果、原生录像真实性之外的商业美感、用户/设备、整区或完整CI。真实画面与路线由另一个像素审查者负责，本代理未看其画面、不修改本轮被审code/Skills delta。
