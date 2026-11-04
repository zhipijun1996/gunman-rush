# 森林敌人数据入口

森林方向由 [森林 Bible](../creative_direction/bibles/2-thorn_forest_region_bible_v2.md) 规定，正式默认与候选版本见 [当前状态](../current_state.md)。本页索引现有对象，不定义另一组生命／尺寸／速度／时长。按实际 Registry、资源和 placement 解释最终实例；资源存在不等于默认地图使用。

| 对象／职责 | 唯一机器资源 | 行为与数据缺口 |
| --- | --- | --- |
| 铃囊萤／移动钩索目标 | [forest_lantern.tres](../../resources/enemies/forest_lantern.tres) | 有限停驻／预告／迁移，真实授予 H 后才可借用；完整动作／表现规范待整理 |
| 棘籽哨／落区压力 | [forest_seed_sentry.tres](../../resources/enemies/forest_seed_sentry.tres) | 锁定空间、预告与种子落区按真实行为；伤害与支持面分别核对 |
| 树皮甲虫 | [forest_bark_beetle.tres](../../resources/enemies/forest_bark_beetle.tres) | 行为入口按 Registry 的 base 家族和实际 Definition；不从名字推定新 AI |
| 摆荚 | [forest_swing_pod.tres](../../resources/enemies/forest_swing_pod.tres) | 同上，完整职责、动作、反制和表现规范待整理 |
| 织棘蛛／线段封路 | [forest_thread_spider.tres](../../resources/enemies/forest_thread_spider.tres) | 预告、展线、持有、收线和恢复；线／身体分别提交伤害，几何与安全点须匹配 |
| 跨枝移动体／可选换岸 | [forest_crossbranch.tres](../../resources/enemies/forest_crossbranch.tres) | 实际转移岸与碰撞积分、停驻／起动／落定；不可把通用 hopper 弧线当同一行为 |
| 圣经织者／宿主枝条 | [forest_bible_weaver.tres](../../resources/enemies/forest_bible_weaver.tres) | 独立 weaver 行为与绑定几何、深度状态；完整对象规范待整理 |
| 复用平原冲锋怪 | [plains_charger.tres](../../resources/enemies/plains_charger.tres) | 规则唯一见 [冲锋怪规范](enemies/plains_charger.md)，森林只提供明确放置／覆写，不重复抄尺寸与时序 |

构建入口为 [EnemyBehaviorRegistry](../../game/enemies/enemy_behavior_registry.gd) → EnemyFactory／Actor；森林专用行为位于 `game/enemies/behaviors/forest_*`，实际场景和资源身份由注册表解析。通用 .tres 未覆写字段采用对应 Definition 的导出默认值，禁止从旧表格导回配置。

## 接入与验证

地图 placement、Manifest 和 Provider 决定出现、巡幅、转移岸、宿主及实例版本。激活安全区来自场景语义安全点与真实身体／攻击体积；生成排除区、AI 激活范围和玩家无敌是不同合同。

真实输入、PlayerMotor、武器及 FrameDamagePolicy 验证击杀／非击杀策略、可选奖励和返程。敌人和机关的组合要有可读观察与合法恢复；H 互动不能替代普通进入构筑的主路。数据字段和共享伤害语义分别引用其权威来源。

`enemy-structure-native` 核 Registry／Factory／身体链，`enemy-region-state` 核真实保存／恢复；代表正式遭遇、正常速度音画和设备按对象另验。旧 FOREST-DEPTH 任务的实验与失败在原工作线／证据，不能用某个候选报告签当前默认地图。
