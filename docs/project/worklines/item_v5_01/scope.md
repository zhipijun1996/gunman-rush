# ITEM-V5-01 当前交接

目标：确定道具未决规则，再同步对象规范、配置与真实效果。进度与依赖唯一见 [任务表](../../tasks.md)。

- 规则入口：[道具](../../../data/items.md)、[奖励构筑](../../../bible/rewards_and_builds.md)；编辑与生成见 [道具维护](../../item_authoring.md)。
- 实现入口：[authoring](../../../../config/item_v5_authoring.json)、`game/loadout/`；当前配置已包含道具、成长与联动，旧实现来源为 `979dbb9ab5f04c82f9c605c775a5e92ee14f7141`，旧结果不认证当前源码。
- 待决定：P17 采用既有三级蓄力全速移动，还是装备后采用配置的等级阶梯速度；G19 是否以 Boss 作为精英，或建立独立精英资格。当前 Boss 计入只标为 implementation_candidate，不能从代码推定定案。
- 下一动作：确认上述取舍，直接重整 items.md 对应行为和 authoring，再生成运行目录并修实现；普通修正无需质量卡。
- 验证入口：`python3 tools/run_item_v5_tests.py`；未整体验收逐件表现、经济平衡或实体设备。原证据按需见 [来源](../../../evidence/quality/records/ITEM-V5-01.json)。
