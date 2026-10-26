# RUN-GEAR-01：正式局内肉鸽装备基础

- 基线：`origin/main @ 26e7f2a4459623f35613a857da8a75e89daa3e62`；独立分支`feature/run-gear-inventory`，PR面向main，不自动合并。
- 模式：System Engineering。沿用game-quality-gate、project-integration及既有Harness；本轮不运行无关美术生产。
- 目标：当前道具均能领取入包，在暂停构筑中装备／卸下／替换，负荷与实际效果一致；新增常规道具以Definition／效果组件扩充。
- 所有者：root负责DemoApp接线、正式流程、权威文档与交付；gear_core负责builds、奖励／商店及必要能力钳制；gear_ui负责DemoMenu／ItemCard及本次实测发现的菜单触屏滚动适配；gear_tests负责原测试语义迁移和装备专项；inventory_review只读独审，不修改生产代码。无重复写集。
- 保持：基础物理、核心能力授予、当前武器、伤害优先、随机流／Manifest、永久音符、交易收据、库存和既有测试门槛。
- 共享接口：RunInventory持有，EquipmentService装备与容量，BuildState只计算装备效果；保留旧入包门面以复用正式消费者。见[权威规则](../../rewards_and_builds.md)。
- G0失败条件：入包即生效、容量影响购买、部分换装／扣款、重开刷物品、卸下重装补飞行次数、生命道具免费回血、环境回退丢构筑、旧操作可提交。
- 验证：窄parse→实际Player模型／交易专项→原core／时间能量／UI→正式DemoApp地图／回退／死亡→真实Godot连续操作与可交付Preview或短录屏。Harness production_plan自动升级full是影响规划，计划不算执行；本地只报实跑范围，完整PR CI另列。
- GUI：PC鼠标、手柄焦点、横屏触控与小屏滚动分别采证；实体安卓和用户体验无证据则unverified。
- 交付：按用户本轮允许的二选一，提供可下载的真实Godot完整操作短片，绑定冻结源码。固定开发三房间用自然键鼠操作完整演示，正式地图领取／换装／触控／跨图／死亡另有实际App集成专项；不把开发片冒充正式区域自然全路线。已有Preview站重建后占用约898.7/900MiB，本轮不删除旧入口或扩大托管预算。
- 当前阶段：实现中；失败与修复保留在build/run_gear，精选证据进入docs/evidence/run_gear_01。
