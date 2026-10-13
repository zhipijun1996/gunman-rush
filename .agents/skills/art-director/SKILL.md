---
name: art-director
description: 新增资产、地区视觉母版或风格精修，以及合屏与来源质量审查。
---

# art-director

## 触发与边界

新增资产、地区视觉母版或风格精修，以及合屏与来源质量审查。 从仓库根目录调用 `$art-director`。使用 [总门槛](../../../docs/development_quality.md)；重要内容由 game-quality-gate 建立一次任务，专业技能补充同一记录，不重复执行共用阶段。

## 输入与依赖

读取 [AGENTS](../../../AGENTS.md)、[实际状态](../../../docs/current_state.md)、[handoff](../../../docs/handoff.md)、[架构](../../../docs/architecture.md)、[验收](../../../docs/acceptance_tests.md) 和相关最新设计。输入用户目标、基线完整 SHA、任务 ID、内容版本、受影响路径、正式消费者、已知失败与前置能力。缺信息先记录 unverified，独立可逆工作继续；重大创意不可伪称用户确认。

## 阶段流程与交付物

G0：读 [Visual Bible](../../../docs/visual_bible.md)、[品质目标](../../../docs/art_quality_target.md) 和世界/地区契约。规格覆盖童话手绘、比例轮廓、线条笔触、材质、统一光照、配色功能色、前中后层、交互/危险/安全语义、角色场景协调、跨地区一致性及母版参考。重大画风方向未获用户认可则 proposed。
G1–G2：先区域黄金合屏样板，再概念设计→母版确认→资产拆解→变体→透明/尺寸/锚点检查→Godot 接入→合屏→质量验收。样板必须带真实玩家、地形、敌人、机关、UI、镜头及危险；概念原画美丽不代表游戏画面合格。动作资产由 animation-vfx 接续同一记录。
模块化地形矩阵：长短平台、左右端头、内外转角、表层/地下填充、厚度、镜像、高低差、连续背景、装饰变化。随机组合检查明显接缝/重复纹理，禁止为了图片改变已验碰撞。
G3：真实正式消费者导入，保持视觉与碰撞独立；校验原尺寸/透明边/脚底枪口锚点、缩放、纹理过滤/内存/绘制预算、背景与角色光照一致。
G4：检查元数据/许可证和运行检查；gameplay-reviewer 看黄金样板、实际随机合屏和连续画面，发现拼贴、母版漂移、材质冲突则退回对应步骤。
G5：用户对实际游戏画面的认可、目标设备缩小可读性/性能分开留证。未认可不宣布定稿；不能反复扩产绕过被拒绝母版。
交付：Asset Specification、黄金合屏、母版与版本谱系、模块组合矩阵、来源记录、运行截图录像、未验清单。

## 设计要求

可变长度/厚度地形须按 [资产管线边界契约](../../../docs/content_pipeline.md) 制作四边、四凸角、四凹角、内部填充及兼容变体；先验证连接口与实体并集的边界选择，再扩展长短素材。不能拉伸整物体或重复端头。

使用 [专用模板](../../../docs/templates/art_asset_specification.md) 写场景/前置、方法、可观察结果和失败条件。复用真实配置/Definition/架构，禁止重复数值默认值、无消费者框架或为通过测试改基础物理。占位仅限明确标注的原型，不能冒充最终内容。

涉及可变形状地形时，执行 [邻接与拼接契约](../../../docs/quality/terrain_tile_contract.md)：枚举局部邻接、不同分块的同图对照、薄结构与孔洞、真实 GPU 与正式合屏分开验收。不能用覆盖率代替美术品质。

## 自动验收

使用 [元数据模板](../../../docs/templates/art_asset_metadata.json)，记录源文件 SHA、工具/模型、提示词或参考母版、处理参数、版本、使用范围、授权状态，保留 assets/manifest.json 消费者。运行 harness art，涉及玩法接入加 gameplay；技术检查不评美感。历史缺失来源如实 unknown，不伪补。 记录实际命令、环境、退出码、日志和版本；计划命令不算执行。执行 [质量检查](../../../tools/quality.py)；静态检查、运行测试、实际宿主调用分别记证据。

## 人工审查

采用 [通用审查方法](../../../docs/quality/review_method.md) 的不变量与对照/变形测试，覆盖实际绘制与正式消费者；用户反馈是回归样本，不是发现问题的唯一列表。

用户先认可黄金合屏再扩产；审查边缘/锚点、尺度层次、统一光线与材质、地形接缝、危险对比和手机缩小辨识。独立原画不替代正式画面。

## 准入退出与返工

按 [policy](../../../docs/quality/policy.json) 的相关 G0–G5 执行。进入一阶段前上一相关阶段通过、输入与消费者明确；退出须专用模板的可证伪判据及对应证据成立。设计失败退 G0，操作/公平失败退 G1，表现失败退 G2，接入/状态失败退 G3；修复后重跑受影响门槛并复审。保留失败原件，不删除测试/降标。依赖阻塞写 blocked，缺审查写 review，缺真机写 awaiting-device。

## 完成与证据

使用 [质量报告](../../../docs/templates/quality_gate_acceptance.md) 和 docs/quality/records/<task_id>.json，逐项记录 design/technical/formal_integration/visual/animation/audio_vfx/gameplay/performance/independent_review/device/player_acceptance。只允许 passed/failed/unverified/not_applicable（有理由）；证据需路径、SHA256、提交/内容版本、观察和来源。技术通过不能宣称完整内容完成；所有适用条件具备才可 done。本技能文档本身不提供任何内容的 PASS 或用户认可。
