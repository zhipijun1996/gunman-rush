---
name: scene-composer
description: 为程序化地区设计空间轮廓、焦点地标、前中背景、视觉引导和模块拼接，建立实际合屏验收。
---

# scene-composer

## 触发与边界

“场景复制粘贴/构图单一/落点看不见”、新地区空间视觉身份、程序化地形构图与模块拼接时调用 `$scene-composer`。负责空间布局和视觉语义；art-director 总负责风格/素材质量/来源，animation-vfx 负责动画声音特效，不能绕过其黄金母版流程。

## 输入与依赖

地区身份、世界观与情绪、真实空间/路线/镜头、玩家碰撞与视觉尺寸、动作落点/预告/危险边界、目标分辨率/设备、素材 manifest/母版版本/接缝规范、随机变体约束、已有截图与玩家反馈。读取 [Visual Bible](../../../docs/visual_bible.md)、[地形合同](../../../docs/quality/terrain_tile_contract.md)、[内容管线](../../../docs/content_pipeline.md)；主题是《失序之钟》治愈童话中隐藏悲伤，不复制参考游戏资产或具体关卡。

## 阶段流程与交付物

1. G0 填 [SceneComposition](../../../docs/templates/scene_composition.md)：主题、主视觉焦点、环境轮廓、前中背景/视差深度、地标、密疏/留白、引导方向、交互优先级、镜头提前展示。每个空间选具体身份，不只更换背景贴图。
2. 与 region-generator 把结构布局转成多尺度/非规则空间构图候选；与 challenge-choreographer 标出观察平台、危险扫掠、落点及整条动作可见区。功能前景不得遮住唯一合法落点/预告，粒子和动画也列入遮挡检查。
3. 与 art-director 从已认可母版拆分资产系列；写实际尺寸/比例/锚点、地形端头/四边/凸凹角/填充、实体/单向/移动平台、接缝和重叠策略。不得为贴图改已验碰撞，也不能随机重复地标充当视觉多样性。
4. G1–G2 在正式比例镜头搭一组对照黄金合屏，包含角色、敌人、机关、UI、光照、前景与背景；再验证不同模块组合和相位/镜头运动。按疏密和轮廓对比而非 Hash 判断身份。
5. G3 接实际 PlainsRegionScenery/PlainsSetDressing 或目标区域消费者，保留既有随机流与资产 manifest；新地区仅 fixture 时显式标 design_only，不伪称已接正式地区。
6. G4 采集正式分辨率截图、正常速度音画、最差 Seed 和组合矩阵，检查地形接缝、重复焦点、空间轮廓、深度、镜头危险与落点可见；G5 人工审核审美/情绪/手机缩小可读性，认可后才扩产。

## 完成与证据

SceneComposition 卡、空间语义→现有资产/消费者映射、AI 资产系列请求（母版/版本/来源/许可在 art-director 的 metadata）、组合与动态遮挡矩阵、截图/录像和失败索引、同任务十一维记录。资产命名使用稳定系列/层/用途/变体/版本，原图/派生图哈希和可复用范围不得缺失；unknown 来源如实记录。

## 自动验收

执行 V2 validate/analyze（元数据范围）、harness docs/art，触及场景接入加 gameplay；复用真实 GPU 地形/拼接与正式消费者工具。新增规则提供通过例和故意失败例：缺深度声明、重复地标/轮廓、前景遮挡候选、错误接缝与锚点。元数据合格不能证明截图好看；静图不能证明动态预告和动画可读。

## 人工审查与协作

art-director 审风格、AI 系列与黄金合屏；gameplay-reviewer 独立看实际路线的功能可读性；encounter-director 看休息、惊喜、高潮和回程地标；目标设备看缩放、眩光/粒子、遮挡与性能。缺图/声音/设备逐项 unverified，不把概念图代替正式合屏。

## 适用示例

“同一套平原素材摆成草甸/风车高地/钟楼回廊”：通过不同轮廓、焦点、层深和镜头节奏建立身份，不能只变装饰种子；“森林树冠”先用现有验证素材搭技术构图片，明确新资产/创意未准入。

## 设计要求与权威来源

先读 [AGENTS](../../../AGENTS.md)、[current_state](../../../docs/current_state.md)、[handoff](../../../docs/handoff.md)、[V2 真实合同/CLI](../../../docs/level_design_harness_v2.md)。实际参数来自 config/player_tuning.json、config/input_profile.json、运行 Definition 和正式消费者授予点；[动作入口](../../../docs/design/player_actions/README.md) 中规划/候选不是已授予能力。复用 RunManifest、RunRandomStream、PlayerMotor、PlatformingModuleDefinition 和现有 LEVEL FOUNDRY，不改物理、武器规则、资源、保存或随机流以让设计过关。

同 game-quality-gate 共用任务 ID、G0–G5 和 docs/quality/records/<task_id>.json，不重造门槛或质量类型。十一维 design/technical/formal_integration/visual/animation/audio_vfx/gameplay/performance/independent_review/device/player_acceptance 分别记录 passed/failed/unverified/not_applicable（理由）。命令保存版本、退出码、日志；轨迹保存 Seed/Manifest、能力、相位、输入、失败位置和来源哈希。意图不冒充运行，单片不外推整图，AI 不代签用户/设备。

## 准入退出与返工

保留失败证据、发现 ID 和最差 Seed；设计失败回 G0、真实操作失败回 G1、表现失败回 G2、消费者失败回 G3，修复后重跑受影响检查并独立复审。依赖不足 blocked，缺主观/独立审查 review，缺设备 awaiting-device；不能删断言、放宽阈值、无限重抽或用静态结构掩盖失败。

正式准入依 [policy](../../../docs/quality/policy.json) 的所有适用门槛。黄金技术片明确 production_pool=false 和未完成视觉/创意项；Foundry 开发池晋级不等于正式地区准入。本技能文档不提供内容 PASS。
