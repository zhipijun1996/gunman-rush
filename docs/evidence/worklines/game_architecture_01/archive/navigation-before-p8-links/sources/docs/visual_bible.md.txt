# Visual Bible：新美术地基入口

## 2026-10-22 最新用户选择：统一细粒度

用户原话：“细粒度好看。确定使用细粒度，之后所有都统一，不统一的都修改。”共享规范现为 [style-v5](creative_direction/bibles/style-continuity-20261022-v5.json)：正式地形原生32px/32wu，世界表现1wu采样/nearest，47邻接和精确边界/物理语义保留；从高分母版整理细源，不能放大旧16px冒充。家园、平原及森林共享消费者同步；材质/生态/光色表达区域差异。新采用暖光、清透空气透视和稀疏前景，以正式合屏评价。旧v4的16px描述属于历史，原文、许可与原Bible字节保持不动。用户确认的是粒度方向，不是新内容最终美术或真机认可。实际范围与剩余问题见 [FINE-SPACE-05](evidence/fine_space_05/README.md)。

## 2026-10-19 最新覆盖：画风与分层

权威入口为 [美术地基 V1](art_foundation_v1.md)。旧的童话手绘定位、既有角色/地区母版、旧概念图及其继承关系全部退出本轮创意输入。新候选从零设计：轮廓清楚、统一材质与信息层级；参考 Spelunky 2、Rogue Legacy 2、Mario Maker 2 的模块表达方法。背景可精细多层；玩家层以 47-tile blob 为核心；装饰/灯光独立且服从玩法可读性。

下文保留历史记录用于溯源；凡涉及旧画风、旧母版、旧参考或与新 tile 流程冲突的制作规则均已失效，不作本轮输入。非美术玩法合同仍按各自最新权威执行。

---

# Visual Bible：原创手绘童话世界

> 2026-10-17 当前覆盖说明：用户不认可PR77整体B效果，已暂停B制作并[重新探索四方向](visual_development/directions_20261017/README.md)。下方B与旧地形认可均是历史范围；当前没有用户最终确认的新视觉母版。本轮保留PR77技术，不继承其颜色/材质/造型为前提，不将任何新概念晋级为强制标准。

本页整合当前全局视觉规范；已知缺陷与阶段历史仍见 [art_quality_target](art_quality_target.md)，世界/地区锚点见 [world_and_story](world_and_story.md)。用户已确定长期方向，不等于已认可任意现有母版或合屏。

## 全局设计语言

童话手绘、具有笔触和体积的自然地形，旧黄铜机械与有机苔草相互嵌合；温柔的表层与深处衰败形成情绪层次。原创轮廓、叙事物件和材质建立身份。研究参考作品的可读性/空间层次/动作方法，不复制其形象、地图、配色布局或资产。

角色保持母版的头身、剪影与重心；实际屏幕尺度下能辨识朝向、手部、枪口、脚底与空中姿态。武器独立瞄准与肩轴连续，方向翻转不更换比例。线条有粗细与手绘变化，外轮廓清晰，内部纹理不抢动作。布料柔软、岩层有断面、木材有纤维、黄铜有磨损，避免所有物体同一种亮塑料高光。

同一地区采用统一主光方向、阴影冷暖、对比和高光强度。移动/旋转物件不要烘焙只适合单朝向的强阴影；跨区域变化气氛和材质，保留人物比例、功能色和交互语言。

## 配色、空间与功能

| 层/对象 | 规范 | 实际合屏失败条件 |
| --- | --- | --- |
| 远景/中景/前景 | 远处大气透视、低对比；地形支撑边和角色优先；装饰不遮危险 | 背景抢主角、地平线竖向重复、角色融进背景 |
| 平原材质 | 草顶冷灰岩层、低饱和青绿远山、旧黄铜；沿已接入母版统一 | 模块间光照/笔触不同，像拼贴，岩填充规律重复 |
| 危险/安全/补给 | 功能色沿现有契约：危险红橙，射击青色/跳跃琥珀等保持；还依形状/动画区分 | 单靠颜色、装饰像平台、危险体积与显示不一致 |
| 可交互/奖励/UI | 明确可用/不可用/已消耗/接受结果；HUD 不盖落点 | 静态高亮冒充实际可交互、奖励图与真实效果不一致 |

## 黄金合屏与模块兼容

先用同一相机、真实角色/HUD/平台/机关/敌人和至少必要景深层完成区域黄金样板；保存实际尺寸截图、手机缩小视图与正常速度运动录像，记录用户原话及版本。母版通过范围只覆盖该样板；重大风格变化重新明确认可状态。

测试长短平台、左右端头、内外角、地表/地下填充、不同厚度、镜像、高低差、连续视差背景和装饰变体。常规覆材保持站立边、接缝净空、锚点与已验碰撞；显式授权的局部空间实验按[共同契约](creative_direction/README.md)联合重设并重新验证，不沿用旧物理通过。长平台铺贴/深竖井/相机平移能暴露接缝、重复纹理和背景不足，返工先定位具体工序。

## 母版与变体

按 [content_pipeline](content_pipeline.md) 顺序从确认母版拆件并生成变体。保存参考图哈希、工具/模型（未公开就说明）、提示词/编辑指令、处理参数、版本、用途和授权状态。资产分类与生成记录使用 [Art Specification](templates/art_asset_specification.md)。同一提示词不保证同一画风，必须比对比例、材质、受光和实际合屏。AI 自评美观不能写用户定稿。

可变尺寸地形的八方向边界、凹角、内部填充及变体连接口遵守 [content_pipeline](content_pipeline.md)。长度改变不能改变边缘材质、站立线或碰撞；实际随机合屏中验收。

## 已认可平原地形母版（2026-10-13）

用户明确认可 v5/v8 水粉石灰岩实际合屏并要求正式接入：低噪声黄绿苔草、暖白石灰岩、冷紫灰阴影，与既有角色和背景共同构成参考。沿用 assets/plains_v8 的材质与边界原图，不追认被拒的褐土/密花稿。复用制作及验收方法见 [地形契约](quality/terrain_tile_contract.md)；用户认可风格不等于设备性能验收。

## B方向实际制作范例

用户选定B“雨釉与偏心”：圆润低重心、盘筑陶形、蛋彩明暗；[版本与认可范围](../resources/visual_development/style_master.json)区分用户方向与候选母版。上节v5/v8是既有正式版本的历史认可，不强制新授权B实验继承石灰岩，也不表示B已替换正式生产池。

- 源参考：[B方向板](../assets/visual_development/proposals/b_board.png)与[B1源母版](../assets/visual_development/master/b1_master.png)。派生保持两者可追溯；单物继续编辑可增加上一步原图，不用它替代源母版。
- 同题对象板：[实际明暗原图](../assets/visual_development/props/value_block.png)→[实际材质编辑](../assets/visual_development/props/material_pass.png)，先固定大形/功能开口/重心，再画木、陶、金属差异。母版图内印出的步骤只是示意，不算真实多轮制作。
- [原生画面paintover目标](../assets/visual_development/master/paintover_target.png)来自实际画面，但仍是目标图；由[候选catalog](../resources/visual_development/candidate.json)逐项映射独立源图、region、比例、pivot/socket及真实节点，不能把目标图贴满游戏屏幕宣称实现。
- [对象家族原始规格](../assets/visual_development/props/family.json)保留两次多物打包失败后改独立树/屋派生的原因。尺寸/alpha实测决定非网格region；内接socket不是最外可站边，必须与真实碰撞端分别校准。
- [环境原始连接规格](../assets/visual_development/environment/connections_family.json)保留等格/padding失败、误画underside及未校准端头。两个同法失败后改为单功能生成，不能再堆atlas或降阈值追认；[新连续草甸原图](../assets/visual_development/environment/continuous_meadow.png)及[来源](../assets/visual_development/environment/continuous_meadow.record.json)只承担远层连续地面，不承担碰撞或整屏关卡。

当前地形制作入口为[连续截面与端转面范例](evidence/painted_terrain/recipe.md)及[候选catalog](../resources/visual_development/painted_terrain_candidate.json)，不是默认沿旧texture+rect覆材。04采用section_v2与meadow_v2的首整屏已获[静态/运动抽帧整体艺术限定接受](evidence/painted_terrain/independent-05-first-space-art-sample.md)，仅允许一次第二真实结构同家族验证，不强制重生成有效源；不是完整G2、用户或商业品质。
