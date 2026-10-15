# PLAINS-REDESIGN-Q6-REWORK-01：现有装饰素材构图候选失败

本轮 **FAILED / blocked，不接受 Q6 完成**。两次实际正常 Godot 黄金都已录制；第二次修复了 atlas 景深材质造成的拖影和硬边，但把小石簇放大为建筑侧界仍产生巨型花草，断钟庭院拱脚也缺乏可信根植关系。技术通过不能冲销这些画面失败。没有完成用户要求的四强空间身份、完整美术或趣味验收。

真实请求 `c6bc757ccc64dee4635763d0b00edfb05f17c3905d136852700676c9be1c5096`；基线 `20f9b21d7e092348dd9de146267c46540a88d9cb`。旧 29 调用已封账，本 call 是另外公开登记的最后有限 Q6 轮之第一次；不因此自动扩大资产范围或继续任意摆位。原件见[新证据索引](../evidence/plains_redesign/scene_q6_rework/index.json)，前对照见[原 C2 索引](../evidence/plains_redesign/q6_before/index.json)。历史 Markdown 按 `.md.source` 保存，不改旧快照或其相对上下文。

## 实际设计与改动范围

只改 `PlainsRegionComposition`、`PlainsRegionScenery` 和原 Scene 的 GDScript/Python 观测器。选择真实通往 high 的首个 clock area 作单主庭院；停止每 junction 固定 offset/360 高拱复制。对实际 `creek_discovery.module` 的 controlled ferry 两岸放远侧石肩，并将出口石肩移至能在返回上攀窗口看到的位置。所有对象仍是可盘点的真实 Sprite，记录来源 SHA、实际 atlas、世界边界、预期背景锚点、连接和深度。

没有改物理、资源、单武器能力、RNG、保存、19 driver、Camera/UI/Generator/Definition 或资产原图。两处 scenery 的 bounds/锚点一致只能证明实现与声明相同，不能证明背景有物理承重、视觉上接地或好看。原有四类消费者与冻结旧导航测试都保留，维修区仍是开放小屋前庭，不冒称压缩回廊。

## 真实黄金与自主返工

原 API `level_visual_capture.capture`，root `level-design-v2-baseline`，map1/return/1100ticks 与 map2/growth/2600ticks，`kill_from_bank_v1`、timeout600、LP1/软件 GPU、1280×720/60fps/48k stereo。两组前后均按同参数串行采集，四片都 captured，**终态均 frame_budget_exhausted，仅完整观察片段，不是完整路线目标通过**。

- golden1：真实 clock720/840/960 出现错误 atlas 采样的竖向拖影/硬矩形底边；creek1440 把小石簇变成巨型花草。作者和父任务均据实际像素拒绝。改源前保存两 GD 的完整原字节与 SHA，失败片不改标。
- golden2：去掉不适配 atlas 的旧 distance shader，调小主拱/右肩并移低左肩根部，移动溪谷出口石肩。重新实际录两片，拖影/硬边消失；但 clock720/840 的植被比例仍失真、arch 左脚露在薄木桥下空气中，creek1440/1680/2160 仍像巨型花园。2280 同一石簇确可见，但“可见”不是可信井口回望的美术完成。
- 不进行第三次无依据试摆，不把背景矩形岩填充或假草台拿来补墙，不增敌/改碰撞/缩镜头避开失败。需要真正匹配角色尺度的庭院侧壁与井口石肩资产；[明确资产缺口](../evidence/plains_redesign/scene_q6_rework/asset_gap.md.source)只描述需求，未实际生成新图。

实际查看的是上列 PNG 及 C2 before840/1440/2280；未完整连续播放所有影片、未听完整音轨，实体设备和用户审美/趣味没有认可。正常录制参数和媒体校验不是音画审美通过。

## 可重复的技术事实及边界

四个 before→golden1/2 对照中，真实 Manifest 与初始单武器 CapabilitySnapshot 精确相同；逐 tick 的位置、速度、HP、能量、跳跃/射击计数和关键状态精确相同。原始事件的 PlayerMotor 进程实例 ID 因新增表现节点分配而不同；只对该已观测 owner ID 和其 event/projectile-source 前缀做显式双射规范化，事件 tick、方向、目标、资源、会话、伤害仍逐项相同。原 raw/ID 未改，不能把规范化声称为 raw 字节相同。

原 Scene 完整八路线及全部 59 断言、原十个实际 Node 坏例、十二个收据坏例保留；本轮新增真实重复主拱、锚点位移、错误实际 atlas、前景遮挡四个 Node 反例，以及缺真实实例/伪实际来源两个收据反例。这些只反证客观配置、声明与实例不符、真实高 z 前景遮挡；低对比背景的颜色、比例、假根部由实际像素审查，不凭矩形交叠或 z=-5 自动判美感。

原十项 Harness checks 未删或降标。本候选在完整原 Scene 专项后因已确认的视觉失败停止，不能把计划中的全十项 fresh、独立审查或后续设备事项写成已通过。旧所有原十项通过和失败历史各自保留其 source，不能改标当前。

## 状态与下一步

本卡可记录有限 G0 设计合同、G1 技术证据；G2/visual 明确 failed。G3/G4/G5、正式品质准入、整区趣味、实体设备与玩家认可未验；整体 verdict 必须 REJECT / content_complete=false，不写 ready_for_review。

当前失败源码留作可重建候选，未自行回滚覆盖。父任务将在原 controller 确认 blocked 后决定正式表现恢复或另行登记资产黄金任务；只有真实新 lease 明列资产路径/元数据/工具预算才可生产。现有素材风格获认可不等于巨大装饰的新合屏获认可；不得用增加抽象层或测试数替代资产与构图工作。
