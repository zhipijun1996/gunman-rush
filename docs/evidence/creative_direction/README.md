# 区域创作入口

## 当前权威

[Bible注册表](bibles/registry.json) 为每地区指定唯一当前Bible、方向文件及共享技术参考。用`current_bible.path`读已选设计，用`direction_path`读专业接口，用`shared_style_authority.path`读当前技术绑定；版本和完整性由注册表校验。

已选区域设计为 [风铃平原](bibles/1-windchime_plains_region_bible_v2.md) 与 [荆棘森林](bibles/2-thorn_forest_region_bible_v2.md)。方向选择、实现和用户／设备最终认可分别记录。当前产品范围见 [当前状态](../current_state.md)。

## 创作步骤

1. 按任务地区读取完整选定Bible，按相关性读取世界阶段、动作和真实消费者。已选方向直接执行，缺Bible时先完成带提案状态的设计稿并经原注册／审查准入。
2. 用真实玩家行为和完整镜头设计一个黄金场所：地形、敌人、机关、奖励、画面与声音共同表达主题。
3. 各专业明确写集、接口和预算，先完成黄金玩法与合屏，再推广到模块族和不同空间。共享画风与区域差异见 [Visual Bible](../visual_bible.md)。
4. 检查设计价值、真实Motor、正式消费者、正常速度音画及独审。局部问题返工；方向不成立或预算耗尽时交代停止／取舍与恢复状态。

源码或绑定变化先核受影响消费者与证据，再通过原工具完成版本迁移。原图、许可和来源按实际输入保留。BGM使用用户提供版本；SFX和环境动态由事件消费者驱动。

## 工具与证据

区域路由入口：`python3 tools/level_design.py route --help`；Bible与共享绑定：`python3 tools/region_creative_direction.py --help`。使用实际支持的CLI及注册检查。

质量阶段、十一维及证据要求见 [开发质量](../development_quality.md)，专业方法由相关Skill提供，任务恢复见 [协作交付](../cloud_production.md)。
