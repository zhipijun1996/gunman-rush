---
name: godot-room-art
description: 为失序之钟的固定世界房间制作、扩充和复用 Underworld 细像素地形、区域道具、多层景深、光照与环境粒子。与 godot-recoil-level-design 分工；按 Visual Bible 和区域 Bible 处理真实房间。
---

# Godot 房间美术

视觉与关卡的规则拥有者仍是项目现行 Visual Bible、区域 Bible、房间合同和真实 Godot 消费者；本技能提供制作方法，不另外建立第二套设计权威。

## 首先读取

1. 读根 `AGENTS.md`，定位目标区域、房间ID和当前分支。按需查 `docs/bible/visual_bible.md`、目标区域 Bible 与实际房间上下文，不全文读取世界数据。
2. 读 [版本与视觉证据](references/versioned-style-standard.md) 与 [组装方法](references/godot-assembly.md)。恢复素材读 [Cloud接续](references/cloud-portability.md)，区域选择读references/region-catalog.json；47邻接、补素材和复用验收分别见references/autotile-47.md、asset-contract.md、quality-and-reuse.md。
3. 使用assets/approved-five-regions.png、approved-tiles-and-props.png与current-plains-forest-v2.png恢复同一参考；NPC/休息站/收集动画按同风格制作，状态时序沿项目animation-vfx技能，不由动画结算。
4. 检查 `art/world-art-v2/assets/terrain47/manifest.json` 是否真的存在。不存在时须说明“素材尚未接入”，不可把参考参数写成已安装资产。

## 与关卡技能分工

`godot-recoil-level-design` 决定房间职责、能力、敌人、出入口、碰撞、路线与复位；本技能消费稳定的房间几何，决定材质、地标、光照、地形外观、平台附着前景和独立视差。修改实际玩法边界前回到关卡合同验证。

## 制作步骤

1. 确认相机、玩家身体高度、真实世界单位、地形碰撞。已有可玩灰盒先复用。
2. 用一个完整房间的大轮廓建立地点身份：地形体量、支撑关系、主要光线、远处地标与视觉留白。
3. 复用当前区域的地形、主构件、装饰与已认可材质。缺结构件时按端头、外角、内角、墙面、薄平台、台底、洞口的实际用途补画，并记录来源、尺寸、alpha、锚点。
4. 近景分为贴地形前景（世界速度1）与独立低矮近景（轻微视差、基座遮罩、角色避让）；远中景保持较低对比度与完整覆盖。不能把整屏前景截成硬直边。
5. 光源与实际发光物对齐；地形参与遮挡，同一光场影响附近材质与角色，保留必要的暗面。风点、草籽、孢子、火星在最终显示尺寸下检查运动可感知性。
6. 用真实场景与正常相机验地形边缘、目标动作、荆棘危险、镜头、跨房回访。分别报告 Canvas 拼装、Godot 无窗口检查、Godot 窗口画面，不能相互冒充。
7. 新素材、配方、实际渲染证据和版权来源随同一变更提交；长期规则只更新项目已有正文，任务状态归现有工作线。

## 交付

至少交付已接入素材、可编辑的正式房间或可明确复用的独立样例、所覆盖镜头的截图/短录屏、相关检查结果和未验证范围。先用同族样房校准，再验证不同几何的第二间房。按授权范围施工，不用漂亮静图代替完整玩法。
