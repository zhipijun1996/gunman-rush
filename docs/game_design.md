# 游戏设计

Gunman Rush 是横屏动作肉鸽，以反冲位移、精确平台操作和随机探索为核心。战斗服务于站位、空中资源和落点判断；奖励支线提供更深的可选技巧与构筑收益。

## 产品范围

正式入口为标题、可操作家园、平原两图、H／钩索权益、森林两图及开发边界。每地区第一图较易并有小Boss，第二图深化机制并有地区Boss。普通探索可绕过怪物；Boss遭遇按实体封场和胜利流程结算。

长期框架为S1–S6六阶段、16地区设计池，每次访问各阶段的一条合法路线。地区能力门槛见 [地区设计](design/player_actions/regions_v0.3.md)，实际开放与缺口见 [当前状态](current_state.md)。地图／能力候选不等于已开放内容。

## 核心体验

- 输入表达移动、跳跃、瞄准、射击和能力意图；唯一PlayerMotor处理碰撞运动。
- 基础一跳、一发空中弹药，命中与合法恢复事件支持动作衔接；射击不消费时间能量，空中瞄准慢时消费时间能量。
- 同一时刻装备一种武器家族。武器进化、H／W／D与随机道具分别承担攻击解法、移动能力和本局构筑。
- 主路依赖已授予能力并提供可读恢复；高收益及隐藏路线可要求更深入的技巧。
- 关卡变化体现在动作、决策、探索和视觉身份，而不只体现在坐标或Seed。

## 规则归属

| 主题 | 唯一设计入口 |
| --- | --- |
| 输入、动作与资源 | [操作](controls_contract.md)、[物理](player_mechanics.md)、[资源](combat_and_recharge.md) |
| 流程、随机与内容复现 | [运行与路线](run_and_routes.md)、[生成](procedural_generation.md) |
| 伤害与死亡 | [伤害回退](damage_and_respawn.md) |
| 本局奖励、背包与商店 | [奖励构筑](rewards_and_builds.md) |
| 家园与永久进度 | [家园保存](home_and_save.md) |
| 世界与剧情 | [世界入口](world_and_story.md) |
| 视觉与内容生产 | [Visual Bible](visual_bible.md)、[创作入口](creative_direction/README.md) |

数值由实际运行配置和Definition维护。设计已确认、候选平衡、运行实现及用户／设备认可分别记录；验证方法见 [Harness](harness.md)。
