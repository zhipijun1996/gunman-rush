# PR72后空间黄金样板：只读执行根因审计

基线：`1597db58`，2026-10-16。未改生产代码、未启动子代理。最新用户授权（父线程转达原话）：“允许在限定实验空间内重新设计局部地形几何、平台布局和镜头，让玩法与空间表现相互服务。但保留核心 PlayerMotor、武器与能力规则、资源、RNG、存档等基础契约；所有新路线必须经过真实操作验证。”首黄金独审通过后才同主要资产制作第二个明显不同结构并检查多Seed/最差；连续两轮无实质改善停止。

结论：PR72失败不只是“素材不够好”，也不是Godot只能矩形。**旧Skill保护边界、任务责任/准入图与现有后置表现消费者共同把“整体空间创作”收窄为“已有solid上覆材+背景”。** 最新授权允许局部几何/镜头实验，必须在原机制明确例外及消费者入口，不需要另造质量框架。

| 实证 | 造成的约束 | 最小现有机制修复 |
| --- | --- | --- |
| `.agents/skills/visual-director/SKILL.md:14` 写“能力、物理、生成、资源和相机规则不为画面改动”，`:22`要求“原相机”；art-director`:20,62`、scene-composer`:22,61`多次无条件“不改已验碰撞”。region-generator`:18`在冻结玩法时仅开放表现。 | 本来用于禁止迁就图片/破坏物理的保护，被整体执行时等同于冻结空间几何和镜头；与本轮局部空间实验授权冲突。 | 不删保护：明确核心Motor/输入/能力/资源/RNG/save冻结；**用户明确授权且隔离版本化的黄金空间**可重设局部平台/几何/镜头，必须真实新路线/负例复验。普通贴图任务继续禁止偷改碰撞。 |
| `tools/level_design.py:210–217` optimize设计有region/challenge/encounter/scene，golden却只有level-module/challenge/art；visual-director只在new_region加到design等专业。 | 黄金实现owner缺整体空间和视觉统筹，设计阶段写集只有docs/tests/tools，无法当场执行空间+镜头灰盒。设计与实现交接后容易回到既有模块画面。 | 为本轮显式spatial-golden任务复用原mission：同一交付绑定region+challenge+encounter+scene+visual/art职责；设计仍可只读设计，但真实灰盒需独立有写权限实施任务。不要全部专业无依赖各自产物后再拼。 |
| `tools/level_design.py:248–253` golden/integration已有`scripts/generation/`、`scripts/demo/`、`resources/generation/`、`scenes/`等广泛写路径；`production_loop.py:1366–1369`真实拒绝越界，`:383–396`把task+Skills原文注入Prompt且禁止擅改scope。独立调用`content_plan('优化风铃平原',phase='production')`已核实golden/integration generation/camera目录可写，design不可写。 | **不能捏造“当前route所有下游都无几何写权限”。** 真正缺少的是本任务明确允许哪些几何/镜头消费者、禁止改哪些基础契约以及该次租约对应写集；笼统指向art文件就会被合法守门锁在表现。 | 在原task增加明确空间实验scope与精确写文件（实际布局/组装或实验场景、StageCameraRig或局部相机配置、配套验证、资产）。预检先核writes覆盖这些消费者，授权不靠宽泛`docs/`推断；保留越界守门，不自动扩scope。 |
| `tools/level_design.py:274–278` golden只required_gates G0/G1；`:217`独立review在integration之后；optimize previous顺序让golden stage完成即可进入integration。约束`:289–291`虽说technical不是visual准入，图没有首黄金独审前置任务。 | 技术G1通过后可以扩到第二空间/整合才第一次整体审，创作否定来得太晚。 | 在原任务图golden后、integration/第二空间前接现有gameplay-reviewer只读实景/路线scope审查，要求G2及对应工程证据和明确ACCEPT_SCOPED；RETHINK/DISCARD停后继。第二空间明显不同结构，复用首批主要资产，另审多Seed/最差。仍用G0–G5，不新编号。 |
| `scripts/demo/plains_region_stage.gd:18–27`先assembler.build现成Manifest得到bounds/spawn，`:81–84`才install_visual_layer和scenery；`plains_region_scenery.gd:11–14,30–33,50–59`接收已存在supports/protected_regions，composition在其上组织。DemoApp`:278–292`add stage完成组装后给相机配置player+bounds。 | 这是正式消费者先定空间、后定画面的单向链。纯表现任务只能选择怎么包装现有solid；不是引擎禁改，而是缺少构图反向约束布局的前置接口。 | 在现有生成/组装入口前应用**显式版本化实验布局**（或独立正式DemoApp实验场景），先有玩家路径/落点/空隙/镜头方案，再同步输出实际Manifest/几何/表现锚点。保持原正常入口默认不变；不要在Manifest完成后偷搬碰撞却仍报旧hash。 |
| `scripts/art/plains_creative_slice.gd:51–70`从floor_bounds取固定shore/roof窗口，与既有solid交集；`:113–122`draw_texture_rect_region；`:71–86`按固定home偏移摆切分钟肋sprite。 | 源码本身明确是“覆绘既有静态solid”，顶部矩形硬裁和长直岸不会因新素材消失。上轮真实static_current三窗与最终20秒片已独审RETHINK，记录在上一轮art-independent-review。 | 保留失败候选及默认隔离，不继续用同覆材接口证明“重设计空间”。新黄金先改布局与完整大轮廓，资产按真实边界/尺度匹配；非碰撞视觉可以超出solid但不可伪造站面，端部/转角/根基必须真实合屏。 |
| `docs/creative_direction/windchime_plains.json:23,30`选择“现有RootBell代表岸、AI/敌数/HP不变”，`:39–44`却承诺不复制矩形台和先整体后拆件；`:47`又要求表现不移动碰撞体。 | 总谱主题与上轮执行范围存在内在张力：只能在原joint_space覆材，却要靠它证明大形重构。不是用户草海方向错误。 | 保留用户方向，按最新授权版本化更新**本轮空间实验范围**；区分表现节点禁止动碰撞与布局作者可设计碰撞。总谱/布局SHA变化按原RETHINK影响分析和证据失效机制重绑，禁止改写上轮失败为通过。 |

## 下一轮独立验收边界

首样板必须实际同屏看见：可站入口/安全落点、反向射击带来的正向位移、主题围合/负空间、活敌/机关预警、资源读数及可靠返回。先全屏截图和正常速度连续片，再按当前源真实路线/失败负例验；fixture初始化、正常到达、正式开放分别说明。图漂亮不能替代真实消费者，路线技术通过不能替代整体创作一致性。

未获首样板独审通过前不批准第二空间。通过后第二空间须复用主要资产但明显不同宏观结构（不是翻转/平移同房间），再覆盖多个Seed及最差镜头，不为每Seed新画整屏图、不以整屏专绘冒随机关卡。审查将保留所有旧RETHINK/REWORK及源码边界，不代签用户/真机/完整CI。
