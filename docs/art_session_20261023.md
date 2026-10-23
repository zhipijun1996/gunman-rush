# 本会话美术修改归整（2026-10-23）

任务`ART-SESSION-CLOSEOUT-09`：整理与skills经验回流，只有文档/skill变更，不重改游戏。源码分支`art/formal-fine-depth`，会话基线`e9ab0e0743466b8983e34cc7de17bab1abf9d53a`，上轮完整交付head`42f673c27d94926df2517d9c2d5e783fb153f7a6`，最后运行修改源`6befe56b8802ac2472264b866deac1d7efdf649f`。提交与推送以当前Git/远端准确HEAD为准；未合main、未新建会自动跑Integration的PR。

本会话前8轮17笔提交全部是当前分支祖先，包含早期实验、被替代实现、正式资源、来源许可、采集工具、失败与限定评审。相对基线442文件变化（含大量证据），不把实验目录存在当作仍被正式消费。此次不压缩/改写历史、不删除旧母版或许可。

## 轮次与结果

| 轮次 | 主要内容与最终处理 | 实现源与原证据 |
| --- | --- | --- |
| LIGHT-STUDY-01 | 光色三个实验方向；仅Lab，不作正式定稿 | [`35a9cd8`](https://github.com/zhipijun1996/gunman-rush/blob/35a9cd8e0ff1b2a6eb0b8f55e3fca9cefe3302f5/docs/evidence/light_study_01/README.md) |
| PIXEL-LIGHT-STUDY-02 | 固定2wu像素对齐、局部暖光/遮光；低粒度损失细节，后续被细粒度选择替代 | [`0c1d1e5`](https://github.com/zhipijun1996/gunman-rush/blob/0c1d1e5f7641f6c8395f7acc39f658ffe9d82100/docs/evidence/pixel_light_study_02/README.md) |
| HIGH-DENSITY-TERRAIN-03 | 原生32px/32wu实验；通用碎纹/斜纹并未解决高级感 | [`7f332ff`](https://github.com/zhipijun1996/gunman-rush/blob/7f332fff1a51fb7439688f1cfb79252d2f6e498f/docs/evidence/high_density_terrain_03/README.md) |
| TERRAIN-DENSITY-04 | 同母版派生47格与同源粗细对照，保持灯光/角色控制变量 | [`73c9add`](https://github.com/zhipijun1996/gunman-rush/blob/73c9add5c5f6b1099a94254932280238a6290178/docs/evidence/terrain_density_04/README.md) |
| FINE-SPACE-05 | 用户选细：正式家园/平原及共享森林消费者接入细源，修可见足点、暖光/景深与HUD | [`efd7843`](https://github.com/zhipijun1996/gunman-rush/blob/efd784349efa31502cb428b14bde10ea517bdd9a/docs/evidence/fine_space_05/README.md) |
| DEPTH-FRAME-06 | 补丰富地标与可见前景；中景过满、显隐不稳留待后续 | [`4a41fd7`](https://github.com/zhipijun1996/gunman-rush/blob/4a41fd729ed06e6806826bf97ded3be5c9c817ed/docs/evidence/depth_frame_06/README.md) |
| SPATIAL-RHYTHM-07 | 局部风车/钟塔组与低草坡底景分离，沿路聚散、留白 | [`f554e6b`](https://github.com/zhipijun1996/gunman-rush/blob/f554e6bbea6c4f7282ed762a4880a92cae4e7918/docs/evidence/spatial_rhythm_07/README.md) |
| FOREGROUND-CONTINUITY-08 | 固定身份/尺寸、完整离屏回收、提前淡化与稳定恢复；整枝避让防切断 | [`6befe56`](https://github.com/zhipijun1996/gunman-rush/blob/6befe56b8802ac2472264b866deac1d7efdf649f/docs/evidence/foreground_continuity_08/README.md) |

## 当前采用的内容

- 共享[style-v5](creative_direction/bibles/style-continuity-20261022-v5.json)：地形原生32px/32wu、世界1wu采样/nearest；原47邻接及exact-boundary语义保持。角色、建筑、背景按实际尺度同屏处理，不能靠放大旧低清源冒充细粒度。
- 家园/平原的可见根部、克制暖点光与空气透视，多层背景复用；森林共享材质/角色等消费者同步，独立地区景层不因此自动通过。
- 地标世界锚定、局部聚落与无建筑窗口交替，前景稳定稀疏；新增资源保留实际来源/许可和生成记录。
- 前景动态提前避让，静态UI/边缘局部保护；长枝按完整保护范围整枝淡化。回收不受当帧透明度影响。

主要运行路径：`scripts/underworld_plains/`（terrain、presentation、parallax、scenery、foreground、landmark_sequence），`shaders/`，`assets/underworld_plains/`，家园/平原正式接入与共享森林消费者。工具入口及依赖以各轮README与Git差异为准，不用目录名猜消费者。

## 验证与交付状态

历史实际结果按各自精确源保留，不冒称本轮重跑：05正式30定位图及地形GPU/支撑/多视口等定向回归、本地Web五入口；07正式30图和连续镜头；08真实Home506采样/23身份无失败、387080严格保护像素差0且有非零前景贡献、六正式窗（Home与两图×两Seed）。独立评审仅其写明的技术/静图范围。

当前公开[08的24秒实机视频与截图](https://zhipijun1996.github.io/gunman-rush-previews/reviews/FOREGROUND-CONTINUITY-08/6befe56/)，实际运行源6befe56，媒体完整字节与Chromium播放已验。历史[05](https://zhipijun1996.github.io/gunman-rush-previews/reviews/FINE-SPACE-05/efd7843/)、[06](https://zhipijun1996.github.io/gunman-rush-previews/reviews/DEPTH-FRAME-06/4a41fd7/)、[07](https://zhipijun1996.github.io/gunman-rush-previews/reviews/SPATIAL-RHYTHM-07/f554e6b/)仍保留。这些是观察评审页，不是可玩Web更新。

公开可玩细粒度包此前被独立站900MiB容量与新仓库权限阻挡；保留本地已验证05 Web包，不能把它称为08包。完整CI/Harness未跑，完整战斗/全区通关、手机性能、最终美术与用户/设备认可仍未验。森林木台/苔草根台造型、家园标签对比等旧缺口未因前景修复自动关闭。

## 值得回流的skills改进

1. **修正实际冲突**：六份skills入口还写v4/16px，现指向用户已选v5；创作入口同步澄清历史与当前版本。原Bible/v4/v5原文字节与运行资源不改。
2. **规格四分法**：原图px、世界wu、表现采样、屏幕输出分开；扩充已有Asset Specification，区分全局规格/区域身份/资产接口。
3. **母版与合屏优先**：整套同族材质/接口再派生47；先正式黄金窗口，再扩资产家族。像素密度、材质大形、光照和构图分别归因。
4. **沿途构图与动态验证**：聚落/留白、可见根基、固定前景/淡化分责写回art/visual/scene/animation/region skills。此次具体地图坐标和时序数值不升格为所有区域规则。
5. **保持短反馈**：用户只要局部实验时，先交一个能判断的小样与必要短片，复用依赖不变的原证据，避免不断加验证和文档后才看画面。既有黄金、独审与来源规则已经具备，不另造一套技能或审批流程。

共用执行说明：[跨区域与像素美术稳定输出](quality/art_consistency_workflow.md)；直接填写[现有资产规格模板](templates/art_asset_specification.md)。这能减少规格/接口漂移与重复返工，无法保证AI每次生成都美观；视觉选择仍由正式合屏和用户反馈决定。

## 恢复与下一步

`git switch art/formal-fine-depth`，正式游戏用`bash tools/godot.sh --path .`。前景定向检查/电影入口见[08](evidence/foreground_continuity_08/README.md)。本次只对新增/修改文档链接、规范指向、原权威字节/运行写集不变与质量记录一致性做定向核对；没有重新录片、导出、部署或跑完整CI。

后续新区域从最新main独立工作线开始，明确需要继承的本分支提交；本分支未合main前，不能假定其他工作区已获得这里的细粒度实现和skills。先给一个跨区正式黄金窗口，表达当地材质/形体/生态/光色，复用当前角色和像素规格，再做同族扩展。
