---
name: game-iteration
description: 游戏需求到可玩切片的实现与验收；用于功能迭代、修复和玩法反馈。
---

# game-iteration

所有命令从仓库根目录运行。现行规则见 [AGENTS](../../../AGENTS.md) 与 [当前状态](../../../docs/current_state.md)；数值和玩法不在 skill 中重复定义。

1. 读仓库根目录下的 AGENTS.md、docs/current_state.md、docs/handoff.md 和对应契约；检查工作区，不覆盖用户改动。把最新需求转成玩家可观察结果，标明确认/候选/待定。
2. 用 docs/templates/iteration.md 记录一个可玩的切片、实际消费者、依赖、禁止回归项和技术/GUI/设备/主观完成条件。选择能独立验证的最小实现，不一次重写所有系统。
3. 创建适当分支，沿既有组件/局部服务实现；参数引用唯一配置。涉及地图、美术或整合时使用对应 skill。
4. 运行 python3 tools/harness.py --plan，检查自动范围，并执行必要 profile。玩法至少 gameplay；涉及视觉再 art；输入/保存/UI 补正式入口真实 GUI，不能靠脚本注入冒充玩家操作。
5. 每轮同时检查教学、探索、动作反馈、成长与结算是否连贯。保留失败轨迹；修复后跑受影响验证。手感、趣味性和设备评价分开记录，不用测试数量代替。
6. 更新任务、权威文档、精选证据和 handoff；技术完成但设备待验保持 awaiting-device/review。提交推送并创建 PR。合并/发布按用户授权和 AGENTS 执行，不凭历史授权扩大范围。

交付物：可玩切片、对应验证报告、失败/未验范围、可复现入口和下一步。
