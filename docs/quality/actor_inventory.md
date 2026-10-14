# 实际人物与动作覆盖（ACTOR-ACTIONS-01）

本轮范围是现有演员，武器仅普通枪/三连，能力H/W/D。来源为实际Studio实例盘点与现有正式入口；运行输出见最终证据目录。不存在多个已实现可玩角色，不自行发明名单。候选guard/moth及历史Guardian仍是开发消费者，不晋级正式随机池。

| 人物/变体 | 实际消费者 | 动作与本轮补充 |
| --- | --- | --- |
| Courier | 共享player.tscn；家园/正式平原/各Lab/ActionStudio | idle/run/短长跳/fall/瞄准/单发与三连反冲/落地/受伤/死亡；羽翼二跳、附墙/蹬墙/重贴、射钩/飞行/拉近/踢跳/落空；脚底锚点、握持枪口及状态衔接 |
| 家园Artisan | HomeScene实际显示的upgrade NPC | 呼吸待机保持脚底；无战斗/死亡合同。未显示的Wardrobe/Archivist仅数据，不冒充实际角色 |
| graybox_patrol_drone | patrol_drone.tscn；历史/Foundry/Studio | 巡逻、转向、命中与死亡；使用现有手绘动作图，连续权重与重心形变 |
| plains_charger | 同场景+charger Definition；正式平原/Studio | 蓄势、冲刺、阻挡、恢复、受伤、死亡；状态姿态过渡保持脚底 |
| plains_sentry/fan_sentry | 同场景+各自Definition；正式/Studio | 瞄准预警、单发/扇区射击、恢复、受伤、死亡；共用形象但行为与事件不同 |
| plains_hopper | 同场景+hopper Definition；正式/Studio | 蓄势、真实弧线跳扑、恢复/受伤/死亡，手绘姿态与速度倾斜连续 |
| plains_diver | 同场景+diver Definition；正式/Studio | 巡飞、俯冲预警、俯冲、归位、受伤/死亡，平滑倾斜/形变 |
| candidate_lure_guard/crosswind_moth | 开发ModuleEnemyPrototypes/Studio | 原有独立AI/手绘图集，预警/攻击/恢复/受伤/死亡，动画转换在process而非draw推进 |
| ClockworkGuardian | 历史开发Boss场景/Studio | 巡行、攻击预警、发射、阶段、受伤/死亡；平滑重心/脚底变形；修复已销毁弹体筛选异常 |
| Bellstrider | 正式第一图/Studio | 登场、滚轮、蓄势、冲刺、铃波、投铃、开芯、受伤/死亡；保留实际轮转/悬挂，死亡姿态连续 |
| Windkeeper | 正式第二图/Studio | 登场/阶段、预警、踩击、冲锋、旋刃、平台试炼、开芯、受伤/死亡；保留已有连续手绘形态/脚底与转子表现并实际回归 |

## 覆盖与边界

新增actor-actions套件验证共享运行、状态/资源、关键正反例、三端意图、30/60/120Hz机关枪和实际Studio的8敌人变体+3Boss，输出runtime_inventory。动作录像由同一Controller输入驱动，明确分段初始化，不宣称一条完整地区通关。正式入口复用同一Courier新表现；平原不自动授予H/W/D或三级技能，成长/存档仍后续系统。

每个动作都需要阶段、中断与转换证据；现有完整核心与地区回归继续执行。角色层表现只能由接受事件驱动，不能写运动/伤害。实时节点回收测量与引擎退出资源诊断分别保留；真机性能、最终连贯性/美术与用户认可不由自动检查替代。
