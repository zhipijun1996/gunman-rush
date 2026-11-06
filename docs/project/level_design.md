# 关卡离线分析与体验验证

固定世界任务按 [当前交接](worklines/mv_migration/scope.md) 直接实施。先从 [世界输入](../data/world/README.md) 按room_id提取目标房、分区、邻接和相关对象，再按 [房间制作](../bible/room_authoring.md) 验证真实连接、回程与状态。代表样房闭环后再扩展，结构灰盒与完整内容分别验收。

本页定位 `tools/level_design.py` 保留的离线分析和旧原型回归工具。创作任务从 [区域入口](content_pipeline.md) 加载选定 Bible，游戏状态与当前消费者见 [模块导航](module_map.md)。仅显式选择通用执行器时才读取 [执行协议](production_loop.md)，手工mission声明`content_domain: fixed_world`并绑定本任务适用检查。

## 数据与职责

固定房间合同描述空间意图、挑战／遭遇、奖励、地标、能力和恢复条件。旧原型 Manifest 描述指定消费者和 Seed 的生成结果，仅供旧链回归；连续 PlayerMotor 轨迹描述指定输入、资源和相位下发生的行为。设计声明、旧生成结果和真实运行分别保存，不能互相代签。

地形、敌人、机关、奖励、画面及声音按当前任务范围共同设计。旧原型问题从实际消费者复现；Foundry等开发场所的结果仅证明其自身范围，不能作为固定世界房间接入证明。

## 实际入口

```sh
python3 tools/level_design.py --help
python3 tools/level_design.py validate --help
python3 tools/level_design.py capture --help
python3 tools/level_design.py analyze --help
python3 tools/level_design.py compare --help
python3 tools/level_design.py experience --help
python3 tools/world/room_context.py P-R03
```

`route_request`、`content_plan`及`visual_director.route`已退役，调用会报错，不生成新任务。历史配方仅作参考元数据，执行器拒绝执行。运行手动专项用 `tools/harness.py --list` 与 `--check <ID>`；日常 CI 固定四项，不存在 full／gameplay／art 自动 profile。

## 证据与判断

| 证据 | 可以证明的范围 |
| --- | --- |
| 设计 validate | 字段、引用和声明符合合同 |
| 旧原型 Manifest | 该旧源、消费者与 Seed 的实际生成结果 |
| 连续 Motor 轨迹 | 记录能力、资源、输入和相位下的真实行为 |
| 静态重复／空白分析 | 指定模块或路线的候选问题 |
| 同源正常速度音画 | 实际构图、动态落点、可读性及声音的审查材料 |
| 独立审查／真人／设备 | 明确参与者、设备、版本和范围的实际结论 |

结构签名不同不等于玩法多样，轨迹到达不等于有趣，截图不等于连续可玩。固定世界保存room_id／section_id、进入侧、状态、源与配置SHA、能力、原始轨迹、失败帧、日志和诊断；旧生成回归另保留Seed／Manifest。前后对照保持消费者、策略和条件可比，不能借用旧录像签署新源码。

新检测须有正常例与故意失败例：未来能力、不可达／循环锁、同动作换 ID、连续资源不足、长无判断路段、空报告与错版本。反例定位真实 route／edge／module／帧。未实现机制只能作设计提案，本次需要但尚未观察的维度保留未验证，不适用项省略。

阈值按地区、挑战类别和目标设备校准；记录测量单位和来源，不设置没有依据的综合趣味分。普通挑战强调容错和学习，进阶强调自愿风险收益，大师强调原创长链与可学失败，三类都需要实际空间和画面验证。
