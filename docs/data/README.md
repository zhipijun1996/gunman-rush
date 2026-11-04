# 具体数据

这里从开发者视角描述玩家可感知的对象行为、招式、反制和视听效果。数值只在实际配置维护；代码结构、字段映射和检查见 [模块导航](../project/module_map.md)。进度、验收和恢复留在 [当前任务](../project/tasks.md)。

| 对象 | 唯一设计入口 |
| --- | --- |
| 平原冲锋怪 | [plains_charger](enemies/plains_charger.md) |
| 森林敌人 | [生态与行为](enemies/forest.md) |
| 鸣铃巡游机 | [bellstrider](bosses/bellstrider.md) |
| 牧风者主动追压版 | [windkeeper](bosses/windkeeper.md) |
| 根铃守卫 | [rootbell_guardian](bosses/rootbell_guardian.md) |
| 棘冠女王版本 | [迁巢织场](bosses/thorn_queen_weave.md)、[Canopy](bosses/thorn_queen_canopy.md) |
| 武器／技能 | [武器](weapons.md)，共享动作入口见 [概览](player_actions.md) |
| H/W/D | [能力与恢复](abilities.md) |
| 道具／成长 | [道具](items.md) |
| 机关／危险／交互 | [世界对象](world_objects.md) |
| 声音 | [音频](audio.md)；各对象发声时机归对象正文 |
| 地区与 Boss 叙事 | [地区片段](story/regions.md)、[Boss动机](story/bosses.md)，时间规则唯一见 [剧情圣经](../bible/story.md) |

## 尚需完善

其余平原物种、森林各物种的完整动作／表现、旧 Boss 身份的实际消费者，以及道具／机关逐项细节，按选中的功能任务整合已有资料。不先创建空卡，也不把代码注册数量当作已完成内容。P17、未来技能和候选地图的选择仍按当前任务明确状态。

`creative_direction/` 是当前选择与技术引用的机器元数据，供现有创作工具核来源；它不另维护人类设计正文。原附件、旧版本和验收记录在 evidence，按需读取。
