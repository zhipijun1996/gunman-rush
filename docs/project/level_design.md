# 关卡设计与体验验证

本页规定 `tools/level_design.py` 的离线设计和体验证据职责。创作任务从 [区域入口](content_pipeline.md) 加载选定 Bible，执行协议见 [生产循环](production_loop.md)，游戏状态与当前消费者见 [模块导航](module_map.md)。

## 数据与职责

设计合同描述空间意图、挑战／遭遇、奖励、地标、能力和恢复条件；真实 Manifest 描述指定消费者和 Seed 的生成结果；连续 PlayerMotor 轨迹描述该输入、资源和相位下发生的行为。三者分别保存，设计声明不能冒充实际运行。

新地区先确认合法进入构筑、机制和差异，再做一个黄金场所；已有地区从当前正式消费者和最严重的实机问题开始。地形、敌人、机关、奖励、画面及声音共同设计，先验证单场所，再验证相邻组合、返程和整图。Foundry 晋级仅限开发工坊，正式集成须单独确认消费者和验收范围。

## 实际入口

```sh
python3 tools/level_design.py --help
python3 tools/level_design.py validate --help
python3 tools/level_design.py capture --help
python3 tools/level_design.py analyze --help
python3 tools/level_design.py compare --help
python3 tools/level_design.py experience --help
python3 tools/level_design.py route --request '优化风铃平原' --output build/creative/optimize.json
python3 tools/production_loop.py --mission build/creative/optimize.json
```

route 只生成带地区绑定、具体 Skill、检查和写集的有界任务。新地区缺已选 Bible 时先预制作。当前视觉任务使用 `visual_director.route`；历史配方仅用于参考，不能执行。运行手动专项用 `tools/harness.py --list` 与 `--check <ID>`；日常 CI 固定四项，不存在 full／gameplay／art 自动 profile。

## 证据与判断

| 证据 | 可以证明的范围 |
| --- | --- |
| 设计 validate | 字段、引用和声明符合合同 |
| 正式 Manifest | 该源、消费者与 Seed 的实际生成结果 |
| 连续 Motor 轨迹 | 记录能力、资源、输入和相位下的真实行为 |
| 静态重复／空白分析 | 指定模块或路线的候选问题 |
| 同源正常速度音画 | 实际构图、动态落点、可读性及声音的审查材料 |
| 独立审查／真人／设备 | 明确参与者、设备、版本和范围的实际结论 |

结构签名不同不等于玩法多样，轨迹到达不等于有趣，截图不等于连续可玩。保存完整 Seed／Manifest、源与配置 SHA、能力、原始轨迹、失败帧、日志和诊断。前后对照保持消费者、策略和条件可比，不能借用旧录像签署新源码。

新检测须有正常例与故意失败例：未来能力、不可达／循环锁、同动作换 ID、连续资源不足、长无判断路段、空报告与错版本。反例定位真实 route／edge／module／帧。未实现机制只能作设计提案，缺少用户、真机或完整正式消费者证据的维度保留未验证。

阈值按地区、挑战类别和目标设备校准；记录测量单位和来源，不设置没有依据的综合趣味分。普通挑战强调容错和学习，进阶强调自愿风险收益，大师强调原创长链与可学失败，三类都需要实际空间和画面验证。
